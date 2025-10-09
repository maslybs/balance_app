import SwiftUI

@main
struct BalanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
