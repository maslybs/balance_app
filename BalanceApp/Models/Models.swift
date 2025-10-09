import Foundation

enum BalanceProvider: String, Identifiable, CaseIterable {
    case privatBank = "PrivatBank (ФОП)"
    case wise = "Wise"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .privatBank:
            return "PrivatBank (ФОП)"
        case .wise:
            return "Wise"
        }
    }
    
    var accentSystemImageName: String {
        switch self {
        case .privatBank:
            return "creditcard.fill"
        case .wise:
            return "globe"
        }
    }
    
    var preferenceDefaultsKey: String {
        switch self {
        case .privatBank:
            return "settings.provider.privatBank.enabled"
        case .wise:
            return "settings.provider.wise.enabled"
        }
    }
}

struct BalanceItem: Identifiable, Hashable {
    let id: UUID
    let provider: BalanceProvider
    let title: String
    let currencyCode: String
    let amount: Decimal
    
    init(id: UUID = UUID(), provider: BalanceProvider, title: String, currencyCode: String, amount: Decimal) {
        self.id = id
        self.provider = provider
        self.title = title
        self.currencyCode = currencyCode
        self.amount = amount
    }
}

extension BalanceItem {
    var formattedAmount: String {
        Formatters.currencyFormatter(for: currencyCode)
            .string(from: amount.asNSDecimalNumber) ?? "\(amount)"
    }
}

struct CurrencyTotal: Identifiable, Hashable {
    let id = UUID()
    let currencyCode: String
    let totalAmount: Decimal
}

extension CurrencyTotal {
    var formattedTotal: String {
        Formatters.currencyFormatter(for: currencyCode)
            .string(from: totalAmount.asNSDecimalNumber) ?? "\(totalAmount)"
    }
}

struct ExchangeRateItem: Identifiable, Hashable {
    let id = UUID()
    let sourceCurrency: String
    let targetCurrency: String
    let rate: Decimal

    var pairDescription: String {
        "\(sourceCurrency) -> \(targetCurrency)"
    }
}

extension ExchangeRateItem {
    var formattedRate: String {
        Formatters.balanceNumberFormatter.string(from: rate.asNSDecimalNumber) ?? "\(rate)"
    }
}

struct BalanceSnapshot {
    let privatBalances: [BalanceItem]
    let wiseBalances: [BalanceItem]
    let exchangeRates: [ExchangeRateItem]
}
