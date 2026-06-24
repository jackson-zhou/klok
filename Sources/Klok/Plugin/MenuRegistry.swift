import AppKit

enum PluginMenuLocation {
    case statusMenu
    case clockMenu
}

final class PluginMenuItem {
    let title: String
    let keyEquivalent: String
    let handler: () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping () -> Void) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.handler = handler
    }
}

final class MenuRegistry {
    private var itemsByLocation: [PluginMenuLocation: [PluginMenuItem]] = [:]

    func addItem(title: String, location: PluginMenuLocation = .statusMenu, keyEquivalent: String = "", handler: @escaping () -> Void) {
        itemsByLocation[location, default: []].append(
            PluginMenuItem(title: title, keyEquivalent: keyEquivalent, handler: handler)
        )
    }

    func items(for location: PluginMenuLocation) -> [PluginMenuItem] {
        itemsByLocation[location] ?? []
    }
}

final class PluginMenuActionTarget: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func invoke() {
        handler()
    }
}

enum PluginMenuBuilder {
    static func appendPluginItems(from registry: MenuRegistry, location: PluginMenuLocation, to menu: NSMenu) {
        let pluginItems = registry.items(for: location)
        guard !pluginItems.isEmpty else { return }

        menu.addItem(.separator())
        for pluginItem in pluginItems {
            let target = PluginMenuActionTarget(handler: pluginItem.handler)
            let item = NSMenuItem(
                title: pluginItem.title,
                action: #selector(PluginMenuActionTarget.invoke),
                keyEquivalent: pluginItem.keyEquivalent
            )
            item.target = target
            item.representedObject = target
            menu.addItem(item)
        }
    }
}
