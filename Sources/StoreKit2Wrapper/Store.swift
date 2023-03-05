//
//  Store.swift
//

import Foundation
import StoreKit

public protocol StoreDelegate: AnyObject {

    func storeDidUpdatePurchasedProducts(_: Store)
    func storeDidReportPurchaseFailure(_: Store, productID: String, error: Error)
    func storeDidReportPurchasePending(_: Store, productID: String)

}

public class Store {

    // MARK: - Public properties

    public weak var delegate: StoreDelegate? = nil
    public private(set) var availableProducts: [Product] = []
    public private(set) var purchasedProducts: [Product] = []

    public static var canMakePurchases: Bool {
        return AppStore.canMakePayments
    }

    // MARK: - Initialization
    
    public init(productIdentifiers: [String], delegate: StoreDelegate? = nil) {
        self.productIdentifiers = productIdentifiers
        self.delegate = delegate
        newTransactionHandler = Task.detached(operation: receiveNewTransactions)

        Task {
            await requestAvailableProducts()
            await refreshPurchasedProducts()
        }
    }

    deinit {
        newTransactionHandler?.cancel()
    }

    // MARK: - Public methods

    public func purchase(_ productID: String) {
        guard let product = availableProducts.first(where: { $0.id == productID } ) else {
            print("IAP Store: Attempted to purchase product that's not in the current catalog.")
            return
        }

        Task {
            do {
                let purchaseResult = try await product.purchase()
                switch purchaseResult {
                    case .success(let verificationResult):
                        switch verificationResult {
                            case .verified(let transaction):
                                print("IAP Store: Purchase succeeded for product \(transaction.productID)")
                                await transaction.finish()
                                await refreshPurchasedProducts()

                            case .unverified(_, let error):
                                throw error
                        }

                    case .userCancelled:
                        print("IAP Store: Purchase cancelled for product '\(productID)'")

                    case .pending:
                        print("IAP Store: Purchase pending for product '\(productID)'")
                        delegate?.storeDidReportPurchasePending(self, productID: productID)

                    @unknown default:
                        break
                }
            } catch {
                print("IAP Store: Purchase failed for product '\(productID)', error:\n\(error)")
                delegate?.storeDidReportPurchaseFailure(self, productID: productID, error: error)
            }
        }
    }

    public func sync() {
        Task {
            do {
                print("IAP Store: Starting AppStore sync (restoring previous purchases).")
                try await AppStore.sync()
                print("IAP Store: Finished AppStore sync (restoring previous purchases).")

                await requestAvailableProducts()
                await refreshPurchasedProducts()
            } catch {
                print("IAP Store: AppStore sync failed. Error:\n\(error)")
            }
        }
    }

    // MARK: - Private methods

    @Sendable
    private func receiveNewTransactions() async {
        for await result in Transaction.updates {
            print("IAP Store: Processing update")

            guard case .verified(let transaction) = result else {
                print("IAP Store: Transaction failed verification; skipping")
                continue
            }

            await transaction.finish()
            await self.refreshPurchasedProducts()
        }
    }

    private func requestAvailableProducts() async {
        do {
            availableProducts = try await Product.products(for: productIdentifiers)
            print("IAP Store: Product catalog fetched from App Store successfully. Available products:")
            for product in availableProducts {
                print("\t• \(product.displayName)")
            }
        } catch {
            print("IAP Store: Failed to request products from App Store. Error:\n\(error)")
        }
    }

    private func refreshPurchasedProducts() async {
        print("IAP Store: Refreshing purchased products")

        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil
            else {
                continue
            }

            await transaction.finish()
        }

        var purchasedProducts: [Product] = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let product = availableProducts.first(where: { $0.id == transaction.productID } )
            else {
                continue
            }

            purchasedProducts.append(product)
        }

        self.purchasedProducts = purchasedProducts

        print("IAP Store: Finished refreshing purchased products; calling update handler.")
        delegate?.storeDidUpdatePurchasedProducts(self)
    }

    // MARK: - Private properties

    private let productIdentifiers: [String]
    private var newTransactionHandler: Task<Void, Error>? = nil

}
