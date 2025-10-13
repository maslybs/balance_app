import Foundation
import Combine

@MainActor
final class ProviderPreferences: ObservableObject {
    static let shared = ProviderPreferences()
    
    @Published private(set) var enabledProviders: Set<BalanceProvider>
    
    private let defaults: UserDefaults
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabledProviders = ProviderPreferences.loadEnabledProviders(from: defaults)
    }
    
    func isEnabled(_ provider: BalanceProvider) -> Bool {
        if provider == .manualAccounts {
            return true
        }
        return enabledProviders.contains(provider)
    }
    
    func set(_ provider: BalanceProvider, enabled: Bool) {
        guard provider != .manualAccounts else { return }
        if enabled {
            enabledProviders.insert(provider)
        } else {
            enabledProviders.remove(provider)
        }
        defaults.set(enabled, forKey: provider.preferenceDefaultsKey)
    }
    
    private static func loadEnabledProviders(from defaults: UserDefaults) -> Set<BalanceProvider> {
        let available = BalanceProvider.remoteProviders
        var enabledSet = Set<BalanceProvider>()
        for provider in available {
            if defaults.object(forKey: provider.preferenceDefaultsKey) == nil {
                enabledSet.insert(provider)
            } else if defaults.bool(forKey: provider.preferenceDefaultsKey) {
                enabledSet.insert(provider)
            }
        }
        return enabledSet
    }
}
