import Foundation

enum APIServiceError: LocalizedError, Equatable {
    case missingToken(BalanceProvider)
    case invalidURL(String)
    case unexpectedStatus(service: BalanceProvider, code: Int)
    case decodingFailed(service: BalanceProvider, message: String)
    case emptyResponse(service: BalanceProvider)
    case custom(message: String)
    
    var errorDescription: String? {
        switch self {
        case .missingToken(let provider):
            return "Не вказано токен для \(provider.displayName). Додайте його у налаштуваннях."
        case .invalidURL(let rawValue):
            return "Невірна адреса запиту: \(rawValue)"
        case .unexpectedStatus(let service, let code):
            return "Сервер \(service.displayName) повернув помилку (\(code)). Спробуйте пізніше."
        case .decodingFailed(let service, let message):
            return "Не вдалося обробити відповідь від \(service.displayName): \(message)"
        case .emptyResponse(let service):
            return "Порожня відповідь від \(service.displayName)."
        case .custom(let message):
            return message
        }
    }
}

final class APIService {
    static let shared = APIService()
    
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    
    private init(session: URLSession? = nil) {
        if let injectedSession = session {
            self.session = injectedSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            configuration.httpAdditionalHeaders = [
                "Accept": "application/json",
                "User-Agent": "BalanceApp/1.0 (macOS)"
            ]
            self.session = URLSession(configuration: configuration)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }
    
    func fetchPrivatBalances() async throws -> [BalanceItem] {
        let token = try privatToken()
        let request = try makePrivatBalancesRequest(token: token)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.emptyResponse(service: .privatBank)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIServiceError.custom(message: message)
        }
        
        let entries = try parsePrivatAccounts(from: data)
        return entries.map {
            BalanceItem(provider: .privatBank,
                        title: $0.title,
                        currencyCode: $0.currency,
                        amount: $0.balance)
        }
    }
    
    func fetchWiseBalances() async throws -> [BalanceItem] {
        let token = try wiseToken()
        let profileId = try await fetchPrimaryWiseProfileId(token: token)
        let request = try makeWiseBalancesRequest(token: token, profileId: profileId)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.emptyResponse(service: .wise)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIServiceError.custom(message: message)
        }
        
