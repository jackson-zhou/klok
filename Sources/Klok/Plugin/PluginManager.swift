import AppKit

final class PluginManager {
    static let shared = PluginManager()

    let menuRegistry = MenuRegistry()
    let settings = PluginSettingsStore()

    private(set) var plugins: [KlokPlugin] = []
    private var activePluginIDs = Set<String>()

    private init() {}

    func registerBuiltinPlugins() {
        guard plugins.isEmpty else { return }
        plugins = [
            ScreenshotPlugin(),
            ClipboardHistoryPlugin()
        ]
    }

    func activateEnabledPlugins() {
        registerBuiltinPlugins()
        for plugin in plugins where settings.isEnabled(pluginID: plugin.id, default: plugin.isEnabledByDefault) {
            let context = PluginContext(menuRegistry: menuRegistry, settings: settings)
            plugin.activate(context: context)
            activePluginIDs.insert(plugin.id)
        }
    }

    func deactivatePlugins() {
        for plugin in plugins where activePluginIDs.contains(plugin.id) {
            plugin.deactivate()
        }
        activePluginIDs.removeAll()
    }

    func plugin(withID id: String) -> KlokPlugin? {
        registerBuiltinPlugins()
        return plugins.first { $0.id == id }
    }
}
