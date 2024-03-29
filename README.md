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

Your host code must provide a catalog of known product identifiers. This is an array of Strings, just as if you were using StoreKit 2 directly.

At runtime, the final set of products made available for purchase is the intersection of this array and the list of active products on App Store Connect. See [`Product.products(for:)`](https://developer.apple.com/documentation/storekit/product/3851116-products) for details.

### Callback Model

`Store` defines a delegate protocol, `StoreDelegate`, whose methods are:

```swift
func storeDidUpdatePurchasedProducts(_: Store)
func storeDidReportPurchaseFailure(_: Store, productID: String, error: Error)
func storeDidReportPurchasePending(_: Store, productID: String)
```

`Store` calls these methods whenever a StoreKit `await` call returns.

As with all delegate-based callback models, there must be a single object that receives the delegate calls. You can either provide that receiver object yourself, or you can use the `StoreManager` class, which hosts `Store` with its own delegate implementation.

### Purchased products

Your implementation of `storeDidUpdatePurchasedProducts()` should read one of the following properties to get the updated list of products that the user has purchased:

- `store.purchasedProducts` — provides more detailed information about the purchased products, but _may_ or _may not_ work if the device is offline.

- `store.purchasedProductIdentifiers`  — works offline using StoreKit’s cached list of identifiers, so your users have access to their purchased products in Airplane Mode.


## StoreManager

The `StoreManager` class places another layer of abstraction between your code and the underlying IAP store.

Code that uses `StoreManager` needs to provide an `enum` of product identifiers and needs to observe Notification Center notifications.

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

### Properties
#### openForBusiness

Remember that the underlying StoreKit code is asynchronous. It has to connect to the App Store and download the list of products and transactions before it can be considered fully initialized.

`StoreManager` exposes a property, `openForBusiness`, that indicates whether initialization has completed.

Do not try to make any purchases or query any product’s purchase status until `openForBusiness` becomes `true`. Otherwise, StoreKit won’t have the information needed to complete the request. Debug builds assert this requirement.

This property is not observable using KVO or Combine. Instead, wait for the first broadcast of `StoreManager.updatedPurchasesNotification`, which indicates that the store is open for business.

#### shelvesStocked

The `shelvesStocked` property indicates whether the Store has any products available. This may be `false` if the device is offline or if your App Store Connect account has no In-App Purchase products defined.

Use this property as a hint for hiding your shopping cart icon or other store UI if there isn’t anything for the user to purchase.

Note: even if `shelvesStocked` is false, the user may have purchased products in the past. You should still check whether `purchaseStatus(for:)` returns `.hasPurchased` when deciding whether to unlock the relevant functionality at runtime.

#### canMakePurchases

The `canMakePurchases` property indicates whether the user is restricted from making purchases on the App Store. This may be the result of parental controls or a managed-device policy. See the StoreKit documentation for more information.

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

This code was developed to support [non-consumable](https://developer.apple.com/documentation/storekit/product/producttype/3749424-nonconsumable) In-App Purchases.

It _may_ or _may not_ work with other [product types](https://developer.apple.com/documentation/storekit/product/producttype), and has not been tested in those use cases.

If changes are required to support other types of IAPs, please submit a pull request.

## Reading

StoreKit 2:

https://developer.apple.com/storekit/

Swift Concurrency and `async` / `await`:

https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