        do {
            let balances = try parseWiseBalances(from: data)
            return balances.compactMap { dto in
                guard let amountValue = dto.primaryAmountValue,
                      let currencyCode = dto.primaryCurrencyCode else {
                    return nil
                }
                let title = dto.displayName
                return BalanceItem(provider: .wise,
                                   title: title,
                                   currencyCode: currencyCode,
                                   amount: amountValue)
            }
        } catch {
            throw APIServiceError.decodingFailed(service: .wise, message: error.localizedDescription)
        }
    }
    
    func fetchExchangeRates() async throws -> [ExchangeRateItem] {
        let currencyPairs: [(String, String)] = [
            ("USD", "UAH"),
            ("EUR", "UAH"),
            ("GBP", "UAH"),
            ("PLN", "UAH")
        ]
        
        var rateItems: [ExchangeRateItem] = []
        rateItems.reserveCapacity(currencyPairs.count)
        
        for (source, target) in currencyPairs {
            let request = try makeWiseRateRequest(source: source, target: target)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                continue
            }
            
            guard let rate = try parseWiseRate(from: data, source: source, target: target) else {
                continue
            }
            
            rateItems.append(rate)
        }
        
        return rateItems
    }
    
    // MARK: - Tokens
    
    private func privatToken() throws -> String {
        guard let token = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.privatToken)?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            throw APIServiceError.missingToken(.privatBank)
        }
        return token
    }
    
    private func wiseToken() throws -> String {
        guard let token = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.wiseToken)?.trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            throw APIServiceError.missingToken(.wise)
        }
        return token
    }
    
    // MARK: - Request builders
    
    private func makePrivatBalancesRequest(token: String) throws -> URLRequest {
        guard var components = URLComponents(string: "https://acp.privatbank.ua/api/statements/balance") else {
            throw APIServiceError.invalidURL("https://acp.privatbank.ua/api/statements/balance")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "uk_UA")
        let startDate = formatter.string(from: Date())
        var queryItems = [URLQueryItem(name: "startDate", value: startDate)]
        if components.queryItems?.isEmpty == false {
            queryItems.append(contentsOf: components.queryItems ?? [])
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw APIServiceError.invalidURL("https://acp.privatbank.ua/api/statements/balance")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "token")
        return request
    }
    
    private func makeWiseProfilesRequest(token: String) throws -> URLRequest {
        guard let url = URL(string: "https://api.transferwise.com/v1/profiles") else {
            throw APIServiceError.invalidURL("https://api.transferwise.com/v1/profiles")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func makeWiseBalancesRequest(token: String, profileId: Int) throws -> URLRequest {
        guard let url = URL(string: "https://api.transferwise.com/v4/profiles/\(profileId)/balances?types=STANDARD") else {
            throw APIServiceError.invalidURL("https://api.transferwise.com/v4/profiles/\(profileId)/balances")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func makeWiseRateRequest(source: String, target: String) throws -> URLRequest {
        guard var components = URLComponents(string: "https://api.transferwise.com/v1/rates") else {
            throw APIServiceError.invalidURL("https://api.transferwise.com/v1/rates")
        }
        components.queryItems = [
            URLQueryItem(name: "source", value: source),
            URLQueryItem(name: "target", value: target)
        ]
        guard let url = components.url else {
            throw APIServiceError.invalidURL("https://api.transferwise.com/v1/rates")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return request
    }
    
    // MARK: - Parsers
    
    private func parsePrivatAccounts(from data: Data) throws -> [PrivatAccountDTO] {
        if data.isEmpty {
            return []
        }
        
        if let envelope = try? jsonDecoder.decode(PrivatAccountsEnvelope.self, from: data) {
            return deduplicatePrivatAccounts(envelope.items)
        }
        
        if let directArray = try? jsonDecoder.decode([PrivatAccountDTO].self, from: data) {
            return deduplicatePrivatAccounts(directArray)
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        if let dictionary = jsonObject as? [String: Any] {
            if let extracted = extractPrivatAccountDictionaries(from: dictionary), extracted.isEmpty == false {
                let mapped = extracted.compactMap(PrivatAccountDTO.init(dictionary:))
                if mapped.isEmpty == false {
                    return deduplicatePrivatAccounts(mapped)
                }
            }
            if let message = dictionary["message"] as? String {
                throw APIServiceError.custom(message: message)
            }
            if let error = dictionary["error"] as? String {
                throw APIServiceError.custom(message: error)
            }
        } else if let array = jsonObject as? [[String: Any]] {
            let mapped = array.compactMap(PrivatAccountDTO.init(dictionary:))
            if mapped.isEmpty == false {
                return deduplicatePrivatAccounts(mapped)
            }
        }
        
        throw APIServiceError.decodingFailed(service: .privatBank, message: "Не вдалося знайти список рахунків.")
    }
    
    private func parseWiseBalances(from data: Data) throws -> [WiseBalanceDTO] {
        if data.isEmpty {
            return []
        }
        if let array = try? jsonDecoder.decode([WiseBalanceDTO].self, from: data) {
            return array
        }
        if let wrapper = try? jsonDecoder.decode(WiseBalancesWrapper.self, from: data) {
            return wrapper.balances
        }
        if let altWrapper = try? jsonDecoder.decode(WiseBalancesAlternativeWrapper.self, from: data) {
            return altWrapper.allBalances
        }
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        if let array = jsonObject as? [[String: Any]] {
            return array.compactMap(WiseBalanceDTO.init(dictionary:))
        }
        if let dictionary = jsonObject as? [String: Any] {
            let candidateKeys = ["balances", "content", "items", "data", "list", "response"]
            for key in candidateKeys {
                if let array = dictionary[key] as? [[String: Any]] {
                    let converted = array.compactMap(WiseBalanceDTO.init(dictionary:))
                    if converted.isEmpty == false {
                        return converted
                    }
                }
            }
            if let single = dictionary["balance"] as? [String: Any],
               let dto = WiseBalanceDTO(dictionary: single) {
                return [dto]
            }
        }
        throw APIServiceError.decodingFailed(service: .wise, message: "Не вдалося розпізнати структуру відповіді Wise.")
    }
    
    private func parseWiseRate(from data: Data, source: String, target: String) throws -> ExchangeRateItem? {
        if data.isEmpty {
            return nil
        }
        do {
            let rates = try jsonDecoder.decode([WiseRateDTO].self, from: data)
            guard let first = rates.first else { return nil }
            return ExchangeRateItem(sourceCurrency: first.source ?? source,
                                    targetCurrency: first.target ?? target,
                                    rate: first.rate)
        } catch {
            throw APIServiceError.decodingFailed(service: .wise, message: "Wise rates: \(error.localizedDescription)")
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String? {
        guard data.isEmpty == false else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let dictionary = object as? [String: Any] {
            if let message = dictionary["message"] as? String { return message }
            if let error = dictionary["error"] as? String { return error }
            if let description = dictionary["description"] as? String { return description }
            if let errors = dictionary["errors"] as? [String] {
                return errors.joined(separator: "\n")
            }
        }
        return nil
    }
    
    // MARK: - Wise helpers
    
    private func fetchPrimaryWiseProfileId(token: String) async throws -> Int {
        let request = try makeWiseProfilesRequest(token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.emptyResponse(service: .wise)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIServiceError.custom(message: message)
        }
        
        do {
            let profiles = try jsonDecoder.decode([WiseProfile].self, from: data)
            if let personal = profiles.first(where: { $0.type == "personal" }) {
                return personal.id
            }
            if let first = profiles.first {
                return first.id
            }
        } catch {
            throw APIServiceError.decodingFailed(service: .wise, message: error.localizedDescription)
        }
        
        throw APIServiceError.decodingFailed(service: .wise, message: "Не вдалося знайти профіль Wise.")
    }
}

// MARK: - DTOs

private func extractPrivatAccountDictionaries(from dictionary: [String: Any]) -> [[String: Any]]? {
    let candidateKeys = [
        "accounts", "cards", "balances", "list", "data", "items",
        "statements", "cardBalances", "cardbalance", "accountsList",
        "response", "res", "result", "body"
    ]
    var collected: [[String: Any]] = []
    var queue: [Any] = [dictionary]
    while let current = queue.popLast() {
        if let dict = current as? [String: Any] {
            for key in candidateKeys {
                if let array = dict[key] as? [[String: Any]] {
                    collected.append(contentsOf: array)
                } else if let nestedDict = dict[key] as? [String: Any] {
                    queue.append(nestedDict)
                }
            }
            for value in dict.values {
                if let nestedArray = value as? [[String: Any]] {
                    collected.append(contentsOf: nestedArray)
                } else if let nestedDict = value as? [String: Any] {
                    queue.append(nestedDict)
                }
            }
        } else if let array = current as? [[String: Any]] {
            collected.append(contentsOf: array)
            for element in array {
                queue.append(element)
            }
        }
    }
    return collected.isEmpty ? nil : collected
}

private func deduplicatePrivatAccounts(_ accounts: [PrivatAccountDTO]) -> [PrivatAccountDTO] {
    var seen = Set<String>()
    var result: [PrivatAccountDTO] = []
    result.reserveCapacity(accounts.count)
    for account in accounts {
        if seen.insert(account.identifier).inserted {
            result.append(account)
        }
    }
    return result
}

private struct PrivatAccountsEnvelope: Decodable {
    let items: [PrivatAccountDTO]
    
    private enum CodingKeys: String, CodingKey {
        case accounts, cards, balances, list, data, items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .accounts) {
            items = decoded
        } else if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .cards) {
            items = decoded
        } else if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .balances) {
            items = decoded
        } else if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .list) {
            items = decoded
        } else if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .data) {
            items = decoded
        } else if let decoded = try container.decodeIfPresent([PrivatAccountDTO].self, forKey: .items) {
            items = decoded
        } else {
            items = []
        }
    }
}

private struct PrivatAccountDTO: Decodable {
    let identifier: String
    let title: String
    let currency: String
    let balance: Decimal
    
    private enum CodingKeys: String, CodingKey {
        case id
        case account
        case cardNumber
        case cardNum
        case cardmask
        case iban
        case alias
        case title
        case description
        case name
        case type
        case currency
        case ccy
        case curr
        case balance
        case rest
        case available
        case amount
        case funds
        case value
        case availableBalance
        case balanceValue
        case balanceSum
        case balanceOut
        case remain
        case balanceIn
    }
    
    init(identifier: String, title: String, currency: String, balance: Decimal) {
        self.identifier = identifier
        self.title = title
        self.currency = currency
        self.balance = balance
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let identifier = try PrivatAccountDTO.decodeString(from: container,
                                                           keys: [.id, .account, .cardNumber, .cardNum, .iban])
            ?? UUID().uuidString
        
        let title = try PrivatAccountDTO.decodeString(from: container,
                                                      keys: [.title, .description, .alias, .cardmask, .name, .type])
            ?? PrivatAccountDTO.shortened(identifier: identifier)
        
        let currency = (try PrivatAccountDTO.decodeString(from: container,
                                                          keys: [.currency, .ccy, .curr]) ?? "UAH").uppercased()
        
        let balanceKeys: [CodingKeys] = [.balance, .rest, .available, .amount, .funds, .value, .availableBalance, .balanceValue, .balanceSum, .balanceOut, .remain, .balanceIn]
        let balance = PrivatAccountDTO.decodeDecimal(from: container,
                                                     keys: balanceKeys) ?? .zero
        
        self.init(identifier: identifier,
                  title: title,
                  currency: currency.uppercased(),
                  balance: balance)
    }
    
    init?(dictionary: [String: Any]) {
        let decimalKeys = ["balance", "rest", "available", "amount", "funds", "value", "balanceValue", "balanceSum", "remain", "availableBalance", "balanceOut", "balanceIn"]
        guard let balanceValue = PrivatAccountDTO.decimalValue(from: dictionary, keys: decimalKeys) else {
            return nil
        }
        
        let identifierKeys = ["id", "account", "cardNumber", "cardnum", "iban", "pan", "card", "acc", "internalId", "accountNumber", "ibanNumber"]
        let identifier = PrivatAccountDTO.stringValue(from: dictionary, keys: identifierKeys) ?? UUID().uuidString
        
        let titleKeys = ["title", "description", "alias", "cardmask", "name", "type", "accountName", "product", "cardType", "nameACC", "brnm"]
        let title = PrivatAccountDTO.stringValue(from: dictionary, keys: titleKeys) ?? PrivatAccountDTO.shortened(identifier: identifier)
        
        let currencyKeys = ["currency", "ccy", "curr", "currencyCode", "currency_code", "mainCurrency"]
        let currency = PrivatAccountDTO.stringValue(from: dictionary, keys: currencyKeys)?.uppercased() ?? "UAH"
        
        self.init(identifier: identifier, title: title, currency: currency, balance: balanceValue)
    }
    
    private static func shortened(identifier: String) -> String {
        if identifier.count > 6 {
            let suffix = identifier.suffix(4)
            return "****\(suffix)"
        } else {
            return identifier
        }
    }
    
    private static func stringValue(from dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, value.isEmpty == false {
                return value
            }
            if let nested = dictionary[key] as? [String: Any],
               let nestedValue = stringValue(from: nested, keys: keys) {
                return nestedValue
            }
            if let array = dictionary[key] as? [Any] {
                for element in array {
                    if let stringElement = element as? String, stringElement.isEmpty == false {
                        return stringElement
                    }
                    if let nestedDict = element as? [String: Any],
                       let nestedValue = stringValue(from: nestedDict, keys: keys) {
                        return nestedValue
                    }
                }
            }
        }
        for value in dictionary.values {
            if let nested = value as? [String: Any],
               let nestedValue = stringValue(from: nested, keys: keys) {
                return nestedValue
            }
            if let array = value as? [Any] {
                for element in array {
                    if let stringElement = element as? String, stringElement.isEmpty == false {
                        return stringElement
                    }
                    if let nestedDict = element as? [String: Any],
                       let nestedValue = stringValue(from: nestedDict, keys: keys) {
                        return nestedValue
                    }
                }
            }
        }
        return nil
    }
    
    private static func decimalValue(from dictionary: [String: Any], keys: [String]) -> Decimal? {
        for key in keys {
            if let value = dictionary[key] {
                if let string = value as? String {
                    let normalized = string.replacingOccurrences(of: ",", with: ".")
                    if let decimal = Decimal(string: normalized) {
                        return decimal
                    }
                } else if let number = value as? NSNumber {
                    return number.decimalValue
                } else if let doubleValue = value as? Double {
                    return Decimal(doubleValue)
                } else if let intValue = value as? Int {
                    return Decimal(intValue)
                } else if let nested = value as? [String: Any],
                          let nestedDecimal = decimalValue(from: nested, keys: keys) {
                    return nestedDecimal
                } else if let array = value as? [Any] {
                    for element in array {
                        if let nestedDecimal = decimalFromAny(element) {
                            return nestedDecimal
                        }
                        if let nestedDict = element as? [String: Any],
                           let nestedDecimal = decimalValue(from: nestedDict, keys: keys) {
                            return nestedDecimal
                        }
                    }
                }
            }
        }
        for value in dictionary.values {
            if let nested = value as? [String: Any],
               let nestedDecimal = decimalValue(from: nested, keys: keys) {
                return nestedDecimal
            }
            if let array = value as? [Any] {
                for element in array {
                    if let nestedDecimal = decimalFromAny(element) {
                        return nestedDecimal
                    }
                    if let nestedDict = element as? [String: Any],
                       let nestedDecimal = decimalValue(from: nestedDict, keys: keys) {
                        return nestedDecimal
                    }
                }
            }
        }
        return nil
    }

    private static func decimalFromAny(_ value: Any) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let doubleValue = value as? Double {
            return Decimal(doubleValue)
        }
        if let intValue = value as? Int {
            return Decimal(intValue)
        }
        if let string = value as? String {
            let normalized = string.replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
        if let decimal = value as? Decimal {
            return decimal
        }
        return nil
    }
    
    private static func decodeString(from container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) throws -> String? {
        for key in keys {
            if let value = try container.decodeIfPresent(String.self, forKey: key), value.isEmpty == false {
                return value
            }
        }
        return nil
    }
    
    private static func decodeDecimal(from container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) -> Decimal? {
        for key in keys {
            if let value = container.decodeDecimalIfPresent(forKey: key) {
                return value
            }
        }
        return nil
    }
}

private struct WiseProfile: Decodable {
    let id: Int
    let type: String
}

private struct WiseBalanceDTO: Decodable {
    struct Amount: Decodable {
        let value: Decimal
        let currency: String
        
        init(value: Decimal, currency: String) {
            self.value = value
            self.currency = currency
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let valueDecimal = container.decodeDecimalIfPresent(forKey: .value) {
                value = valueDecimal
            } else if let valueString = try container.decodeIfPresent(String.self, forKey: .value),
                      let decimal = Decimal(string: valueString.replacingOccurrences(of: ",", with: ".")) {
                value = decimal
            } else {
                value = .zero
            }
            currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? ""
        }
        
        private enum CodingKeys: String, CodingKey {
            case value
            case currency
        }
    }
    
    let id: Int?
    let balanceType: String?
    let currency: String?
    let amount: Amount?
    let totalWorth: Amount?
    let reservedAmount: Amount?
    let name: String?
    let type: String?
    let alias: String?
    
    init(id: Int?, balanceType: String?, currency: String?, amount: Amount?, totalWorth: Amount?, reserved: Amount?, name: String?, type: String?, alias: String?) {
        self.id = id
        self.balanceType = balanceType
        self.currency = currency
        self.amount = amount
        self.totalWorth = totalWorth
        self.reservedAmount = reserved
        self.name = name
        self.type = type
        self.alias = alias
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        balanceType = try container.decodeIfPresent(String.self, forKey: .balanceType)
        currency = try container.decodeIfPresent(String.self, forKey: .currency)
        amount = try container.decodeIfPresent(Amount.self, forKey: .amount)
        totalWorth = try container.decodeIfPresent(Amount.self, forKey: .totalWorth)
        reservedAmount = try container.decodeIfPresent(Amount.self, forKey: .reservedAmount)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        alias = try container.decodeIfPresent(String.self, forKey: .alias)
    }
    
    init?(dictionary: [String: Any]) {
        let idValue = dictionary["id"] as? Int ?? (dictionary["profileId"] as? Int)
        let balanceTypeValue = dictionary["balanceType"] as? String ?? dictionary["type"] as? String
        let aliasValue = dictionary["alias"] as? String
        let nameValue = dictionary["name"] as? String
        let typeValue = dictionary["type"] as? String
        let currencyValue = (dictionary["currency"] as? String)?.uppercased()
            ?? (dictionary["amount"] as? [String: Any])?["currency"] as? String
            ?? (dictionary["totalWorth"] as? [String: Any])?["currency"] as? String
        let mainAmount = WiseBalanceDTO.decimalAmount(from: dictionary["amount"])
        let totalWorthAmount = WiseBalanceDTO.decimalAmount(from: dictionary["totalWorth"])
        let reserved = WiseBalanceDTO.decimalAmount(from: dictionary["reservedAmount"])
        let primaryCurrency = currencyValue ?? mainAmount?.currency ?? totalWorthAmount?.currency ?? reserved?.currency
        if primaryCurrency == nil && mainAmount == nil && totalWorthAmount == nil && reserved == nil {
            return nil
        }
        id = idValue
        balanceType = balanceTypeValue
        currency = primaryCurrency
        amount = mainAmount
        totalWorth = totalWorthAmount
        reservedAmount = reserved
        name = nameValue
        type = typeValue
        alias = aliasValue
    }
    
    var displayName: String {
        if let alias, alias.isEmpty == false {
            return alias
        }
        if let name, name.isEmpty == false {
            return name
        }
        if let type, type.isEmpty == false {
            return type.uppercased()
        }
        if let balanceType, balanceType.isEmpty == false {
            return balanceType.uppercased()
        }
        if let currency {
            return currency.uppercased()
        }
        return "Wise баланс"
    }
    
    var primaryAmountValue: Decimal? {
        if let amount {
            return amount.value
        }
        if let totalWorth {
            return totalWorth.value
        }
        if let reservedAmount {
            return reservedAmount.value
        }
        return nil
    }
    
    var primaryCurrencyCode: String? {
        if let amount, amount.currency.isEmpty == false {
            return amount.currency
        }
        if let currency, currency.isEmpty == false {
            return currency
        }
        if let totalWorth, totalWorth.currency.isEmpty == false {
            return totalWorth.currency
        }
        if let reservedAmount, reservedAmount.currency.isEmpty == false {
            return reservedAmount.currency
        }
        return nil
    }
    
    private static func decimalAmount(from value: Any?) -> Amount? {
        guard let value else { return nil }
        if let amountDictionary = value as? [String: Any] {
            let currency = amountDictionary["currency"] as? String ?? ""
            if let decimal = WiseBalanceDTO.decimalFrom(any: amountDictionary["value"]) {
                return Amount(value: decimal, currency: currency)
            }
        }
        if let decimal = decimalFrom(any: value) {
            return Amount(value: decimal, currency: "")
        }
        return nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case balanceType
        case currency
        case amount
        case totalWorth
        case reservedAmount
        case name
        case type
        case alias
    }
    
    private static func decimalFrom(any value: Any?) -> Decimal? {
        guard let value else { return nil }
        if let decimal = value as? Decimal {
            return decimal
        }
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let doubleValue = value as? Double {
            return Decimal(doubleValue)
        }
        if let intValue = value as? Int {
            return Decimal(intValue)
        }
        if let stringValue = value as? String {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
        return nil
    }
}

private struct WiseBalancesWrapper: Decodable {
    let balances: [WiseBalanceDTO]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balances = try container.decodeIfPresent([WiseBalanceDTO].self, forKey: .balances) ?? []
    }
    
    private enum CodingKeys: String, CodingKey {
        case balances
    }
}

private struct WiseBalancesAlternativeWrapper: Decodable {
    let content: [WiseBalanceDTO]?
    let items: [WiseBalanceDTO]?
    let data: [WiseBalanceDTO]?
    let list: [WiseBalanceDTO]?
    let response: [WiseBalanceDTO]?
    
    var allBalances: [WiseBalanceDTO] {
        return [content, items, data, list, response]
            .compactMap { $0 }
            .flatMap { $0 }
    }
}

private struct WiseRateDTO: Decodable {
    let source: String?
    let target: String?
    let rate: Decimal
}
