import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var privatToken: String = ""
    @State private var wiseToken: String = ""
    @State private var statusMessage: String?
    @State private var statusColor: Color = .green
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Налаштування API")
                .font(.title3.weight(.semibold))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("PrivatBank (ФОП)")
                    .font(.headline)
                SecureField("API токен PrivatBank (ФОП)", text: $privatToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                Text("Wise")
                    .font(.headline)
                SecureField("API токен Wise", text: $wiseToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                HelperTextView()
            }
            
            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(statusColor)
            }
            
            HStack {
                Button("Скасувати") {
                    dismiss()
                }
                Spacer()
                Button(role: .destructive) {
                    clearTokens()
                } label: {
                    Label("Очистити", systemImage: "trash")
                }
                Button {
                    saveTokens()
                } label: {
                    Label("Зберегти", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(privatToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                          wiseToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear(perform: loadTokens)
    }
    
    private func loadTokens() {
        privatToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.privatToken) ?? ""
        wiseToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.wiseToken) ?? ""
    }
    
    private func saveTokens() {
        let privatValue = privatToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let wiseValue = wiseToken.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if privatValue.isEmpty {
                try KeychainHelper.shared.deleteToken(forKey: KeychainKey.privatToken)
            } else {
                try KeychainHelper.shared.saveToken(privatValue, forKey: KeychainKey.privatToken)
            }
            
            if wiseValue.isEmpty {
                try KeychainHelper.shared.deleteToken(forKey: KeychainKey.wiseToken)
            } else {
                try KeychainHelper.shared.saveToken(wiseValue, forKey: KeychainKey.wiseToken)
            }
            statusColor = .green
            statusMessage = "Токени збережено успішно."
        } catch {
            statusColor = .red
            statusMessage = error.localizedDescription
        }
    }
    
    private func clearTokens() {
        do {
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.privatToken)
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.wiseToken)
            privatToken = ""
            wiseToken = ""
            statusColor = .green
            statusMessage = "Токени видалено."
        } catch {
            statusColor = .red
            statusMessage = error.localizedDescription
        }
    }
}

private struct HelperTextView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Підказки")
                .font(.subheadline.weight(.semibold))
            Text("- Токени зберігаються у Keychain.")
            Text("- Переконайтеся, що маєте права читати баланси у відповідних API.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
