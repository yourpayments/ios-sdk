# YourPayments SDK — справочник публичного API

Этот документ описывает публичный контракт Swift-модуля `Yourpayments`: методы, модели, входные параметры, результаты и основные ошибки. SDK является headless: он не предоставляет готовый checkout экран, а приложение мерчанта строит UI самостоятельно.

Merchant-facing руководство по интеграции находится в корневом [`README.md`](../README.md): там разобраны сценарии оплаты, 3DS, альтернативные методы, polling, безопасность и чек-лист запуска.

SDK работает с Payment Intent API. Описания полей ниже сверены с публичными моделями SDK и `docs/openapi.json.txt`. Если OpenAPI содержит поле, которого нет в публичной модели SDK, это поле не считается доступным через текущий SDK.

> Breaking change: public status API приведен к Android/Web контракту. `IntentStatus.pending` и `IntentStatus.failed` удалены; используйте `.requiresPaymentData`, `.requiresPaymentMethod`, `.expired`, `.success`. `PaymentIntent.waitForResult(opts:)` возвращает `WaitForResultStatus`, включая `.declined` для отказа текущей попытки.

## Содержание

- [Требования](#требования)
- [Установка](#установка)
- [Базовая схема работы](#базовая-схема-работы)
- [Конфигурация](#конфигурация)
- [Методы `YP`](#методы-yp)
- [Методы и свойства `PaymentIntent`](#методы-и-свойства-paymentintent)
- [Оплата картой и криптограммой](#оплата-картой-и-криптограммой)
- [3DS](#3ds)
- [Альтернативные методы оплаты](#альтернативные-методы-оплаты)
- [Статусы, polling и события](#статусы-polling-и-события)
- [Публичные модели](#публичные-модели)
- [Ошибки](#ошибки)
- [Соответствие endpoint](#соответствие-endpoint)

## Требования

| Требование | Значение |
|---|---|
| iOS | 17.0+ |
| Swift tools | 5.9 |
| Менеджер зависимостей | Swift Package Manager |
| Product | `Yourpayments` |
| Module | `Yourpayments` |

Пакет также объявляет macOS 12. 3DS UI API доступен только там, где можно импортировать UIKit и WebKit.

## Установка

Swift Package URL:

```text
https://github.com/darkkifir/YPSDK_iOS.git
```

В Xcode выберите `File` -> `Add Package Dependencies`, добавьте URL пакета и подключите product `Yourpayments` к target приложения.

Пример для `Package.swift`:

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

## Базовая Схема Работы

```text
Merchant UI
  -> YPConfig
  -> YP.createIntent / YP.getIntent / YP.wrapIntent
  -> render paymentMethods in merchant UI
  -> card: PaymentIntent.pay(input: .card) or PaymentIntent.pay(input: .cryptogram)
  -> if needed: PaymentIntent.create3dsView + ThreeDsView.mount
  -> alt-pay: get flow + get link + open app/web flow
  -> PaymentIntent.getStatus or PaymentIntent.waitForResult
```

Минимальный пример:

```swift
let config = YPConfig(baseUrl: YPConfig.sandboxBaseUrl)

let request = CreateIntentRequest(
    merchantCode: "widget",
    amount: 2000,
    currency: "RUB",
    messageScheme: "SMS",
    description: "Demo payment"
)

let intent = try await YP.createIntent(request: request, config: config)
let result = try await intent.pay(input: .card(
    CardData(pan: "4242424242424242", expMonth: "12", expYear: "29", cvv: "123")
))

if case .threeDsRequired = result {
    let threeDsView = try intent.create3dsView(result: result)
    await MainActor.run { threeDsView.mount(into: containerView) }
}

let finalStatus: WaitForResultStatus = try await intent.waitForResult()
```

## Конфигурация

### `YPConfig`

```swift
public struct YPConfig: Sendable {
    public static let productionBaseUrl = "https://ypmn.ru"
    public static let sandboxBaseUrl = "https://sandbox.ypmn.ru"

    public let baseUrl: String
    public let headers: [String: String]

    public init(baseUrl: String = Self.productionBaseUrl, headers: [String: String] = [:])
}
```

| Параметр | Обязательный | Значение по умолчанию | Описание |
|---|---:|---|---|
| `baseUrl` | Нет | `YPConfig.productionBaseUrl` | Базовый URL API. Для sandbox используйте `YPConfig.sandboxBaseUrl`. |
| `headers` | Нет | `[:]` | Дополнительные HTTP headers для всех SDK-запросов. |

Результат и side effects: `YPConfig` сам не выполняет запросы. Он передается в `YP.createIntent`, `YP.getIntent` или `YP.wrapIntent`, после чего используется внутренним API-клиентом SDK.

Пример:

```swift
let config = YPConfig(
    baseUrl: YPConfig.sandboxBaseUrl,
    headers: ["X-Custom-Header": "value"]
)
```

## Методы `YP`

`YP` является основной точкой входа в SDK. У него нет public initializer.

```swift
public enum YP {
    public static func createIntent(request: CreateIntentRequest, config: YPConfig = YPConfig()) async throws -> PaymentIntent
    public static func getIntent(id: String, config: YPConfig = YPConfig(), secret: String? = nil) async throws -> PaymentIntent
    public static func wrapIntent(data: IntentResponse, config: YPConfig = YPConfig()) -> PaymentIntent
}
```

### `YP.createIntent(request:config:)`

Создает новый payment intent и возвращает объект для дальнейшей оплаты.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `request` | `CreateIntentRequest` | Да | Данные для создания intent. |
| `config` | `YPConfig` | Нет | API URL и дополнительные headers. |

Выход: `PaymentIntent` с актуальными данными `IntentResponse` и intent `secret` из ответа backend.

Сетевой вызов: `POST api/intent/`.

Пример:

```swift
let request = CreateIntentRequest(
    merchantCode: "widget",
    amount: 2000,
    currency: "RUB",
    messageScheme: "SMS",
    description: "Demo payment",
    merchantPaymentReference: "order-123",
    receiptEmail: "customer@example.com",
    accountId: "customer-42",
    tokenize: true
)

let intent = try await YP.createIntent(request: request, config: config)
```

`CreateIntentRequest`:

| Поле | Тип | Обязательное | Описание |
|---|---|---:|---|
| `merchantCode` | `String` | Да | Публичный идентификатор терминала мерчанта. |
| `amount` | `Int64` | Да | Сумма в минорных единицах валюты, например в копейках или центах. По OpenAPI: min `100`, max `999999999`. |
| `currency` | `String` | Да | Код валюты, например `RUB`, `USD`, `EUR`. |
| `messageScheme` | `String` | Да | Схема списания. По OpenAPI: `SMS` для одностадийной оплаты, `DMS` для двухстадийной. |
| `description` | `String?` | Нет | Описание платежа, по OpenAPI до 255 символов. |
| `merchantPaymentReference` | `String?` | Нет | Внешний идентификатор заказа, аналог invoice/order id мерчанта. |
| `receiptEmail` | `String?` | Нет | Email для чека. |
| `accountId` | `String?` | Нет | Внешний идентификатор плательщика. |
| `tokenize` | `Bool?` | Нет | Нужно ли токенизировать карту. |
| `orderTimeout` | `Int?` | Нет | Время жизни intent до 30 дней, в секундах (1200-2592000). По дефолту 60 минут (3600 секунд). По истечении - статус .expired |
| `retryPayment` | `Bool?` | Нет | Разрешить повторную попытку оплаты после отказа. |
| `successRedirectUrl` | `String?` | Нет | URL возврата при успешной оплате на внешних платежных страницах. |
| `failRedirectUrl` | `String?` | Нет | URL возврата при неуспешной оплате на внешних платежных страницах. |
| `items` | `[ProductItem]?` | Нет | Состав заказа. |
| `receipts` | `YPJSONObject?` | Нет | Данные чеков (формат АТОЛа, см. документацию провайдера) |
| `userInfo` | `UserInfo?` | Нет | Данные плательщика. |
| `metaData` | `YPJSONObject?` | Нет | Произвольные метаданные; JSON key чувствителен к регистру: `metaData`. |
| `scenario` | `String` | Да, задается SDK | SDK всегда отправляет `IoSSDK`; параметр отсутствует в public initializer. |

`ProductItem`: обязательные `name`, `sku`, `unitPrice`, `quantity`; опциональные `additionalDetails`, `vat`, `marketplace`. `Marketplace` содержит обязательный `merchantCode`.

`UserInfo` содержит опциональный `billing`. `Billing` содержит опциональные строки `firstName`, `lastName`, `email`, `countryCode`, `phone`, `city`, `state`, `companyName`, `taxId`, `addressLine1`, `addressLine2`, `zipCode`.

Hosted/widget поля `autoClose`, `skin`, `emailBehavior`, `paymentUrl` не exposed в текущей public модели `CreateIntentRequest` для нативного SDK.

### `YP.getIntent(id:config:secret:)`

Загружает существующий intent по id и возвращает `PaymentIntent`.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `id` | `String` | Да | UUID payment intent. |
| `config` | `YPConfig` | Нет | API URL и headers. |
| `secret` | `String?` | Нет | Intent secret. Если передан, SDK использует его для последующих защищенных операций. Если не передан, SDK использует `IntentResponse.secret` из ответа. |

Выход: `PaymentIntent`.

Сетевой вызов: `GET api/intent/{id}/`.

Пример:

```swift
let intent = try await YP.getIntent(
    id: "intent-id",
    config: config,
    secret: "intent-secret"
)
```

### `YP.wrapIntent(data:config:)`

Создает `PaymentIntent` из уже полученного `IntentResponse` без сетевого запроса.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `data` | `IntentResponse` | Да | Готовые данные intent. |
| `config` | `YPConfig` | Нет | API URL и headers для будущих операций. |

Выход: `PaymentIntent`, который использует `data.secret` для последующих операций.

Пример:

```swift
let intent = YP.wrapIntent(data: intentResponse, config: config)
```

## Методы И Свойства `PaymentIntent`

`PaymentIntent` создается только через `YP.createIntent`, `YP.getIntent` или `YP.wrapIntent`. Public initializer отсутствует.

```swift
public final class PaymentIntent: @unchecked Sendable {
    public var id: String { get async }
    public var status: IntentStatus { get async }
    public var data: IntentResponse { get async }
    public var events: AsyncStream<IntentEvent> { get }

    public func update(changes: UpdateChanges) async throws
    public func getStatus() async throws -> IntentStatus
    public func getStatusDetails() async throws -> IntentStatusResponse
    public func getBinInfo(bin: String) async throws -> BinInfo
    public func pay(input: PayInput) async throws -> PayResult
    public func getPaymentMethod(method: AltPayMethod, opts: AltRequestOpts = AltRequestOpts()) async throws -> AltPayFlow
    public func getFasterPaymentsFlow(opts: AltRequestOpts = AltRequestOpts()) async throws -> FasterPaymentsFlow
    public func getSberPayFlow(opts: AltRequestOpts = AltRequestOpts()) async throws -> SberPayFlow
    public func waitForResult(opts: WaitForResultOpts = WaitForResultOpts()) async throws -> WaitForResultStatus
}
```

В окружении с UIKit и WebKit дополнительно доступны методы 3DS:

```swift
extension PaymentIntent {
    public func create3dsView(result: PayResult) throws -> ThreeDsView
    public func create3dsView(threeDsUrl: String) -> ThreeDsView
}
```

### Свойства

| Свойство | Тип | Описание |
|---|---|---|
| `id` | `String` | Идентификатор intent из `IntentResponse.id`. |
| `status` | `IntentStatus` | Текущий resolved статус SDK. Берется из кэша и последнего status response. |
| `data` | `IntentResponse` | Кэшированные данные intent. Обновляются после `update`, `getStatus`, `pay` и успешного 3DS. |
| `events` | `AsyncStream<IntentEvent>` | Поток событий intent. Каждый вызов возвращает новый stream. |

Пример:

```swift
let id = await intent.id
let status = await intent.status
let data = await intent.data
```

### `update(changes:)`

Обновляет редактируемые поля intent.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `changes` | `UpdateChanges` | Да | Набор изменений. Должно быть передано хотя бы одно поле. |

Выход: `Void`. После успешного запроса SDK обновляет `intent.data` и отправляет событие `.update(PaymentIntent)`.

Сетевой вызов: `PATCH api/intent/{id}/` с header `X-Intent-Secret`.

Пример:

```swift
try await intent.update(
    changes: UpdateChanges(
        receiptEmail: "customer@example.com",
        tokenize: true
    )
)
```

`UpdateChanges`:

| Поле | Тип | Описание |
|---|---|---|
| `receiptEmail` | `String?` | Новый email для чека. `nil` — не менять. В JSON Patch отправляется как `/receiptEmail`. |
| `tokenize` | `Bool?` | Новый флаг токенизации. В JSON Patch отправляется как `/tokenize`. |
| `clearReceiptEmail` | `Bool` | `true` — очистить email чека. В JSON Patch отправляется `/receiptEmail` со значением `null`. По умолчанию `false`. |

Если `receiptEmail` и `tokenize` равны `nil`, а `clearReceiptEmail == false`, SDK бросает `YPError(message: "update: no editable fields provided")`.

### `getStatus()`

Однократно запрашивает статус intent.

Входных параметров нет.

Выход: `IntentStatus`.

Сетевой вызов: `GET api/intent/{id}/status/`.

Side effects: обновляет `intent.data.status`, `intent.data.transactions`, внутренний resolved status и отправляет `.statusChange(IntentStatus)`, если resolved статус изменился.

Пример:

```swift
let status = try await intent.getStatus()
```

### `getStatusDetails()`

Однократно запрашивает статус intent вместе с транзакциями.

Входных параметров нет.

Выход: `IntentStatusResponse`.

Сетевой вызов: `GET api/intent/{id}/status/`.

Side effects: обновляет `intent.data.status`, `intent.data.transactions`, внутренний resolved status и отправляет `.statusChange(IntentStatus)`, если resolved статус изменился.

Пример:

```swift
let details = try await intent.getStatusDetails()
print(details.intent.status, details.transactions)
```

### `getBinInfo(bin:)`

Получает информацию по BIN карты.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `bin` | `String` | Да | Первые 6 цифр карты. SDK удаляет все не ASCII-цифры и требует ровно 6 цифр после нормализации. |

Выход: `BinInfo`.

Сетевой вызов: `GET api/intent/{id}/bin-info/{bin}/`.

Пример:

```swift
let binInfo = try await intent.getBinInfo(bin: "424242")
print(binInfo.cardType as Any, binInfo.countryCode as Any, binInfo.bankName as Any)
```

Если после нормализации не 6 цифр, SDK бросает `YPError(message: "getBinInfo: bin must contain exactly 6 digits")`.

### `pay(input:)`

Запускает оплату картой или готовой криптограммой.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `input` | `PayInput` | Да | `.card(CardData)` для создания криптограммы внутри SDK или `.cryptogram(String)` для внешней криптограммы. |

Выход: `PayResult`.

Сетевые вызовы: для `.card` SDK может сначала вызвать `GET api/intent/pay/key/`, затем всегда вызывает `POST api/intent/{id}/pay/`.

Side effects: при успешной авторизации обновляет статус и transactions, отправляет `.success(PayResult)`. При ошибке оплаты отправляет `.error(Error)` и пробрасывает ошибку вызывающему коду.

Подробнее: [Оплата картой и криптограммой](#оплата-картой-и-криптограммой).

### `getPaymentMethod(method:opts:)`

Возвращает flow для выбранного альтернативного метода оплаты.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `method` | `AltPayMethod` | Да | Метод: `FasterPayments`, `SberPay`, `AlfaPay`, `TPay`. |
| `opts` | `AltRequestOpts` | Нет | Начальные параметры получения ссылок: `webview`, `puid`. |

Выход: `AltPayFlow`, фактически один из `FasterPaymentsFlow`, `SberPayFlow` или `GenericAltFlow`.

Сетевого запроса на этом этапе нет. SDK ищет метод в `intent.data.paymentMethods`.

Пример:

```swift
let tPay = try await intent.getPaymentMethod(method: .tPay)
let link = try await tPay.getLink()
```

Если метод отсутствует в `intent.data.paymentMethods`, SDK бросает `YPError(message: "getPaymentMethod: method <type> not present in intent")`.

### `getFasterPaymentsFlow(opts:)`

Удобный метод для СБП/Faster Payments.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `opts` | `AltRequestOpts` | Нет | Начальные параметры получения ссылки. |

Выход: `FasterPaymentsFlow` с массивом банков `banks`.

Пример:

```swift
let sbp = try await intent.getFasterPaymentsFlow()
let link = try await sbp.getLink()

if let bank = sbp.banks.first {
    let bankLink = try await sbp.getLink(opts: AltLinkOpts(schema: bank.schema))
}
```

### `getSberPayFlow(opts:)`

Удобный метод для SberPay.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `opts` | `AltRequestOpts` | Нет | Начальные параметры получения ссылки. |

Выход: `SberPayFlow`.

Пример:

```swift
let sberPay = try await intent.getSberPayFlow()
let link = try await sberPay.getLink()
try await sberPay.sendSms(phone: "79990000000")
```

### `waitForResult(opts:)`

Опрашивает статус до успешного/истекшего состояния intent, declined transaction с matching `puid` или timeout.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `opts` | `WaitForResultOpts` | Нет | Интервал polling, timeout и optional `puid` текущей попытки оплаты. |

Выход: `WaitForResultStatus`.

Сетевой вызов: повторяет `GET api/intent/{id}/status/`.

`waitForResult` возвращает `.success` или `.expired` по backend intent status. `.declined` возвращается, если в status response есть transaction со `status == "DECLINED"` и matching непустым `puid` из `WaitForResultOpts`.

Пример:

```swift
let altPaymentPuid = UUID().uuidString.lowercased()
let status = try await intent.waitForResult(
    opts: WaitForResultOpts(intervalMs: 3000, timeoutMs: 600_000, puid: altPaymentPuid)
)
```

`WaitForResultOpts`:

| Поле | Тип | Значение в `WaitForResultOpts()` | Эффективное значение в `waitForResult()` | Описание |
|---|---|---|---|---|
| `intervalMs` | `Int64?` | `nil` | `3000` | Период опроса (по умолчанию 3 секунды) |
| `timeoutMs` | `Int64?` | `nil` | `600_000` | Общий таймаут (по умолчанию 10 минут) |
| `puid` | `String?` | `nil` | `nil` | PUID текущей alt-payment попытки. Если не передан, declined transaction не считается финальным результатом polling. |

При matching declined transaction SDK возвращает `.declined` и отправляет `.error` с сообщением `payment declined (transaction N)`, если id transaction есть, иначе `payment declined`. При timeout SDK бросает `YPError(message: "pollUntil: timeout")`.

### `create3dsView(result:)`

Создает `ThreeDsView` из результата оплаты, если результат требует 3DS.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `result` | `PayResult` | Да | Должен быть `.threeDsRequired(threeDsUrl:)`. |

Выход: `ThreeDsView`.

Сетевого запроса при создании view нет.

Если передать не `.threeDsRequired`, SDK бросает `YPError(message: "create3dsView: 3DS result required")`.

### `create3dsView(threeDsUrl:)`

Создает `ThreeDsView` напрямую по URL 3DS.

| Входной параметр | Тип | Обязательный | Описание |
|---|---|---:|---|
| `threeDsUrl` | `String` | Да | URL страницы 3DS, полученный от backend. |

Выход: `ThreeDsView`.

Этот метод полезен, если URL 3DS был сохранен или передан в приложение отдельно.

## Оплата Картой И Криптограммой

### `CardData`

```swift
public struct CardData: CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    public let pan: String
    public let expMonth: String
    public let expYear: String
    public let cvv: String

    public init(pan: String, expMonth: String, expYear: String, cvv: String)
}
```

| Поле | Тип | Описание |
|---|---|---|
| `pan` | `String` | Полный номер карты. |
| `expMonth` | `String` | Месяц окончания срока действия, обычно `MM`. |
| `expYear` | `String` | Год окончания срока действия, обычно `YY`. |
| `cvv` | `String` | CVV/CVC, обычно 3-4 цифры. |

Строковое и debug-представление `CardData` маскирует PAN, срок действия, CVV и ID текущего интента. Не логируйте PAN, CVV, Intent.ID и криптограммы.

### `PayInput`

```swift
public enum PayInput: Sendable {
    case card(CardData)
    case cryptogram(String)
}
```

| Case | Вход | Описание |
|---|---|---|
| `.card` | `CardData` | SDK получает RSA public key, формирует криптограмму и отправляет оплату. |
| `.cryptogram` | `String` | SDK отправляет готовую Base64-криптограмму, сформированную вне SDK. |

### `PayResult`

```swift
public enum PayResult: Sendable {
    case authorized(IntentStatusResponse)
    case threeDsRequired(threeDsUrl: String)
}
```

| Case | Выходные данные | Описание |
|---|---|---|
| `.authorized` | `IntentStatusResponse` | Оплата авторизована без дополнительного 3DS. |
| `.threeDsRequired` | `threeDsUrl: String` | Требуется 3DS. Нужно создать и показать `ThreeDsView`. |

Пример оплаты картой:

```swift
let result = try await intent.pay(input: .card(
    CardData(pan: "4242424242424242", expMonth: "12", expYear: "29", cvv: "123")
))

switch result {
case .authorized(let response):
    print(response.intent.status)

case .threeDsRequired(let threeDsUrl):
    print("3DS required:", threeDsUrl)
}
```

Пример оплаты готовой криптограммой:

```swift
let result = try await intent.pay(input: .cryptogram("<merchant-built-card-cryptogram>"))
```

По OpenAPI запрос оплаты картой содержит `paymentMethod = Card` и `cryptogram`, а ответом может быть `200` с `IntentStatusResponse` или `202` с `threeDsUrl`.

## 3DS

3DS API доступен при наличии UIKit и WebKit.

### `ThreeDsView`

```swift
public typealias ThreeDsContainerView = UIView

public final class ThreeDsView: @unchecked Sendable {
    @MainActor public private(set) var webView: WKWebView?
    @MainActor public var results: AsyncStream<ThreeDsResult> { get }

    @discardableResult
    @MainActor
    public func mount(into container: ThreeDsContainerView) -> ThreeDsView

    @MainActor public func unmount()
    @MainActor public func destroy()
}
```

| Метод или свойство | Вход | Выход | Описание |
|---|---|---|---|
| `webView` | Нет | `WKWebView?` | Текущий web view, созданный SDK после `mount`. |
| `results` | Нет | `AsyncStream<ThreeDsResult>` | Поток результатов 3DS. Новый подписчик получает последний результат, если он уже был. |
| `mount(into:)` | `UIView` | `ThreeDsView` | Создает `WKWebView`, добавляет его в контейнер, загружает 3DS URL, включает JS bridge с проверкой origin и fallback polling. |
| `unmount()` | Нет | `Void` | Удаляет web view с экрана и отменяет polling. Stream не завершается. |
| `destroy()` | Нет | `Void` | Освобождает web view, отменяет polling и завершает текущих подписчиков `results`. Новый доступ к `results` после `destroy()` создаст новый stream. |

Пример:

```swift
let result = try await intent.pay(input: .card(cardData))

if case .threeDsRequired = result {
    let threeDsView = try intent.create3dsView(result: result)

    await MainActor.run {
        threeDsView.mount(into: containerView)
    }

    Task {
        for await result in await threeDsView.results {
            switch result.status {
            case .success:
                print("3DS success", result.intentStatus as Any)
            case .failure:
                print("3DS failure", result.code as Any, result.intentStatus as Any)
            }
        }
    }
}
```

### `ThreeDsResult`

```swift
public struct ThreeDsResult: Sendable, Equatable {
    public enum Status: String, Sendable {
        case success = "SUCCESS"
        case failure = "FAILURE"
    }

    public let status: Status
    public let code: String?
    public let intentStatus: IntentStatus?

    public init(status: Status, code: String? = nil, intentStatus: IntentStatus? = nil)
}
```

| Поле | Тип | Описание |
|---|---|---|
| `status` | `ThreeDsResult.Status` | `.success` или `.failure`. |
| `code` | `String?` | Код из JS message 3DS страницы. `"0"` означает success, другой непустой код означает failure. |
| `intentStatus` | `IntentStatus?` | Статус intent, если SDK смог его определить. |

SDK принимает JS message 3DS только от разрешенного origin, полученного из внутренней API-конфигурации. Fallback polling внутри 3DS проверяет статус каждые 3 секунды. `.success` завершает 3DS успешно, `.expired` или новая declined transaction завершают 3DS ошибкой. JS message с non-zero code возвращает failure без синтетического `IntentStatus`.

## Альтернативные Методы Оплаты

### `AltPayMethod`

```swift
public enum AltPayMethod: String, CaseIterable, Sendable {
    case fasterPayments = "FasterPayments"
    case sberPay = "SberPay"
    case alfaPay = "AlfaPay"
    case tPay = "TPay"

    public var type: String { get }
    public static func fromType(_ type: String) -> AltPayMethod?
}
```

| API | Вход | Выход | Описание |
|---|---|---|---|
| `type` | Нет | `String` | Raw строка метода для API. |
| `fromType(_:)` | `String` | `AltPayMethod?` | Преобразует raw строку backend в enum SDK. |

### `AltRequestOpts`

```swift
public struct AltRequestOpts: Sendable {
    public let webview: Bool
    public let puid: String?
    public init(webview: Bool = false, puid: String? = nil)
}
```

| Поле | Тип | Значение по умолчанию | Описание |
|---|---|---|---|
| `webview` | `Bool` | `false` | Передается в запрос ссылки как `webview=true`, если ссылку нужно открыть в webview-сценарии. |
| `puid` | `String?` | `nil` | Payment User ID. По OpenAPI: UUID v4/v6 строка длиной 1-36, backend проверяет UUID regex. |

### `AltLinkOpts`

```swift
public struct AltLinkOpts: Sendable {
    public let webview: Bool
    public let puid: String?
    public let schema: String?
    public init(webview: Bool = false, puid: String? = nil, schema: String? = nil)
}
```

| Поле | Тип | Значение по умолчанию | Описание |
|---|---|---|---|
| `webview` | `Bool` | `false` | Параметр открытия ссылки. Объединяется с `AltRequestOpts.webview` через OR. |
| `puid` | `String?` | `nil` | PUID для конкретного запроса ссылки. Имеет приоритет над `AltRequestOpts.puid`. |
| `schema` | `String?` | `nil` | Схема банка для СБП. Берется из `SbpBank.schema`. |

### `AltPayFlow`

```swift
public class AltPayFlow {
    public let method: AltPayMethod
    public let link: String?

    public func getImage() -> String
    public func getLink(opts: AltLinkOpts = AltLinkOpts()) async throws -> String
}
```

| API | Вход | Выход | Описание |
|---|---|---|---|
| `method` | Нет | `AltPayMethod` | Метод оплаты flow. |
| `link` | Нет | `String?` | Ссылка из `PaymentMethodDto.link` или первый deep link из `PaymentMethodDto.deepLinks`, если backend вернул эти поля в intent. |
| `getImage()` | Нет | `String` | URL картинки метода или пустая строка. |
| `getLink(opts:)` | `AltLinkOpts` | `String` | Запрашивает свежую ссылку/deeplink для оплаты. |

Сетевой вызов `getLink` в текущей реализации SDK: `GET api/intent/alt/{id}/link/{method}/` с query параметрами `webview`, `puid`, `schema`.

Примечание по контракту: `docs/openapi.json.txt` описывает AltPay endpoint как `/alt/{uuid}/{view}/{method}/`. Этот раздел фиксирует именно поведение текущего SDK; при ручной интеграции с backend сверяйте актуальный server contract.

После открытия external app, deeplink или web flow приложение мерчанта должно вызвать `getStatus()` или `waitForResult()`.
Для alt-payment попыток рекомендуется сгенерировать client-side `puid`, передать его в `AltRequestOpts`/`AltLinkOpts`, а затем использовать тот же `puid` в `WaitForResultOpts`, чтобы declined transaction относился только к этой попытке.

### `FasterPaymentsFlow`

```swift
public final class FasterPaymentsFlow: AltPayFlow {
    public let banks: [SbpBank]
}
```

Дополнительный выход: `banks` со списком банков СБП.

Пример:

```swift
let sbp = try await intent.getFasterPaymentsFlow()

if let bank = sbp.banks.first {
    let link = try await sbp.getLink(opts: AltLinkOpts(schema: bank.schema))
}
```

### `SberPayFlow`

```swift
public final class SberPayFlow: AltPayFlow {
    public func sendSms(phone: String) async throws
}
```

| Метод | Вход | Выход | Описание |
|---|---|---|---|
| `sendSms(phone:)` | `String` | `Void` | Отправляет телефон для SberPay SMS/app flow. По OpenAPI формат телефона: `79XXXXXXXXX`. |

Сетевой вызов: `POST api/intent/{id}/send-sms/`.

Пример:

```swift
let sberPay = try await intent.getSberPayFlow()
try await sberPay.sendSms(phone: "79990000000")
```

### `GenericAltFlow`

```swift
public final class GenericAltFlow: AltPayFlow {}
```

Используется для `AlfaPay`, `TPay`, которым не нужен специализированный subclass.

## Статусы, Polling И События

### `IntentStatus`

```swift
public enum IntentStatus: String, Codable, Sendable {
    case requiresPaymentData = "RequiresPaymentData"
    case requiresPaymentMethod = "RequiresPaymentMethod"
    case expired = "Expired"
    case success = "Success"

    public static func from(_ raw: String) -> IntentStatus
    public var isTerminal: Bool { get }
}
```

| API | Вход | Выход | Описание |
|---|---|---|---|
| `from(_:)` | `String` | `IntentStatus` | Преобразует raw status backend. Legacy `Pending` становится `.requiresPaymentData`, неизвестное значение становится `.requiresPaymentData`. |
| `isTerminal` | Нет | `Bool` | `true` для `.success`, `.expired`; `false` для `.requiresPaymentData`, `.requiresPaymentMethod`. |

`getStatus()` отражает backend intent status mapping. Если нужен raw status response с транзакциями, используйте `getStatusDetails()` и `IntentStatus.from(response.intent.status)`. Declined transactions не меняют результат `getStatus()` глобально; они учитываются только в `waitForResult(opts:)` при matching непустом `puid`.

### `WaitForResultStatus`

```swift
public enum WaitForResultStatus: String, Codable, Sendable {
    case requiresPaymentData = "RequiresPaymentData"
    case requiresPaymentMethod = "RequiresPaymentMethod"
    case expired = "Expired"
    case success = "Success"
    case declined = "Declined"
}
```

`waitForResult(opts:)` продолжает polling на `.requiresPaymentData` и `.requiresPaymentMethod` до `.success`, `.expired`, `.declined` или timeout.

### `IntentStatusResponse`

```swift
public struct IntentStatusData: Codable, Sendable {
    public let status: String
    public init(status: String)
}

public struct IntentStatusResponse: Codable, Sendable {
    public let intent: IntentStatusData
    public let transactions: [YPJSONObject]
    public init(intent: IntentStatusData, transactions: [YPJSONObject] = [])
    public init(from decoder: Decoder) throws
}
```

| Поле | Тип | Описание |
|---|---|---|
| `intent.status` | `String` | Raw статус intent из backend. |
| `transactions` | `[YPJSONObject]` | Список связанных transaction. Отсутствующий массив декодируется как `[]`. |

### `IntentEvent`

```swift
public enum IntentEvent {
    case update(PaymentIntent)
    case statusChange(IntentStatus)
    case success(PayResult)
    case error(Error)
}
```

| Событие | Данные | Когда отправляется |
|---|---|---|
| `.update` | `PaymentIntent` | После успешного `update(changes:)`. |
| `.statusChange` | `IntentStatus` | Когда resolved статус изменился после `getStatus`, `pay`, `waitForResult` или 3DS. |
| `.success` | `PayResult` | После успешной авторизации, успешного терминального polling или успешного 3DS. |
| `.error` | `Error` | После ошибок оплаты, declined/expired результата polling или неуспешного 3DS. |

Пример:

```swift
Task {
    for await event in intent.events {
        switch event {
        case .update(let intent):
            print(await intent.data)
        case .statusChange(let status):
            print("Status changed:", status)
        case .success(let result):
            print("Payment success:", result)
        case .error(let error):
            print("Payment error:", error)
        }
    }
}
```

Ошибки сетевых/status запросов и timeout `waitForResult()` пробрасываются вызывающему коду. Они попадают в `events` только для flow, который явно отправляет событие.

## Публичные Модели

### `IntentResponse`

```swift
public struct IntentResponse: Codable, Sendable {
    public let id: String
    public var status: String
    public let secret: String
    public let createdAt: Int64
    public let updatedAt: Int64
    public let expiredAt: Int64
    public let merchantCode: String
    public let amount: Int64
    public let currency: String
    public let messageScheme: String
    public let description: String?
    public let receiptEmail: String?
    public let tokenize: Bool?
    public let paymentMethods: [PaymentMethodDto]?
    public let terminalInfo: TerminalInfoDto?
    public internal(set) var transactions: [YPJSONObject]?

    public init(
        id: String,
        status: String,
        secret: String = "",
        createdAt: Int64 = 0,
        updatedAt: Int64 = 0,
        expiredAt: Int64 = 0,
        merchantCode: String = "",
        amount: Int64 = 0,
        currency: String = "",
        messageScheme: String = "",
        description: String? = nil,
        receiptEmail: String? = nil,
        tokenize: Bool? = nil,
        paymentMethods: [PaymentMethodDto]? = nil,
        terminalInfo: TerminalInfoDto? = nil,
        transactions: [YPJSONObject]? = nil
    )

    public init(from decoder: Decoder) throws
}
```

| Поле | Тип | Описание |
|---|---|---|
| `id` | `String` | UUID intent. |
| `status` | `String` | Raw статус intent. SDK может обновлять поле после status-запросов. |
| `secret` | `String` | Secret intent для защищенных операций. Не логируйте и не раскрывайте его без необходимости. |
| `createdAt` | `Int64` | Timestamp создания. |
| `updatedAt` | `Int64` | Timestamp последнего обновления. |
| `expiredAt` | `Int64` | Timestamp истечения intent. |
| `merchantCode` | `String` | Публичный идентификатор терминала мерчанта. |
| `amount` | `Int64` | Сумма в минорных единицах валюты. |
| `currency` | `String` | Код валюты. |
| `messageScheme` | `String` | Схема списания. |
| `description` | `String?` | Описание платежа. |
| `receiptEmail` | `String?` | Email для чека. |
| `tokenize` | `Bool?` | Флаг токенизации. |
| `paymentMethods` | `[PaymentMethodDto]?` | Методы оплаты, доступные для intent. |
| `terminalInfo` | `TerminalInfoDto?` | Информация терминала для отображения логотипа и рекламного баннера, если backend вернул эти данные. |
| `transactions` | `[YPJSONObject]?` | Связанные transaction. Публично читается, внутри SDK обновляется после status-запросов. |

### `TerminalInfoDto`

```swift
public struct TerminalInfoDto: Codable, Sendable {
    public let logoUrl: String?
    public let displayAdvertiseBannerOnWidget: Bool?
    public let bannerImage: String?
    public let bannerLink: String?

    public init(
        logoUrl: String? = nil,
        displayAdvertiseBannerOnWidget: Bool? = nil,
        bannerImage: String? = nil,
        bannerLink: String? = nil
    )
}
```

| Поле | Тип | Описание |
|---|---|---|
| `logoUrl` | `String?` | URL логотипа терминала. |
| `displayAdvertiseBannerOnWidget` | `Bool?` | Нужно ли отображать рекламный баннер widget/checkout. |
| `bannerImage` | `String?` | URL изображения рекламного баннера. |
| `bannerLink` | `String?` | URL перехода по рекламному баннеру. |

### `PaymentMethodDto`

```swift
public struct PaymentMethodDto: Codable, Sendable {
    public let type: String
    public let group: String?
    public let link: String?
    public let deepLinks: [String]?
    public let image: String?
    public let banks: [SbpBank]?
    public let capabilities: [PaymentMethodCapability]?
    public let primary: Bool?

    public init(
        type: String,
        group: String? = nil,
        link: String? = nil,
        deepLinks: [String]? = nil,
        image: String? = nil,
        banks: [SbpBank]? = nil,
        capabilities: [PaymentMethodCapability]? = nil,
        primary: Bool? = nil
    )

    public init(from decoder: Decoder) throws
}
```

| Поле | Тип | Описание |
|---|---|---|
| `type` | `String` | Тип метода оплаты, например `Card`, `FasterPayments`, `SberPay`. |
| `group` | `String?` | Группа метода, если backend ее вернул. |
| `link` | `String?` | Ссылка для оплаты. |
| `deepLinks` | `[String]?` | Список deeplink схем для оплаты, например для SberPay. |
| `image` | `String?` | URL изображения метода. |
| `banks` | `[SbpBank]?` | Банки для СБП. |
| `capabilities` | `[PaymentMethodCapability]?` | Возможности метода. Неизвестные capability игнорируются при декодировании. |
| `primary` | `Bool?` | Признак основного метода оплаты, если backend его вернул. |

### `PaymentMethodCapability`

```swift
public enum PaymentMethodCapability: String, Codable, Sendable, Hashable {
    case international = "international"
    case domestic = "domestic"
}
```

| Case | Описание |
|---|---|
| `.international` | Метод поддерживает international card capability. |
| `.domestic` | Метод поддерживает domestic card capability. |

Пример проверки карты:

```swift
let data = await intent.data
let cardMethod = data.paymentMethods?.first { $0.type == "Card" }
let capabilities = Set(cardMethod?.capabilities ?? [])

if capabilities.contains(.domestic), capabilities.contains(.international) {
    print("Принимаем карты любой страны")
}
```

### `SbpBank`

```swift
public struct SbpBank: Codable, Sendable {
    public let bankName: String
    public let logoUrl: String?
    public let schema: String
    public let webClientUrl: String?
    public let isWebClientActive: Bool?
    public let packageName: String?

    public init(
        bankName: String,
        logoUrl: String? = nil,
        schema: String,
        webClientUrl: String? = nil,
        isWebClientActive: Bool? = nil,
        packageName: String? = nil
    )
}
```

| Поле | Тип | Описание |
|---|---|---|
| `bankName` | `String` | Название банка. |
| `logoUrl` | `String?` | URL логотипа. Декодируется из `logoURL`. |
| `schema` | `String` | Схема банка для генерации СБП-ссылки. |
| `webClientUrl` | `String?` | Web URL банка, если доступен. |
| `isWebClientActive` | `Bool?` | Признак доступности web client. |
| `packageName` | `String?` | Package name приложения банка. Декодируется из `packageName`. |

### `BinInfo`

```swift
public struct BinInfo: Codable, Sendable {
    public let cardType: String?
    public let countryCode: String?
    public let bankId: Int?
    public let bankName: String?

    public init(cardType: String? = nil, countryCode: String? = nil, bankId: Int? = nil, bankName: String? = nil)
    public init(from decoder: Decoder) throws
    public func encode(to encoder: Encoder) throws
}
```

| Поле | Тип | Описание |
|---|---|---|
| `cardType` | `String?` | Тип карты, например `Visa`. |
| `countryCode` | `String?` | Код страны. SDK умеет декодировать строку или число и приводит число к строке. |
| `bankId` | `Int?` | Идентификатор банка. |
| `bankName` | `String?` | Название банка. |

### `YPJSONObject` И `YPJSONValue`

```swift
public typealias YPJSONObject = [String: YPJSONValue]

public enum YPJSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: YPJSONValue])
    case array([YPJSONValue])
    case null

    public init(from decoder: Decoder) throws
    public func encode(to encoder: Encoder) throws
}
```

Используется для opaque JSON payload, например в `IntentStatusResponse.transactions` и `IntentResponse.transactions`.

`init(from:)` и `encode(to:)` в Codable-моделях являются protocol methods. Обычно merchant-код не вызывает их напрямую, но они доступны при работе с `JSONDecoder` и `JSONEncoder`.

### `YPError`

```swift
public struct YPError: Error, LocalizedError {
    public let message: String
    public let cause: Error?

    public init(message: String, cause: Error? = nil)
    public var errorDescription: String? { get }
}
```

| Поле | Тип | Описание |
|---|---|---|
| `message` | `String` | Человекочитаемое сообщение SDK или backend. |
| `cause` | `Error?` | Исходная ошибка, например network/decoding/HTTP cause. |
| `errorDescription` | `String?` | Возвращает `message`. |

## Ошибки

SDK может бросать `YPError`, `CancellationError` и ошибки нижнего уровня, завернутые в `YPError.cause`.

Типовой pattern:

```swift
do {
    let result = try await intent.pay(input: .card(cardData))
} catch let error as YPError {
    print(error.message)
    print(error.cause as Any)
} catch is CancellationError {
    print("Cancelled")
} catch {
    print(error)
}
```

Частые сообщения:

| Сообщение | Когда возникает |
|---|---|
| `getBinInfo: bin must contain exactly 6 digits` | BIN после нормализации не содержит ровно 6 цифр. |
| `update: no editable fields provided` | В `UpdateChanges` не передано ни одного поля. |
| `getPaymentMethod: method <type> not present in intent` | Метод оплаты отсутствует в `intent.data.paymentMethods`. |
| `create3dsView: 3DS result required` | В `create3dsView(result:)` передан не `.threeDsRequired`. |
| `pollUntil: timeout` | `waitForResult()` не дождался терминального статуса. |
| `payment expired` | Polling завершился `.expired`. |
| `3DS failed` | 3DS завершился неуспешно. |
| `invalid response` | Ответ backend не удалось декодировать или распознать. |
| `network error` | Ошибка сети или не HTTP response. |
| `HTTP <statusCode>` | Backend вернул не 2xx и не прислал понятное message. |

## Соответствие Endpoint

Эти endpoint являются деталями реализации текущего SDK, но помогают понять, какие сетевые вызовы выполняют публичные методы. Если OpenAPI и SDK расходятся, приоритет для мобильного приложения имеет поведение установленной версии SDK, а для backend-интеграции нужно сверить актуальный server contract.

| Public API | Endpoint |
|---|---|
| `YP.createIntent` | `POST api/intent/` |
| `YP.getIntent` | `GET api/intent/{id}/` |
| `PaymentIntent.update` | `PATCH api/intent/{id}/` |
| `PaymentIntent.getStatus` | `GET api/intent/{id}/status/` |
| `PaymentIntent.getStatusDetails` | `GET api/intent/{id}/status/` |
| `PaymentIntent.getBinInfo` | `GET api/intent/{id}/bin-info/{bin}/` |
| `PaymentIntent.pay(input: .card(...))` | `GET api/intent/pay/key/`, затем `POST api/intent/{id}/pay/` |
| `PaymentIntent.pay(input: .cryptogram(...))` | `POST api/intent/{id}/pay/` |
| `AltPayFlow.getLink` | `GET api/intent/alt/{id}/link/{method}/` |
| `SberPayFlow.sendSms` | `POST api/intent/{id}/send-sms/` |

## Миграция От Старого Public API

Текущий SDK не экспортирует старый UI-oriented API: `PaymentConfiguration`, старый `PaymentIntent` как `ObservableObject`, `PaymentData`, `PaymentDelegate`, `PaymentUIDelegate`, public payment UI helpers, `YourpaymentsApi` и отдельный product `YourpaymentsNetworking`.

Новый public контракт строится вокруг `YP`, `PaymentIntent`, `CardData`, `PayInput`, `PayResult`, `ThreeDsView` и AltPay flow моделей.
