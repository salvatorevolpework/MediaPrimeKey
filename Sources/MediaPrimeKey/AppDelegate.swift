import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let mediaKeys = MediaKeyController()
    private let musicPlayers = MusicPlayerController.shared
    private let defaults = UserDefaults.standard

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var enabledItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var spotifyItem: NSMenuItem!
    private var appleMusicItem: NSMenuItem!
    private var testItem: NSMenuItem!
    private var connectItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var permissionTimer: Timer?
    private var transientStatusWorkItem: DispatchWorkItem?

    private var isEnabled: Bool {
        get {
            defaults.object(forKey: "MediaKeysEnabled") == nil
                ? true
                : defaults.bool(forKey: "MediaKeysEnabled")
        }
        set { defaults.set(newValue, forKey: "MediaKeysEnabled") }
    }

    private var selectedPlayer: MusicPlayer {
        get {
            guard let stored = defaults.string(forKey: "SelectedPlayer"),
                  let player = MusicPlayer(rawValue: stored)
            else { return .spotify }
            return player
        }
        set { defaults.set(newValue.rawValue, forKey: "SelectedPlayer") }
    }

    private var showsStatusItem: Bool {
        get {
            defaults.object(forKey: "ShowsStatusItem") == nil
                ? true
                : defaults.bool(forKey: "ShowsStatusItem")
        }
        set { defaults.set(newValue, forKey: "ShowsStatusItem") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let stoppedLegacyApp = stopLegacyMediaSpot()
        configureStatusItem()

        mediaKeys.onCommand = { [weak self] command in
            self?.handle(command)
        }
        mediaKeys.onTapDisabled = { [weak self] in
            self?.showTransientStatus("Media keys reactivated")
        }

        statusItem.isVisible = showsStatusItem

        if stoppedLegacyApp {
            statusMenuItem.title = "Stopped the old MediaSpot app"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.applyEnabledState(requestPermission: true)
            }
        } else {
            applyEnabledState(requestPermission: true)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // Reopening the app is the escape hatch when its menu bar icon is hidden.
        showsStatusItem = true
        statusItem.isVisible = true
        refreshMenu()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        mediaKeys.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu()
    }

    private func stopLegacyMediaSpot() -> Bool {
        let legacyApplications = NSRunningApplication.runningApplications(
            withBundleIdentifier: "nl.mediaspot.app"
        )
        for application in legacyApplications {
            application.terminate()
        }
        return !legacyApplications.isEmpty
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = false
            statusItem.button?.image = icon
        } else {
            statusItem.button?.image = NSImage(
                systemSymbolName: "music.note",
                accessibilityDescription: "MediaPrimeKey"
            )
        }
        statusItem.button?.toolTip = "MediaPrimeKey — media keys for your music player"

        menu = NSMenu()
        menu.delegate = self

        statusMenuItem = NSMenuItem(title: "MediaPrimeKey", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(
            title: "Enable Media Keys",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        menu.addItem(enabledItem)

        let playerItem = NSMenuItem(
            title: "Music Player",
            action: nil,
            keyEquivalent: ""
        )
        let playerMenu = NSMenu()

        spotifyItem = NSMenuItem(
            title: "Spotify",
            action: #selector(selectSpotify),
            keyEquivalent: ""
        )
        spotifyItem.target = self
        playerMenu.addItem(spotifyItem)

        appleMusicItem = NSMenuItem(
            title: "Apple Music",
            action: #selector(selectAppleMusic),
            keyEquivalent: ""
        )
        appleMusicItem.target = self
        playerMenu.addItem(appleMusicItem)
        playerItem.submenu = playerMenu
        menu.addItem(playerItem)

        testItem = NSMenuItem(
            title: "Test Play/Pause",
            action: #selector(testPlayer),
            keyEquivalent: ""
        )
        testItem.target = self
        menu.addItem(testItem)

        menu.addItem(.separator())

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        connectItem = NSMenuItem(
            title: "Connect to Spotify…",
            action: #selector(connectPlayer),
            keyEquivalent: ""
        )
        connectItem.target = self
        menu.addItem(connectItem)

        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        let hideItem = NSMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideStatusItem),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MediaPrimeKey",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshMenu()
    }

    private func applyEnabledState(requestPermission: Bool) {
        permissionTimer?.invalidate()
        permissionTimer = nil

        guard isEnabled else {
            mediaKeys.stop()
            refreshMenu()
            return
        }

        guard MediaKeyController.hasAccessibilityPermission else {
            mediaKeys.stop()
            if requestPermission {
                MediaKeyController.requestAccessibilityPermission()
            }
            startPermissionPolling()
            refreshMenu()
            return
        }

        if !mediaKeys.start() {
            showTransientStatus("Media keys could not start")
        }
        refreshMenu()
    }

    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(
            withTimeInterval: 1.5,
            repeats: true
        ) { [weak self] timer in
            guard let self else { return }
            guard MediaKeyController.hasAccessibilityPermission else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.applyEnabledState(requestPermission: false)
            self.showTransientStatus("Media keys are active")
        }
    }

    private func handle(_ command: MediaCommand) {
        let player = selectedPlayer
        let action: String
        switch command {
        case .playPause: action = "Play/Pause → \(player.displayName)"
        case .next: action = "Next → \(player.displayName)"
        case .previous: action = "Previous → \(player.displayName)"
        }
        showTransientStatus(action)

        musicPlayers.perform(command, with: player) { [weak self] error in
            if let error {
                self?.presentControlError(error)
            }
        }
    }

    private func refreshMenu() {
        enabledItem?.state = isEnabled ? .on : .off
        spotifyItem?.state = selectedPlayer == .spotify ? .on : .off
        appleMusicItem?.state = selectedPlayer == .appleMusic ? .on : .off
        testItem?.title = "Test \(selectedPlayer.displayName)"
        connectItem?.title = "Connect to \(selectedPlayer.displayName)…"

        if !isEnabled {
            statusMenuItem?.title = "Disabled"
        } else if !MediaKeyController.hasAccessibilityPermission {
            statusMenuItem?.title = "Accessibility access required"
        } else if mediaKeys.isRunning {
            statusMenuItem?.title = musicPlayers.isRunning(selectedPlayer)
                ? "Active — \(selectedPlayer.displayName) is open"
                : "Active — \(selectedPlayer.displayName)"
        } else {
            statusMenuItem?.title = "Inactive"
        }

        if #available(macOS 13.0, *) {
            launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            launchAtLoginItem?.isHidden = true
        }
    }

    private func showTransientStatus(_ text: String) {
        transientStatusWorkItem?.cancel()
        statusMenuItem?.title = text

        let item = DispatchWorkItem { [weak self] in
            self?.refreshMenu()
        }
        transientStatusWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MediaPrimeKey"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentControlError(_ error: MusicPlayerControlError) {
        let alert = NSAlert()
        alert.messageText = "MediaPrimeKey"
        alert.informativeText = error.message
        alert.alertStyle = .warning

        if error.needsAutomationSettings {
            alert.addButton(withTitle: "Open Automation Settings")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.addButton(withTitle: "OK")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if error.needsAutomationSettings, response == .alertFirstButtonReturn {
            openSystemSettings(anchor: "Privacy_Automation")
        }
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        applyEnabledState(requestPermission: true)
    }

    @objc private func testPlayer() {
        let player = selectedPlayer
        musicPlayers.perform(.playPause, with: player) { [weak self] error in
            if let error {
                self?.presentControlError(error)
            } else {
                self?.showTransientStatus("\(player.displayName) is working")
            }
        }
    }

    @objc private func connectPlayer() {
        let player = selectedPlayer
        musicPlayers.requestAutomationPermission(for: player) { [weak self] error in
            if let error {
                self?.presentControlError(error)
            } else {
                self?.showTransientStatus("\(player.displayName) is connected")
            }
        }
    }

    @objc private func selectSpotify() {
        selectPlayer(.spotify)
    }

    @objc private func selectAppleMusic() {
        selectPlayer(.appleMusic)
    }

    private func selectPlayer(_ player: MusicPlayer) {
        selectedPlayer = player
        refreshMenu()
        showTransientStatus("Opening \(player.displayName)…")
        musicPlayers.requestAutomationPermission(for: player) { [weak self] error in
            if let error {
                self?.presentControlError(error)
            } else {
                self?.showTransientStatus("\(player.displayName) is ready")
            }
        }
    }

    @objc private func hideStatusItem() {
        showsStatusItem = false
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.isVisible = false
        }
    }

    @objc private func openAccessibilitySettings() {
        MediaKeyController.requestAccessibilityPermission()
        openSystemSettings(anchor: "Privacy_Accessibility")
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            presentError("Launch at Login could not be changed: \(error.localizedDescription)")
        }
        refreshMenu()
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
