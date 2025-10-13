import Foundation

struct ManualAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var amount: Decimal
    var currencyCode: String
    
    init(id: UUID = UUID(), title: String, amount: Decimal, currencyCode: String = "UAH") {
        self.id = id
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode.uppercased()
    }
}

extension ManualAccount {
    private enum CodingKeys: String, CodingKey {
        case id, title, amount, currencyCode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Decimal.self, forKey: .amount)
        if let code = try container.decodeIfPresent(String.self, forKey: .currencyCode) {
            currencyCode = code.uppercased()
        } else {
            currencyCode = "UAH"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(amount, forKey: .amount)
        try container.encode(currencyCode.uppercased(), forKey: .currencyCode)
    }
}
