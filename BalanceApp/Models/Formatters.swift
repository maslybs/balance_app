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
    
    static let manualAmountInputFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
    
    static func decimal(from string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return Decimal.zero }
        if let number = manualAmountInputFormatter.number(from: trimmed) {
            return number.decimalValue
        }
        if let decimal = Decimal(string: trimmed, locale: Locale(identifier: "uk_UA")) {
            return decimal
        }
        return Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX"))
    }
    
    static func string(from decimal: Decimal) -> String {
        manualAmountInputFormatter.string(from: decimal.asNSDecimalNumber) ?? "\(decimal)"
    }
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
