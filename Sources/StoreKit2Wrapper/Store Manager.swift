//
//  Store Manager.swift
//

import Foundation

public class StoreManager<ProductID: CaseIterable & RawRepresentable & Hashable> where ProductID.RawValue == String {

    public typealias ProductInfo = (displayName: String, description: String, displayPrice: String)

    public enum PurchaseStatus {
        case hasPurchased
        case canPurchase
        case purchasePending
        case notAvailable
    }

    public let updatedPurchasesNotification = Foundation.Notification.Name("StoreManager.updatedPurchasesNotification")
    public let purchaseFailedNotification = Foundation.Notification.Name("StoreManager.purchaseFailedNotification")
    public let purchasePendingNotification = Foundation.Notification.Name("StoreManager.purchasePendingNotification")
    public let errorKeyName = "Error"
    public let productIDKeyName = "Product ID"

    public private(set) var openForBusiness = false

    public var canMakePurchases: Bool {
        return Store.canMakePurchases
    }

    public init() {
        let productIdentifiers = ProductID.allCases.map { $0.rawValue }
        store = Store(productIdentifiers: productIdentifiers, delegate: self)
    }

    // MARK: - Binding

    public func observeChanges(using block: @escaping (Foundation.Notification) -> Void) -> NSObjectProtocol {
        return notificationCenter.addObserver(forName: nil, object: self, queue: .current!, using: block)
    }

    public func stopObservingChanges(observer: NSObjectProtocol) {
        notificationCenter.removeObserver(observer)
    }

    // MARK: - Purchases

    public func purchaseStatus(for product: ProductID) -> PurchaseStatus {
        assert(openForBusiness, "IAP StoreManager: Do not call purchaseStatus() until the Store is open for business.")

        guard canMakePurchases else {
            return .notAvailable
        }

        return purchased[product] ?? .notAvailable
    }

    public func purchase(_ productID: ProductID) {
        assert(openForBusiness, "IAP StoreManager: Do not call purchase() until the Store is open for business.")
        store.purchase(productID.rawValue)
    }

    public func productInfo(for productID: ProductID) -> ProductInfo? {
        assert(openForBusiness, "IAP StoreManager: Do not call productInfo() until the Store is open for business.")
        guard let product = store.availableProducts.first(where: { $0.id == productID.rawValue } ) else {
            return nil
        }

        return (displayName: product.displayName, description: product.description, displayPrice: product.displayPrice)
    }

    public func restorePurchases() {
        store.sync()
    }
    
    // MARK: - Private properties

    private var purchased: [ProductID : PurchaseStatus] = [:]
    private var store: Store! = nil
    private let notificationCenter = NotificationCenter.default

}


extension StoreManager: StoreDelegate {

    public func storeDidUpdatePurchasedProducts(_ store: Store) {
        purchased = [:]

        for product in store.availableProducts {
            guard let productID = ProductID(rawValue: product.id) else { continue }
            purchased[productID] = .canPurchase
        }

        for product in store.purchasedProducts {
            guard let productID = ProductID(rawValue: product.id) else { continue }
            purchased[productID] = .hasPurchased
        }

        openForBusiness = true

        print("IAP StoreManager: Finished refreshing purchases; posting notification.")
        notificationCenter.post(name: updatedPurchasesNotification, object: self, userInfo: nil)
    }

    public func storeDidReportPurchaseFailure(_ store: Store, productID: String, error: Error) {
        let userInfo: [String : Any] = [
            errorKeyName : error,
            productIDKeyName : productID
        ]

        notificationCenter.post(name: purchaseFailedNotification, object: self, userInfo: userInfo)
    }

    public func storeDidReportPurchasePending(_: Store, productID: String) {
        guard let productID = ProductID(rawValue: productID) else { return }

        purchased[productID] = .purchasePending

        let userInfo: [String : Any] = [
            productIDKeyName : productID
        ]

        notificationCenter.post(name: purchasePendingNotification, object: self, userInfo: userInfo)
    }

}
