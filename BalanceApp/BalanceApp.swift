import SwiftUI

@main
struct BalanceApp: App {
    var body: some Scene {
        MenuBarExtra("Balance App", systemImage: "dollarsign.circle.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
