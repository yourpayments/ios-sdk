# YPMN iOS SDK — руководство по интеграции

> Headless Swift SDK для приёма платежей в iOS-приложении мерчанта: банковские карты с 3-D Secure, СБП, SberPay, T-Pay, AlfaPay. Вы полностью управляете интерфейсом — SDK берёт на себя API, шифрование карточных данных, 3DS в `WKWebView` и отслеживание результата. Нативный аналог YPMN Web SDK с тем же набором понятий и сценариев.

**Версия документа**: 1.0 (август 2026) · **Подробный API-справочник**: [`sdk/README.md`](sdk/README.md)

---

## Содержание

- [YPMN iOS SDK — руководство по интеграции](#ypmn-ios-sdk--руководство-по-интеграции)
  - [Содержание](#содержание)
  - [1. О продукте](#1-о-продукте)
  - [2. Быстрый старт](#2-быстрый-старт)
  - [3. Основные понятия](#3-основные-понятия)
    - [Интент](#интент)
    - [Жизненный цикл и статусы](#жизненный-цикл-и-статусы)
    - [PUID — идентификатор попытки оплаты](#puid--идентификатор-попытки-оплаты)
    - [Окружения](#окружения)
  - [4. Подключение](#4-подключение)
    - [Требования](#требования)
    - [Swift Package Manager](#swift-package-manager)
    - [Разрешения и настройки приложения](#разрешения-и-настройки-приложения)
  - [5. Создание intent](#5-создание-intent)
    - [Обязательные параметры](#обязательные-параметры)
    - [Опциональные параметры](#опциональные-параметры)
  - [6. Объект PaymentIntent](#6-объект-paymentintent)
    - [Методы](#методы)
    - [События](#события)
  - [7. Оплата картой и 3-D Secure](#7-оплата-картой-и-3-d-secure)
    - [intent.pay(input:)](#intentpayinput)
    - [3-D Secure: `ThreeDsView`](#3-d-secure-threedsview)
  - [8. Альтернативные методы оплаты](#8-альтернативные-методы-оплаты)
    - [SberPay](#sberpay)
    - [СБП (FasterPayments)](#сбп-fasterpayments)
    - [Прочие методы: AlfaPay, T-Pay](#прочие-методы-alfapay-t-pay)
  - [9. Ожидание результата: waitForResult](#9-ожидание-результата-waitforresult)
  - [10. Обновление интента](#10-обновление-интента)
  - [11. Восстановление intent](#11-восстановление-intent)
  - [12. Swift Concurrency и потоки](#12-swift-concurrency-и-потоки)
  - [13. Обработка ошибок](#13-обработка-ошибок)
  - [14. Тестирование в песочнице](#14-тестирование-в-песочнице)
    - [Успешная оплата](#успешная-оплата)
    - [Отказ в авторизации](#отказ-в-авторизации)
  - [15. Безопасность и PCI DSS](#15-безопасность-и-pci-dss)
  - [16. Краткий справочник типов](#16-краткий-справочник-типов)
    - [`YPConfig`](#ypconfig)
    - [`CreateIntentRequest`](#createintentrequest)
    - [`ProductItem`](#productitem)
    - [`UserInfo`](#userinfo)
    - [`IntentResponse`](#intentresponse)
    - [Статусы](#статусы)
    - [Оплата картой](#оплата-картой)
    - [Альтернативные методы](#альтернативные-методы)
    - [3-D Secure](#3-d-secure)
    - [Ошибки](#ошибки)
  - [17. Чек-лист перед выходом в продакшен](#17-чек-лист-перед-выходом-в-продакшен)

---

## 1. О продукте

iOS SDK — это **headless**-решение: SDK не рисует checkout экран, форму карты, список банков или состояние ожидания. UI вы строите сами на UIKit или SwiftUI, а SDK даёт программный API:

- создать платёжную сессию (**интент**) и управлять ею;
- принять карту: шифрование данных на устройстве, проведение платежа, 3-D Secure в `WKWebView`;
- получить ссылки и данные для СБП и других альтернативных методов;
- дождаться результата оплаты через поллинг статуса с учётом отклонённых попыток.

**Разделение ответственности:**

| Задача | Кто делает |
|---|---|
| UI: экраны, форма карты, кнопки способов оплаты | Мерчант |
| Валидация и маскирование полей ввода | Мерчант |
| Шифрование карточных данных на устройстве | SDK |
| Запросы к платёжному API | SDK |
| 3-D Secure (`WKWebView` + отслеживание результата) | SDK |
| Polling статуса платежа | SDK |

Основной API — Swift `async/await`; события доступны через `AsyncStream<IntentEvent>`.

---

## 2. Быстрый старт

Минимальный сценарий «оплата картой»:

```swift
import UIKit
import Yourpayments

let config = YPConfig(baseUrl: YPConfig.sandboxBaseUrl) // продакшен: YPConfig.productionBaseUrl

func payWithCard(containerView: UIView) async throws {
    // 1. Создаём intent (платёжную сессию)
    let intent = try await YP.createIntent(
        request: CreateIntentRequest(
            merchantCode: "your_terminal_id",
            amount: 100_000,       // 1000.00 ₽ — сумма в копейках
            currency: "RUB",
            messageScheme: "SMS",
            description: "Заказ #123",
            userInfo: UserInfo(billing: Billing(email: "buyer@example.com"))
        ),
        config: config
    )

    // 2. Проводим платёж данными карты из вашей формы
    let card = CardData(pan: pan, expMonth: expMonth, expYear: expYear, cvv: cvv)
    let result = try await intent.pay(input: .card(card))

    switch result {
    case .authorized:
        showSuccessScreen(intentId: await intent.id)

    case .threeDsRequired:
        // 3. Банк требует 3-D Secure — показываем WKWebView подтверждения
        let threeDsView = try intent.create3dsView(result: result)

        await MainActor.run {
            threeDsView.mount(into: containerView)
        }

        let results = await MainActor.run { threeDsView.results }
        for await threeDsResult in results {
            await MainActor.run { threeDsView.destroy() }

            switch threeDsResult.status {
            case .success:
                showSuccessScreen(intentId: await intent.id)
            case .failure:
                showRetryScreen()
            }
            break
        }
    }
}
```

Дальше по документу каждый шаг разобран подробно.

---

## 3. Основные понятия

### Интент

**Интент (Intent)** — платёжная сессия на стороне платёжного API. Он хранит сумму, валюту, описание заказа, список доступных методов оплаты и текущий статус. Одна оплата заказа = один intent; внутри одного intent возможно несколько **попыток** оплаты, например после отказа покупатель может попробовать снова другой картой или другим методом.

В Swift SDK intent представлен объектом `PaymentIntent`.

### Жизненный цикл и статусы

| Статус (`IntentStatus`) | Значение |
|---|---|
| `.requiresPaymentData` | Ожидаются данные для оплаты (начальное состояние) |
| `.requiresPaymentMethod` | Ожидается выбор или повтор метода оплаты |
| `.success` | Оплата успешна. **Терминальный** |
| `.expired` | Время жизни сессии истекло. **Терминальный** |

У `IntentStatus` есть свойство `isTerminal`: для `.success` и `.expired` оно возвращает `true`.

> **Важно:** отдельного терминального статуса «неуспех» у intent нет. Отклонённая попытка возвращает intent в `requiresPayment*`, а сам факт отказа виден по транзакции со статусом `DECLINED`. Чтобы надёжно ловить отказ конкретной попытки альтернативного метода, используйте `puid`.

### PUID — идентификатор попытки оплаты

`puid` (Payment User ID) — уникальная строка, которую **вы генерируете на каждую попытку** оплаты альтернативным методом:

```swift
let puid = UUID().uuidString.lowercased()
```

Один и тот же `puid` нужно передать при получении ссылки альтернативного метода и затем в `waitForResult(opts:)`: 

```swift
let flow = try await intent.getPaymentMethod(
    method: .tPay,
    opts: AltRequestOpts(puid: puid)
)

let link = try await flow.getLink()
let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: puid))
```

Когда среди транзакций intent появится `DECLINED`-транзакция с этим `puid`, `waitForResult` вернёт `.declined`. Без `puid` declined transaction не завершает polling как `.declined`; **Без `puid` детект отказа не работает.**

### Окружения

| Окружение | `YPConfig.baseUrl` | Назначение |
|---|---|---|
| Песочница | `YPConfig.sandboxBaseUrl` (`https://sandbox.ypmn.ru`) | Разработка и тесты; работают [тестовые карты](#14-тестирование-в-песочнице) |
| Продакшен | `YPConfig.productionBaseUrl` (`https://ypmn.ru`) | Реальные платежи |

Адрес API задаётся в рантайме через `YPConfig`. `merchantCode` вам выдаёт менеджер при подключении или вы можете посмотреть его в настройках Личного кабинета.

---

## 4. Подключение

### Требования

| Требование | Значение |
|---|---|
| iOS | 17.0+ |
| Swift tools | 5.9 |
| Менеджер зависимостей | Swift Package Manager |
| Product | `Yourpayments` |
| Module | `Yourpayments` |

### Swift Package Manager

Добавьте Swift Package:

```text
https://github.com/darkkifir/YPSDK_iOS.git
```

В Xcode выберите `File` -> `Add Package Dependencies`, укажите URL пакета и добавьте product `Yourpayments` в target приложения.

Если зависимости подключаются через `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/darkkifir/YPSDK_iOS.git", from: "1.0.0")
],
targets: [
    .target(
        name: "App",
        dependencies: [
            .product(name: "Yourpayments", package: "YourpaymentsSDK")
        ]
    )
]
```

Импорт:

```swift
import Yourpayments
```

### Разрешения и настройки приложения

SDK не требует дополнительных entitlements. Убедитесь, что приложение может открывать внешние URL или deeplink банка, если вы используете альтернативные методы оплаты через внешние приложения.

Для 3DS SDK создаёт `WKWebView` внутри переданного вами `UIView`-контейнера. JavaScript включён, потому что это требуется банковским страницам 3-D Secure.

---

## 5. Создание intent

```swift
let intent: PaymentIntent = try await YP.createIntent(
    request: CreateIntentRequest(
        merchantCode: "your_terminal_id",
        amount: 100_000,
        currency: "RUB",
        messageScheme: "SMS"
    ),
    config: YPConfig(baseUrl: YPConfig.productionBaseUrl)
)
```

`YP.createIntent(request:config:)` — асинхронный метод; вызывайте его из `Task`, `async`-функции или другого lifecycle-aware async-контекста.

### Обязательные параметры

| Параметр | Тип | Описание |
|---|---|---|
| `merchantCode` | `String` | Публичный идентификатор вашего терминала |
| `amount` | `Int64` | Сумма в **минорных единицах** (копейки). Минимум `100` |
| `currency` | `String` | Код валюты: `"RUB"` |
| `messageScheme` | `String` | `"SMS"` — одностадийный платёж (списание сразу), `"DMS"` — двухстадийный (холдирование с последующим подтверждением) |

### Опциональные параметры

| Параметр | Тип | Описание |
|---|---|---|
| `description` | `String?` | Описание платежа, до 255 символов |
| `merchantPaymentReference` | `String?` | Ваш идентификатор заказа |
| `receiptEmail` | `String?` | Email для квитанции |
| `accountId` | `String?` | Ваш идентификатор плательщика |
| `tokenize` | `Bool?` | Токенизировать карту для будущих платежей |
| `orderTimeout` | `Int?` | Время жизни intent до 30 дней, в секундах (1200-2592000). По дефолту 60 минут (3600 секунд). По истечении - статус .expired |
| `retryPayment` | `Bool?` | Разрешить повторные попытки после отказа |
| `successRedirectUrl` / `failRedirectUrl` | `String?` | URL возврата покупателя с внешних платёжных страниц |
| `items` | `[ProductItem]?` | Состав заказа ([формат](#productitem)) |
| `receipts` | `YPJSONObject?` | Данные чеков (формат АТОЛа, см. документацию провайдера) |
| `userInfo` | `UserInfo?` | Данные плательщика ([формат](#userinfo)) |
| `metaData` | `YPJSONObject?` | Произвольные метаданные |

`scenario` не передаётся в public initializer: iOS SDK автоматически отправляет `"IoSSDK"`. Hosted/widget поля `autoClose`, `skin`, `emailBehavior`, `paymentUrl` относятся к хостед-страницам (виджет/чекаут) и нативному SDK не нужны; они оставлены в контракте для полноты.

> **Рекомендация:** при оплате картой всегда передавайте `userInfo.billing` (достаточно `email` и/или имя плательщика). В текущей версии API оплата картой по intent, созданному без billing-данных, может быть отклонена сервером.

---

## 6. Объект PaymentIntent

`YP.createIntent()`, `YP.getIntent()` и `YP.wrapIntent()` возвращают хэндл intent — объект `PaymentIntent`:

| Свойство | Тип | Описание |
|---|---|---|
| `id` | `String` async property | Идентификатор intent — сохраняйте для восстановления |
| `status` | `IntentStatus` async property | Текущий закэшированный статус |
| `data` | `IntentResponse` async property | Полные данные intent: сумма, валюта, методы оплаты, транзакции, `expiredAt` и т.д. |
| `events` | `AsyncStream<IntentEvent>` | Поток событий intent |

Пример чтения async-свойств:

```swift
let id = await intent.id
let status = await intent.status
let data = await intent.data
```

### Методы

| Метод | Возвращает | Описание |
|---|---|---|
| `pay(input:)` | `PayResult` | Оплата картой или готовой криптограммой ([раздел 7](#7-оплата-картой-и-3-d-secure)) |
| `create3dsView(result:)` | `ThreeDsView` | WebView 3-D Secure ([раздел 7](#7-оплата-картой-и-3-d-secure)) |
| `create3dsView(threeDsUrl:)` | `ThreeDsView` | Создать 3DS view напрямую по URL |
| `getPaymentMethod(method:opts:)` | `AltPayFlow` | Flow альтернативного метода ([раздел 8](#8-альтернативные-методы-оплаты)) |
| `getFasterPaymentsFlow(opts:)` | `FasterPaymentsFlow` | Удобный метод для СБП |
| `getSberPayFlow(opts:)` | `SberPayFlow` | Удобный метод для SberPay |
| `waitForResult(opts:)` | `WaitForResultStatus` | Polling до результата ([раздел 9](#9-ожидание-результата-waitforresult)) |
| `update(changes:)` | `Void` | Обновление полей intent ([раздел 10](#10-обновление-intent)) |
| `getStatus()` | `IntentStatus` | Разовый запрос текущего статуса |
| `getStatusDetails()` | `IntentStatusResponse` | Статус и список транзакций для собственного polling |
| `getBinInfo(bin:)` | `BinInfo` | Информация по BIN карты, первые 6 цифр |

### События

`intent.events` — `AsyncStream<IntentEvent>`. События дублируют исходы операций, чтобы результат можно было обрабатывать в одном месте независимо от способа оплаты:

| Событие | Payload | Когда возникает |
|---|---|---|
| `.success` | `PayResult` | Оплата успешно завершена: после `pay()`, после 3DS или когда `waitForResult` дождался `.success` |
| `.error` | `Error` | Ошибка `pay()`, провал 3DS, `.expired`, отклонение попытки |
| `.statusChange` | `IntentStatus` | Статус intent изменился |
| `.update` | `PaymentIntent` | Поля intent обновлены после `update()` |

```swift
Task {
    for await event in intent.events {
        switch event {
        case .success:
            await MainActor.run { showSuccess() }
        case .error(let error):
            await MainActor.run { showError(error) }
        case .statusChange(let status):
            print("Статус:", status)
        case .update(let intent):
            print(await intent.data)
        }
    }
}
```

---

## 7. Оплата картой и 3-D Secure

### intent.pay(input:)

Принимает данные карты, получает открытый ключ у API, шифрует карточные данные на устройстве и проводит платёж. PAN, CVV и ID текущего интента уходят на сервер только внутри криптограммы (RSA-OAEP SHA-256, открытый ключ запрашивается у API автоматически).

```swift
let result = try await intent.pay(
    input: .card(
        CardData(
            pan: "4111111111111111", // номер карты, только цифры
            expMonth: "12",          // месяц, 2 цифры
            expYear: "30",           // год, 2 цифры
            cvv: "123"
        )
    )
)
```

Если криптограмма собрана вами заранее, передайте её напрямую:

```swift
let result = try await intent.pay(input: .cryptogram(cryptogram))
```

Результат — `PayResult`:

| Вариант | Что означает | Что делать |
|---|---|---|
| `.authorized(IntentStatusResponse)` | Платёж проведён без 3DS | Показать экран успеха |
| `.threeDsRequired(threeDsUrl:)` | Банк требует подтверждение 3-D Secure | Создать и показать `ThreeDsView` |

При отказе банка или ошибке API `pay()` бросает ошибку и эмитит `.error`.

### 3-D Secure: `ThreeDsView`

```swift
let result = try await intent.pay(input: .card(card))

if case .threeDsRequired = result {
    let threeDsView = try intent.create3dsView(result: result)

    await MainActor.run {
        threeDsView.mount(into: containerView)
    }

    let results = await MainActor.run { threeDsView.results }
    for await result in results {
        await MainActor.run { threeDsView.destroy() }

        switch result.status {
        case .success:
            showSuccess()
        case .failure:
            showRetryScreen()
        }
        break
    }
}
```

`mount(into:)` создаёт `WKWebView` со страницей подтверждения банка и добавляет его в ваш `UIView`-контейнер. SDK следит за результатом двумя путями одновременно: принимает сообщение от возвратной страницы 3DS только с разрешённого origin платёжного API и параллельно опрашивает статус intent каждые 3 секунды.

**API ThreeDsView:**

| Метод/свойство | Описание |
|---|---|
| `mount(into:)` | Создать `WKWebView`, добавить в `UIView`. Вызывать на `MainActor` |
| `unmount()` | Извлечь `WKWebView` из контейнера и остановить 3DS polling |
| `destroy()` | Полностью завершить: остановить polling, удалить и уничтожить `WKWebView`, завершить текущих подписчиков `results` |
| `results` | `AsyncStream<ThreeDsResult>` — исход проверки; новый подписчик получает последний результат, если он уже был |
| `webView` | Сам `WKWebView` после `mount`, если нужна тонкая настройка |

Вызывайте `destroy()` после получения результата и при закрытии экрана 3DS.

---

## 8. Альтернативные методы оплаты

Список методов, доступных покупателю, приходит в `intent.data.paymentMethods` и зависит от настроек вашего терминала. Стройте кнопки способов оплаты по нему:

```swift
let data = await intent.data
let available: [AltPayMethod] = data.paymentMethods?
    .compactMap { AltPayMethod.fromType($0.type) } ?? []
```
Для запуска оплаты получите flow метода:

```swift
let puid = UUID().uuidString.lowercased()
let flow = try await intent.getPaymentMethod(
    method: .sberPay,
    opts: AltRequestOpts(puid: puid)
)
```

`getPaymentMethod(method:opts:)`:

| Параметр | Тип | Описание |
|---|---|---|
| `method` | `AltPayMethod` | `.fasterPayments`, `.sberPay`, `.alfaPay`, `.tPay` |
| `opts.puid` | `String?` | Идентификатор попытки ([раздел 3](#puid--идентификатор-попытки-оплаты)) |
| `opts.webview` | `Bool` | Укажите `true`, если страница открыта внутри WebView мобильного приложения — платежный сервис вернет ссылку, корректно работающую из WebView |

Если метода нет в intent, вызов бросит `YPError`. Для СБП и SberPay есть удобные методы `getFasterPaymentsFlow(opts:)` и `getSberPayFlow(opts:)`.

Общий API flow (`AltPayFlow`):

| Свойство/метод | Описание |
|---|---|
| `method` | Тип метода |
| `link` | Ссылка или deeplink из данных intent, если backend вернул её сразу |
| `getLink(opts:)` | Запросить свежую ссылку у API с учётом `puid`, `webview` и `schema` банка для СБП |
| `getImage()` | Вернуть URL изображения метода из данных intent или пустую строку |

> **Правило:** если вы используете `waitForResult(puid:)`, получайте ссылку через `getLink()` с тем же `puid`. Встроенный `flow.link` этого не гарантирует.

### SberPay

```swift
let puid = UUID().uuidString.lowercased()
let sberPay = try await intent.getSberPayFlow(opts: AltRequestOpts(puid: puid))

// Вариант А: открыть приложение банка по ссылке/deeplink
let link = try await sberPay.getLink()
if let url = URL(string: link) {
    await MainActor.run { UIApplication.shared.open(url) }
}

// Вариант Б: отправить пуш/СМС со ссылкой на оплату
try await sberPay.sendSms(phone: "79990000000") // формат 79XXXXXXXXX

// В обоих случаях ждём результат
let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: puid))
```

### СБП (FasterPayments)

У СБП-flow есть список банков и изображение/QR, если backend вернул его в данных метода:

```swift
let puid = UUID().uuidString.lowercased()
let sbp = try await intent.getFasterPaymentsFlow(opts: AltRequestOpts(puid: puid))

// 1. Список банков для выбора
showBankPicker(sbp.banks)

// 2. Deeplink в выбранный банк
let link = try await sbp.getLink(opts: AltLinkOpts(schema: selectedBank.schema))
if let url = URL(string: link) {
    await MainActor.run { UIApplication.shared.open(url) }
}

// 3. Либо изображение метода/QR, если оно есть в данных intent
let imageUrl = sbp.getImage()

// Ожидание результата
let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: puid))
```

`SbpBank` содержит `bankName`, `logoUrl`, `schema`, `webClientUrl`, `isWebClientActive`, `packageName`. На iOS `packageName` Android-приложения банка обычно не используется для запуска приложения, но может приходить в данных API.

### Прочие методы: AlfaPay, T-Pay

Универсальный сценарий — получить ссылку и открыть её:

```swift
let puid = UUID().uuidString.lowercased()
let flow = try await intent.getPaymentMethod(method: .tPay, opts: AltRequestOpts(puid: puid))
let link = try await flow.getLink()

if let url = URL(string: link) {
    await MainActor.run { UIApplication.shared.open(url) }
}

let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: puid))
```

---

## 9. Ожидание результата: waitForResult

Для карты результат приходит синхронно из `pay()` или через `ThreeDsView`, а при оплате альтернативным методом покупатель уходит во внешний сценарий — результат нужно **ждать**. `waitForResult` опрашивает статус intent до терминального исхода:

```swift
let status = try await intent.waitForResult(
    opts: WaitForResultOpts(
        intervalMs: 3_000,   // период опроса (по умолчанию 3 секунды)
        timeoutMs: 600_000,  // общий таймаут (по умолчанию 10 минут)
        puid: puid           // ловить отказ именно этой попытки
    )
)

switch status {
case .success:
    showSuccessScreen()
case .declined:
    showRetryScreen()    // попытка отклонена — intent жив, новый puid и повтор
case .expired:
    showExpiredScreen()  // сессия истекла — нужен новый intent
case .requiresPaymentData, .requiresPaymentMethod:
    break
}
```

Исходы:

- **`.success`** — оплата прошла, дополнительно эмитится `.success`;
- **`.declined`** — среди транзакций появилась `DECLINED`-транзакция с вашим `puid`: текущая попытка отклонена, но intent не терминален; предложите покупателю оплатить снова;
- **`.expired`** — время жизни intent истекло, дополнительно эмитится `.error`.

По истечении `timeoutMs` метод бросает `YPError(message: "pollUntil: timeout")`.

> **Отмена ожидания** — стандартная отмена Swift `Task`. Запускайте `waitForResult` из задачи, привязанной к жизненному циклу экрана. При уходе с экрана отменяйте задачу, иначе polling API доживёт до timeout.

```swift
let pollingTask = Task {
    let status = try await intent.waitForResult(opts: WaitForResultOpts(puid: puid))
    // ...
}

// при закрытии экрана ожидания:
pollingTask.cancel()
```

Если нужен собственный цикл polling, используйте `intent.getStatusDetails()` — он возвращает статус вместе с транзакциями.

---

## 10. Обновление интента

После создания intent можно изменить ограниченный набор полей:

```swift
try await intent.update(
    changes: UpdateChanges(
        receiptEmail: "buyer@example.com",
        tokenize: true
    )
)
```

`UpdateChanges` — поле со значением `nil` означает «не менять»:

| Поле | Тип | Описание |
|---|---|---|
| `receiptEmail` | `String?` | Новый email для квитанции |
| `tokenize` | `Bool?` | Токенизация карты |
| `clearReceiptEmail` | `Bool` | `true` — очистить email; `nil` у `receiptEmail` означает «не трогать» |

Типовой сценарий: покупатель ввёл email на вашем экране прямо перед оплатой — обновите intent до вызова `pay()`. Несколько параллельных вызовов `update()` SDK автоматически объединяет в один запрос. Вызов без единого редактируемого поля бросает `YPError(message: "update: no editable fields provided")`. После успешного обновления эмитится `.update`.

---

## 11. Восстановление intent

`YP.getIntent(id:config:secret:)` загружает существующий intent — тот же полнофункциональный хэндл, что и после `createIntent`:

```swift
let intent = try await YP.getIntent(id: savedIntentId, config: config)

switch await intent.status {
case .success:
    showSuccessScreen()
case .expired:
    showExpiredScreen()
case .requiresPaymentData, .requiresPaymentMethod:
    resumeCheckout(intent)
}
```

Когда это нужно:

- **пересоздание экрана или процесса** во время оплаты — сохраните `intent.id` и восстановите сессию;
- **возврат покупателя** из приложения банка в ваше приложение — проверьте фактический статус;
- **intent создан на вашем бэкенде** server-to-server, а приложение получает только его id — так параметры платежа не проходят через клиент.

Если ваш бэкенд уже отдал приложению полный JSON intent, можно обойтись без лишнего запроса:

```swift
let intent = YP.wrapIntent(data: intentResponse, config: config)
```

Если у вас отдельно сохранён `secret`, передайте его в `YP.getIntent(id:config:secret:)`; иначе SDK использует `IntentResponse.secret` из ответа API.

---

## 12. Swift Concurrency и потоки

SDK использует `async throws` и `AsyncStream`. UI обновляйте на `MainActor`:

```swift
Task {
    do {
        let result = try await intent.pay(input: .card(card))
        await MainActor.run { render(result) }
    } catch is CancellationError {
        // пользователь закрыл экран или задача отменена
    } catch {
        await MainActor.run { showError(error) }
    }
}
```

3DS API (`ThreeDsView.mount`, `unmount`, `destroy`, `results`, `webView`) помечен `@MainActor`, потому что работает с UIKit/WebKit.

Для SwiftUI храните `Task` оплаты или polling в `@State`/view model и отменяйте её в `onDisappear`, если экран больше не должен ждать результат.

---

## 13. Обработка ошибок

SDK может бросать `YPError`, `CancellationError` и ошибки нижнего уровня, завёрнутые в `YPError.cause`.

```swift
do {
    let result = try await intent.pay(input: .card(card))
    handle(result)
} catch let error as YPError {
    showError(error.message)
    print(error.cause as Any)
} catch is CancellationError {
    // операция отменена
} catch {
    showError("Ошибка оплаты")
}
```

Типичные сообщения:

| Сообщение | Причина |
|---|---|
| `payment declined (transaction N)` | Попытка с вашим `puid` отклонена (`waitForResult` -> `.declined`) |
| `payment expired` | Intent истёк (`waitForResult` -> `.expired`) |
| `3DS failed` | Покупатель не прошёл 3-D Secure |
| `pollUntil: timeout` | `waitForResult` не дождался результата за `timeoutMs` |
| `getPaymentMethod: method X not present in intent` | Метод недоступен для терминала или запрещён |
| `update: no editable fields provided` | В `update()` не передано ни одного редактируемого поля |
| `getBinInfo: bin must contain exactly 6 digits` | BIN после нормализации не содержит ровно 6 цифр |
| `create3dsView: 3DS result required` | В `create3dsView(result:)` передан не `.threeDsRequired` |

**Рекомендации по UX ошибок:**

- отказ оплаты (`.declined`, ошибка `pay()`) — не тупик: предложите повторить оплату другой картой или другим методом;
- `.expired` — создайте новый intent и предложите оплатить заново;
- не показывайте покупателю технические сообщения — переводите их в понятные формулировки, например «Платёж отклонён банком. Попробуйте другую карту».

---

## 14. Тестирование в песочнице

Для тестов используйте `YPConfig(baseUrl: YPConfig.sandboxBaseUrl)`. Тестовые карты действуют **только в песочнице**.

### Успешная оплата

| Номер карты | Платёжная система | 3-D Secure | Срок действия | CVV |
|---|---|---|---|---|
| `4652 0354 4066 7037` | VISA | нет | 08 / следующий год | 971 |
| `4051 0600 0000 0178` | VISA | да | 12 / следующий год | 895 |
| `5105 1051 0510 5100` | MasterCard | нет | 03 / следующий год | 235 |
| `5547 6294 7878 5897` | MasterCard | да | 07 / следующий год | 123 |
| `2200 2042 6557 0145` | МИР | нет | 03 / следующий год | 235 |
| `2200 2016 7368 7446` | МИР | да | 07 / следующий год | 123 |

### Отказ в авторизации

| Номер карты | Платёжная система | Причина отказа | Срок действия | CVV |
|---|---|---|---|---|
| `5563 6930 6203 0796` | MasterCard | Stolen card, pick up | 03 / любой будущий год | 235 |
| `4921 3010 1045 9253` | VISA | Default error | 03 / любой будущий год | 235 |
| `2200 2000 0000 0000` | МИР | Non Sufficient Funds | 03 / любой будущий год | 235 |

> «Следующий год» — именно следующий календарный год. Например, в 2026 году указывайте `27`. Месяц — из таблицы.

**Чек-лист сценариев для проверки интеграции:**

- [ ] оплата картой без 3DS -> экран успеха;
- [ ] оплата картой с 3DS -> `WKWebView` -> успех; `destroy()` вызван;
- [ ] карта с отказом -> сообщение об ошибке -> повторная попытка успешной картой;
- [ ] альтернативный метод: ссылка получена с `puid`, `waitForResult` доводит до результата;
- [ ] сворачивание приложения и возврат во время ожидания -> polling продолжает работать только если экран/задача ещё актуальны;
- [ ] уход с экрана ожидания -> `Task` отменена, polling остановлен;
- [ ] пересоздание экрана во время оплаты -> `YP.getIntent` восстанавливает сессию.

---

## 15. Безопасность и PCI DSS

- SDK шифрует данные карты на устройстве до отправки; PAN и CVV покидают приложение только внутри криптограммы. Открытый ключ шифрования SDK получает у API автоматически.
- Поскольку данные карты вводятся в вашем приложении, объём ваших обязательств по PCI DSS согласуйте со службой безопасности НКО.

**Обязательные требования к вашему приложению:**

1. Не сохраняйте и не логируйте PAN, CVV, срок действия карты и криптограммы: ни в логи, ни в аналитику, ни в crash reports.
2. Не передавайте данные карты на свой сервер. Они должны идти только в `intent.pay(input: .card(...))`.
3. Не логируйте `intent.data.secret` и не передавайте его третьим лицам.
4. На экране ввода карты отключите скриншоты и запись экрана, если это требуется вашей моделью угроз и политиками безопасности.
5. Не переопределяйте обработку TLS/SSL-ошибок в приложении; SDK работает только по HTTPS.

`CardData.description` и `CardData.debugDescription` маскируют данные карты. Не обходите это, собирая строки из полей вручную.

---

## 16. Краткий справочник типов

Полный справочник публичного Swift API находится в [`sdk/README.md`](sdk/README.md). Ниже — основные типы, которые чаще всего нужны при интеграции.

### `YPConfig`

```swift
YPConfig(
    baseUrl: YPConfig.productionBaseUrl, // или YPConfig.sandboxBaseUrl
    headers: [:]                      // дополнительные заголовки, по согласованию
)
```

### `CreateIntentRequest`

```swift
CreateIntentRequest(
    merchantCode: String,
    amount: Int64,                              // сумма в копейках, min 100
    currency: String,                           // "RUB" 
    messageScheme: String,                      // "SMS" | "DMS"
    description: String? = nil,                 // ≤ 255 символов
    merchantPaymentReference: String? = nil,    // ≤ 100 символов
    receiptEmail: String? = nil,
    accountId: String? = nil,
    tokenize: Bool? = nil,
    orderTimeout: Int? = nil,                   // секунды, 1200–2592000
    retryPayment: Bool? = nil,
    successRedirectUrl: String? = nil,
    failRedirectUrl: String? = nil,
    items: [ProductItem]? = nil,
    receipts: YPJSONObject? = nil,
    userInfo: UserInfo? = nil,
    metaData: YPJSONObject? = nil
)
```

### `ProductItem`

```swift
ProductItem(
    name: String,                       // ≤ 255 символов
    sku: String,                        // ≤ 100 символов
    unitPrice: String,                  // строка, ≤ 9999999
    quantity: String,                   // строка, ≤ 99999
    additionalDetails: String? = nil,
    vat: String? = nil,                 // "0" | "5" | "7" | "10" | "22"
    marketplace: Marketplace? = nil     // Marketplace(merchantCode)
)
```

### `UserInfo`

```swift
UserInfo(billing: Billing(
    firstName: nil,
    lastName: nil,
    email: "buyer@example.com",
    countryCode: "RU",          // ISO 3166-1 alpha-2, например "RU"
    phone: "79990000000"        // 79XXXXXXXXX
))
```

### `IntentResponse`

```swift
public struct IntentResponse: Codable, Sendable {
    public let id: String
    public var status: String
    public let secret: String                               // служебное — не логировать
    public let createdAt: Int64
    public let updatedAt: Int64
    public let expiredAt: Int64                             // когда интент перейдёт в Expired
    public let merchantCode: String
    public let amount: Int64
    public let currency: String
    public let messageScheme: String
    public let description: String?
    public let receiptEmail: String?
    public let tokenize: Bool?
    public let paymentMethods: [PaymentMethodDto]?          // доступные методы оплаты
    public let terminalInfo: TerminalInfoDto?
    public internal(set) var transactions: [YPJSONObject]?  // попытки оплаты
}
```

### Статусы

```swift
enum IntentStatus {
    case requiresPaymentData
    case requiresPaymentMethod
    case expired
    case success
}

enum WaitForResultStatus {
    case requiresPaymentData
    case requiresPaymentMethod
    case expired
    case success
    case declined
}
```

### Оплата картой

```swift
CardData(
    pan: String,            // только цифры
    expMonth: String,       // 2 цифры, "01"–"12"
    expYear: String,        // 2 цифры
    cvv: String
) 
// CardData.toString() маскирует данные

enum PayInput {
    case card(CardData)
    case cryptogram(String)
}

enum PayResult {
    case authorized(IntentStatusResponse)
    case threeDsRequired(threeDsUrl: String)
}
```

### Альтернативные методы

```swift
enum AltPayMethod: String {
    case fasterPayments = "FasterPayments"
    case sberPay = "SberPay"
    case alfaPay = "AlfaPay"
    case tPay = "TPay"
}

AltRequestOpts(webview: Bool = false, puid: String? = nil)
AltLinkOpts(webview: Bool = false, puid: String? = nil, schema: String? = nil)
```

### 3-D Secure

```swift
public final class ThreeDsView {
    @MainActor public private(set) var webView: WKWebView?
    @MainActor public var results: AsyncStream<ThreeDsResult> { get }
    @MainActor public func mount(into container: UIView) -> ThreeDsView
    @MainActor public func unmount()
    @MainActor public func destroy()
}
```

### Ошибки

```swift
public struct YPError: Error, LocalizedError {
    public let message: String
    public let cause: Error?
}
```

---

## 17. Чек-лист перед выходом в продакшен

- [ ] `YPConfig.baseUrl` указывает на продакшен (`YPConfig.productionBaseUrl`), используется продакшен-`merchantCode`.
- [ ] `amount` передаётся в копейках, а не в рублях.
- [ ] Передаётся `userInfo.billing` для карточных платежей.
- [ ] Обработаны оба исхода `pay()`: `.authorized` и `.threeDsRequired`; `ThreeDsView.destroy()` вызывается после результата и при закрытии экрана.
- [ ] Для альтернативных методов: `puid` генерируется на каждую попытку, ссылки берутся через `getLink()`, результат — через `waitForResult(puid:)`.
- [ ] `waitForResult` вызывается из `Task`, привязанной к жизненному циклу экрана; при уходе с экрана задача отменяется.
- [ ] `intent.id` переживает пересоздание экрана или процесса, восстановление — через `YP.getIntent`.
- [ ] Отказ и истечение сессии обрабатываются: покупателю предложен повтор или новый intent.
- [ ] Данные карты, криптограммы и `intent.data.secret` не логируются и не попадают в аналитику/crash reports.
- [ ] UIKit/WebKit операции 3DS выполняются на `MainActor`.
- [ ] Проведены тестовые платежи по [чек-листу сценариев](#14-тестирование-в-песочнице).

---

*Появились вопросы по интеграции — обратитесь к вашему менеджеру или в техническую поддержку help@ypmn.ru*
