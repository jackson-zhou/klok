import AppKit

final class PluginContext {
    let menuRegistry: MenuRegistry
    let settings: PluginSettingsStore

    init(menuRegistry: MenuRegistry, settings: PluginSettingsStore) {
        self.menuRegistry = menuRegistry
        self.settings = settings
    }

    func showAlert(title: String, message: String = "") {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }
}
