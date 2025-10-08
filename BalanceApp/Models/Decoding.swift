import Foundation

extension KeyedDecodingContainer {
    func decodeDecimalIfPresent(forKey key: Key) -> Decimal? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            if let decimal = Decimal(string: normalized) {
                return decimal
            }
        }
        
        if let decimal = try? decodeIfPresent(Decimal.self, forKey: key) {
            return decimal
        }
        
        do {
            if let doubleValue = try decodeIfPresent(Double.self, forKey: key) {
                return Decimal(doubleValue)
            }
        } catch { }
        
        do {
            if let intValue = try decodeIfPresent(Int.self, forKey: key) {
                return Decimal(intValue)
            }
        } catch { }
        
        return nil
    }
}
