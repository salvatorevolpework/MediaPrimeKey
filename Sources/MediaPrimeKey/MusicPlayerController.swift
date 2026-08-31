import AppKit
import Carbon

struct PlayerAppleEvent {
    let eventClass: AEEventClass
    let eventID: AEEventID
}

private func automationPermissionStatus(for processIdentifier: pid_t) -> OSStatus {
    var processIdentifier = processIdentifier
    var descriptor = AEAddressDesc()
    let createStatus = AECreateDesc(
        DescType(typeKernelProcessID),
        &processIdentifier,
        MemoryLayout<pid_t>.size,
        &descriptor
    )

    guard createStatus == noErr else { return OSStatus(createStatus) }
    defer { AEDisposeDesc(&descriptor) }

    return AEDeterminePermissionToAutomateTarget(
        &descriptor,
        AEEventClass(typeWildCard),
        AEEventID(typeWildCard),
        true
    )
}

enum MusicPlayer: String, CaseIterable {
    case spotify
    case appleMusic

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }

    func appleEvent(for command: MediaCommand, startPlayback: Bool) -> PlayerAppleEvent {
        let eventClass: AEEventClass = self == .spotify
            ? 0x7370_6679 // 'spfy'
            : 0x686F_6F6B // 'hook'

        let eventID: AEEventID
        switch command {
        case .playPause:
            eventID = startPlayback
                ? 0x506C_6179 // 'Play'
                : 0x506C_5073 // 'PlPs'
        case .next:
            eventID = 0x4E65_7874 // 'Next'
        case .previous:
            eventID = 0x5072_6576 // 'Prev'
        }

        return PlayerAppleEvent(eventClass: eventClass, eventID: eventID)
    }
}

enum MusicPlayerControlError: Error {
    case notInstalled(MusicPlayer)
    case launchFailed(MusicPlayer, String)
    case automationPermission(MusicPlayer)
    case scriptFailed(MusicPlayer, String)

    var message: String {
        switch self {
        case .notInstalled(let player):
            return "\(player.displayName) is not installed."
        case .launchFailed(let player, let detail):
            return "\(player.displayName) could not be opened. \(detail)"
        case .automationPermission(let player):
            return "Allow MediaPrimeKey to control \(player.displayName) in System Settings → Privacy & Security → Automation."
        case .scriptFailed(let player, let detail):
            return "\(player.displayName) could not be controlled. \(detail)"
        }
    }

    var needsAutomationSettings: Bool {
        if case .automationPermission = self { return true }
        return false
    }
}

final class MusicPlayerController {
    typealias Completion = (MusicPlayerControlError?) -> Void

    static let shared = MusicPlayerController()

    private struct Request {
        let player: MusicPlayer
        let event: PlayerAppleEvent?
        let completion: Completion?
        var retryCount = 0
    }

    private let permissionQueue = DispatchQueue(
        label: "nl.mediaprimekey.automation-permission",
        qos: .userInitiated
    )
    private var requests: [Request] = []
    private var isProcessing = false

    func isInstalled(_ player: MusicPlayer) -> Bool {
        NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: player.bundleIdentifier
        ) != nil
    }

    func isRunning(_ player: MusicPlayer) -> Bool {
        runningApplication(for: player) != nil
    }

    func perform(
        _ command: MediaCommand,
        with player: MusicPlayer,
        completion: Completion? = nil
    ) {
        let event = player.appleEvent(
            for: command,
            startPlayback: command == .playPause && !isRunning(player)
        )
        enqueue(Request(player: player, event: event, completion: completion))
    }

    func requestAutomationPermission(
        for player: MusicPlayer,
        completion: Completion? = nil
    ) {
        enqueue(Request(
            player: player,
            event: nil,
            completion: completion
        ))
    }

    private func enqueue(_ request: Request) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.enqueue(request) }
            return
        }

        requests.append(request)
        processNextRequest()
    }

    private func processNextRequest() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isProcessing, !requests.isEmpty else { return }
        isProcessing = true

        let request = requests.removeFirst()
        ensureRunning(request.player) { [weak self] error in
            guard let self else { return }
            if let error {
                self.finish(request, error: error)
                return
            }

            self.determineAutomationPermission(for: request.player) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.finish(request, error: error)
                    return
                }
                if request.event == nil {
                    self.finish(request, error: nil)
                } else {
                    self.execute(request)
                }
            }
        }
    }

    private func ensureRunning(
        _ player: MusicPlayer,
        completion: @escaping (MusicPlayerControlError?) -> Void
    ) {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: player.bundleIdentifier
        ) else {
            completion(.notInstalled(player))
            return
        }

        guard runningApplication(for: player) == nil else {
            completion(nil)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false

        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: configuration
        ) { [weak self] application, error in
            DispatchQueue.main.async {
                guard self != nil else { return }
                if let error {
                    completion(.launchFailed(player, error.localizedDescription))
                    return
                }
                guard application != nil else {
                    completion(.launchFailed(player, "macOS did not return an application."))
                    return
                }

                // The process exists here, but its AppleScript dictionary may need
                // a brief moment before accepting the first command.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    completion(nil)
                }
            }
        }
    }

    private func determineAutomationPermission(
        for player: MusicPlayer,
        completion: @escaping (MusicPlayerControlError?) -> Void
    ) {
        guard let processIdentifier = runningApplication(for: player)?.processIdentifier else {
            completion(.launchFailed(player, "The player is not running yet."))
            return
        }

        permissionQueue.async {
            let permissionStatus = automationPermissionStatus(
                for: processIdentifier
            )

            DispatchQueue.main.async {
                if permissionStatus == noErr {
                    completion(nil)
                } else if permissionStatus == -1743 || permissionStatus == -1744 {
                    completion(.automationPermission(player))
                } else {
                    completion(.scriptFailed(
                        player,
                        "The automation check returned error \(permissionStatus)."
                    ))
                }
            }
        }
    }

    private func execute(_ request: Request) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let playerEvent = request.event,
              let application = runningApplication(for: request.player)
        else {
            retryOrFinish(request, errorNumber: -600, detail: "The player is not running.")
            return
        }

        let target = NSAppleEventDescriptor(
            processIdentifier: application.processIdentifier
        )
        let event = NSAppleEventDescriptor(
            eventClass: playerEvent.eventClass,
            eventID: playerEvent.eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            _ = try event.sendEvent(
                options: [.noReply, .neverInteract],
                timeout: 2.0
            )
            finish(request, error: nil)
        } catch let sendError as NSError {
            retryOrFinish(
                request,
                errorNumber: sendError.code,
                detail: sendError.localizedDescription
            )
        }
    }

    private func retryOrFinish(
        _ request: Request,
        errorNumber: Int,
        detail: String
    ) {
        if (errorNumber == -600 || errorNumber == -1712), request.retryCount == 0 {
            var retry = request
            retry.retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.execute(retry)
            }
            return
        }

        if errorNumber == -1743 || errorNumber == -1744 {
            finish(request, error: .automationPermission(request.player))
            return
        }

        finish(request, error: .scriptFailed(request.player, detail))
    }

    private func finish(_ request: Request, error: MusicPlayerControlError?) {
        dispatchPrecondition(condition: .onQueue(.main))
        request.completion?(error)
        isProcessing = false
        processNextRequest()
    }

    private func runningApplication(for player: MusicPlayer) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(
            withBundleIdentifier: player.bundleIdentifier
        ).first { !$0.isTerminated }
    }
}
