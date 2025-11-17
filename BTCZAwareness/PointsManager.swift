import Foundation
import Combine
import UIKit   // <-- OBVEZNO!

class PointsManager: ObservableObject {
    static let shared = PointsManager()
    
    // Vse javno – da lahko WalletView in ClaimView posodobita vrednosti
    @Published var currentPoints: Int = 0
    @Published var hasWallet: Bool = false
    @Published var referralCode: String = ""
    
    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    private init() {
        loadFromDisk()
        checkWalletStatus()
        syncWithServer() // Sinhroniziraj takoj ob zagonu
    }
    
    // MARK: - Dodajanje točk (uporablja se iz kviza, taskov, daily swipe-a itd.)
    func addPoints(_ points: Int) {
        currentPoints += points
        saveToDisk()
        syncWithServer() // Pošlje na server tudi brez denarnice
    }
    
    // MARK: - Sinhronizacija s serverjem (glavna funkcija!)
    func syncWithServer() {
        ApiService.getPoints { [weak self] pointsFromServer, hasWalletFromServer, referralCodeFromServer in
            DispatchQueue.main.async {
                // Posodobi lokalne točke samo če so na serverju večje (da ne izgubimo lokalnih)
                if pointsFromServer > self?.currentPoints ?? 0 {
                    self?.currentPoints = pointsFromServer
                    self?.saveToDisk()
                }
                
                self?.hasWallet = hasWalletFromServer
                
                if let code = referralCodeFromServer, !code.isEmpty {
                    self?.referralCode = code
                    UserDefaults.standard.set(code, forKey: "myReferralCode")
                }
            }
        }
    }
    
    // MARK: - Pokliči po uspešnem dodajanju denarnice
    func walletAdded() {
        checkWalletStatus()
        syncWithServer()
        NotificationCenter.default.post(name: .walletAdded, object: nil)
    }
    
    // MARK: - Preveri, če je denarnica že dodana
    private func checkWalletStatus() {
        let address = UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
        hasWallet = !address.isEmpty
    }
    
    // MARK: - Shranjevanje lokalno
    private func loadFromDisk() {
        currentPoints = UserDefaults.standard.integer(forKey: "localBTCZPoints")
        if let code = UserDefaults.standard.string(forKey: "myReferralCode") {
            referralCode = code
        }
    }
    
    private func saveToDisk() {
        UserDefaults.standard.set(currentPoints, forKey: "localBTCZPoints")
    }
}

// MARK: - Notification za odklepanje taskov itd.
extension Notification.Name {
    static let walletAdded = Notification.Name("walletAdded")
}
