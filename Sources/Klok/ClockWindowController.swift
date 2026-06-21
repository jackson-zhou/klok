import AppKit

final class ClockWindowController: NSWindowController {
    private let clockView: ClockView

    init(calendarPanel: CalendarPanel) {
        let size = Settings.shared.clockSize
        let x = Settings.shared.windowX
        let y = Settings.shared.windowY

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        clockView = ClockView(frame: NSRect(origin: .zero, size: CGSize(width: size, height: size)),
                              calendarPanel: calendarPanel)
        panel.contentView = clockView

        super.init(window: panel)
        applyWindowLevel()
        applyMouseBehavior()

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError() }

    func showClock() {
        window?.orderFrontRegardless()
    }

    @objc private func settingsChanged() {
        applyWindowLevel()
        applyOpacity()
        applySize()
        applyMouseBehavior()
    }

    private func applyWindowLevel() {
        guard let win = window else { return }
        if Settings.shared.embedInDesktop {
            // Sit just above the desktop (wallpaper), behind every app window
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        } else if Settings.shared.pinToDesktop {
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevel.init(0)))
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        } else if Settings.shared.alwaysOnTop {
            win.level = .floating
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            win.level = .normal
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        }
    }

    private func applyMouseBehavior() {
        window?.ignoresMouseEvents = Settings.shared.clickThrough
    }

    private func applyOpacity() {
        window?.alphaValue = CGFloat(Settings.shared.opacity)
    }

    private func applySize() {
        guard let win = window else { return }
        let s = Settings.shared.clockSize
        let origin = win.frame.origin
        let newFrame = NSRect(x: origin.x, y: origin.y, width: s, height: s)
        win.setFrame(newFrame, display: true)
        clockView.frame = NSRect(origin: .zero, size: CGSize(width: s, height: s))
    }
}
