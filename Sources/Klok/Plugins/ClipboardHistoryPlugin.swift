import AppKit

struct ClipboardHistoryItem: Equatable {
    let text: String
    let createdAt: Date
}

final class ClipboardHistoryPlugin: KlokPlugin {
    let id = "clipboard-history"
    let name = "Clipboard History"
    let version = "0.1.0"
    let isConfigurable = true

    private var monitor: PasteboardMonitor?
    private var history: [ClipboardHistoryItem] = []
    private var windowController: ClipboardHistoryWindowController?
    private weak var context: PluginContext?

    func activate(context: PluginContext) {
        self.context = context
        monitor = PasteboardMonitor { [weak self] text in
            self?.record(text)
        }
        monitor?.start()

        context.menuRegistry.addItem(title: L10n.pluginClipboardMenu, location: .statusMenu) { [weak self] in
            self?.showHistoryWindow()
        }
        context.menuRegistry.addItem(title: L10n.pluginClipboardMenu, location: .clockMenu) { [weak self] in
            self?.showHistoryWindow()
        }
    }

    func deactivate() {
        monitor?.stop()
        monitor = nil
        windowController?.close()
        windowController = nil
    }

    func showConfiguration(parentWindow: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = L10n.pluginClipboardTitle
        alert.informativeText = L10n.pluginClipboardConfigInfo
        alert.addButton(withTitle: L10n.btnOK)
        alert.addButton(withTitle: L10n.pluginClipboardClear)
        if let parentWindow {
            alert.beginSheetModal(for: parentWindow) { [weak self] response in
                if response == .alertSecondButtonReturn {
                    self?.clearHistory()
                }
            }
            return
        } else {
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                clearHistory()
            }
        }
    }

    private func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.main.async {
            self.history.removeAll { $0.text == trimmed }
            self.history.insert(ClipboardHistoryItem(text: trimmed, createdAt: Date()), at: 0)
            let maxItems = self.context?.settings.integer(pluginID: self.id, key: "maxItems", default: 200) ?? 200
            if self.history.count > maxItems {
                self.history.removeLast(self.history.count - maxItems)
            }
            self.windowController?.update(items: self.history)
        }
    }

    private func showHistoryWindow() {
        if windowController == nil {
            windowController = ClipboardHistoryWindowController { [weak self] text in
                self?.copyToPasteboard(text)
            }
        }
        windowController?.update(items: history)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clearHistory() {
        history.removeAll()
        windowController?.update(items: history)
    }
}

final class PasteboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private let onTextChanged: (String) -> Void

    init(onTextChanged: @escaping (String) -> Void) {
        self.onTextChanged = onTextChanged
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string) else { return }
        onTextChanged(text)
    }
}

final class ClipboardHistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private var items: [ClipboardHistoryItem] = []
    private var filteredItems: [ClipboardHistoryItem] = []
    private let onSelect: (String) -> Void

    init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.pluginClipboardTitle
        super.init(window: win)
        win.center()
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(items: [ClipboardHistoryItem]) {
        self.items = items
        applyFilter()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        searchField.frame = NSRect(x: 14, y: 376, width: 492, height: 26)
        searchField.placeholderString = L10n.pluginClipboardSearch
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.delegate = self
        content.addSubview(searchField)

        let scroll = NSScrollView(frame: NSRect(x: 14, y: 14, width: 492, height: 350))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clipboard"))
        col.width = 476
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = 46
        tableView.dataSource = self
        tableView.delegate = self
        tableView.doubleAction = #selector(chooseSelected)
        tableView.target = self
        scroll.documentView = tableView
        content.addSubview(scroll)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(searchField)
    }

    @objc private func searchChanged() {
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filteredItems = query.isEmpty ? items : items.filter { $0.text.lowercased().contains(query) }
        tableView.reloadData()
        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            chooseSelected()
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(delta: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(delta: -1)
            return true
        default:
            return false
        }
    }

    private func moveSelection(delta: Int) {
        guard !filteredItems.isEmpty else { return }
        let current = max(tableView.selectedRow, 0)
        let next = min(max(current + delta, 0), filteredItems.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    @objc private func chooseSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredItems.count else { return }
        onSelect(filteredItems[row].text)
        close()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredItems[row]
        let cell = NSTableCellView()
        cell.frame = NSRect(x: 0, y: 0, width: tableColumn?.width ?? 476, height: 46)

        let text = item.text.replacingOccurrences(of: "\n", with: " ")
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 8, y: 18, width: cell.frame.width - 16, height: 18)
        label.lineBreakMode = .byTruncatingTail
        label.font = .systemFont(ofSize: 13)
        cell.addSubview(label)

        let date = NSTextField(labelWithString: item.createdAt.formatted(date: .omitted, time: .shortened))
        date.frame = NSRect(x: 8, y: 3, width: cell.frame.width - 16, height: 14)
        date.textColor = .secondaryLabelColor
        date.font = .systemFont(ofSize: 10)
        cell.addSubview(date)

        return cell
    }
}
