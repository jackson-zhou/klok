import AppKit
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
        session?.cancel()
        let newSession = ScreenshotSessionController(
            onCopy: { [weak self] in self?.notifyCopied() },
            onFinish: { [weak self] in self?.session = nil },
            onError: { [weak self] message in
                self?.context?.showAlert(title: L10n.pluginScreenshotFailed, message: message)
            }
        )
        session = newSession
        newSession.start()
    }

    private func notifyCopied() {
        let content = UNMutableNotificationContent()
        content.title = L10n.pluginScreenshotTitle
        content.body = L10n.pluginScreenshotCopied
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
    private var permissionCheckWorkItem: DispatchWorkItem?
    private var isFinished = false
    private let onCopy: () -> Void
    private let onFinish: () -> Void
    private let onError: (String) -> Void

    init(onCopy: @escaping () -> Void, onFinish: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.onCopy = onCopy
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
        let snapshots = NSScreen.screens.compactMap { screen -> ScreenSnapshot? in
            guard let image = Self.capture(screen: screen) else { return nil }
            return ScreenSnapshot(screen: screen, image: image)
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

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        permissionCheckWorkItem?.cancel()
        permissionCheckWorkItem = nil
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

    private func requestScreenCaptureAccess(completion: @escaping (Bool) -> Void) {
        if CGPreflightScreenCaptureAccess() {
            completion(true)
            return
        }

        _ = CGRequestScreenCaptureAccess()
        waitForScreenCaptureAccess(deadline: Date().addingTimeInterval(60), completion: completion)
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
    case mosaic(NSRect)
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
        case .mosaic(let rect):
            return .mosaic(rect.offsetBy(dx: dx, dy: dy))
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
        case .rectangle(let rect, _), .ellipse(let rect, _), .mosaic(let rect):
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
        }
    }
}

private final class ScreenshotOverlayView: NSView {
    var onCopy: ((NSRect) -> Void)?
    var onSave: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

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
    private var dragStart: NSPoint?
    private var dragMode: DragMode?
    private var activeTool: ScreenshotTool = .select
    private var activeColor: NSColor = .systemRed
    private var annotations: [ScreenshotAnnotation] = []
    private var previewAnnotation: ScreenshotAnnotation?
    private var selectedAnnotationIndex: Int?
    private var toolButtons: [ScreenshotTool: NSButton] = [:]
    private var colorButtons: [ColorButton] = []
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

    override func mouseDown(with event: NSEvent) {
        let point = event.locationInWindow
        if handleToolbarClick(at: point) { return }
        commitActiveText()
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
            selection = NSRect(origin: point, size: .zero)
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
            selection = normalizedRect(from: start, to: current)
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
        }

        guard let start = dragStart, let dragMode else { return }
        switch dragMode {
        case .selection:
            let rect = normalizedRect(from: start, to: event.locationInWindow)
            if rect.width < 6 || rect.height < 6 {
                selection = nil
                toolbar.isHidden = true
            } else {
                selection = rect
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

        guard let rect = selection else { return }
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

        drawHandles(for: rect)
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
            (.brush, L10n.pluginScreenshotBrush, "paintbrush"),
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
        let commandCount = CGFloat(4)
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
            return .mosaic(normalizedRect(from: start, to: current))
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
            case .mosaic(let rect):
                drawMosaic(rect)
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

    private func drawMosaic(_ rect: NSRect) {
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
        case .mosaic(let rect):
            return rect.width < 4 || rect.height < 4
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
        annotations.indices.reversed().first { annotations[$0].bounds.insetBy(dx: -6, dy: -6).contains(point) }
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
