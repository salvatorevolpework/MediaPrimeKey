import AppKit
import ApplicationServices

// Quartz does not publish a Swift enum case for NX_SYSDEFINED (raw value 14).
private let systemDefinedEventType = CGEventType(rawValue: 14)!

enum MediaCommand: Int, Equatable {
    case playPause = 16
    case next = 17
    case previous = 18
}

enum MediaKeyDecoder {
    static func isManagedKey(data1: Int) -> Bool {
        MediaCommand(rawValue: keyCode(fromData1: data1)) != nil
    }

    static func command(fromData1 data1: Int) -> MediaCommand? {
        let flags = data1 & 0x0000_FFFF
        let state = (flags & 0x0000_FF00) >> 8
        let isKeyDown = state == 0x0A
        let isRepeat = (flags & 0x1) == 1

        guard isKeyDown, !isRepeat else { return nil }
        return MediaCommand(rawValue: keyCode(fromData1: data1))
    }

    private static func keyCode(fromData1 data1: Int) -> Int {
        (data1 & 0xFFFF_0000) >> 16
    }
}

private let mediaKeyTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<MediaKeyController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return controller.handle(type: type, event: event)
}

final class MediaKeyController {
    var onCommand: ((MediaCommand) -> Void)?
    var onTapDisabled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool { eventTap != nil }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard Self.hasAccessibilityPermission else { return false }

        let mask = CGEventMask(1) << systemDefinedEventType.rawValue
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: pointer
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            DispatchQueue.main.async { [weak self] in
                self?.onTapDisabled?()
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == systemDefinedEventType,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8,
              MediaKeyDecoder.isManagedKey(data1: nsEvent.data1)
        else {
            return Unmanaged.passUnretained(event)
        }

        if let command = MediaKeyDecoder.command(fromData1: nsEvent.data1) {
            DispatchQueue.main.async { [weak self] in
                self?.onCommand?(command)
            }
        }

        // Suppress both key-down and key-up for the three managed media keys.
        return nil
    }

    deinit {
        stop()
    }
}
