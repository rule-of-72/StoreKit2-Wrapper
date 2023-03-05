# StoreKit2-Wrapper

Swift Package for using StoreKit 2 with delegates and notifications instead of async/await.

## Background

Apple’s new [**StoreKit 2 SDK**](https://developer.apple.com/storekit/) greatly simplifies the programming model for In-App Purchases compared to the original StoreKit, but it requires that you adopt [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/) and use `async` / `await` to call its APIs.

Many Swift apps have years of tested, mature code that uses more traditional asynchronous paradigms, such as delegate protocols and [Notification Center](https://developer.apple.com/documentation/foundation/notificationcenter) observers.

Even though `async` / `await` is awesome, it can be hard to introduce a new paradigm into your code and get it to play nicely with what you’ve already got.

The **📦 StoreKit 2 Wrapper** package takes care of calling StoreKit 2’s `async` APIs for you, then informs you of the result using a delegate or notifications.

## Usage

Add the **📦 StoreKit 2 Wrapper** package as a Package Dependency in your Xcode project settings.

Add the **🏛️ StoreKit2-Wrapper** library under *Frameworks, Libraries, and Embedded Content* in your Xcode target’s General settings.

Then `import StoreKit2Wrapper` in your Swift source files, wherever you need to interact with In-App Purchases.

The package has two classes: `Store` and `StoreManager`.

## Store

The `Store` class wraps the StoreKit 2 API directly.

Code that uses `Store` needs to provide an array of product identifiers and an implementation of `StoreDelegate`.

### Product Identifiers

Your host code must provide a catalog of known product identifiers as an array of Strings, just as if you were using StoreKit 2 directly.

The final set of products made available for purchase are the intersection of this catalog and the list of active products on App Store Connect at the time the app is running. See [`Product.products(for:)`](https://developer.apple.com/documentation/storekit/product/3851116-products) for details.

### Callback Model

`Store` defines a delegate protocol, `StoreDelegate`, whose methods are:

```swift
func storeDidUpdatePurchasedProducts(_: Store)
func storeDidReportPurchaseFailure(_: Store, productID: String, error: Error)
func storeDidReportPurchasePending(_: Store, productID: String)
```

`Store` calls these methods whenever a StoreKit `await` call returns.

Your implementation of `storeDidUpdatePurchasedProducts()` should read the `store.purchasedProducts` property to get the updated list of purchases. 

As with all delegate-based callback models, there must be a single host that receives the delegate calls. You can either provide that host yourself, or you can use the `StoreManager` class, which hosts `Store` with its own delegate implementation.

## StoreManager

The `StoreManager` class places another layer of abstraction between your code and the underlying IAP store.

Code that uses `StoreManager` needs to provide an enum of product identifiers and to observe notifications.

### The Store Manager says: Open for Business!

Remember that the underlying StoreKit code is asynchronous. It has to connect to the App Store and download the list of products and transactions before it can be considered fully initialized.

`StoreManager` exposes a property, `openForBusiness`, that indicates whether initialization has completed.

Do not try to make any purchases or query any product’s purchase status until this property becomes `true`. Otherwise, StoreKit won’t have the information needed to complete the request. Debug builds assert this requirement.

This property is not observable using KVO or Combine. Instead, wait for the first broadcast of `StoreManager.updatedPurchasesNotification`, which indicates that the store is open for business.

### Product Identifiers

Instead of raw strings, `StoreManager` uses an enum that you provide to hold the catalog of known product identifiers.

This allows for better compile-time checking and for the use of `switch` statements.

```swift
enum MyAppProduct: String, CaseIterable {
    case foo = "MyApp.Foo"
    case bar = "MyApp.Bar"
}

typealias MyAppStoreManager = StoreManager<MyAppProduct>
let storeManager = MyAppStoreManager()
```

### Callback Model

`StoreManager` broadcasts any changes to In-App Purchases using Notification Center. The notification names are:

```swift
StoreManager.updatedPurchasesNotification
StoreManager.purchaseFailedNotification
StoreManager.purchasePendingNotification 
```

Any part of your app that needs to know about IAP updates can add an observer. For example, a class that unlocks new features when the user completes a purchase might have code like this:

```swift
init() {
    iapObserver = storeManager.observeChanges() { [weak self] notification in
        guard let self = self else { return }
        self.handleIAPChangeNotification(notification)
    }
}

deinit {
    if let iapObserver = iapObserver {
        storeManager.stopObservingChanges(observer: iapObserver)
    }
}

func handleIAPChangeNotification(_ notification: Notification) {
        switch notification.name {
            case storeManager.updatedPurchasesNotification:
                ⋮

            case storeManager.purchaseFailedNotification:
                ⋮

            case storeManager.purchasePendingNotification:
                ⋮

            default:
                return
        }
    }

private var iapObserver: NSObjectProtocol? = nil
```

## Limitations

This code was developed to support [non-consumable](https://developer.apple.com/documentation/storekit/product/producttype/3749424-nonconsumable) In-App Purchases only.

It may or may not work with other [product types](https://developer.apple.com/documentation/storekit/product/producttype), and has not been tested in those use cases.

Pull request submissions will be considered if changes are required to support other types of IAPs.

## Reading

StoreKit 2:

https://developer.apple.com/storekit/

Swift Concurrency and `async` / `await`:

https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
