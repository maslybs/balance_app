import SwiftUI

struct ManualAccountDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var amountString: String
    var currencyCode: String
    
    init(id: UUID = UUID(), title: String = "", amountString: String = "", currencyCode: String = "UAH") {
        self.id = id
        self.title = title
        self.amountString = amountString
        self.currencyCode = currencyCode
    }
    
    init(account: ManualAccount) {
        self.id = account.id
        self.title = account.title
        self.amountString = Formatters.string(from: account.amount)
        self.currencyCode = account.currencyCode
    }
    
    func validatedAccount() throws -> ManualAccount {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedTitle.isEmpty ? "Без назви" : trimmedTitle
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.isEmpty == false else {
            throw ManualAccountValidationError.invalidCurrency(name: displayName)
        }
        guard let decimal = Formatters.decimal(from: amountString) else {
            throw ManualAccountValidationError.invalidAmount(name: displayName)
        }
        return ManualAccount(id: id, title: trimmedTitle, amount: decimal, currencyCode: code)
    }
}

struct ManualAccountsEditorView: View {
    @Binding var drafts: [ManualAccountDraft]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Власні статичні рахунки")
                    .font(.headline)
                Spacer()
                Button {
                    addDraft()
                } label: {
                    Label("Додати рахунок", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
            
            if drafts.isEmpty {
                Text("Додайте рахунок, щоб вручну зберігати суму без інтеграції з банком.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach($drafts) { $draft in
                        ManualAccountRow(draft: $draft) {
                            removeDraft(withId: draft.id)
                        }
                    }
                }
            }
        }
    }
    
    private func addDraft() {
        drafts.append(ManualAccountDraft())
    }
    
    private func removeDraft(withId id: ManualAccountDraft.ID) {
        drafts.removeAll { $0.id == id }
    }
}

enum ManualAccountValidationError: LocalizedError {
    case invalidAmount(name: String)
    case invalidCurrency(name: String)

    var errorDescription: String? {
        switch self {
        case .invalidAmount(let name):
            return "Некоректна сума для рахунку «\(name)»."
        case .invalidCurrency(let name):
            return "Некоректна валюта для рахунку «\(name)»."
        }
    }
}

private struct ManualAccountRow: View {
    @Binding var draft: ManualAccountDraft
    var onDelete: () -> Void
    private let supportedCurrencies = ["UAH", "USD", "EUR", "GBP", "PLN"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Назва рахунку", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                    TextField("Сума", text: $draft.amountString)
                        .textFieldStyle(.roundedBorder)
                        .monospacedDigit()
                    HStack(spacing: 8) {
                        TextField("Валюта", text: currencyBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Menu {
                            ForEach(supportedCurrencies, id: \.self) { currency in
                                Button(currency) {
                                    draft.currencyCode = currency
                                }
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .imageScale(.medium)
                        }
                        .help("Обрати валюту")
                    }
                }
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Видалити рахунок")
            }
            Divider()
                .overlay(Color.primary.opacity(0.05))
        }
    }
    
    private var currencyBinding: Binding<String> {
        Binding(
            get: { draft.currencyCode },
            set: { draft.currencyCode = $0.uppercased() }
        )
    }
}
