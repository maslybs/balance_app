import SwiftUI

@main
struct BalanceApp: App {
    var body: some Scene {
        MenuBarExtra("Balance App", systemImage: "dollarsign.circle.fill") {
            ContentView()
                .frame(minWidth: 620, idealWidth: 680, minHeight: 520)
        }
        .menuBarExtraStyle(.window)
    }
}
