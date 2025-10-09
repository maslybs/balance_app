import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    
    private var localMonitor: Any?
    
    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu(title: "Balance App")
        
        let openItem = NSMenuItem(title: "Відкрити панель", action: #selector(openFromMenu(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Вийти", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }()
    
    init(popover: NSPopover) {
        self.popover = popover
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
    }
    
    func invalidate() {
        stopEventMonitors()
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    @objc private func handleClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        
        switch event.type {
        case .rightMouseUp, .rightMouseDown:
            showMenu()
        default:
            togglePopover(sender)
        }
    }
    
    @objc private func openFromMenu(_ sender: Any?) {
        togglePopover(sender)
    }
    
    @objc private func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
    
    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        button.image = NSImage(systemSymbolName: "dollarsign.circle.fill", accessibilityDescription: "Balance App")?
            .withSymbolConfiguration(symbolConfig)
        button.action = #selector(handleClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Balance App"
    }
    
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    private func showPopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startEventMonitors()
    }
    
    private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopEventMonitors()
    }
    
    private func showMenu() {
        closePopover(nil)
        guard let button = statusItem.button else { return }
        statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
    }
    
    private func startEventMonitors() {
        stopEventMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if let popoverWindow = self.popover.contentViewController?.view.window,
               event.window === popoverWindow {
                return event
            }
            self.closePopover(nil)
            return event
        }
    }
    
    private func stopEventMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
