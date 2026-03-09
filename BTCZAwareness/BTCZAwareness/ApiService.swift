// ApiService.swift – 100 % CELOTNA – Z GLOBALNIM SERVER ERROR + VSE FUNKCIJE + PRAVILEN syncPoints (brez /api)
import Foundation
import UIKit

private func apiLog(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let ts = formatter.string(from: Date())
    print("[API][\(ts)] \(message)")
}

struct ApiService {
    static let baseURL = "https://btczkviz.btcz.rocks"
    static let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
    
    // Added for deleteAccount method
    static var baseURLString: String = "https://btczkviz.btcz.rocks/"
    static var authToken: String? = nil // TODO: set from login/session if applicable
    
    // Centralized helper to apply server points to local PointsManager
    private static func applyServerPoints(_ points: Int) {
        DispatchQueue.main.async {
            PointsManager.shared.currentPoints = points
            // Persist through PointsManager's disk method if available
            // PointsManager has private saveToDisk; call public refresh path if needed
            UserDefaults.standard.set(points, forKey: "currentPoints")
        }
    }
    
    // IAP config cache (5-minute TTL)
    private static var cachedIAPConfig: (items: [(productId: String, credits: Int, label: String?, sortOrder: Int?, badge: String?)], timestamp: Date)? = nil
    private static let iapConfigTTL: TimeInterval = 5 * 60
    
    // GLOBALNI CALLBACK ZA SERVER ERROR (angleščina)
    static var onServerError: ((String) -> Void)?
    
    // CENTRALIZIRANO OBVESTILO ZA SERVER ERROR
    static func showServerError(message: String = "Server is currently unavailable. Please try again later.") {
        DispatchQueue.main.async {
            onServerError?(message)
        }
    }
    
    // 1. Registracija
    static func registerUserIfNeeded() {
        guard let url = URL(string: "\(baseURL)/register-device") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // Removed debug print line below as per instructions
        // print("[REGISTER][DEVICE] POST /register-device body={\"device_id\": \(deviceID)}")
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // 2. Točke – GET
    static func getPoints(completion: @escaping (Int) -> Void) {
        let urlStr = "\(baseURL)/points?device_id=\(deviceID)"
        print("[API][GET POINTS] URL=\(urlStr)")
        guard let url = URL(string: urlStr) else {
            showServerError()
            completion(0)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[API][GET POINTS] status=\(statusCode) err=\(String(describing: err))")
            if let data = data, let raw = String(data: data, encoding: .utf8) {
                print("[API][GET POINTS] raw=\(raw)")
            }
            if err != nil || statusCode != 200 {
                showServerError()
                completion(0)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let points: Int = {
                    if let p = json["points"] as? Int { return p }
                    if let ps = json["points"] as? String, let parsed = Int(ps) { return parsed }
                    return 0
                }()
                let serverAddress: String = {
                    if let a = json["address"] as? String { return a }
                    return ""
                }()
                if !serverAddress.isEmpty {
                    UserDefaults.standard.set(serverAddress, forKey: "savedBTCZAddress")
                }
                print("[API][GET POINTS] parsed points=\(points)")
                applyServerPoints(points)
                DispatchQueue.main.async { completion(points) }
            } else {
                completion(0)
            }
        }.resume()
    }
    
    // GET points + restore_code in one call
    static func getPointsWithRestore(completion: @escaping (Int, String?) -> Void) {
        let urlStr = "\(baseURL)/points?device_id=\(deviceID)"
        print("[API][GET POINTS WITH RESTORE] URL=\(urlStr)")
        guard let url = URL(string: urlStr) else {
            showServerError()
            completion(0, nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[API][GET POINTS WITH RESTORE] status=\(statusCode) err=\(String(describing: err))")
            if let data = data, let raw = String(data: data, encoding: .utf8) {
                print("[API][GET POINTS WITH RESTORE] raw=\(raw)")
            }
            if err != nil || statusCode != 200 {
                showServerError()
                completion(0, nil)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let points: Int = {
                    if let p = json["points"] as? Int { return p }
                    if let ps = json["points"] as? String, let parsed = Int(ps) { return parsed }
                    return 0
                }()
                let code = json["restore_code"] as? String
                let serverAddress: String = {
                    if let a = json["address"] as? String { return a }
                    return ""
                }()
                if !serverAddress.isEmpty {
                    UserDefaults.standard.set(serverAddress, forKey: "savedBTCZAddress")
                }
                print("[API][GET POINTS WITH RESTORE] parsed points=\(points), restore_code=\(code ?? "nil")")
                applyServerPoints(points)
                DispatchQueue.main.async { completion(points, code) }
            } else {
                completion(0, nil)
            }
        }.resume()
    }
    
    // Convenience: Wallet balance (alias for points)
    static func getWalletBalance(completion: @escaping (Int) -> Void) {
        getPoints { points in
            completion(points)
        }
    }
    
    // NOVO: POST /sync-points – VARNO POŠILJANJE BALANCE-A (brez /api)
    static func syncPoints(points: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/sync-points") else {  // BREZ /api
            showServerError()
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["device_id": deviceID, "points": points] as [String: Any]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            let success = err == nil && (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                if !success {
                    showServerError()
                }
                completion(success)
            }
        }.resume()
    }
    
    // 3. Shrani denarnico
    static func saveWallet(address: String, referralCode: String?, completion: @escaping (Bool, String, Int, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim") else {
            completion(false, "URL error", 0, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["action": "save_wallet", "address": address, "device_id": deviceID]
        if let ref = referralCode, !ref.isEmpty { body["referral_code"] = ref }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable", 0, nil)
                return
            }
            let success = (resp as? HTTPURLResponse)?.statusCode == 200
            var msg = success ? "Wallet saved successfully" : "Error saving wallet"
            var pts = 0
            var code: String? = nil
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                msg = json["message"] as? String ?? msg
                pts = json["new_points"] as? Int ?? 0
                code = json["referral_code"] as? String
            }
            applyServerPoints(pts)
            DispatchQueue.main.async { completion(success, msg, pts, code) }
        }.resume()
    }
    
