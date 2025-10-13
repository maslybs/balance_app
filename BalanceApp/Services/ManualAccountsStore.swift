import Foundation

@MainActor
final class ManualAccountsStore: ObservableObject {
    static let shared = ManualAccountsStore()
    
    @Published private(set) var accounts: [ManualAccount]
    
    private let defaults: UserDefaults
    private let defaultsKey = "settings.manualAccounts"
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([ManualAccount].self, from: data) {
            self.accounts = decoded
        } else {
            self.accounts = []
        }
    }
    
    func replace(with newAccounts: [ManualAccount]) {
        accounts = newAccounts
        persist()
    }
    
    func addEmptyAccount() {
        var updated = accounts
        updated.append(ManualAccount(title: "", amount: 0, currencyCode: "UAH"))
        replace(with: updated)
    }
    
    func removeAccount(_ account: ManualAccount) {
        replace(with: accounts.filter { $0.id != account.id })
    }
    
    func updateAccount(_ account: ManualAccount) {
        var updated = accounts
        if let index = updated.firstIndex(where: { $0.id == account.id }) {
            updated[index] = account
            replace(with: updated)
        }
    }
    
    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
