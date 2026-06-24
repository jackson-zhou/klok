import AppKit

protocol KlokPlugin: AnyObject {
    var id: String { get }
    var name: String { get }
    var version: String { get }
    var isConfigurable: Bool { get }

    func activate(context: PluginContext)
    func deactivate()
    func showConfiguration(parentWindow: NSWindow?)
}

extension KlokPlugin {
    var isConfigurable: Bool { false }

    func showConfiguration(parentWindow: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = L10n.pluginNoConfiguration
        alert.informativeText = name
        alert.runModal()
    }
}
