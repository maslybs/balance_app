import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 640, height: 600)
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        statusBarController = StatusBarController(popover: popover)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.invalidate()
    }
}
