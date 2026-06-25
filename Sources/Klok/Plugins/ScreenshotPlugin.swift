import AppKit
import AVFoundation
import AVKit
import Carbon
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import UserNotifications

final class ScreenshotPlugin: KlokPlugin {
    let id = "screenshot"
    let name = "Screenshot"
    let version = "0.2.0"
    let isConfigurable = true

    private weak var context: PluginContext?
    private var session: ScreenshotSessionController?
    private var recording: ScreenRecordingController?
    private var countdownWindow: ScreenRecordingCountdownWindow?
    private var controlWindow: ScreenRecordingControlWindow?
    private var boundsWindow: ScreenRecordingBoundsWindow?
    private var previewWindows: [ScreenRecordingPreviewWindowController] = []
    private var globalHotKey: GlobalHotKey?

    func activate(context: PluginContext) {
        self.context = context
        context.menuRegistry.addItem(title: L10n.pluginScreenshotMenu, location: .statusMenu) { [weak self] in
            self?.startCapture()
        }
        context.menuRegistry.addItem(title: L10n.pluginScreenshotMenu, location: .clockMenu) { [weak self] in
            self?.startCapture()
        }
        registerShortcut()
    }

    func deactivate() {
        unregisterShortcut()
        session?.cancel()
        session = nil
        recording?.stop()
        recording = nil
        countdownWindow?.close()
        countdownWindow = nil
        controlWindow?.close()
        controlWindow = nil
        boundsWindow?.close()
        boundsWindow = nil
    }

    func showConfiguration(parentWindow: NSWindow?) {
        let shortcut = currentShortcut()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 126))

        let enabled = NSButton(checkboxWithTitle: L10n.pluginScreenshotShortcutEnabled, target: nil, action: nil)
        enabled.state = shortcut.isEnabled ? .on : .off
        enabled.frame = NSRect(x: 0, y: 100, width: 220, height: 22)
        view.addSubview(enabled)

        let keyLabel = NSTextField(labelWithString: L10n.pluginScreenshotShortcutKey)
        keyLabel.frame = NSRect(x: 0, y: 68, width: 76, height: 20)
        keyLabel.alignment = .right
        view.addSubview(keyLabel)

        let keyField = NSTextField(string: shortcut.key.uppercased())
        keyField.frame = NSRect(x: 86, y: 66, width: 52, height: 24)
        keyField.placeholderString = "A"
        view.addSubview(keyField)

        let command = modifierCheckbox(L10n.pluginScreenshotShortcutCommand, selected: shortcut.modifiers.contains(.command), x: 0, y: 34)
        let shift = modifierCheckbox(L10n.pluginScreenshotShortcutShift, selected: shortcut.modifiers.contains(.shift), x: 78, y: 34)
        let control = modifierCheckbox(L10n.pluginScreenshotShortcutControl, selected: shortcut.modifiers.contains(.control), x: 150, y: 34)
        let option = modifierCheckbox(L10n.pluginScreenshotShortcutOption, selected: shortcut.modifiers.contains(.option), x: 230, y: 34)
        [command, shift, control, option].forEach(view.addSubview)

        let hint = NSTextField(wrappingLabelWithString: L10n.pluginScreenshotShortcutHint)
        hint.frame = NSRect(x: 0, y: 0, width: 300, height: 28)
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        view.addSubview(hint)

        let alert = NSAlert()
        alert.messageText = L10n.pluginScreenshotTitle
        alert.informativeText = L10n.pluginScreenshotConfigInfo
        alert.accessoryView = view
        alert.addButton(withTitle: L10n.btnOK)
        alert.addButton(withTitle: L10n.btnCancel)
        if let parentWindow {
            alert.beginSheetModal(for: parentWindow) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.saveShortcut(
                    isEnabled: enabled.state == .on,
                    key: keyField.stringValue,
                    command: command.state == .on,
                    shift: shift.state == .on,
                    control: control.state == .on,
                    option: option.state == .on
                )
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                saveShortcut(
                    isEnabled: enabled.state == .on,
                    key: keyField.stringValue,
                    command: command.state == .on,
                    shift: shift.state == .on,
                    control: control.state == .on,
                    option: option.state == .on
                )
            }
        }
    }

    private func startCapture() {
        guard session == nil, countdownWindow == nil, controlWindow == nil, boundsWindow == nil else {
            return
        }

        guard recording == nil else {
            context?.showAlert(title: L10n.pluginScreenRecordingTitle, message: L10n.pluginScreenRecordingAlreadyRunning)
            return
        }

        let newSession = ScreenshotSessionController(
            onCopy: { [weak self] in self?.notifyCopied() },
            onStartRecording: { [weak self] screen, rect, options in
                self?.startRecording(screen: screen, rect: rect, options: options)
            },
            onFinish: { [weak self] in self?.session = nil },
            onError: { [weak self] message in
                self?.context?.showAlert(title: L10n.pluginScreenshotFailed, message: message)
            }
        )
        session = newSession
        newSession.start()
    }

    private func startRecording(screen: NSScreen, rect: NSRect, options: ScreenRecordingOptions) {
        countdownWindow?.close()
        let countdown = ScreenRecordingCountdownWindow(screen: screen, selection: rect) { [weak self] in
            self?.countdownWindow = nil
            self?.beginRecording(screen: screen, rect: rect, options: options)
        }
        countdownWindow = countdown
        countdown.start()
    }

    private func beginRecording(screen: NSScreen, rect: NSRect, options: ScreenRecordingOptions) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Klok Recording \(Self.filenameTimestamp())")
            .appendingPathExtension(options.fileExtension)

        do {
            let controller = try ScreenRecordingController(screen: screen, rect: rect, outputURL: url, options: options) { [weak self] result in
                DispatchQueue.main.async {
                    self?.controlWindow?.close()
                    self?.controlWindow = nil
                    self?.boundsWindow?.close()
                    self?.boundsWindow = nil
                    self?.recording = nil
                    switch result {
                    case .success(let url):
                        self?.showRecordingPreview(url: url)
                    case .failure(let error):
                        self?.context?.showAlert(title: L10n.pluginScreenRecordingFailed, message: error.localizedDescription)
                    }
                }
            }
            recording = controller
            try controller.start()
            let bounds = ScreenRecordingBoundsWindow(screen: screen, selection: rect)
            boundsWindow = bounds
            bounds.show()
            let control = ScreenRecordingControlWindow(maxDuration: options.maxDuration) { [weak self] in
                self?.stopRecording()
            }
            controlWindow = control
            control.show()
        } catch {
            context?.showAlert(title: L10n.pluginScreenRecordingFailed, message: error.localizedDescription)
        }
    }

    private func stopRecording() {
        guard let recording else {
            context?.showAlert(title: L10n.pluginScreenRecordingTitle, message: L10n.pluginScreenRecordingNotRunning)
            return
        }
        recording.stop()
    }

    private func showRecordingPreview(url: URL) {
        let controller = ScreenRecordingPreviewWindowController(url: url) { [weak self] controller in
            self?.previewWindows.removeAll { $0 === controller }
        }
        previewWindows.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func notifyCopied() {
        let content = UNMutableNotificationContent()
        content.title = L10n.pluginScreenshotTitle
        content.body = L10n.pluginScreenshotCopied
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func notifyRecordingSaved() {
        let content = UNMutableNotificationContent()
        content.title = L10n.pluginScreenRecordingTitle
        content.body = L10n.pluginScreenRecordingSaved
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }

    private func modifierCheckbox(_ title: String, selected: Bool, x: CGFloat, y: CGFloat) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.state = selected ? .on : .off
        button.frame = NSRect(x: x, y: y, width: 80, height: 22)
        return button
    }

    private func currentShortcut() -> ScreenshotShortcut {
        guard let context else { return .default }
        return ScreenshotShortcut(
            isEnabled: context.settings.bool(pluginID: id, key: "shortcut.enabled", default: true),
            key: context.settings.string(pluginID: id, key: "shortcut.key", default: ScreenshotShortcut.default.key),
            modifiers: ScreenshotShortcut.Modifiers(rawValue: context.settings.integer(pluginID: id, key: "shortcut.modifiers", default: ScreenshotShortcut.default.modifiers.rawValue))
        ).normalized
    }

    private func saveShortcut(isEnabled: Bool, key: String, command: Bool, shift: Bool, control: Bool, option: Bool) {
        guard let context else { return }
        var modifiers: ScreenshotShortcut.Modifiers = []
        if command { modifiers.insert(.command) }
        if shift { modifiers.insert(.shift) }
        if control { modifiers.insert(.control) }
        if option { modifiers.insert(.option) }

        let shortcut = ScreenshotShortcut(isEnabled: isEnabled, key: key, modifiers: modifiers).normalized
        context.settings.setBool(shortcut.isEnabled, pluginID: id, key: "shortcut.enabled")
        context.settings.setString(shortcut.key, pluginID: id, key: "shortcut.key")
        context.settings.setInteger(shortcut.modifiers.rawValue, pluginID: id, key: "shortcut.modifiers")
        registerShortcut()
    }

    private func registerShortcut() {
        unregisterShortcut()
        let shortcut = currentShortcut()
        guard shortcut.isEnabled, !shortcut.key.isEmpty else { return }
        globalHotKey = GlobalHotKey(shortcut: shortcut) { [weak self] in
            self?.startCapture()
        }
    }

    private func unregisterShortcut() {
        globalHotKey = nil
    }
}

