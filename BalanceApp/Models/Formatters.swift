import Foundation

enum Formatters {
    static func currencyFormatter(for currencyCode: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let uppercasedCode = currencyCode.uppercased()
        formatter.currencyCode = uppercasedCode
        if let symbol = customCurrencySymbols[uppercasedCode] {
            formatter.currencySymbol = symbol
        }
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter
    }
    
    static let balanceNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter
    }()
}

private let customCurrencySymbols: [String: String] = [
    "USD": "$",
    "EUR": "€",
    "UAH": "₴",
    "GBP": "£",
    "PLN": "zł"
]

extension Decimal {
    var asNSDecimalNumber: NSDecimalNumber {
        NSDecimalNumber(decimal: self)
    }
}