    // 4. Complete task
    static func completeTask(taskId: String, completion: @escaping (Bool) -> Void) {
        func attempt(urlString: String, fallback: String?, _ done: @escaping (Bool) -> Void) {
            guard let url = URL(string: urlString) else { done(false); return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["task_id": Int(taskId) ?? 0, "device_id": deviceID]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: request) { data, resp, err in
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if err != nil {
                    showServerError()
                    done(false)
                    return
                }
                if status == 404, let fb = fallback {
                    attempt(urlString: fb, fallback: nil, done)
                    return
                }
                if status != 200 {
                    showServerError()
                    done(false)
                    return
                }
                done(true)
            }.resume()
        }
        // Try /api first, then root fallback
        attempt(urlString: "\(baseURL)/api/complete-task", fallback: "\(baseURL)/complete-task", completion)
    }
    
    // 5. Preveri kviz
    static func isQuizCompleted(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/user-status?device_id=\(deviceID)") else {
            apiLog("isQuizCompleted URL error")
            completion(false)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("isQuizCompleted network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("isQuizCompleted non-200 status=\(status)")
                completion(false)
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let done = json["quiz_completed_today"] as? Bool {
                // Removed noisy log line as requested:
                // apiLog("isQuizCompleted done=\(done)")
                DispatchQueue.main.async { completion(done) }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // User status: includes daily login state
    static func getUserStatus(completion: @escaping (_ dailyLoginClaimed: Bool, _ nextAvailableAt: Date?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/user-status?device_id=\(deviceID)") else {
            apiLog("getUserStatus URL error")
            completion(false, nil)
            return
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("getUserStatus network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("getUserStatus non-200 status=\(status)")
                completion(false, nil)
                return
            }
            var claimed = false
            var nextDate: Date? = nil
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let rawClaimed = json["daily_login_claimed"] as? Bool {
                    claimed = rawClaimed
                }
                if let nextStr = json["next_available_at"] as? String, !nextStr.isEmpty {
                    if let parsed = isoFormatter.date(from: nextStr) {
                        nextDate = parsed
                    } else {
                        let df = DateFormatter()
                        df.locale = Locale(identifier: "en_US_POSIX")
                        df.timeZone = TimeZone(secondsFromGMT: 0)
                        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
                        if let parsed2 = df.date(from: nextStr) {
                            nextDate = parsed2
                        }
                    }
                }
            }
            // Removed the logging line below as requested:
            // apiLog("getUserStatus parsed claimed=\(claimed) next=\(String(describing: nextDate))")
            DispatchQueue.main.async { completion(claimed, nextDate) }
        }.resume()
    }
    
    // 6. Fetch tasks
    static func fetchTasks(completion: @escaping ([AppTask]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/tasks") else {
            apiLog("fetchTasks URL error")
            completion([])
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("fetchTasks network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("fetchTasks non-200 status=\(status)")
                completion([])
                return
            }
            guard let data = data,
                  let tasks = try? JSONDecoder().decode([AppTask].self, from: data) else {
                completion([])
                return
            }
            DispatchQueue.main.async { completion(tasks) }
        }.resume()
    }
    
    // 7. Fetch settings (daily reward)
    static func fetchSettings(completion: @escaping (Int) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/settings") else {
            apiLog("fetchSettings URL error")
            completion(10)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("fetchSettings network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("fetchSettings non-200 status=\(status)")
                completion(10)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reward = json["daily_login_reward"] as? Int {
                DispatchQueue.main.async { completion(reward) }
            } else {
                completion(10)
            }
        }.resume()
    }
    
    // 8. Leaderboard
    static func fetchLeaderboard(completion: @escaping ([UserRank]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/leaderboard") else {
            apiLog("fetchLeaderboard URL error")
            completion([])
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("fetchLeaderboard network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("fetchLeaderboard non-200 status=\(status)")
                completion([])
                return
            }
            if let data = data, let list = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
                let ranks = list.enumerated().map { i, entry in
                    let display = (entry.address.isEmpty || entry.address.lowercased() == "brez") ? "Anonymous" : anonymize(entry.address)
                    return UserRank(position: "\(i+1)", anonymizedAddress: display, points: entry.points)
                }
                DispatchQueue.main.async { completion(ranks) }
            } else {
                completion([])
            }
        }.resume()
    }
    
    // 9. Fun facts
    static func fetchFunFacts(completion: @escaping ([String]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/fun-facts") else {
            apiLog("fetchFunFacts URL error")
            completion(["BTCZ is awesome!"])
            return
        }
        apiLog("fetchFunFacts calling /api/fun-facts")
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            apiLog("fetchFunFacts status=\(status) err=\(err?.localizedDescription ?? "nil")")
            if let data = data, let raw = String(data: data, encoding: .utf8) {
                apiLog("fetchFunFacts raw=\(raw)")
            }
            if status != 200 {
                apiLog("fetchFunFacts non-200 status=\(status)")
                completion(["BTCZ is awesome!"])
                return
            }
            if let data = data, let facts = try? JSONDecoder().decode([String].self, from: data), !facts.isEmpty {
                apiLog("fetchFunFacts parsed count=\(facts.count)")
                DispatchQueue.main.async { completion(facts) }
            } else {
                completion(["BTCZ has 21 billion supply!", "Privacy with zk-SNARKs!"])
            }
        }.resume()
    }
    
