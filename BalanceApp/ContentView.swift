import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @State private var isSettingsVisible = false
    
    private let cardWidth: CGFloat = 220
    private let cardSpacing: CGFloat = 16
    private let columnLimit: Int = 3
    
    init() {
        let sharedPreferences = ProviderPreferences.shared
        _viewModel = StateObject(wrappedValue: ContentViewModel(preferences: sharedPreferences))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isSettingsVisible {
                        InlineSettingsView(viewModel: viewModel,
                                           isVisible: $isSettingsVisible) {
                            Task {
                                await viewModel.refreshManually()
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Оновлюємо дані...")
                            .progressViewStyle(.linear)
                    }
                    
                    if viewModel.missingTokens.isEmpty == false {
                        MissingTokensView(missingProviders: Array(viewModel.missingTokens))
                    }
                    
                    if viewModel.errorMessages.isEmpty == false {
                        ErrorListView(messages: viewModel.errorMessages)
                    }
                    
                    if viewModel.totals.isEmpty == false {
                        TotalsView(totals: viewModel.totals)
                    }
                    
                    if viewModel.manualBalances.isEmpty == false {
                        BalanceProviderSection(title: "Власні рахунки",
                                               systemImage: BalanceProvider.manualAccounts.accentSystemImageName,
                                               balances: viewModel.manualBalances,
                                               columns: columns(for: viewModel.manualBalances.count),
                                               cardWidth: cardWidth,
                                               cardSpacing: cardSpacing)
                    }
                    
                    if viewModel.privatBalances.isEmpty == false {
                        BalanceProviderSection(title: "PrivatBank (ФОП)",
                                               systemImage: "creditcard.fill",
                                               balances: viewModel.privatBalances,
                                               columns: columns(for: viewModel.privatBalances.count),
                                               cardWidth: cardWidth,
                                               cardSpacing: cardSpacing)
                    }

                    if viewModel.wiseBalances.isEmpty == false {
                        BalanceProviderSection(title: "Wise",
                                               systemImage: "globe",
                                               balances: viewModel.wiseBalances,
                                               columns: columns(for: viewModel.wiseBalances.count),
                                               cardWidth: cardWidth,
                                               cardSpacing: cardSpacing)
                    }
                    
                    if viewModel.exchangeRates.isEmpty == false {
                        ExchangeRatesSection(rates: viewModel.exchangeRates)
                    }
                    
                    if viewModel.isLoading == false &&
                        viewModel.missingTokens.isEmpty &&
                        viewModel.errorMessages.isEmpty &&
                        viewModel.privatBalances.isEmpty &&
                        viewModel.wiseBalances.isEmpty &&
                        viewModel.manualBalances.isEmpty {
                        EmptyStateView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(minWidth: preferredWidth, idealWidth: preferredWidth, maxWidth: preferredWidth, minHeight: 520, idealHeight: 600, maxHeight: 720)
        .task {
            await viewModel.loadAllData()
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Баланси")
                    .font(.title3.weight(.semibold))
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Оновлено: \(Formatters.timeFormatter.string(from: lastUpdated))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSettingsVisible.toggle()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Налаштування")
        }
    }
    
    private var footer: some View {
        HStack {
            Button {
                Task {
                    await viewModel.refreshManually()
                }
            } label: {
                Label("Оновити", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isLoading)
            
            Spacer()
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    Text("Завантаження...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Готово")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Button(role: .destructive) {
                    quitApp()
                } label: {
                    Label("Вийти", systemImage: "power")
                }
                .help("Вийти з програми")
            }
        }
    }
    
    private var currentColumnCount: Int {
        let maxCount = max(viewModel.privatBalances.count,
                           max(viewModel.wiseBalances.count, viewModel.manualBalances.count))
        return max(2, min(columnLimit, maxCount))
    }
    
    private var preferredWidth: CGFloat {
        let columns = currentColumnCount
        let cardsWidth = CGFloat(columns) * cardWidth
        let spacingWidth = CGFloat(max(columns - 1, 0)) * cardSpacing
        let contentWidth = cardsWidth + spacingWidth
        return max(contentWidth + 32, 620) // account for horizontal padding
    }
    
    private func columns(for count: Int) -> Int {
        let effective = max(count, 1)
        return max(2, min(columnLimit, effective))
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}


private struct MissingTokensView: View {
    let missingProviders: [BalanceProvider]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Відсутні токени для увімкнених банків", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Увімкнені банки без токена:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(sortedProviders) { provider in
                Text("- \(provider.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Відкрийте налаштування та введіть токени API.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var sortedProviders: [BalanceProvider] {
        missingProviders.sorted { $0.displayName < $1.displayName }
    }
}

private struct ErrorListView: View {
    let messages: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Сталася помилка", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.callout.weight(.semibold))
            ForEach(messages, id: \.self) { message in
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct TotalsView: View {
    let totals: [CurrencyTotal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Загальна сума по всіх рахунках", systemImage: "sum")
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                ForEach(totals) { total in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(total.currencyCode)
                            .font(.title3.weight(.semibold))
                        Text(total.formattedTotal)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BalanceProviderSection: View {
    let title: String
    let systemImage: String
    let balances: [BalanceItem]
    let columns: Int
    let cardWidth: CGFloat
    let cardSpacing: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: cardSpacing) {
                ForEach(sortedBalances) { item in
                    BalanceCard(item: item, cardWidth: cardWidth)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = max(2, min(columns, 3))
        return Array(
            repeating: GridItem(.fixed(cardWidth), spacing: cardSpacing, alignment: .top),
            count: count
        )
    }
    
    private struct BalanceCard: View {
        let item: BalanceItem
        let cardWidth: CGFloat
        
        var body: some View {
            let style = cardStyle(for: item)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(style.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.formattedAmount)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(style.text)
                    Text(item.currencyCode)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.text.opacity(0.75))
                }
            }
            .padding(16)
            .frame(width: cardWidth, alignment: .leading)
            .background(style.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(style.text.opacity(0.15), lineWidth: 1)
            )
        }
        
        private func cardStyle(for item: BalanceItem) -> (background: Color, text: Color) {
            switch item.currencyCode.uppercased() {
            case "UAH":
                return (
                    Color(red: 0.87, green: 0.94, blue: 0.84),
                    Color(red: 0.16, green: 0.39, blue: 0.20)
                )
            case "USD":
                return (
                    Color(red: 0.83, green: 0.93, blue: 0.98),
                    Color(red: 0.12, green: 0.32, blue: 0.50)
                )
            case "EUR":
                return (
                    Color(red: 0.95, green: 0.86, blue: 0.92),
                    Color(red: 0.42, green: 0.09, blue: 0.31)
                )
            case "GBP":
                return (
                    Color(red: 0.90, green: 0.88, blue: 0.95),
                    Color(red: 0.29, green: 0.19, blue: 0.54)
                )
            case "PLN":
                return (
                    Color(red: 0.91, green: 0.95, blue: 0.85),
                    Color(red: 0.27, green: 0.43, blue: 0.16)
                )
            default:
                return (
                    Color.primary.opacity(0.07),
                    Color.primary
                )
            }
        }
    }
    
    private var sortedBalances: [BalanceItem] {
        balances.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
}

private struct ExchangeRatesSection: View {
    let rates: [ExchangeRateItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Курси Wise", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            ForEach(rates) { rate in
                HStack {
                    Text(rate.pairDescription)
                    Spacer()
                    Text(rate.formattedRate)
                        .monospacedDigit()
                }
                .font(.footnote)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.primary.opacity(0.04), in: Capsule())
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Тут поки що порожньо")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Додайте токени або створіть власні рахунки, щоб побачити дані.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct InlineSettingsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isVisible: Bool
    var onSaved: () -> Void
    
    @State private var privatToken: String = ""
    @State private var wiseToken: String = ""
    @State private var balanceApiURL: String = ""
    @State private var balanceApiToken: String = ""
    @State private var manualDrafts: [ManualAccountDraft] = []
    @State private var statusMessage: String?
    @State private var statusColor: Color = .green
    private let manualAccountsStore = ManualAccountsStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Налаштування API")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Відображення банків")
                    .font(.subheadline.weight(.semibold))
                Toggle("PrivatBank (ФОП)", isOn: binding(for: .privatBank))
                Toggle("Wise", isOn: binding(for: .wise))
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("API для балансів")
                    .font(.subheadline.weight(.semibold))
                TextField("URL API для відправки балансів", text: $balanceApiURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("Токен доступу до API", text: $balanceApiToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                
                Text("PrivatBank (ФОП)")
                    .font(.subheadline.weight(.semibold))
                SecureField("Введіть токен PrivatBank (ФОП)", text: $privatToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                
                Text("Wise")
                    .font(.subheadline.weight(.semibold))
                SecureField("Введіть токен Wise", text: $wiseToken)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Підказки")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("- Токени зберігаються у Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("- Переконайтеся, що токен дійсний і має права читати баланси.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Divider()
            ManualAccountsEditorView(drafts: $manualDrafts)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            
            HStack {
                Button("Скасувати") {
                    withAnimation {
                        isVisible = false
                    }
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
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            loadTokens()
            loadManualAccounts()
        }
    }
    
    private func loadTokens() {
        privatToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.privatToken) ?? ""
        wiseToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.wiseToken) ?? ""
        balanceApiURL = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.balanceApiURL) ?? ""
        balanceApiToken = KeychainHelper.shared.retrieveToken(forKey: KeychainKey.balanceApiToken) ?? ""
        statusMessage = nil
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
            statusMessage = nil
            withAnimation {
                isVisible = false
            }
            onSaved()
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
            get: { viewModel.isProviderEnabled(provider) },
            set: { viewModel.setProvider(provider, enabled: $0) }
        )
    }
}
