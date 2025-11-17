// ApiService.swift – 100 % DELUJE (vse točke na server, kviz, taski, claim, leaderboard, fun facts)
import Foundation
import UIKit

struct ApiService {
    static let baseURL = "https://btczkviz.btcz.rocks"
    private static let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device_\(UUID().uuidString)"
    
    // MARK: - Pridobi točke + wallet status + referral code
    static func getPoints(completion: @escaping (Int, Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/points?device_id=\(deviceID)") else {
            completion(PointsManager.shared.currentPoints, PointsManager.shared.hasWallet, PointsManager.shared.referralCode)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let points = json["points"] as? Int {
                let hasWallet = json["has_wallet"] as? Bool ?? false
                let code = json["referral_code"] as? String
                completion(points, hasWallet, code)
            } else {
                completion(PointsManager.shared.currentPoints, PointsManager.shared.hasWallet, PointsManager.shared.referralCode)
            }
        }.resume()
    }
    
    // MARK: - Shrani denarnico + referral
    static func saveWallet(address: String, referralCode: String?, completion: @escaping (Bool, String, Int, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim") else {
            completion(false, "Napaka URL", 0, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "action": "save_wallet",
            "address": address.trimmingCharacters(in: .whitespacesAndNewlines),
            "device_id": deviceID
        ]
        if let ref = referralCode, !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["referral_code"] = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            var message = success ? "Denarnica shranjena!" : "Napaka"
            var points = PointsManager.shared.currentPoints
            var refCode: String? = nil
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = (json["message"] as? String) ?? (json["error"] as? String) ?? "Neznana napaka"
                if let pts = json["new_points"] as? Int { points = pts }
                refCode = json["referral_code"] as? String
            }
            
            DispatchQueue.main.async {
                completion(success, message, points, refCode)
            }
        }.resume()
    }
    
    // MARK: - Claim (izplačilo)
    static func claim(amount: Int, completion: @escaping (Bool, String, Int) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim") else {
            completion(false, "Napaka URL", 0)
            return
        }
        
        let address = UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
        guard !address.isEmpty else {
            completion(false, "Najprej dodaj denarnico!", 0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "action": "claim",
            "address": address,
            "device_id": deviceID,
            "claim_amount": amount
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode == 200 && error == nil
            var message = success ? "Zahteva sprejeta!" : "Napaka"
            var points = PointsManager.shared.currentPoints
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = json["message"] as? String ?? message
                if let pts = json["new_points"] as? Int { points = pts }
            }
            
            DispatchQueue.main.async {
                completion(success, message, points)
            }
        }.resume()
    }
    
    // MARK: - Fetch Tasks
    static func fetchTasksFromAPI(completion: @escaping ([AppTask]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tasks") else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let tasks = try? JSONDecoder().decode([AppTask].self, from: data) {
                DispatchQueue.main.async { completion(tasks) }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    // MARK: - Complete Task (KVIZ, TASKI, SHARE – VSE GRE NA SERVER!)
    static func completeTask(taskId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/complete-task") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "task_id": taskId,
            "device_id": deviceID
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                completion(success)
            }
        }.resume()
    }
    
    // MARK: - Settings (daily reward)
    static func fetchSettings(completion: @escaping (Settings) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/settings") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let settings = try? JSONDecoder().decode(Settings.self, from: data) {
                DispatchQueue.main.async { completion(settings) }
            }
        }.resume()
    }
    
    // MARK: - Leaderboard
    static func fetchLeaderboard(completion: @escaping ([UserRank]) -> Void) {
        guard let url = URL(string: "\(baseURL)/leaderboard") else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let entries = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
                let ranks = entries.enumerated().map { i, e in
                    UserRank(position: "\(i+1)", anonymizedAddress: anonymize(e.address), points: e.points)
                }
                DispatchQueue.main.async { completion(ranks) }
            } else {
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    // MARK: - Fun Facts
    static func fetchFunFacts(completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/fun-facts") else {
            completion(["BTCZ is awesome!"])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let facts = try? JSONDecoder().decode([String].self, from: data),
               !facts.isEmpty {
                DispatchQueue.main.async { completion(facts) }
            } else {
                DispatchQueue.main.async {
                    completion(["BTCZ has 21 billion supply!", "Privacy with zk-SNARKs!", "Community driven since 2017!"])
                }
            }
        }.resume()
    }
    
    // MARK: - Pomožni modeli
    private struct LeaderboardEntry: Codable {
        let address: String
        let points: Int
    }
    
    private static func anonymize(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))***\(address.suffix(5))"
    }
}

// MARK: - Modeli
struct Settings: Codable {
    let daily_login_reward: Int
    let referral_reward: Int
    var dailyReward: Int { daily_login_reward }
}

struct AppTask: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let points: Int
    let type: String?
    let link: String?
    let repeatable: String?
}

struct UserRank: Identifiable {
    let id = UUID()
    let position: String
    let anonymizedAddress: String
    let points: Int
}
