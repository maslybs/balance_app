# Єдина специфікація для додатку "Balance App"

## 1. Загальна мета, архітектура та UX

### 1.1. Концепція

**Тип додатку:** Легкий додаток, що живе у **меню барі (Menu Bar)** macOS.

**Основна функція:** Надавати швидкий доступ до фінансової інформації (баланси рахунків, курси валют) без необхідності відкривати повноцінне вікно чи веб-браузер.

### 1.2. Поведінка (User Flow)

1.  Після запуску, іконка додатку з'являється у системному меню барі.
2.  При натисканні на іконку, з'являється невелике **спливаюче вікно (Popover)**.
3.  **Одразу після появи вікна** автоматично ініціюється запит до API для отримання актуальних даних.
4.  У вікні відображаються баланси, загальна сума (якщо реалізовано) та поточні курси валют.
5.  Вікно має містити іконку (напр., шестірня) для переходу до **екрану налаштувань**.
6.  В налаштуваннях користувач може вводити та зберігати свої API-токени для PrivatBank та Wise.

### 1.3. Дизайн та локалізація

-   **Дизайн:** Має бути **приємним, мінімалістичним та лаконічним**. Інформація повинна зчитуватися з першого погляду.
-   **Мова інтерфейсу:** Повністю **українська**.

### 1.4. Технологічний стек

-   **Платформа:** macOS
-   **Мова:** Swift
-   **Інтерфейс:** SwiftUI
-   **Архітектура:** Menu Bar App with Popover (`MenuBarExtra` в SwiftUI).
-   **Мережа:** `URLSession` (`async/await`).
-   **Зберігання токенів:** **Keychain**.

## 2. Інтеграція з API

(Цей розділ залишається без змін, оскільки описує взаємодію з серверами)

### 2.1. PrivatBank API...
### 2.2. Wise API...

## 3. Структура додатку на Swift

### 3.1. Головний вхід (`BalanceApp.swift`)

Замість стандартного `WindowGroup`, будемо використовувати `MenuBarExtra`.

```swift
import SwiftUI

@main
struct BalanceApp: App {
    var body: some Scene {
        MenuBarExtra("Balance App", systemImage: "dollarsign.circle.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
```

### 3.2. Моделі даних (`Models.swift`)

(Структури даних залишаються без змін)

### 3.3. Мережевий сервіс (`APIService.swift`)

Сервіс має отримувати токени з Keychain, а не зберігати їх як константи.

```swift
import Foundation

class APIService {
    // Приклад отримання токена
    private func getPrivatToken() -> String {
        // Тут буде логіка читання з Keychain
        return KeychainHelper.shared.retrieveToken(forKey: "privatToken") ?? ""
    }
    
    // ... методи fetchPrivatBalances, getWiseBalances і т.д. ...
    // У кожному методі токен має читатися з Keychain перед виконанням запиту.
}
```

### 3.4. ViewModel (`ContentViewModel.swift`)

(Логіка завантаження даних залишається, але тепер вона викликатиметься при появі `ContentView`)

### 3.5. Основний інтерфейс (`ContentView.swift`)

Це UI, що відображається у Popover.

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var isSettingsPresented = false

    var body: some View {
        VStack {
            // Header з назвою та іконкою налаштувань
            HStack {
                Text("Баланси")
                Spacer()
                Button(action: { isSettingsPresented.toggle() }) {
                    Image(systemName: "gearshape.fill")
                }
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                }
            }

            // ... решта UI з даними, як у попередній специфікації ...
        }
        .padding()
        .task {
            // Завантаження даних при появі вікна
            await viewModel.loadAllData()
        }
    }
}
```

### 3.6. Екран налаштувань (`SettingsView.swift`)

Новий файл для UI, де користувач вводить свої токени.

```swift
import SwiftUI

struct SettingsView: View {
    @State private var privatToken: String = ""
    @State private var wiseToken: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Налаштування API").font(.title)
            
            SecureField("PrivatBank API Token", text: $privatToken)
            SecureField("Wise API Token", text: $wiseToken)
            
            Button("Зберегти") {
                // Зберігаємо токени в Keychain
                KeychainHelper.shared.saveToken(privatToken, forKey: "privatToken")
                KeychainHelper.shared.saveToken(wiseToken, forKey: "wiseToken")
            }
        }
        .padding()
        .onAppear {
            // При відкритті завантажуємо збережені токени для відображення
            privatToken = KeychainHelper.shared.retrieveToken(forKey: "privatToken") ?? ""
            wiseToken = KeychainHelper.shared.retrieveToken(forKey: "wiseToken") ?? ""
        }
    }
}
```

## 4. Безпека

-   **Обов'язково використовувати Keychain** для зберігання API-токенів. Це системне, безпечне сховище.
-   У полях для вводу токенів використовувати `SecureField`, щоб символи не відображалися на екрані.

## 5. План розробки (Оновлений)

1.  **Налаштування проєкту:** Створити проєкт та налаштувати `MenuBarExtra`.
2.  **Безпека:** Реалізувати `KeychainHelper` для збереження та читання токенів.
3.  **UI Налаштувань:** Створити `SettingsView` для вводу API-ключів.
4.  **Моделі та API:** Реалізувати `Models.swift` та `APIService.swift` (з інтеграцією Keychain).
5.  **Основний UI:** Створити `ContentView` для відображення даних.
6.  **ViewModel:** Зв'язати UI з логікою завантаження даних.
7.  **Тестування:** Перевірити повний цикл: запуск, введення токенів, збереження, відображення даних, оновлення.