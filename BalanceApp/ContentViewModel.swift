import Foundation
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var privatBalances: [BalanceItem] = []
    @Published private(set) var wiseBalances: [BalanceItem] = []
    @Published private(set) var exchangeRates: [ExchangeRateItem] = []
    @Published private(set) var totals: [CurrencyTotal] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessages: [String] = []
    @Published private(set) var missingTokens: Set<BalanceProvider> = []
    @Published private(set) var enabledProviders: Set<BalanceProvider>
    @Published private(set) var manualBalances: [BalanceItem] = []
    
    private let apiService: APIService
    private let preferences: ProviderPreferences
    private let manualAccountsStore: ManualAccountsStore
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService = .shared, preferences: ProviderPreferences? = nil) {
        self.apiService = apiService
        let resolvedPreferences = preferences ?? ProviderPreferences.shared
        self.preferences = resolvedPreferences
        self.enabledProviders = resolvedPreferences.enabledProviders
        self.manualAccountsStore = ManualAccountsStore.shared
        
        resolvedPreferences.$enabledProviders
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                self.enabledProviders = newValue
                Task {
                    await self.loadAllData()
                }
            }
            .store(in: &cancellables)
        
        manualAccountsStore.$accounts
            .receive(on: RunLoop.main)
            .sink { [weak self] accounts in
                guard let self else { return }
                self.manualBalances = accounts.map { account in
                    BalanceItem(
                        id: account.id,
                        provider: .manualAccounts,
                        title: account.title.isEmpty ? "Без назви" : account.title,
                        currencyCode: account.currencyCode.uppercased(),
                        amount: account.amount
                    )
                }
                self.rebuildTotals()
            }
            .store(in: &cancellables)
    }
    
    func loadAllData() async {
        if isLoading {
            return
        }
        isLoading = true
        errorMessages.removeAll()
        missingTokens.removeAll()
        
        await withTaskGroup(of: Void.self) { group in
            if isProviderEnabled(.privatBank) {
                group.addTask { [weak self] in
                    await self?.loadPrivatBalances()
                }
            } else {
                privatBalances = []
            }
            
            if isProviderEnabled(.wise) {
                group.addTask { [weak self] in
                    await self?.loadWiseBalances()
                }
                
                group.addTask { [weak self] in
                    await self?.loadExchangeRates()
                }
            } else {
                wiseBalances = []
                exchangeRates = []
            }
        }
        
        rebuildTotals()
        if privatBalances.isEmpty == false ||
            wiseBalances.isEmpty == false ||
            exchangeRates.isEmpty == false ||
            manualBalances.isEmpty == false {
            lastUpdated = Date()
        } else {
            lastUpdated = nil
        }
        isLoading = false
    }
    
    func refreshManually() async {
        await loadAllData()
    }
    
    func setProvider(_ provider: BalanceProvider, enabled: Bool) {
        guard provider != .manualAccounts else { return }
        preferences.set(provider, enabled: enabled)
        if enabled == false {
            switch provider {
            case .privatBank:
                privatBalances = []
            case .wise:
                wiseBalances = []
                exchangeRates = []
            case .manualAccounts:
                break
            }
            missingTokens.remove(provider)
            rebuildTotals()
            if privatBalances.isEmpty && wiseBalances.isEmpty && exchangeRates.isEmpty && manualBalances.isEmpty {
                lastUpdated = nil
            }
        }
    }
    
    func isProviderEnabled(_ provider: BalanceProvider) -> Bool {
        preferences.isEnabled(provider)
    }
    
    private func loadPrivatBalances() async {
        do {
            let items = try await apiService.fetchPrivatBalances()
            privatBalances = filterNonZeroBalances(items)
        } catch let error as APIServiceError {
            handle(apiError: error)
            privatBalances = []
        } catch {
            appendError(message: error.localizedDescription)
            privatBalances = []
        }
    }
    
    private func loadWiseBalances() async {
        do {
            let items = try await apiService.fetchWiseBalances()
            wiseBalances = filterNonZeroBalances(items)
        } catch let error as APIServiceError {
            handle(apiError: error)
            wiseBalances = []
        } catch {
            appendError(message: error.localizedDescription)
            wiseBalances = []
        }
    }
    
    private func loadExchangeRates() async {
        do {
            let items = try await apiService.fetchExchangeRates()
            exchangeRates = items.sorted { lhs, rhs in
                if lhs.sourceCurrency == rhs.sourceCurrency {
                    return lhs.targetCurrency < rhs.targetCurrency
                }
                return lhs.sourceCurrency < rhs.sourceCurrency
            }
        } catch let error as APIServiceError {
            handle(apiError: error)
            exchangeRates = []
        } catch {
            appendError(message: error.localizedDescription)
            exchangeRates = []
        }
    }
    
    private func rebuildTotals() {
        let allBalances = privatBalances + wiseBalances + manualBalances
        var accumulator: [String: Decimal] = [:]
        for item in allBalances {
            accumulator[item.currencyCode, default: .zero] += item.amount
        }
        totals = accumulator
            .map { CurrencyTotal(currencyCode: $0.key, totalAmount: $0.value) }
            .sorted { $0.currencyCode < $1.currencyCode }
    }
    
    private func appendError(message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        if errorMessages.contains(trimmed) == false {
            errorMessages.append(trimmed)
        }
    }
    
    private func handle(apiError: APIServiceError) {
        switch apiError {
        case .missingToken(let provider):
            missingTokens.insert(provider)
        default:
            appendError(message: apiError.localizedDescription)
        }
    }
    
    private func filterNonZeroBalances(_ balances: [BalanceItem]) -> [BalanceItem] {
        balances.filter { $0.amount != .zero }
    }
}
