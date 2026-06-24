import Foundation

final class PluginSettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isEnabled(pluginID: String, default defaultValue: Bool = true) -> Bool {
        let key = enabledKey(pluginID)
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func setEnabled(_ enabled: Bool, pluginID: String) {
        defaults.set(enabled, forKey: enabledKey(pluginID))
    }

    func bool(pluginID: String, key: String, default defaultValue: Bool = false) -> Bool {
        let namespacedKey = settingKey(pluginID: pluginID, key: key)
        guard defaults.object(forKey: namespacedKey) != nil else { return defaultValue }
        return defaults.bool(forKey: namespacedKey)
    }

    func setBool(_ value: Bool, pluginID: String, key: String) {
        defaults.set(value, forKey: settingKey(pluginID: pluginID, key: key))
    }

    func integer(pluginID: String, key: String, default defaultValue: Int) -> Int {
        let namespacedKey = settingKey(pluginID: pluginID, key: key)
        guard defaults.object(forKey: namespacedKey) != nil else { return defaultValue }
        return defaults.integer(forKey: namespacedKey)
    }

    func setInteger(_ value: Int, pluginID: String, key: String) {
        defaults.set(value, forKey: settingKey(pluginID: pluginID, key: key))
    }

    func string(pluginID: String, key: String, default defaultValue: String = "") -> String {
        defaults.string(forKey: settingKey(pluginID: pluginID, key: key)) ?? defaultValue
    }

    func setString(_ value: String, pluginID: String, key: String) {
        defaults.set(value, forKey: settingKey(pluginID: pluginID, key: key))
    }

    private func enabledKey(_ pluginID: String) -> String {
        "plugin.\(pluginID).enabled"
    }

    private func settingKey(pluginID: String, key: String) -> String {
        "plugin.\(pluginID).\(key)"
    }
}