    // 10. Claim
    static func claim(amount: Int, completion: @escaping (Bool, String, Int) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim") else {
            showServerError()
            completion(false, "URL error", 0)
            return
        }
        let address = UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
        guard !address.isEmpty else {
            showServerError()
            completion(false, "No wallet", 0)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["action": "claim", "address": address, "device_id": deviceID, "claim_amount": amount] as [String: Any]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable", 0)
                return
            }
            let success = (resp as? HTTPURLResponse)?.statusCode == 200
            var msg = success ? "Claim successful" : "Claim failed"
            var pts = 0
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                msg = json["message"] as? String ?? msg
                pts = json["new_points"] as? Int ?? 0
            }
            applyServerPoints(pts)
            DispatchQueue.main.async { completion(success, msg, pts) }
        }.resume()
    }
    
    // 11. Quiz reward
    static func fetchQuizReward(completion: @escaping (Int) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/config") else {
            showServerError()
            completion(100)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(100)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reward = json["quiz_reward"] as? Int {
                DispatchQueue.main.async { completion(reward) }
            } else {
                completion(100)
            }
        }.resume()
    }
    
    // 12. Quiz questions
    static func fetchQuizQuestions(completion: @escaping ([QuizQuestion]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/quiz") else {
            showServerError()
            completion([])
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion([])
                return
            }
            if let data = data,
               let questions = try? JSONDecoder().decode([QuizQuestion].self, from: data) {
                DispatchQueue.main.async { completion(questions) }
            } else {
                completion([])
            }
        }.resume()
    }
    
    // 13. DISCORD VERIFIKACIJA
    static func verifyDiscordJoin(discordID: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/verify-discord") else {
            completion(false, "URL error")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["device_id": deviceID, "discord_id": discordID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable")
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                completion(success, message)
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // 14. DISCORD CLAIM
    static func claimDiscordReward(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim-discord") else {
            completion(false, "URL error")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable")
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                completion(success, message)
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // 15. TELEGRAM CLAIM
    static func claimTelegramReward(completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/claim-telegram") else {
            completion(false, "URL error")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable")
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                completion(success, message)
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    // 16. Dobi config – Z LOGIRANJEM
    static func getConfig(completion: @escaping ([String: Any]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/config") else {
            apiLog("getConfig URL error")
            completion([:])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                apiLog("getConfig error: \(err.localizedDescription)")
                completion([:])
                return
            }
            
            if let httpResp = resp as? HTTPURLResponse {
                if httpResp.statusCode != 200 {
                    apiLog("getConfig non-200 status=\(httpResp.statusCode)")
                    completion([:])
                    return
                }
            }
            
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async { completion(json) }
            } else {
                completion([:])
            }
        }.resume()
    }
    
    // 17. Referral stats
    static func getReferralStats(completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/referral-stats?device_id=\(deviceID)") else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(nil)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                DispatchQueue.main.async { completion(json) }
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    // 18. Completed tasks
    static func fetchCompletedTasks(completion: @escaping ([AppTask]) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/completed-tasks?device_id=\(deviceID)") else {
            apiLog("fetchCompletedTasks URL error")
            completion([])
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            if let err = err { apiLog("fetchCompletedTasks network error: \(err.localizedDescription)") }
            if status != 200 {
                apiLog("fetchCompletedTasks non-200 status=\(status)")
                completion([])
                return
            }
            guard let data = data,
                  let tasks = try? JSONDecoder().decode([AppTask].self, from: data) else {
                completion([])
                return
            }
            DispatchQueue.main.async { completion(tasks) }
        }.resume()
    }
    
    // 19. REWARDED VIDEO
    static func rewardVideo(completion: @escaping (Bool, String?, Int?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/rewarded-video") else {
            completion(false, "URL error", nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable", nil)
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                var message = json["message"] as? String
                let newPoints = json["new_points"] as? Int

                // Normalize message to English if server returned localized text
                if var msg = message {
                    msg = msg.replacingOccurrences(of: "Dodano", with: "Added")
                             .replacingOccurrences(of: "dodano", with: "added")
                             .replacingOccurrences(of: "Uspešno", with: "Success")
                             .replacingOccurrences(of: "uspešno", with: "success")
                    message = msg
                }

                if (message == nil || message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true) {
                    message = "Success!"
                }
                
                if let np = newPoints {
                    applyServerPoints(np)
                }

                completion(success, message, newPoints)
            } else {
                completion(false, "Invalid response", nil)
            }
        }.resume()
    }
    
    // Rewarded video status (daily limit)
    static func getRewardedVideoStatus(completion: @escaping (_ canWatch: Bool, _ remainingViews: Int, _ maxViews: Int, _ message: String?) -> Void) {
        let urlStr = "\(baseURL)/api/rewarded-video-status?device_id=\(deviceID)"
        guard let url = URL(string: urlStr) else {
            completion(false, 0, 0, "URL error")
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil {
                DispatchQueue.main.async { completion(false, 0, 0, "Network error") }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(false, 0, 0, "Invalid response") }
                return
            }
            let canWatch = json["canWatch"] as? Bool ?? false
            let remaining = json["remainingViews"] as? Int ?? 0
            let maxViews = json["maxViews"] as? Int ?? 0
            let message = json["message"] as? String
            DispatchQueue.main.async { completion(canWatch, remaining, maxViews, message) }
        }.resume()
    }
    
    // 20. Buy credits (placeholder endpoint)
    static func buyCredits(amount: Int, completion: @escaping (Bool, String?, Int?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/buy-credits") else {
            completion(false, "URL error", nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "amount": amount
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, "Server unavailable", nil)
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                let newPoints = json["new_points"] as? Int
                if let np = newPoints { applyServerPoints(np) }
                completion(success, message, newPoints)
            } else {
                completion(false, "Invalid response", nil)
            }
        }.resume()
    }
    
    // IAP: Fetch configuration for products (credits, labels, badges, order)
    static func fetchIAPConfig(forceRefresh: Bool = false, completion: @escaping ([(productId: String, credits: Int, label: String?, sortOrder: Int?, badge: String?)]) -> Void) {
        // Serve from cache if fresh
        if !forceRefresh, let cache = cachedIAPConfig, Date().timeIntervalSince(cache.timestamp) < iapConfigTTL {
            DispatchQueue.main.async { completion(cache.items) }
            return
        }
        guard let url = URL(string: "\(baseURL)/api/iap-config") else {
            completion([])
            return
        }
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                // On failure, if we have stale cache, return it; else empty
                if let cache = cachedIAPConfig {
                    DispatchQueue.main.async { completion(cache.items) }
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
                return
            }
            var result: [(productId: String, credits: Int, label: String?, sortOrder: Int?, badge: String?)] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let products = json["products"] as? [[String: Any]] {
                for p in products {
                    let productId = p["product_id"] as? String ?? ""
                    let credits: Int = {
                        if let intVal = p["credits"] as? Int { return intVal }
                        if let strVal = p["credits"] as? String, let parsed = Int(strVal) { return parsed }
                        return 0
                    }()
                    let label = p["label"] as? String
                    let sortOrder: Int? = {
                        if let intVal = p["sort_order"] as? Int { return intVal }
                        if let strVal = p["sort_order"] as? String, let parsed = Int(strVal) { return parsed }
                        return nil
                    }()
                    let badge = p["badge"] as? String
                    if !productId.isEmpty && credits > 0 {
                        result.append((productId: productId, credits: credits, label: label, sortOrder: sortOrder, badge: badge))
                    }
                }
            }
            // Cache result with timestamp
            cachedIAPConfig = (items: result, timestamp: Date())
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    
    // IAP: Confirm purchase with backend (idempotent) and get updated points
    static func confirmPurchase(productId: String, transactionId: String, completion: @escaping (Bool, String?, Int?, Int?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/confirm-purchase") else {
            completion(false, "URL error", nil, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "product_id": productId,
            "transaction_id": transactionId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil {
                DispatchQueue.main.async { completion(false, "Network error", nil, nil) }
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(false, "No response", nil, nil) }
                return
            }
            if http.statusCode != 200 {
                var message = "Server unavailable"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMsg = json["message"] as? String {
                    message = serverMsg
                }
                DispatchQueue.main.async { completion(false, message, nil, nil) }
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                let newPoints = json["new_points"] as? Int
                if let np = newPoints { applyServerPoints(np) }
                let creditsAdded = json["credits_added"] as? Int
                DispatchQueue.main.async { completion(success, message, newPoints, creditsAdded) }
            } else {
                DispatchQueue.main.async { completion(false, "Invalid response", nil, nil) }
            }
        }.resume()
    }
    
    static func addPoints(amount: Int, completion: @escaping (Bool, String?, Int?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/add-points") else {
            completion(false, "URL error", nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "amount": amount
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil {
                DispatchQueue.main.async { completion(false, "Network error", nil) }
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(false, "No response", nil) }
                return
            }
            if http.statusCode != 200 {
                var message = "Server unavailable"
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMsg = json["message"] as? String {
                    message = serverMsg
                }
                DispatchQueue.main.async {
                    showServerError(message: message)
                    completion(false, message, nil)
                }
                return
            }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let success = json["success"] as? Bool ?? false
                let message = json["message"] as? String
                let newPoints = json["new_points"] as? Int
                if let np = newPoints { applyServerPoints(np) }
                DispatchQueue.main.async { completion(success, message, newPoints) }
            } else {
                DispatchQueue.main.async { completion(false, "Invalid response", nil) }
            }
        }.resume()
    }
    
    // PvP Memory Match – implementations
    static func createMemoryMatchPvP(completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/create-match") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let startCreate = Date()
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func getMemoryMatchPvPState(matchId: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let qs = "match_id=\(matchId)&device_id=\(deviceID)"
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/state?\(qs)") else {
            completion(false, nil)
            return
        }
        let startState = Date()
        
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func flipMemoryMatchPvP(matchId: String, indices: [Int], completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/flip") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "match_id": matchId,
            "indices": indices
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let startFlip = Date()
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func useBonusMemoryMatchPvP(matchId: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/use-bonus") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "match_id": matchId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let startBonus = Date()
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func finishMemoryMatchPvP(matchId: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/finish") else {
            completion(false, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "device_id": deviceID,
            "match_id": matchId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let startFinish = Date()
        
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    static func leaveWaitingMemoryMatchPvP(matchId: String, deviceId: String = deviceID, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let qs = "match_id=\(matchId)&device_id=\(deviceId)"
        guard let url = URL(string: "\(baseURL)/api/pvp/memory/leave-waiting?\(qs)") else {
            completion(false, nil)
            return
        }
        let start = Date()
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(true, nil)
            }
        }.resume()
    }

    // PvP Tetris – implementations with /api only, no fallback
    static func createTetrisPvP(completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/tetris/create-match") else { completion(false, nil); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let start = Date()
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                showServerError()
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func getTetrisPvPState(matchId: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let qs = "match_id=\(matchId)&device_id=\(deviceID)"
        guard let url = URL(string: "\(baseURL)/api/pvp/tetris/state?\(qs)") else { completion(false, nil); return }
        let start = Date()
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func tetrisPvPMove(matchId: String, move: String, tick: Int, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/tetris/move") else { completion(false, nil); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["device_id": deviceID, "match_id": matchId, "move": move, "tick": tick]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let start = Date()
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func tetrisPvPLinesCleared(matchId: String, lines: Int, combo: Int? = nil, tick: Int, completion: @escaping (Bool, [String: Any]?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/pvp/tetris/lines-cleared") else { completion(false, nil); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["device_id": deviceID, "match_id": matchId, "lines": lines, "tick": tick]
        if let combo = combo { body["combo"] = combo }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let start = Date()
        URLSession.shared.dataTask(with: request) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    static func leaveTetrisPvP(matchId: String, completion: @escaping (Bool, [String: Any]?) -> Void) {
        let qs = "match_id=\(matchId)&device_id=\(deviceID)"
        guard let url = URL(string: "\(baseURL)/api/pvp/tetris/leave-waiting?\(qs)") else { completion(false, nil); return }
        let start = Date()
        URLSession.shared.dataTask(with: url) { data, resp, err in
            if err != nil || (resp as? HTTPURLResponse)?.statusCode != 200 {
                completion(false, nil)
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                completion(true, json)
            } else {
                completion(false, nil)
            }
        }.resume()
    }
    
    // PRIVATE MODELI
    private struct LeaderboardEntry: Codable {
        let address: String
        let points: Int
    }
    
    private static func anonymize(_ address: String) -> String {
        guard address.count > 8 else { return address }
        return "\(address.prefix(4))***\(address.suffix(5))"
    }
    
    // 21. Restore account
    static func restoreAccount(restoreCode: String, completion: @escaping (Bool, String) -> Void) {
        func attempt(urlString: String, fallback: String?, _ done: @escaping (Bool, String) -> Void) {
            guard let url = URL(string: urlString) else { done(false, "URL error"); return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["restore_code": restoreCode, "device_id": deviceID]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let task = URLSession.shared.dataTask(with: request) { data, resp, err in
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if err != nil {
                    showServerError()
                    done(false, "Network error")
                    return
                }
                if status == 404, let _ = fallback {
                    attempt(urlString: fallback!, fallback: nil, done)
                    return
                }
                if status != 200 {
                    var msg = "Server unavailable"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let serverMsg = json["message"] as? String { msg = serverMsg }
                    showServerError(message: msg)
                    done(false, msg)
                    return
                }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let success = json["success"] as? Bool, let message = json["message"] as? String {
                    done(success, message)
                } else {
                    done(false, "Invalid response")
                }
            }
            task.resume()
        }
        // Try root first, then /api fallback
        attempt(urlString: "\(baseURL)/restore-account", fallback: "\(baseURL)/api/restore-account", completion)
    }
    
    // 22. Register with restore code
    static func registerWithRestore(restoreCode: String, completion: @escaping (Bool, String) -> Void) {
        func attempt(urlString: String, fallback: String?, _ done: @escaping (Bool, String) -> Void) {
            guard let url = URL(string: urlString) else { done(false, "URL error"); return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = ["restore_code": restoreCode, "device_id": deviceID]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            let task = URLSession.shared.dataTask(with: request) { data, resp, err in
                let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if err != nil {
                    showServerError()
                    done(false, "Network error")
                    return
                }
                if status == 404, let _ = fallback {
                    attempt(urlString: fallback!, fallback: nil, done)
                    return
                }
                if status != 200 {
                    var msg = "Server unavailable"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let serverMsg = json["message"] as? String { msg = serverMsg }
                    showServerError(message: msg)
                    done(false, msg)
                    return
                }
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let success = json["success"] as? Bool, let message = json["message"] as? String {
                    done(success, message)
                } else {
                    done(false, "Invalid response")
                }
            }
            task.resume()
        }
        // Try root first, then /api fallback
        attempt(urlString: "\(baseURL)/register-with-restore", fallback: "\(baseURL)/api/register-with-restore", completion)
    }
    
    // 23. Delete account
    static func deleteAccount(verification: String, completion: @escaping (_ success: Bool, _ message: String?) -> Void) {
        // Construct URL
        guard let baseURL = URL(string: baseURLString) else {
            completion(false, "Invalid base URL")
            return
        }
        let url = baseURL.appendingPathComponent("api/account")

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { // if you store auth token in ApiService
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "verification": verification,
            "device_id": deviceID
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(false, "Failed to encode request body")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(false, "No response")
                return
            }
            let status = http.statusCode
            var message: String? = nil
            if let data = data, !data.isEmpty {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    message = (json["message"] as? String) ?? message
                    if let success = json["success"] as? Bool {
                        if status == 200 && success {
                            completion(true, message)
                            return
                        }
                    }
                }
            }
            if status == 200 { // Some backends may not return JSON success flag
                completion(true, message)
            } else if status == 400 {
                completion(false, message ?? "Verification failed")
            } else if status == 401 {
                completion(false, message ?? "Unauthorized")
            } else {
                completion(false, message ?? "Server error (\(status))")
            }
        }
        task.resume()
    }
}

// MODELI
struct AppTask: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String?
    let points: Int
    let type: String?
    let platform: String?
    let link: String?
    let text: String?
    let image: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.points = try container.decode(Int.self, forKey: .points)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform)
        self.link = try container.decodeIfPresent(String.self, forKey: .link)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
    }
}

struct UserRank: Identifiable, Equatable {
    let id = UUID()
    let position: String
    let anonymizedAddress: String
    let points: Int
}

struct QuizQuestion: Codable {
    let text: String
    let options: [String]
    let correctAnswer: String
}

