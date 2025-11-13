import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var preferences = ProviderPreferences.shared
    @ObservedObject private var manualAccountsStore = ManualAccountsStore.shared

    @State private var privatToken: String = ""
    @State private var wiseToken: String = ""
    @State private var balanceApiURL: String = ""
    @State private var balanceApiToken: String = ""
    @State private var manualDrafts: [ManualAccountDraft] = []
    @State private var statusMessage: String?
    @State private var statusColor: Color = .green
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Налаштування API")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                Text("Відображення банків")
                    .font(.headline)
                Toggle("PrivatBank (ФОП)", isOn: binding(for: .privatBank))
                Toggle("Wise", isOn: binding(for: .wise))
            }
            
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("API для балансів")
                    .font(.headline)

                Button("Debug: Show API values") {
                    print("URL: '\(balanceApiURL)'")
                    print("Token: '\(balanceApiToken.isEmpty ? "empty" : "has value")'")
                }

                TextField("URL API для відправки балансів", text: $balanceApiURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 22)
                SecureField("Токен доступу до API", text: $balanceApiToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .frame(minHeight: 22)

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

            Divider()

            ManualAccountsEditorView(drafts: $manualDrafts)
            
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
                    saveSettings()
                } label: {
                    Label("Зберегти", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360)
        .onAppear {
            print("SettingsView appeared, loading tokens...")
            loadTokens()
            loadManualAccounts()
            print("balanceApiURL loaded: '\(balanceApiURL)'")
            print("balanceApiToken loaded: '\(balanceApiToken.isEmpty ? "empty" : "has value")'")
        }
    }

    private func loadTokens() {
        privatToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.privatToken) ?? ""
        wiseToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.wiseToken) ?? ""
        balanceApiURL = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.balanceApiURL) ?? ""
        balanceApiToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.balanceApiToken) ?? ""
    }

    private func saveSettings() {
        let privatValue = privatToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let wiseValue = wiseToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiUrlValue = balanceApiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiTokenValue = balanceApiToken.trimmingCharacters(in: .whitespacesAndNewlines)

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

            if apiUrlValue.isEmpty {
                try KeychainHelper.shared.deleteToken(forKey: KeychainKey.balanceApiURL)
            } else {
                try KeychainHelper.shared.saveToken(apiUrlValue, forKey: KeychainKey.balanceApiURL)
            }

            if apiTokenValue.isEmpty {
                try KeychainHelper.shared.deleteToken(forKey: KeychainKey.balanceApiToken)
            } else {
                try KeychainHelper.shared.saveToken(apiTokenValue, forKey: KeychainKey.balanceApiToken)
            }

            let manualAccounts = try buildManualAccounts()
            manualAccountsStore.replace(with: manualAccounts)
            statusColor = .green
            statusMessage = "Налаштування збережено успішно."
        } catch {
            statusColor = .red
            statusMessage = error.localizedDescription
        }
    }
    
    private func clearTokens() {
        do {
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.privatToken)
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.wiseToken)
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.balanceApiURL)
            try KeychainHelper.shared.deleteToken(forKey: KeychainKey.balanceApiToken)
            privatToken = ""
            wiseToken = ""
            balanceApiURL = ""
            balanceApiToken = ""
            statusColor = .green
            statusMessage = "Токени видалено."
        } catch {
            statusColor = .red
            statusMessage = error.localizedDescription
        }
    }

    private func loadManualAccounts() {
        manualDrafts = manualAccountsStore.accounts.map(ManualAccountDraft.init)
    }

    private func buildManualAccounts() throws -> [ManualAccount] {
        try manualDrafts.map { try $0.validatedAccount() }
    }
    
    private func binding(for provider: BalanceProvider) -> Binding<Bool> {
        Binding(
            get: { preferences.isEnabled(provider) },
            set: { preferences.set(provider, enabled: $0) }
        )
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
