// PointsManager.swift – 100 % CELOTNA – VARNA SINHRONIZACIJA + LOGI + PODPORA ZA CLICKER
import Foundation
import Combine
import UIKit

class PointsManager: ObservableObject {
    static let shared = PointsManager()
    
    @Published var currentPoints: Int = 0
    @Published var hasWallet: Bool = false
    @Published var referralCode: String = ""

    private var isSaving = false
    
    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
    
    private init() {
        loadFromDisk()
        // print("PointsManager: device_id=\(ApiService.deviceID), baseURL=\(ApiService.baseURL)")
        // Delay initial sync to avoid race with registration and ensure main-thread update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.syncWithServer()
        }
    }
    
    // NALOŽI TOČKE IZ SERVERJA (GET /points)
    func syncWithServer(completion: (() -> Void)? = nil) {
        // print("PointsManager: syncWithServer – GET from server")
        // print("PointsManager: calling \(ApiService.baseURL)/points?device_id=\(ApiService.deviceID)")
        ApiService.getPoints { [weak self] points in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let serverPoints = points
                if serverPoints == 0 {
                    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.6) {
                        ApiService.getPoints { [weak self] retryPoints in
                            DispatchQueue.main.async {
                                guard let self = self else { return }
                                let resolved = retryPoints == 0 ? self.currentPoints : retryPoints
                                self.currentPoints = resolved
                                self.saveToDisk()
                                completion?()
                            }
                        }
                    }
                } else {
                    self.currentPoints = serverPoints
                    self.saveToDisk()
                    completion?()
                }
            }
        }
    }
    
    // PUBLIC: force refresh from server (server is the single source of truth)
    func refreshFromServer(completion: (() -> Void)? = nil) {
        syncWithServer(completion: completion)
    }
    
    // POŠLJI TOČKE NA SERVER (POST /api/sync-points) – VARNO
    func saveToServer(completion: (() -> Void)? = nil) {
        // Deprecated in server-only model; prefer ApiService.addPoints and syncWithServer
        completion?()
    }
    
    // DODAJ TOČKE LOKALNO + POŠLJI NA SERVER
    func addPoints(_ points: Int) {
        // Deprecated for server-only flows. Use ApiService.addPoints and then syncWithServer.
        currentPoints += points
        saveToDisk()
    }
    
    // POSODOBI WALLET STATUS + POŠLJI NA SERVER
    func walletAdded() {
        hasWallet = true
        saveToDisk()
        syncWithServer()
        NotificationCenter.default.post(name: .walletAdded, object: nil)
    }
    
    // NALOŽI IZ UserDefaults (backup če ni interneta)
    private func loadFromDisk() {
        currentPoints = UserDefaults.standard.integer(forKey: "currentPoints")
        hasWallet = UserDefaults.standard.bool(forKey: "hasWallet")
        referralCode = UserDefaults.standard.string(forKey: "referralCode") ?? ""
        // print("PointsManager: loaded from disk – points: \(currentPoints), hasWallet: \(hasWallet)")
    }
    
    // SHRANI V UserDefaults (backup)
    private func saveToDisk() {
        UserDefaults.standard.set(currentPoints, forKey: "currentPoints")
        UserDefaults.standard.set(hasWallet, forKey: "hasWallet")
        UserDefaults.standard.set(referralCode, forKey: "referralCode")
    }
}

extension Notification.Name {
    static let walletAdded = Notification.Name("walletAdded")
}
