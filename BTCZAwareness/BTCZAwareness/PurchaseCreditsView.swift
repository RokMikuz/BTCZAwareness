import SwiftUI
import StoreKit

struct PurchaseCreditsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    @ObservedObject private var pointsManager = PointsManager.shared
    
    private let productIDs: [String] = [
        "com.btczawareness.btczcredits.10000",
        "com.btczawareness.btczcredits.40000",
        "com.btczawareness.btczcredits.100000"
    ]
    @State private var products: [Product] = []
    @State private var selectedProduct: Product? = nil
    @State private var iapConfig: [String: (credits: Int, label: String?, sortOrder: Int?, badge: String?)] = [:]
    
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @State private var transactionListenerTask: Task<Void, Never>? = nil
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.indigo, Color.black, Color.purple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Buy BTCZ Credits")
                    .font(.headline)
                    .foregroundColor(.white)
                
                VStack(spacing: 14) {
                    ForEach(products, id: \.id) { product in
                        let isSelected = selectedProduct?.id == product.id
                        ZStack {
                            // Background card with premium stroke
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(isSelected ? Color.orange : Color.white.opacity(0.22), lineWidth: isSelected ? 3 : 1)
                                )
                                .shadow(color: isSelected ? Color.orange.opacity(0.45) : Color.black.opacity(0.25), radius: isSelected ? 16 : 8, x: 0, y: isSelected ? 6 : 3)

                            HStack(spacing: 14) {
                                // Icon / badge
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color.orange.opacity(0.22) : Color.white.opacity(0.08))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: isSelected ? "checkmark.seal.fill" : "creditcard")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(isSelected ? .orange : .white.opacity(0.9))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(iapConfig[product.id]?.label ?? product.displayName)
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .lineLimit(1)
                                        if let badge = iapConfig[product.id]?.badge, !badge.isEmpty {
                                            Text(badge)
                                                .font(.caption2.bold())
                                                .foregroundColor(.black)
                                                .padding(.vertical, 3)
                                                .padding(.horizontal, 6)
                                                .background(Color.yellow)
                                                .cornerRadius(6)
                                        }
                                    }
                                    if let credits = iapConfig[product.id]?.credits {
                                        Text("\(credits) Credits")
                                            .foregroundColor(.white.opacity(0.9))
                                            .font(.subheadline)
                                    }
                                    Text(product.displayPrice)
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.subheadline)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 22))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(18)
                            .onAppear {
                                // Removed print statement as per instructions
                            }
                        }
                        .scaleEffect(isSelected ? 1.03 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isSelected)
                        .onTapGesture { withAnimation { selectedProduct = product } }
                    }
                }
                
                Button(action: buyCredits) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                Group {
                                    if selectedProduct == nil {
                                        Color.gray
                                    } else {
                                        LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .leading, endPoint: .trailing)
                                    }
                                }
                            )
                            .cornerRadius(12)
                            .shadow(color: (selectedProduct == nil ? Color.clear : Color.orange.opacity(0.35)), radius: 12, x: 0, y: 4)
                    } else {
                        Text("Buy")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                Group {
                                    if selectedProduct == nil {
                                        Color.gray
                                    } else {
                                        LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .leading, endPoint: .trailing)
                                    }
                                }
                            )
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: (selectedProduct == nil ? Color.clear : Color.orange.opacity(0.35)), radius: 12, x: 0, y: 4)
                    }
                }
                .disabled(selectedProduct == nil || isLoading)
                .scaleEffect(isLoading ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isLoading)
                
                if showConfirmation {
                    HStack(spacing: 10) {
                        Text("✅ Purchase successful. Your balance will sync shortly.")
                            .foregroundColor(.green)
                            .bold()
                    }
                    .transition(.opacity)
                }
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                Spacer()
                
                Text("You purchase BTCZ Credits as in-app credits. After a successful purchase, your balance is synchronized with the server as your BTCZ balance. Payouts are requested from the Claim screen.")
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .padding(.horizontal)
            }
            .padding()
            .task {
                await loadIAPConfig()
                await loadProducts()
                startTransactionListenerIfNeeded()
                await checkUnfinishedTransactions()
            }
        }
        .navigationTitle("BTCZ Credits")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut, value: showConfirmation)
        .animation(.easeInOut, value: showError)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    backPressed = true
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        backPressed = false
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                        .scaleEffect(backPressed ? 0.92 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: backPressed)
                }
            }
        }
    }
    
    private func loadIAPConfig() async {
        await withCheckedContinuation { continuation in
            ApiService.fetchIAPConfig(forceRefresh: true) { items in
                // Removed print statement for fetched items count
                var map: [String: (credits: Int, label: String?, sortOrder: Int?, badge: String?)] = [:]
                for it in items {
                    map[it.productId] = (credits: it.credits, label: it.label, sortOrder: it.sortOrder, badge: it.badge)
                }
                // Removed print statements that print config details
                DispatchQueue.main.async {
                    self.iapConfig = map
                    continuation.resume()
                }
            }
        }
    }
    
    private func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            // Removed print statement for loaded products
            // Preserve the order defined by productIDs to avoid complex type-checking in async sort
            var ordered: [Product] = []
            for id in productIDs {
                if let match = storeProducts.first(where: { $0.id == id }) {
                    ordered.append(match)
                }
            }
            self.products = ordered
        } catch {
            // Error loading products, leave products empty
        }
    }
    
    private func buyCredits() {
        guard let product = selectedProduct else { return }
        showError = false
        showConfirmation = false
        isLoading = true
        Task {
            do {
                let result = try await product.purchase()
                // Note: A global transaction listener will also catch updates
                
                switch result {
                case .success(let verification):
                    if let transaction = try? verification.payloadValue, transaction.revocationDate == nil {
                        let productId = product.id
                        let transactionId: String
                        if let id = transaction.id as? CustomStringConvertible {
                            transactionId = String(describing: id)
                        } else if let legacyId = transaction.originalID as? CustomStringConvertible {
                            transactionId = String(describing: legacyId)
                        } else {
                            transactionId = "\(transaction.hashValue)"
                        }
                        // Removed print statement for confirm request
                        ApiService.confirmPurchase(productId: productId, transactionId: transactionId) { success, message, newPoints, creditsAdded in
                            // Removed print statement for confirm response
                            DispatchQueue.main.async {
                                isLoading = false
                                if success {
                                    withAnimation { showConfirmation = true; showError = false }
                                    if let newPoints = newPoints { PointsManager.shared.currentPoints = newPoints }
                                    PointsManager.shared.syncWithServer()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { showConfirmation = false }
                                    }
                                } else {
                                    errorMessage = message ?? "Purchase failed. Please try again."
                                    withAnimation { showError = true; showConfirmation = false }
                                }
                            }
                        }
                        await transaction.finish()
                    } else {
                        await finishLoadingWithError("Transaction verification failed.")
                    }
                case .userCancelled:
                    await finishLoadingWithError("Purchase cancelled.")
                case .pending:
                    await finishLoadingWithError("Purchase pending.")
                @unknown default:
                    await finishLoadingWithError("Unknown purchase result.")
                }
            } catch {
                await finishLoadingWithError("Purchase failed. Please try again.")
            }
        }
    }
    
    @MainActor
    private func finishLoadingWithError(_ message: String) {
        isLoading = false
        errorMessage = message
        withAnimation { showError = true; showConfirmation = false }
    }
    
    private func startTransactionListenerIfNeeded() {
        if transactionListenerTask != nil { return }
        transactionListenerTask = Task {
            for await update in StoreKit.Transaction.updates {
                await handle(transactionResult: update)
            }
        }
    }
    
    private func checkUnfinishedTransactions() async {
        do {
            for await entitlement in StoreKit.Transaction.currentEntitlements {
                await handle(transactionResult: entitlement)
            }
        } catch {
            // No active account or no entitlements
        }
    }
    
    @MainActor
    private func handle(transactionResult: VerificationResult<StoreKit.Transaction>) async {
        switch transactionResult {
        case .unverified(_, _):
            // Ignore unverified transactions
            break
        case .verified(let transaction):
            let productId = transaction.productID
            let transactionId: String = String(describing: transaction.id)
            // Removed print statement for confirm request listener
            ApiService.confirmPurchase(productId: productId, transactionId: transactionId) { success, message, newPoints, creditsAdded in
                // Removed print statement for confirm response listener
                DispatchQueue.main.async {
                    if success {
                        if let newPoints = newPoints { PointsManager.shared.currentPoints = newPoints }
                        PointsManager.shared.syncWithServer()
                        withAnimation { showConfirmation = true; showError = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showConfirmation = false }
                        }
                    } else {
                        errorMessage = message ?? "Purchase processed but server sync failed. Please refresh."
                        withAnimation { showError = true }
                    }
                }
            }
            await transaction.finish()
        }
    }
}

struct PurchaseCreditsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PurchaseCreditsView()
        }
    }
}