private struct ScreenshotShortcut {
    struct Modifiers: OptionSet {
        let rawValue: Int

        static let command = Modifiers(rawValue: 1 << 0)
        static let shift = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let option = Modifiers(rawValue: 1 << 3)
    }

    static let `default` = ScreenshotShortcut(isEnabled: true, key: "a", modifiers: [.command, .control])

    let isEnabled: Bool
    let key: String
    let modifiers: Modifiers

    var normalized: ScreenshotShortcut {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let first = trimmed.first.map(String.init) ?? ScreenshotShortcut.default.key
        return ScreenshotShortcut(isEnabled: isEnabled, key: first, modifiers: modifiers)
    }

    func matches(_ event: NSEvent) -> Bool {
        guard let eventKey = event.charactersIgnoringModifiers?.lowercased(), eventKey == key else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command) == modifiers.contains(.command)
            && flags.contains(.shift) == modifiers.contains(.shift)
            && flags.contains(.control) == modifiers.contains(.control)
            && flags.contains(.option) == modifiers.contains(.option)
    }

    var carbonKeyCode: UInt32? {
        Self.carbonKeyCodes[key]
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        return value
    }

    private static let carbonKeyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
        "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33,
        "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "`": 50
    ]
}

private final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init?(shortcut: ScreenshotShortcut, action: @escaping () -> Void) {
        guard let keyCode = shortcut.carbonKeyCode else { return nil }
        self.action = action

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    hotKey.action()
                }
                return noErr
            },
            1,
            &eventSpec,
            selfPointer,
            &handlerRef
        )
        guard handlerStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B4C4F4B), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}

private final class ScreenshotSessionController {
    private var windows: [ScreenshotOverlayWindow] = []
    private var optionsPanel: ScreenRecordingOptionsPanel?
    private var permissionCheckWorkItem: DispatchWorkItem?
    private var isFinished = false
    private let onCopy: () -> Void
    private let onStartRecording: ((NSScreen, NSRect, ScreenRecordingOptions) -> Void)?
    private let onFinish: () -> Void
    private let onError: (String) -> Void

    init(
        onCopy: @escaping () -> Void,
        onStartRecording: ((NSScreen, NSRect, ScreenRecordingOptions) -> Void)?,
        onFinish: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onCopy = onCopy
        self.onStartRecording = onStartRecording
        self.onFinish = onFinish
        self.onError = onError
    }

    func start() {
        requestScreenCaptureAccess { [weak self] allowed in
            guard let self, !self.isFinished else { return }
            guard allowed else {
                self.onError(L10n.pluginScreenshotPermissionHint)
                self.finish()
                return
            }
            self.startAfterPermissionGranted()
        }
    }

    private func startAfterPermissionGranted() {
        let windowCandidates = Self.windowCandidates()
        let snapshots = NSScreen.screens.compactMap { screen -> ScreenSnapshot? in
            guard let image = Self.capture(screen: screen) else { return nil }
            return ScreenSnapshot(
                screen: screen,
                image: image,
                windowCandidates: Self.localWindowCandidates(for: screen, candidates: windowCandidates)
            )
        }

        guard !snapshots.isEmpty else {
            onError(L10n.pluginScreenshotPermissionHint)
            finish()
            return
        }

        for snapshot in snapshots {
            let window = ScreenshotOverlayWindow(snapshot: snapshot)
            window.overlayView.onCancel = { [weak self] in self?.cancel() }
            window.overlayView.onCopy = { [weak self, weak window] rect in
                guard let self, let window else { return }
                self.copySelection(rect, from: window.overlayView)
            }
            window.overlayView.onSave = { [weak self, weak window] rect in
                guard let self, let window else { return }
                self.saveSelection(rect, from: window.overlayView)
            }
            if onStartRecording != nil {
                window.overlayView.onRecord = { [weak self, weak window] rect in
                    guard let self, let window else { return }
                    self.recordSelection(rect, from: window.overlayView)
                }
            }
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        NSCursor.crosshair.set()
    }

    func cancel() {
        finish()
    }

    private func copySelection(_ rect: NSRect, from view: ScreenshotOverlayView) {
        guard let image = view.croppedImage(for: rect) else {
            onError(L10n.pluginScreenshotFailed)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        onCopy()
        finish()
    }

    private func saveSelection(_ rect: NSRect, from view: ScreenshotOverlayView) {
        guard let image = view.croppedImage(for: rect),
              let data = image.pngData()
        else {
            onError(L10n.pluginScreenshotFailed)
            return
        }

        windows.forEach { $0.close() }
        windows.removeAll()
        NSCursor.arrow.set()

        let panel = NSSavePanel()
        panel.title = L10n.pluginScreenshotSave
        panel.nameFieldStringValue = "Screenshot \(Self.filenameTimestamp()).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.level = .modalPanel

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                self?.finish()
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                self?.finish()
            } catch {
                self?.onError(error.localizedDescription)
                self?.finish()
            }
        }
    }

    private func recordSelection(_ rect: NSRect, from view: ScreenshotOverlayView) {
        guard let onStartRecording else { return }
        let screen = view.screen

        windows.forEach { $0.close() }
        windows.removeAll()
        NSCursor.arrow.set()

        NSApp.activate(ignoringOtherApps: true)
        let panel = ScreenRecordingOptionsPanel { [weak self] options in
            guard let self else { return }
            self.optionsPanel = nil
            onStartRecording(screen, rect, options)
            self.finish()
        } onCancel: { [weak self] in
            self?.optionsPanel = nil
            self?.finish()
        }
        optionsPanel = panel
        panel.show()
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        permissionCheckWorkItem?.cancel()
        permissionCheckWorkItem = nil
        optionsPanel?.close()
        optionsPanel = nil
        windows.forEach { $0.close() }
        windows.removeAll()
        NSCursor.arrow.set()
        onFinish()
    }

    private static func capture(screen: NSScreen) -> CGImage? {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return CGDisplayCreateImage(id)
    }

    private static func windowCandidates() -> [GlobalWindowCandidate] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let currentPID = getpid()
        return rawWindows.compactMap { info in
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            guard ownerPID != currentPID else { return nil }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { return nil }

            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.05 else { return nil }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                return nil
            }
            guard bounds.width >= 32, bounds.height >= 32 else { return nil }

            return GlobalWindowCandidate(bounds: NSRectFromCGRect(bounds))
        }
    }

    private static func localWindowCandidates(
        for screen: NSScreen,
        candidates: [GlobalWindowCandidate]
    ) -> [WindowCandidate] {
        let screenFrame = screen.frame
        return candidates.compactMap { candidate in
            let flipped = NSRect(
                x: candidate.bounds.minX,
                y: screenFrame.maxY - candidate.bounds.maxY,
                width: candidate.bounds.width,
                height: candidate.bounds.height
            )
            let local = flipped.intersection(screenFrame)
            guard !local.isNull, local.width >= 6, local.height >= 6 else { return nil }
            return WindowCandidate(rect: NSRect(
                x: local.minX - screenFrame.minX,
                y: local.minY - screenFrame.minY,
                width: local.width,
                height: local.height
            ))
        }
    }

    private func requestScreenCaptureAccess(completion: @escaping (Bool) -> Void) {
        if CGPreflightScreenCaptureAccess() {
            completion(true)
            return
        }

        _ = CGRequestScreenCaptureAccess()
        Self.openScreenCapturePrivacySettings()
        waitForScreenCaptureAccess(deadline: Date().addingTimeInterval(60), completion: completion)
    }

    private static func openScreenCapturePrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording"
        ]
        for value in urls {
            guard let url = URL(string: value), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }

    private func waitForScreenCaptureAccess(deadline: Date, completion: @escaping (Bool) -> Void) {
        if CGPreflightScreenCaptureAccess() {
            completion(true)
            return
        }
        guard Date() < deadline else {
            completion(false)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.waitForScreenCaptureAccess(deadline: deadline, completion: completion)
        }
        permissionCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private static func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}

private struct ScreenSnapshot {
    let screen: NSScreen
    let image: CGImage
    let windowCandidates: [WindowCandidate]
}

private struct GlobalWindowCandidate {
    let bounds: NSRect
}

private struct WindowCandidate {
    let rect: NSRect
}

private struct ScreenRecordingOptions {
    enum Format {
        case mp4
        case gif
    }

    let format: Format
    let includeMouse: Bool

    var maxDuration: TimeInterval {
        switch format {
        case .mp4: return 60 * 60
        case .gif: return 30
        }
    }

    var fileExtension: String {
        switch format {
        case .mp4: return "mp4"
        case .gif: return "gif"
        }
    }

    var fileType: AVFileType {
        switch format {
        case .mp4: return .mp4
        case .gif: return .mp4
        }
    }

    static let `default` = ScreenRecordingOptions(format: .mp4, includeMouse: true)
}

private final class ScreenRecordingOptionsPanel: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let onStart: (ScreenRecordingOptions) -> Void
    private let onCancel: () -> Void
    private let mp4Button: NSButton
    private let gifButton: NSButton
    private let mouseButton: NSButton
    private var isCompleting = false

    init(onStart: @escaping (ScreenRecordingOptions) -> Void, onCancel: @escaping () -> Void) {
        self.onStart = onStart
        self.onCancel = onCancel
        self.mp4Button = NSButton(radioButtonWithTitle: "MP4", target: nil, action: nil)
        self.gifButton = NSButton(radioButtonWithTitle: "GIF", target: nil, action: nil)
        self.mouseButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 190),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = L10n.pluginScreenRecordingTitle
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let view = NSView(frame: panel.contentView?.bounds ?? .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        panel.contentView = view

        let startButton = NSButton(title: L10n.pluginScreenRecordingStart, target: nil, action: nil)
        startButton.bezelStyle = .rounded
        startButton.isBordered = false
        startButton.wantsLayer = true
        startButton.layer?.cornerRadius = 8
        startButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        startButton.contentTintColor = .white
        startButton.font = .systemFont(ofSize: 19, weight: .semibold)
        startButton.frame = NSRect(x: 18, y: 132, width: 384, height: 44)
        startButton.target = self
        startButton.action = #selector(startClicked)
        view.addSubview(startButton)

        let formatLabel = NSTextField(labelWithString: L10n.pluginScreenRecordingFormat)
        formatLabel.textColor = .secondaryLabelColor
        formatLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        formatLabel.frame = NSRect(x: 22, y: 94, width: 78, height: 22)
        view.addSubview(formatLabel)

        mp4Button.state = .on
        mp4Button.font = .systemFont(ofSize: 14, weight: .medium)
        mp4Button.frame = NSRect(x: 112, y: 94, width: 74, height: 22)
        view.addSubview(mp4Button)

        gifButton.font = .systemFont(ofSize: 14, weight: .medium)
        gifButton.frame = NSRect(x: 206, y: 94, width: 74, height: 22)
        gifButton.toolTip = L10n.pluginScreenRecordingGIFHint
        view.addSubview(gifButton)

        let controls: [(String, String, Bool)] = [
            ("speaker.slash.fill", L10n.pluginScreenRecordingSpeaker, false),
            ("mic.fill", L10n.pluginScreenRecordingMicrophone, false),
            ("video.slash.fill", L10n.pluginScreenRecordingCamera, false),
            ("cursorarrow", L10n.pluginScreenRecordingMouse, true)
        ]
        var x: CGFloat = 30
        for (symbol, title, enabled) in controls {
            let icon = NSButton(title: "", target: nil, action: nil)
            icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            icon.imagePosition = .imageOnly
            icon.isBordered = false
            icon.isEnabled = enabled
            icon.contentTintColor = .secondaryLabelColor
            icon.frame = NSRect(x: x, y: 44, width: 34, height: 28)
            if !enabled {
                icon.toolTip = L10n.pluginScreenRecordingMediaUnsupported
            }
            view.addSubview(icon)

            if title == L10n.pluginScreenRecordingMouse {
                mouseButton.state = .on
                mouseButton.isBordered = false
                mouseButton.frame = NSRect(x: x + 22, y: 52, width: 18, height: 18)
                view.addSubview(mouseButton)
                icon.target = self
                icon.action = #selector(toggleMouse)
            }

            let label = NSTextField(labelWithString: title)
            label.alignment = .center
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.frame = NSRect(x: x - 19, y: 20, width: 72, height: 18)
            view.addSubview(label)
            x += 98
        }
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.close()
    }

    @objc private func startClicked() {
        isCompleting = true
        panel.close()
        let format: ScreenRecordingOptions.Format = gifButton.state == .on ? .gif : .mp4
        onStart(ScreenRecordingOptions(format: format, includeMouse: mouseButton.state == .on))
    }

    @objc private func toggleMouse() {
        mouseButton.state = mouseButton.state == .on ? .off : .on
    }

    func windowWillClose(_ notification: Notification) {
        guard !isCompleting else { return }
        isCompleting = true
        onCancel()
    }
}

private final class ScreenRecordingCountdownWindow: NSPanel {
    private final class CountdownView: NSView {
        var value = 3 {
            didSet { needsDisplay = true }
        }
        let selection: NSRect

        init(frame: NSRect, selection: NSRect) {
            self.selection = selection
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.setFill()
            dirtyRect.fill()

            let center = NSPoint(x: selection.midX, y: selection.midY)
            let radius: CGFloat = 96
            let circle = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(ovalIn: circle).fill()

            let text = "\(value)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 110, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(
                at: NSPoint(x: circle.midX - size.width / 2, y: circle.midY - size.height / 2 + 6),
                withAttributes: attrs
            )
        }
    }

    private let countdownView: CountdownView
    private let onComplete: () -> Void
    private var timer: Timer?
    private var value = 3

    init(screen: NSScreen, selection: NSRect, onComplete: @escaping () -> Void) {
        countdownView = CountdownView(frame: NSRect(origin: .zero, size: screen.frame.size), selection: selection)
        self.onComplete = onComplete
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = countdownView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
    }

    func start() {
        makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.value -= 1
            guard self.value > 0 else {
                timer.invalidate()
                self.close()
                self.onComplete()
                return
            }
            self.countdownView.value = self.value
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class ScreenRecordingBoundsWindow: NSPanel {
    private final class BoundsView: NSView {
        let selection: NSRect

        init(frame: NSRect, selection: NSRect) {
            self.selection = selection
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) { fatalError() }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.withAlphaComponent(0.22).setFill()
            let mask = NSBezierPath(rect: bounds)
            mask.append(NSBezierPath(rect: selection))
            mask.windingRule = .evenOdd
            mask.fill()

            NSColor.systemRed.setStroke()
            let path = NSBezierPath(rect: selection.insetBy(dx: 1, dy: 1))
            path.lineWidth = 2
            path.stroke()
        }
    }

    init(screen: NSScreen, selection: NSRect) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = BoundsView(frame: NSRect(origin: .zero, size: screen.frame.size), selection: selection)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        sharingType = .none
    }

    func show() {
        orderFrontRegardless()
    }
}

private final class ScreenRecordingControlWindow: NSPanel {
    private let elapsedLabel = NSTextField(labelWithString: "00:00:00")
    private let progress = NSProgressIndicator()
    private let maxDuration: TimeInterval
    private let stopHandler: () -> Void
    private let startDate = Date()
    private var timer: Timer?

    init(maxDuration: TimeInterval, stopHandler: @escaping () -> Void) {
        self.maxDuration = maxDuration
        self.stopHandler = stopHandler

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let size = NSSize(width: 430, height: 54)
        let origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height - 18)
        super.init(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        view.layer?.cornerRadius = 12
        contentView = view

        let grip = NSTextField(labelWithString: "⋮")
        grip.textColor = .secondaryLabelColor
        grip.font = .systemFont(ofSize: 18, weight: .semibold)
        grip.frame = NSRect(x: 14, y: 18, width: 18, height: 22)
        view.addSubview(grip)

        let pause = NSButton(title: "", target: nil, action: nil)
        pause.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)
        pause.imagePosition = .imageOnly
        pause.isBordered = false
        pause.isEnabled = false
        pause.contentTintColor = .labelColor
        pause.frame = NSRect(x: 40, y: 13, width: 34, height: 28)
        view.addSubview(pause)

        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        elapsedLabel.textColor = .secondaryLabelColor
        elapsedLabel.frame = NSRect(x: 92, y: 17, width: 88, height: 24)
        view.addSubview(elapsedLabel)

        let slash = NSTextField(labelWithString: "/")
        slash.font = .systemFont(ofSize: 18, weight: .regular)
        slash.textColor = .secondaryLabelColor
        slash.frame = NSRect(x: 184, y: 17, width: 14, height: 24)
        view.addSubview(slash)

        let total = NSTextField(labelWithString: Self.format(maxDuration))
        total.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        total.textColor = .secondaryLabelColor
        total.frame = NSRect(x: 204, y: 17, width: 94, height: 24)
        view.addSubview(total)

        let stop = NSButton(title: L10n.pluginScreenRecordingStop, target: self, action: #selector(stopClicked))
        stop.bezelStyle = .rounded
        stop.isBordered = false
        stop.wantsLayer = true
        stop.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.82).cgColor
        stop.layer?.cornerRadius = 7
        stop.contentTintColor = .white
        stop.font = .systemFont(ofSize: 15, weight: .semibold)
        stop.frame = NSRect(x: 312, y: 10, width: 102, height: 34)
        view.addSubview(stop)

        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = maxDuration
        progress.doubleValue = 0
        progress.controlSize = .small
        progress.frame = NSRect(x: 12, y: 0, width: size.width - 24, height: 4)
        view.addSubview(progress)
    }

    func show() {
        makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(startDate)
        elapsedLabel.stringValue = Self.format(elapsed)
        progress.doubleValue = min(elapsed, maxDuration)
        if elapsed >= maxDuration {
            stopHandler()
        }
    }

    @objc private func stopClicked() {
        stopHandler()
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", value / 3600, (value / 60) % 60, value % 60)
    }
}

private final class ScreenRecordingPreviewWindowController: NSWindowController, NSWindowDelegate {
    private let url: URL
    private let player: AVPlayer?
    private let onClose: (ScreenRecordingPreviewWindowController) -> Void

    init(url: URL, onClose: @escaping (ScreenRecordingPreviewWindowController) -> Void) {
        self.url = url
        self.player = url.pathExtension.lowercased() == "gif" ? nil : AVPlayer(url: url)
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.pluginScreenRecordingPreview
        super.init(window: window)
        window.delegate = self
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        guard let window else { return }
        let content = NSView(frame: window.contentView?.bounds ?? .zero)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        let toolbar = NSView(frame: NSRect(x: 0, y: content.bounds.height - 64, width: content.bounds.width, height: 64))
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        content.addSubview(toolbar)

        let title = NSTextField(labelWithString: L10n.pluginScreenRecordingPreview)
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 18, y: 20, width: 240, height: 24)
        toolbar.addSubview(title)

        let download = NSButton(title: L10n.pluginScreenRecordingDownload, target: self, action: #selector(downloadClicked))
        download.bezelStyle = .rounded
        download.font = .systemFont(ofSize: 15, weight: .semibold)
        download.frame = NSRect(x: toolbar.bounds.width - 126, y: 16, width: 108, height: 34)
        download.autoresizingMask = [.minXMargin]
        toolbar.addSubview(download)

        let playerView = AVPlayerView(frame: NSRect(x: 0, y: 0, width: content.bounds.width, height: content.bounds.height - 64))
        playerView.autoresizingMask = [.width, .height]
        if let player {
            playerView.player = player
            playerView.controlsStyle = .floating
            content.addSubview(playerView)
        } else {
            let imageView = NSImageView(frame: playerView.frame)
            imageView.autoresizingMask = [.width, .height]
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.image = NSImage(contentsOf: url)
            content.addSubview(imageView)
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        player?.play()
    }

    @objc private func downloadClicked() {
        let panel = NSSavePanel()
        panel.title = L10n.pluginScreenRecordingDownload
        panel.nameFieldStringValue = url.lastPathComponent
        panel.allowedContentTypes = url.pathExtension.lowercased() == "gif" ? [.gif] : [.mpeg4Movie]
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: self.url, to: destination)
            } catch {
                NSAlert(error: error).beginSheetModal(for: self.window!)
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        player?.pause()
        try? FileManager.default.removeItem(at: url)
        onClose(self)
    }
}

private enum ScreenRecordingError: LocalizedError {
    case invalidDisplay
    case invalidRegion
    case cannotCaptureFrame
    case cannotCreatePixelBuffer
    case writerStartFailed(String)
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDisplay:
            return L10n.pluginScreenRecordingInvalidDisplay
        case .invalidRegion:
            return L10n.pluginScreenRecordingInvalidRegion
        case .cannotCaptureFrame:
            return L10n.pluginScreenRecordingCaptureFailed
        case .cannotCreatePixelBuffer:
            return L10n.pluginScreenRecordingEncodeFailed
        case .writerStartFailed(let message), .writerFailed(let message):
            return message
        }
    }
}

private final class ScreenRecordingController {
    private let displayID: CGDirectDisplayID
    private let screenFrame: NSRect
    private let screenSize: CGSize
    private let rect: NSRect
    private let outputURL: URL
    private let options: ScreenRecordingOptions
    private let framesPerSecond: Int32 = 15
    private let completion: (Result<URL, Error>) -> Void
    private let queue = DispatchQueue(label: "com.klok.screen-recording")

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var gifFrames: [CGImage] = []
    private var timer: DispatchSourceTimer?
    private var startDate: Date?
    private var didFinish = false

    init(
        screen: NSScreen,
        rect: NSRect,
        outputURL: URL,
        options: ScreenRecordingOptions,
        completion: @escaping (Result<URL, Error>) -> Void
    ) throws {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw ScreenRecordingError.invalidDisplay
        }
        guard rect.width >= 8, rect.height >= 8 else {
            throw ScreenRecordingError.invalidRegion
        }
        guard let firstFrame = Self.capture(displayID: id, screenFrame: screen.frame, rect: rect, includeMouse: options.includeMouse) else {
            throw ScreenRecordingError.cannotCaptureFrame
        }

        self.displayID = id
        self.screenFrame = screen.frame
        self.screenSize = screen.frame.size
        self.rect = rect
        self.outputURL = outputURL
        self.options = options
        self.completion = completion

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        if options.format == .mp4 {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: options.fileType)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: firstFrame.width,
                AVVideoHeightKey: firstFrame.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(1_500_000, firstFrame.width * firstFrame.height * 4)
                ]
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            let attributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: firstFrame.width,
                kCVPixelBufferHeightKey as String: firstFrame.height,
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)

            guard writer.canAdd(input) else {
                throw ScreenRecordingError.writerStartFailed(L10n.pluginScreenRecordingEncodeFailed)
            }
            writer.add(input)
            self.writer = writer
            self.input = input
            self.adaptor = adaptor
        }
    }

    func start() throws {
        try queue.sync {
            if options.format == .mp4 {
                guard let writer else {
                    throw ScreenRecordingError.writerStartFailed(L10n.pluginScreenRecordingEncodeFailed)
                }
                guard writer.startWriting() else {
                    throw ScreenRecordingError.writerStartFailed(writer.error?.localizedDescription ?? L10n.pluginScreenRecordingEncodeFailed)
                }
                writer.startSession(atSourceTime: .zero)
            }
            startDate = Date()
            appendFrame(at: .zero)

            let interval = DispatchTimeInterval.milliseconds(Int(1_000 / framesPerSecond))
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(8))
            timer.setEventHandler { [weak self] in
                self?.appendCurrentFrame()
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.finish(nil)
        }
    }

    private func appendCurrentFrame() {
        guard let startDate else { return }
        let elapsed = Date().timeIntervalSince(startDate)
        appendFrame(at: CMTime(seconds: elapsed, preferredTimescale: 600))
    }

    private func appendFrame(at presentationTime: CMTime) {
        guard let image = Self.capture(displayID: displayID, screenFrame: screenFrame, rect: rect, includeMouse: options.includeMouse) else {
            finish(ScreenRecordingError.cannotCaptureFrame)
            return
        }

        if options.format == .gif {
            gifFrames.append(image)
            return
        }

        guard let input, let adaptor, input.isReadyForMoreMediaData else { return }
        guard let pixelBuffer = Self.makePixelBuffer(from: image) else {
            finish(ScreenRecordingError.cannotCreatePixelBuffer)
            return
        }
        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            finish(ScreenRecordingError.writerFailed(writer?.error?.localizedDescription ?? L10n.pluginScreenRecordingEncodeFailed))
            return
        }
    }

    private func finish(_ error: Error?) {
        guard !didFinish else { return }
        didFinish = true
        timer?.cancel()
        timer = nil

        if let error {
            writer?.cancelWriting()
            completion(.failure(error))
            return
        }

        if options.format == .gif {
            do {
                try writeGIF()
                completion(.success(outputURL))
            } catch {
                completion(.failure(error))
            }
            return
        }

        guard let writer, let input else {
            completion(.failure(ScreenRecordingError.writerFailed(L10n.pluginScreenRecordingEncodeFailed)))
            return
        }
        input.markAsFinished()
        writer.finishWriting { [outputURL, completion] in
            if writer.status == .completed {
                completion(.success(outputURL))
            } else {
                completion(.failure(ScreenRecordingError.writerFailed(writer.error?.localizedDescription ?? L10n.pluginScreenRecordingEncodeFailed)))
            }
        }
    }

    private func writeGIF() throws {
        guard !gifFrames.isEmpty,
              let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, gifFrames.count, nil)
        else {
            throw ScreenRecordingError.writerFailed(L10n.pluginScreenRecordingEncodeFailed)
        }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ] as CFDictionary)

        let frameDelay = 1.0 / Double(framesPerSecond)
        let frameProperties = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ] as CFDictionary

        for frame in gifFrames {
            CGImageDestinationAddImage(destination, frame, frameProperties)
        }
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenRecordingError.writerFailed(L10n.pluginScreenRecordingEncodeFailed)
        }
        gifFrames.removeAll()
    }

    private static func capture(displayID: CGDirectDisplayID, screenFrame: NSRect, rect: NSRect, includeMouse: Bool) -> CGImage? {
        guard let image = CGDisplayCreateImage(displayID) else { return nil }
        let scaleX = CGFloat(image.width) / screenFrame.width
        let scaleY = CGFloat(image.height) / screenFrame.height
        var cropRect = CGRect(
            x: rect.minX * scaleX,
            y: (screenFrame.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral

        cropRect.size.width = CGFloat(max(2, Int(cropRect.width) & ~1))
        cropRect.size.height = CGFloat(max(2, Int(cropRect.height) & ~1))
        cropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard cropRect.width >= 2, cropRect.height >= 2 else { return nil }
        guard let cropped = image.cropping(to: cropRect) else { return nil }
        guard includeMouse else { return cropped }
        return drawCursor(on: cropped, screenFrame: screenFrame, selection: rect, scaleX: scaleX, scaleY: scaleY)
    }

    private static func drawCursor(on image: CGImage, screenFrame: NSRect, selection: NSRect, scaleX: CGFloat, scaleY: CGFloat) -> CGImage? {
        let mouse = NSEvent.mouseLocation
        let local = NSPoint(x: mouse.x - screenFrame.minX, y: mouse.y - screenFrame.minY)
        guard selection.contains(local) else { return image }

        guard let cursorCG = NSCursor.current.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let cursorSize = NSCursor.current.image.size
        let hotSpot = NSCursor.current.hotSpot
        let cursorX = (local.x - selection.minX - hotSpot.x) * scaleX
        let cursorY = (selection.maxY - local.y - (cursorSize.height - hotSpot.y)) * scaleY
        let cursorRect = CGRect(
            x: cursorX,
            y: cursorY,
            width: cursorSize.width * scaleX,
            height: cursorSize.height * scaleY
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(cursorCG, in: cursorRect)
        return context.makeImage() ?? image
    }

    private static func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            image.width,
            image.height,
            kCVPixelFormatType_32ARGB,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixelBuffer
    }
}

private final class ScreenshotOverlayWindow: NSPanel {
    let overlayView: ScreenshotOverlayView

    init(snapshot: ScreenSnapshot) {
        overlayView = ScreenshotOverlayView(snapshot: snapshot)
        super.init(
            contentRect: snapshot.screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        contentView = overlayView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
}

private final class ColorButton: NSButton {
    let annotationColor: NSColor
    private var isTrackingClick = false

    init(color: NSColor, target: AnyObject?, action: Selector?) {
        annotationColor = color
        super.init(frame: .zero)
        self.target = target
        self.action = action
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isTrackingClick = true
        highlight(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTrackingClick else { return }
        highlight(bounds.contains(convert(event.locationInWindow, from: nil)))
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingClick else { return }
        isTrackingClick = false
        highlight(false)
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        guard let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

private final class ScreenshotToolbarView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0, bounds.contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
}

private final class ScreenshotToolbarButton: NSButton {
    private var isTrackingClick = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isTrackingClick = true
        highlight(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTrackingClick else { return }
        highlight(bounds.contains(convert(event.locationInWindow, from: nil)))
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingClick else { return }
        isTrackingClick = false
        highlight(false)
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        guard let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }
}

private enum ScreenshotTool {
    case select
    case rectangle
    case ellipse
    case arrow
    case brush
    case text
    case mosaic
}

private enum ScreenshotAnnotation {
    case rectangle(NSRect, NSColor)
    case ellipse(NSRect, NSColor)
    case arrow(NSPoint, NSPoint, NSColor)
    case brush([NSPoint], NSColor)
    case text(String, NSPoint, NSColor)
    case mosaic([NSPoint])
}

private extension ScreenshotAnnotation {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> ScreenshotAnnotation {
        func offset(_ point: NSPoint) -> NSPoint {
            NSPoint(x: point.x + dx, y: point.y + dy)
        }

        switch self {
        case .rectangle(let rect, let color):
            return .rectangle(rect.offsetBy(dx: dx, dy: dy), color)
        case .ellipse(let rect, let color):
            return .ellipse(rect.offsetBy(dx: dx, dy: dy), color)
        case .arrow(let start, let end, let color):
            return .arrow(offset(start), offset(end), color)
        case .brush(let points, let color):
            return .brush(points.map(offset), color)
        case .text(let text, let point, let color):
            return .text(text, offset(point), color)
        case .mosaic(let points):
            return .mosaic(points.map(offset))
        }
    }

    func withColor(_ color: NSColor) -> ScreenshotAnnotation {
        switch self {
        case .rectangle(let rect, _):
            return .rectangle(rect, color)
        case .ellipse(let rect, _):
            return .ellipse(rect, color)
        case .arrow(let start, let end, _):
            return .arrow(start, end, color)
        case .brush(let points, _):
            return .brush(points, color)
        case .text(let text, let point, _):
            return .text(text, point, color)
        case .mosaic:
            return self
        }
    }

    var bounds: NSRect {
        switch self {
        case .rectangle(let rect, _), .ellipse(let rect, _):
            return rect
        case .arrow(let start, let end, _):
            return NSRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y)).insetBy(dx: -20, dy: -20)
        case .brush(let points, _):
            guard let first = points.first else { return .zero }
            return points.reduce(NSRect(origin: first, size: .zero)) { partial, point in
                partial.union(NSRect(origin: point, size: .zero))
            }.insetBy(dx: -20, dy: -20)
        case .text(_, let point, _):
            return NSRect(x: point.x, y: point.y, width: 240, height: 40)
        case .mosaic(let points):
            guard let first = points.first else { return .zero }
            return points.reduce(NSRect(origin: first, size: .zero)) { partial, point in
                partial.union(NSRect(origin: point, size: .zero))
            }.insetBy(dx: ScreenshotOverlayView.mosaicBrushRadius, dy: ScreenshotOverlayView.mosaicBrushRadius)
        }
    }
}

private final class ScreenshotOverlayView: NSView {
    fileprivate static let mosaicBrushRadius: CGFloat = 14
    private static let mosaicSampleStep: CGFloat = 8

    var onCopy: ((NSRect) -> Void)?
    var onSave: ((NSRect) -> Void)?
    var onRecord: ((NSRect) -> Void)? {
        didSet {
            recordButton?.isHidden = onRecord == nil
        }
    }
    var onCancel: (() -> Void)?

    var screen: NSScreen { snapshot.screen }

    private enum DragMode {
        case selection
        case moveSelection
        case moveAnnotation(Int)
        case resizeSelection(SelectionHandle)
        case annotation
    }

    private enum SelectionHandle {
        case minXMinY
        case midXMinY
        case maxXMinY
        case minXMidY
        case maxXMidY
        case minXMaxY
        case midXMaxY
        case maxXMaxY
    }

    private let snapshot: ScreenSnapshot
    private var selection: NSRect?
    private var selectionAtDragStart: NSRect?
    private var hoverSelection: NSRect?
    private var pendingWindowSelection: NSRect?
    private var dragStart: NSPoint?
    private var dragMode: DragMode?
    private var didDragBeyondClick = false
    private var activeTool: ScreenshotTool = .select
    private var activeColor: NSColor = .systemRed
    private var annotations: [ScreenshotAnnotation] = []
    private var previewAnnotation: ScreenshotAnnotation?
    private var selectedAnnotationIndex: Int?
    private var toolButtons: [ScreenshotTool: NSButton] = [:]
    private var colorButtons: [ColorButton] = []
    private var recordButton: NSButton?
    private let toolbar = ScreenshotToolbarView()
    private let colorBar = ScreenshotToolbarView()
    private var activeTextField: NSTextField?
    private var activeTextOrigin: NSPoint?

    init(snapshot: ScreenSnapshot) {
        self.snapshot = snapshot
        super.init(frame: NSRect(origin: .zero, size: snapshot.screen.frame.size))
        wantsLayer = true
        setupToolbar()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if !toolbar.isHidden, toolbar.frame.contains(point) {
            return self
        }
        return super.hitTest(point)
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased()
        switch event.keyCode {
        case 6 where event.modifierFlags.contains(.command):
            undo()
        case 8 where event.modifierFlags.contains(.command):
            copySelection()
        case 1 where event.modifierFlags.contains(.command):
            saveSelection()
        case 15 where event.modifierFlags.contains(.command):
            recordSelection()
        case 53:
            onCancel?()
        default:
            switch key {
            case "v":
                selectTool(.select)
            case "r":
                selectTool(.rectangle)
            case "o":
                selectTool(.ellipse)
            case "a":
                selectTool(.arrow)
            case "b":
                selectTool(.brush)
            case "t":
                selectTool(.text)
            case "m":
                selectTool(.mosaic)
            default:
                super.keyDown(with: event)
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard dragStart == nil, selection == nil else { return }
        let point = event.locationInWindow
        let next = isPointInToolbar(point) ? nil : windowCandidate(at: point)?.rect
        guard next != hoverSelection else { return }
        hoverSelection = next
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = event.locationInWindow
        if handleToolbarClick(at: point) { return }
        commitActiveText()
        didDragBeyondClick = false
        pendingWindowSelection = nil
        if let selection, selection.contains(point) {
            if activeTool == .select {
                if let handle = handle(at: point, in: selection) {
                    dragMode = .resizeSelection(handle)
                } else if let index = annotationIndex(at: point) {
                    dragMode = .moveAnnotation(index)
                    selectedAnnotationIndex = index
                } else {
                    dragMode = .moveSelection
                    selectedAnnotationIndex = nil
                }
                dragStart = point
                selectionAtDragStart = selection
                toolbar.isHidden = true
            } else {
                if let index = annotationIndex(at: point) {
                    dragMode = .moveAnnotation(index)
                    selectedAnnotationIndex = index
                    dragStart = point
                    selectionAtDragStart = selection
                    toolbar.isHidden = true
                    needsDisplay = true
                    return
                }
                if activeTool == .text {
                    addText(at: point)
                    return
                }
                dragMode = .annotation
                dragStart = point
                previewAnnotation = annotation(for: activeTool, start: point, current: point)
                toolbar.isHidden = true
            }
        } else {
            dragMode = .selection
            dragStart = point
            selectionAtDragStart = nil
            pendingWindowSelection = hoverSelection
            selection = pendingWindowSelection == nil ? NSRect(origin: point, size: .zero) : nil
            annotations.removeAll()
            previewAnnotation = nil
            selectedAnnotationIndex = nil
            activeTool = .select
            refreshToolButtons()
            toolbar.isHidden = true
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isPointInToolbar(event.locationInWindow) else { return }
        guard let start = dragStart, let dragMode else { return }
        let current = event.locationInWindow
        switch dragMode {
        case .selection:
            if didDragBeyondClick || distance(from: start, to: current) > 4 {
                didDragBeyondClick = true
                hoverSelection = nil
                pendingWindowSelection = nil
                selection = normalizedRect(from: start, to: current)
            }
        case .moveSelection:
            guard let original = selectionAtDragStart else { return }
            let moved = movedRect(original, byX: current.x - start.x, y: current.y - start.y)
            let delta = NSPoint(x: moved.minX - original.minX, y: moved.minY - original.minY)
            selection = moved
            annotations = annotations.map { $0.offsetBy(dx: delta.x, dy: delta.y) }
            selectionAtDragStart = moved
            dragStart = current
        case .moveAnnotation(let index):
            guard annotations.indices.contains(index) else { return }
            let deltaX = current.x - start.x
            let deltaY = current.y - start.y
            annotations[index] = annotations[index].offsetBy(dx: deltaX, dy: deltaY)
            dragStart = current
        case .resizeSelection(let handle):
            guard let original = selectionAtDragStart else { return }
            selection = resizedRect(original, handle: handle, to: current)
        case .annotation:
            guard let selection else { return }
            let clipped = clamp(current, to: selection)
            if activeTool == .brush {
                if case .brush(var points, let color) = previewAnnotation {
                    points.append(clipped)
                    previewAnnotation = .brush(points, color)
                } else {
                    previewAnnotation = .brush([start, clipped], activeColor)
                }
            } else if activeTool == .mosaic {
                if case .mosaic(var points) = previewAnnotation {
                    points.append(clipped)
                    previewAnnotation = .mosaic(points)
                } else {
                    previewAnnotation = .mosaic([start, clipped])
                }
            } else {
                previewAnnotation = annotation(for: activeTool, start: start, current: clipped)
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard !isPointInToolbar(event.locationInWindow) else { return }
        defer {
            dragStart = nil
            dragMode = nil
            selectionAtDragStart = nil
            pendingWindowSelection = nil
            didDragBeyondClick = false
        }

        guard let start = dragStart, let dragMode else { return }
        switch dragMode {
        case .selection:
            let rect = didDragBeyondClick
                ? normalizedRect(from: start, to: event.locationInWindow)
                : (pendingWindowSelection ?? normalizedRect(from: start, to: event.locationInWindow))
            if rect.width < 6 || rect.height < 6 {
                selection = nil
                toolbar.isHidden = true
            } else {
                selection = rect
                hoverSelection = nil
                positionToolbar(for: rect)
            }
        case .moveSelection, .moveAnnotation, .resizeSelection:
            if let selection {
                positionToolbar(for: selection)
            }
        case .annotation:
            if let annotation = previewAnnotation, !isTiny(annotation) {
                annotations.append(annotation)
            }
            previewAnnotation = nil
            if let selection { positionToolbar(for: selection) }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawSnapshot()

        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        guard let rect = selection ?? hoverSelection else { return }
        context.saveGState()
        context.clip(to: rect)
        drawSnapshot()
        drawAnnotations(annotations)
        if let previewAnnotation {
            drawAnnotations([previewAnnotation])
        }
        if let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) {
            drawSelectionOutline(for: annotations[selectedAnnotationIndex].bounds)
        }
        context.restoreGState()

        NSColor.systemBlue.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 2
        border.stroke()

        if selection != nil {
            drawHandles(for: rect)
        }
        drawSizeBadge(for: rect)
    }

    func croppedImage(for rect: NSRect) -> NSImage? {
        let scaleX = CGFloat(snapshot.image.width) / bounds.width
        let scaleY = CGFloat(snapshot.image.height) / bounds.height
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: (bounds.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral

        guard let cropped = snapshot.image.cropping(to: cropRect) else { return nil }
        let base = NSImage(cgImage: cropped, size: rect.size)
        let output = NSImage(size: rect.size)
        output.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: rect.size))
        NSGraphicsContext.current?.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
        drawAnnotations(annotations.filter { intersects($0, rect) })
        output.unlockFocus()
        return output
    }

    private func setupToolbar() {
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 0.92).cgColor
        toolbar.layer?.cornerRadius = 7
        toolbar.layer?.borderWidth = 1
        toolbar.layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        toolbar.layer?.shadowColor = NSColor.black.cgColor
        toolbar.layer?.shadowOpacity = 0.35
        toolbar.layer?.shadowRadius = 8
        toolbar.layer?.shadowOffset = CGSize(width: 0, height: -3)
        toolbar.isHidden = true
        addSubview(toolbar)
        setupColorBar()

        let tools: [(ScreenshotTool, String, String)] = [
            (.rectangle, L10n.pluginScreenshotRect, "rectangle"),
            (.ellipse, L10n.pluginScreenshotEllipse, "circle"),
            (.arrow, L10n.pluginScreenshotArrow, "arrow.up.right"),
            (.brush, L10n.pluginScreenshotBrush, "pencil"),
            (.mosaic, L10n.pluginScreenshotMosaic, "checkerboard.rectangle"),
            (.text, L10n.pluginScreenshotText, "textformat")
        ]

        var x: CGFloat = 16
        for (tool, title, symbolName) in tools {
            let button = toolbarButton(title: title, symbolName: symbolName, action: #selector(toolSelected(_:)), isToggle: true)
            button.tag = tool.tag
            button.frame = NSRect(x: x, y: 10, width: 38, height: 38)
            toolbar.addSubview(button)
            toolButtons[tool] = button
            x += 54
        }

        let saveButton = toolbarButton(title: L10n.pluginScreenshotSave, symbolName: "square.and.arrow.down", action: #selector(saveSelection))
        saveButton.frame = NSRect(x: x, y: 10, width: 38, height: 38)
        toolbar.addSubview(saveButton)
        x += 54

        let recordButton = toolbarButton(title: L10n.pluginScreenRecordingStart, symbolName: "record.circle", action: #selector(recordSelection))
        recordButton.contentTintColor = .systemRed
        recordButton.isHidden = true
        recordButton.frame = NSRect(x: x, y: 10, width: 38, height: 38)
        toolbar.addSubview(recordButton)
        self.recordButton = recordButton
        x += 54

        let separator = NSBox(frame: NSRect(x: x, y: 13, width: 1, height: 32))
        separator.boxType = .separator
        separator.alphaValue = 0.35
        toolbar.addSubview(separator)
        x += 18

        let undoButton = toolbarButton(title: L10n.pluginScreenshotUndo, symbolName: "arrow.uturn.backward", action: #selector(undo))
        let cancelButton = toolbarButton(title: L10n.btnCancel, symbolName: "xmark", action: #selector(cancel))
        let copyButton = toolbarButton(title: L10n.pluginScreenshotCopy, symbolName: "checkmark", action: #selector(copySelection))
        undoButton.frame = NSRect(x: x, y: 10, width: 38, height: 38)
        cancelButton.frame = NSRect(x: x + 54, y: 10, width: 38, height: 38)
        copyButton.frame = NSRect(x: x + 108, y: 10, width: 38, height: 38)
        toolbar.addSubview(undoButton)
        toolbar.addSubview(cancelButton)
        toolbar.addSubview(copyButton)
        refreshToolButtons()
    }

    private func setupColorBar() {
        colorBar.wantsLayer = true
        colorBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.02, alpha: 0.98).cgColor
        colorBar.isHidden = true
        toolbar.addSubview(colorBar)

        let colors: [NSColor] = [
            .systemBlue,
            NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 0.07, green: 0.12, blue: 0.17, alpha: 1),
            .systemRed,
            NSColor(calibratedRed: 0.63, green: 0.44, blue: 0.18, alpha: 1),
            .systemBlue,
            .systemGreen,
            .black,
            .darkGray,
            .systemGray
        ]

        var x: CGFloat = 48
        for color in colors {
            let button = colorButton(color)
            button.frame = NSRect(x: x, y: 12, width: 22, height: 22)
            colorBar.addSubview(button)
            colorButtons.append(button)
            x += 36
        }

        let separator = NSBox(frame: NSRect(x: 250, y: 9, width: 1, height: 28))
        separator.boxType = .separator
        separator.alphaValue = 0.3
        colorBar.addSubview(separator)
        refreshColorButtons()
    }

    private func drawSnapshot() {
        let image = NSImage(cgImage: snapshot.image, size: bounds.size)
        image.draw(in: bounds)
    }

    private func toolbarButton(title: String, symbolName: String, action: Selector, isToggle: Bool = false) -> NSButton {
        let button = ScreenshotToolbarButton(title: "", target: self, action: action)
        if isToggle {
            button.setButtonType(.toggle)
        }
        let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.contentTintColor = .white
        button.appearance = NSAppearance(named: .darkAqua)
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.toolTip = title
        button.setAccessibilityLabel(title)
        return button
    }

    private func colorButton(_ color: NSColor) -> ColorButton {
        let button = ColorButton(color: color, target: self, action: #selector(colorSelected(_:)))
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.layer?.backgroundColor = color.cgColor
        button.layer?.borderWidth = 0
        button.layer?.borderColor = NSColor.systemGreen.cgColor
        button.toolTip = L10n.pluginScreenshotColor
        return button
    }

    private func positionToolbar(for rect: NSRect) {
        let width = toolbarWidth
        let height: CGFloat = toolUsesColor(activeTool) ? 104 : 58
        var x = min(max(rect.maxX - width, 8), bounds.maxX - width - 8)
        var y = rect.minY - height - 8
        if y < 8 {
            y = min(rect.maxY + 8, bounds.maxY - height - 8)
        }
        x = min(max(x, 8), bounds.maxX - width - 8)
        toolbar.frame = NSRect(x: x, y: y, width: width, height: height)
        colorBar.frame = NSRect(x: 0, y: 0, width: width, height: 46)
        colorBar.isHidden = !toolUsesColor(activeTool)
        layoutToolbarButtons(hasColorBar: toolUsesColor(activeTool))
        toolbar.isHidden = false
    }

    private func layoutToolbarButtons(hasColorBar: Bool) {
        let buttonY: CGFloat = hasColorBar ? 56 : 10
        var x: CGFloat = 16
        let orderedTools: [ScreenshotTool] = [.rectangle, .ellipse, .arrow, .brush, .mosaic, .text]
        for tool in orderedTools {
            toolButtons[tool]?.frame = NSRect(x: x, y: buttonY, width: 38, height: 38)
            x += 54
        }
        for subview in toolbar.subviews where subview !== colorBar && !toolButtons.values.contains(where: { $0 === subview }) {
            if let button = subview as? NSButton {
                if button.action == #selector(saveSelection) {
                    button.frame = NSRect(x: x, y: buttonY, width: 38, height: 38)
                    x += 54
                } else if button.action == #selector(recordSelection) {
                    button.frame = NSRect(x: x, y: buttonY, width: 38, height: 38)
                    if !button.isHidden {
                        x += 54
                    }
                }
            } else if let separator = subview as? NSBox {
                separator.frame = NSRect(x: x, y: buttonY + 3, width: 1, height: 32)
                x += 18
            }
        }
        let actionButtons = toolbar.subviews.compactMap { $0 as? NSButton }.filter { button in
            button.action == #selector(undo) || button.action == #selector(cancel) || button.action == #selector(copySelection)
        }
        for button in actionButtons {
            button.frame = NSRect(x: x, y: buttonY, width: 38, height: 38)
            x += 54
        }
    }

    private var toolbarWidth: CGFloat {
        let leftPadding: CGFloat = 16
        let toolCount = CGFloat(6)
        let commandCount = CGFloat(onRecord == nil ? 4 : 5)
        let buttonStep: CGFloat = 54
        let separatorWidth: CGFloat = 18
        return leftPadding + ((toolCount + commandCount) * buttonStep) + separatorWidth
    }

    private func isPointInToolbar(_ point: NSPoint) -> Bool {
        !toolbar.isHidden && toolbar.frame.contains(point)
    }

    private func handleToolbarClick(at point: NSPoint) -> Bool {
        guard isPointInToolbar(point) else { return false }
        let toolbarPoint = NSPoint(x: point.x - toolbar.frame.minX, y: point.y - toolbar.frame.minY)
        if let button = button(at: toolbarPoint, in: toolbar) {
            button.performClick(nil)
        }
        return true
    }

    private func button(at point: NSPoint, in view: NSView) -> NSButton? {
        for subview in view.subviews.reversed() {
            guard !subview.isHidden, subview.alphaValue > 0 else { continue }
            let subviewPoint = NSPoint(x: point.x - subview.frame.minX, y: point.y - subview.frame.minY)
            guard subview.bounds.contains(subviewPoint) else { continue }
            if let button = subview as? NSButton {
                return button
            }
            if let nested = button(at: subviewPoint, in: subview) {
                return nested
            }
        }
        return nil
    }

    private func windowCandidate(at point: NSPoint) -> WindowCandidate? {
        snapshot.windowCandidates.first { $0.rect.contains(point) }
    }

    private func distance(from start: NSPoint, to end: NSPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func normalizedRect(from start: NSPoint, to end: NSPoint) -> NSRect {
        NSRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).intersection(bounds)
    }

    private func clamp(_ point: NSPoint, to rect: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func movedRect(_ rect: NSRect, byX deltaX: CGFloat, y deltaY: CGFloat) -> NSRect {
        var moved = rect.offsetBy(dx: deltaX, dy: deltaY)
        if moved.minX < bounds.minX {
            moved.origin.x = bounds.minX
        }
        if moved.maxX > bounds.maxX {
            moved.origin.x = bounds.maxX - moved.width
        }
        if moved.minY < bounds.minY {
            moved.origin.y = bounds.minY
        }
        if moved.maxY > bounds.maxY {
            moved.origin.y = bounds.maxY - moved.height
        }
        return moved
    }

    private func resizedRect(_ rect: NSRect, handle: SelectionHandle, to point: NSPoint) -> NSRect {
        let point = clamp(point, to: bounds)
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch handle {
        case .minXMinY:
            minX = point.x; minY = point.y
        case .midXMinY:
            minY = point.y
        case .maxXMinY:
            maxX = point.x; minY = point.y
        case .minXMidY:
            minX = point.x
        case .maxXMidY:
            maxX = point.x
        case .minXMaxY:
            minX = point.x; maxY = point.y
        case .midXMaxY:
            maxY = point.y
        case .maxXMaxY:
            maxX = point.x; maxY = point.y
        }

        let minSize: CGFloat = 8
        if abs(maxX - minX) < minSize {
            if minX < maxX { maxX = minX + minSize } else { minX = maxX + minSize }
        }
        if abs(maxY - minY) < minSize {
            if minY < maxY { maxY = minY + minSize } else { minY = maxY + minSize }
        }
        return normalizedRect(from: NSPoint(x: minX, y: minY), to: NSPoint(x: maxX, y: maxY))
    }

    private func handle(at point: NSPoint, in rect: NSRect) -> SelectionHandle? {
        let hitSize: CGFloat = 12
        let handles: [(SelectionHandle, NSPoint)] = [
            (.minXMinY, NSPoint(x: rect.minX, y: rect.minY)),
            (.midXMinY, NSPoint(x: rect.midX, y: rect.minY)),
            (.maxXMinY, NSPoint(x: rect.maxX, y: rect.minY)),
            (.minXMidY, NSPoint(x: rect.minX, y: rect.midY)),
            (.maxXMidY, NSPoint(x: rect.maxX, y: rect.midY)),
            (.minXMaxY, NSPoint(x: rect.minX, y: rect.maxY)),
            (.midXMaxY, NSPoint(x: rect.midX, y: rect.maxY)),
            (.maxXMaxY, NSPoint(x: rect.maxX, y: rect.maxY))
        ]
        return handles.first { _, center in
            NSRect(x: center.x - hitSize / 2, y: center.y - hitSize / 2, width: hitSize, height: hitSize)
                .contains(point)
        }?.0
    }

    private func annotation(for tool: ScreenshotTool, start: NSPoint, current: NSPoint) -> ScreenshotAnnotation? {
        switch tool {
        case .select, .text:
            return nil
        case .rectangle:
            return .rectangle(normalizedRect(from: start, to: current), activeColor)
        case .ellipse:
            return .ellipse(normalizedRect(from: start, to: current), activeColor)
        case .arrow:
            return .arrow(start, current, activeColor)
        case .brush:
            return .brush([start, current], activeColor)
        case .mosaic:
            return .mosaic([start, current])
        }
    }

    private func drawAnnotations(_ annotations: [ScreenshotAnnotation]) {
        for annotation in annotations {
            switch annotation {
            case .rectangle(let rect, let color):
                drawRectangle(rect, color: color)
            case .ellipse(let rect, let color):
                drawEllipse(rect, color: color)
            case .arrow(let start, let end, let color):
                drawArrow(from: start, to: end, color: color)
            case .brush(let points, let color):
                drawBrush(points, color: color)
            case .text(let text, let point, let color):
                drawText(text, at: point, color: color)
            case .mosaic(let points):
                drawMosaic(points)
            }
        }
    }

    private func drawRectangle(_ rect: NSRect, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath()
        if rect.width < 2 || rect.height < 2 {
            path.move(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.appendRect(rect)
        }
        path.lineWidth = 3
        path.stroke()
    }

    private func drawEllipse(_ rect: NSRect, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 3
        path.stroke()
    }

    private func drawArrow(from start: NSPoint, to end: NSPoint, color: NSColor) {
        color.setStroke()
        color.setFill()
        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        line.lineWidth = 4
        line.lineCapStyle = .round
        line.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 14
        let spread: CGFloat = .pi / 7
        let p1 = NSPoint(x: end.x - length * cos(angle - spread), y: end.y - length * sin(angle - spread))
        let p2 = NSPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread))
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: p1)
        head.line(to: p2)
        head.close()
        head.fill()
    }

    private func drawBrush(_ points: [NSPoint], color: NSColor) {
        guard points.count > 1 else { return }
        color.setStroke()
        let path = NSBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.line(to: point)
        }
        path.lineWidth = 4
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private func drawText(_ text: String, at point: NSPoint, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: color,
            .strokeColor: NSColor.white,
            .strokeWidth: -2
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private func drawMosaic(_ points: [NSPoint]) {
        guard !points.isEmpty else { return }
        let sampledPoints = sampleStrokePoints(points, spacing: Self.mosaicSampleStep)
        for point in sampledPoints {
            let rect = NSRect(
                x: point.x - Self.mosaicBrushRadius,
                y: point.y - Self.mosaicBrushRadius,
                width: Self.mosaicBrushRadius * 2,
                height: Self.mosaicBrushRadius * 2
            ).intersection(bounds)
            drawMosaicBlock(rect)
        }
    }

    private func drawMosaicBlock(_ rect: NSRect) {
        guard rect.width >= 8, rect.height >= 8 else { return }
        let scaleX = CGFloat(snapshot.image.width) / bounds.width
        let scaleY = CGFloat(snapshot.image.height) / bounds.height
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: (bounds.height - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral
        guard let cropped = snapshot.image.cropping(to: cropRect) else { return }
        let tinySize = NSSize(width: max(1, rect.width / 12), height: max(1, rect.height / 12))
        let source = NSImage(cgImage: cropped, size: rect.size)
        let tiny = NSImage(size: tinySize)
        tiny.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: tinySize), from: NSRect(origin: .zero, size: rect.size), operation: .copy, fraction: 1)
        tiny.unlockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        tiny.draw(in: rect, from: NSRect(origin: .zero, size: tinySize), operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.imageInterpolation = .default
    }

    private func sampleStrokePoints(_ points: [NSPoint], spacing: CGFloat) -> [NSPoint] {
        guard let first = points.first else { return [] }
        guard points.count > 1 else { return [first] }

        var sampled = [first]
        var previous = first
        var carry: CGFloat = 0

        for point in points.dropFirst() {
            let dx = point.x - previous.x
            let dy = point.y - previous.y
            let distance = hypot(dx, dy)
            guard distance > 0 else { continue }

            var traveled = spacing - carry
            while traveled <= distance {
                let t = traveled / distance
                sampled.append(NSPoint(x: previous.x + dx * t, y: previous.y + dy * t))
                traveled += spacing
            }

            carry = distance - max(0, traveled - spacing)
            previous = point
        }

        return sampled
    }

    private func drawHandles(for rect: NSRect) {
        NSColor.systemBlue.setFill()
        let points = [
            NSPoint(x: rect.minX, y: rect.minY),
            NSPoint(x: rect.midX, y: rect.minY),
            NSPoint(x: rect.maxX, y: rect.minY),
            NSPoint(x: rect.minX, y: rect.midY),
            NSPoint(x: rect.maxX, y: rect.midY),
            NSPoint(x: rect.minX, y: rect.maxY),
            NSPoint(x: rect.midX, y: rect.maxY),
            NSPoint(x: rect.maxX, y: rect.maxY)
        ]
        for point in points {
            NSBezierPath(ovalIn: NSRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)).fill()
        }
    }

    private func drawSizeBadge(for rect: NSRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        var badge = NSRect(x: rect.minX, y: rect.maxY + 6, width: size.width + 12, height: 22)
        if badge.maxY > bounds.maxY - 4 {
            badge.origin.y = rect.minY - 28
        }
        badge.origin.x = min(max(badge.origin.x, 6), bounds.maxX - badge.width - 6)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5).fill()
        (text as NSString).draw(
            at: NSPoint(x: badge.minX + 6, y: badge.minY + 4),
            withAttributes: attrs
        )
    }

    private func intersects(_ annotation: ScreenshotAnnotation, _ rect: NSRect) -> Bool {
        annotation.bounds.intersects(rect)
    }

    private func isTiny(_ annotation: ScreenshotAnnotation) -> Bool {
        switch annotation {
        case .rectangle(let rect, _), .ellipse(let rect, _):
            return rect.width < 4 && rect.height < 4
        case .mosaic(let points):
            return points.count < 2
        case .arrow(let start, let end, _):
            return hypot(end.x - start.x, end.y - start.y) < 6
        case .brush(let points, _):
            return points.count < 2
        case .text(let text, _, _):
            return text.isEmpty
        }
    }

    private func addText(at point: NSPoint) {
        commitActiveText()
        toolbar.isHidden = true
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y - 4, width: 240, height: 28))
        field.placeholderString = L10n.pluginScreenshotTextPlaceholder
        field.font = .systemFont(ofSize: 20, weight: .semibold)
        field.textColor = .systemRed
        field.backgroundColor = NSColor.white.withAlphaComponent(0.9)
        field.focusRingType = .none
        field.target = self
        field.action = #selector(commitActiveText)
        addSubview(field)
        activeTextField = field
        activeTextOrigin = point
        window?.makeFirstResponder(field)
    }

    @objc private func commitActiveText() {
        guard let field = activeTextField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let origin = activeTextOrigin ?? field.frame.origin
        field.removeFromSuperview()
        activeTextField = nil
        activeTextOrigin = nil
        if !text.isEmpty {
            annotations.append(.text(text, origin, activeColor))
        }
        if let selection {
            positionToolbar(for: selection)
        }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    @objc private func toolSelected(_ sender: NSButton) {
        guard let tool = ScreenshotTool(tag: sender.tag) else { return }
        selectTool(tool)
    }

    private func selectTool(_ tool: ScreenshotTool) {
        activeTool = tool
        refreshToolButtons()
        if let selection {
            positionToolbar(for: selection)
        }
    }

    private func refreshToolButtons() {
        for (tool, button) in toolButtons {
            button.state = tool == activeTool ? .on : .off
            button.contentTintColor = .white
            button.layer?.backgroundColor = tool == activeTool
                ? NSColor.white.withAlphaComponent(0.16).cgColor
                : NSColor.clear.cgColor
        }
    }

    @objc private func colorSelected(_ sender: NSButton) {
        guard let sender = sender as? ColorButton else { return }
        let color = sender.annotationColor
        activeColor = color
        if let selectedAnnotationIndex, annotations.indices.contains(selectedAnnotationIndex) {
            annotations[selectedAnnotationIndex] = annotations[selectedAnnotationIndex].withColor(color)
        }
        refreshColorButtons()
        needsDisplay = true
    }

    private func refreshColorButtons() {
        for button in colorButtons {
            let color = button.annotationColor
            let selected = color == activeColor
            button.layer?.borderWidth = selected ? 2 : 0
            button.layer?.borderColor = selected ? NSColor.systemGreen.cgColor : NSColor.clear.cgColor
            button.title = selected ? "✓" : ""
            button.font = .systemFont(ofSize: 12, weight: .bold)
            button.contentTintColor = .systemGreen
        }
    }

    private func toolUsesColor(_ tool: ScreenshotTool) -> Bool {
        switch tool {
        case .rectangle, .ellipse, .arrow, .brush, .text:
            return true
        case .select, .mosaic:
            return false
        }
    }

    private func annotationIndex(at point: NSPoint) -> Int? {
        annotations.indices.reversed().first { annotationContainsPoint(annotations[$0], point) }
    }

    private func annotationContainsPoint(_ annotation: ScreenshotAnnotation, _ point: NSPoint) -> Bool {
        let tolerance: CGFloat = 8
        switch annotation {
        case .rectangle(let rect, _):
            if rect.width < 2 || rect.height < 2 {
                return distance(from: point, toSegmentFrom: rect.origin, to: NSPoint(x: rect.maxX, y: rect.maxY)) <= tolerance
            }
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
                && !rect.insetBy(dx: tolerance, dy: tolerance).contains(point)
        case .ellipse(let rect, _):
            guard rect.width > 0, rect.height > 0 else { return false }
            guard rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point) else { return false }
            let rx = rect.width / 2
            let ry = rect.height / 2
            guard rx > 0, ry > 0 else { return false }
            let dx = (point.x - rect.midX) / rx
            let dy = (point.y - rect.midY) / ry
            let normalizedDistance = sqrt(dx * dx + dy * dy)
            return abs(normalizedDistance - 1) * min(rx, ry) <= tolerance
        case .arrow(let start, let end, _):
            return distance(from: point, toSegmentFrom: start, to: end) <= tolerance
        case .brush(let points, _):
            return stroke(points, contains: point, tolerance: tolerance)
        case .text:
            return annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .mosaic(let points):
            return stroke(points, contains: point, tolerance: Self.mosaicBrushRadius)
        }
    }

    private func stroke(_ points: [NSPoint], contains point: NSPoint, tolerance: CGFloat) -> Bool {
        guard let first = points.first else { return false }
        guard points.count > 1 else { return hypot(point.x - first.x, point.y - first.y) <= tolerance }

        var previous = first
        for current in points.dropFirst() {
            if distance(from: point, toSegmentFrom: previous, to: current) <= tolerance {
                return true
            }
            previous = current
        }
        return false
    }

    private func distance(from point: NSPoint, toSegmentFrom start: NSPoint, to end: NSPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projected = NSPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projected.x, point.y - projected.y)
    }

    private func drawSelectionOutline(for rect: NSRect) {
        NSColor.controlAccentColor.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: -4, dy: -4))
        path.lineWidth = 1
        path.setLineDash([4, 3], count: 2, phase: 0)
        path.stroke()
    }

    @objc private func undo() {
        if previewAnnotation != nil {
            previewAnnotation = nil
        } else if !annotations.isEmpty {
            annotations.removeLast()
        }
        needsDisplay = true
    }

    @objc private func copySelection() {
        commitActiveText()
        guard let selection else { return }
        onCopy?(selection)
    }

    @objc private func saveSelection() {
        commitActiveText()
        guard let selection else { return }
        onSave?(selection)
    }

    @objc private func recordSelection() {
        commitActiveText()
        guard let selection, onRecord != nil else { return }
        onRecord?(selection)
    }

    @objc private func cancel() {
        activeTextField?.removeFromSuperview()
        activeTextField = nil
        onCancel?()
    }
}

private extension ScreenshotTool {
    var tag: Int {
        switch self {
        case .select: return 0
        case .rectangle: return 1
        case .ellipse: return 2
        case .arrow: return 3
        case .brush: return 4
        case .text: return 5
        case .mosaic: return 6
        }
    }

    init?(tag: Int) {
        switch tag {
        case 1: self = .rectangle
        case 2: self = .ellipse
        case 3: self = .arrow
        case 4: self = .brush
        case 5: self = .text
        case 6: self = .mosaic
        default: return nil
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
