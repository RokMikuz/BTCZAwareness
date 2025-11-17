// DailyLoginStatus.swift – 100 % POPRAVLJENO – BREZ INICIALIZACIJSKIH NAPAK
import Foundation
import SwiftUI
import Combine  // za ObservableObject

@MainActor
class DailyLoginStatus: ObservableObject {
    @Published var claimed: Bool = false
    @Published var timeRemaining: String = ""
    
    private let udNextKey = "daily_nextAvailableAt"
    private let udClaimedKey = "daily_claimed"
    
    private var nextAvailableAt: Date? = nil
    private var lastServerFetch: Date = .distantPast
    
    private var pollingTask: Task<Void, Never>? = nil
    private var countdownTask: Task<Void, Never>? = nil
    
    private func loadFromUserDefaults() {
        let ud = UserDefaults.standard
        if let nextTs = ud.object(forKey: udNextKey) as? Date {
            self.nextAvailableAt = nextTs
        }
        self.claimed = ud.bool(forKey: udClaimedKey)
        if self.nextAvailableAt == nil && self.claimed {
            if let lastClaim = ud.object(forKey: "lastDailyClaim") as? Date {
                let candidate = lastClaim.addingTimeInterval(24 * 3600)
                if candidate.timeIntervalSinceNow > 0 {
                    self.nextAvailableAt = candidate
                }
            }
        }
        updateTimeRemainingFromServer()
    }
    
    private func saveToUserDefaults() {
        let ud = UserDefaults.standard
        if let next = nextAvailableAt {
            ud.set(next, forKey: udNextKey)
        } else {
            ud.removeObject(forKey: udNextKey)
        }
        ud.set(claimed, forKey: udClaimedKey)
    }
    
    init() {
        loadFromUserDefaults()
        updateTimeRemainingFromServer()
        startPolling()
        refresh()
        startCountdownTicker()
        
        // Poslušaj notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshFromNotification),
            name: Notification.Name("DailyLoginClaimedNotification"),
            object: nil
        )
    }
    
    deinit {
        pollingTask?.cancel()
        countdownTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func refreshFromNotification() {
        refresh()
    }
    
    func refresh() {
        ApiService.getUserStatus { claimed, nextAvailableAt in
            DispatchQueue.main.async {
                self.claimed = claimed
                self.nextAvailableAt = nextAvailableAt
                if self.nextAvailableAt == nil && self.claimed {
                    if let lastClaim = UserDefaults.standard.object(forKey: "lastDailyClaim") as? Date {
                        let candidate = lastClaim.addingTimeInterval(24 * 3600)
                        if candidate.timeIntervalSinceNow > 0 {
                            self.nextAvailableAt = candidate
                        }
                    }
                }
                self.lastServerFetch = Date()
                self.saveToUserDefaults()
                self.updateTimeRemainingFromServer()
                self.startCountdownTicker()
            }
        }
    }
    
    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    ApiService.getUserStatus { claimed, nextAvailableAt in
                        self.claimed = claimed
                        self.nextAvailableAt = nextAvailableAt
                        self.lastServerFetch = Date()
                        self.saveToUserDefaults()
                        self.updateTimeRemainingFromServer()
                        self.startCountdownTicker()
                        continuation.resume()
                    }
                }
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)
            }
        }
    }
    
    private func startCountdownTicker() {
        // Cancel any existing ticker
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let next = self?.nextAvailableAt, next.timeIntervalSinceNow > 0 else { return }
            while !Task.isCancelled {
                await MainActor.run {
                    self?.updateTimeRemainingFromServer()
                }
                if let next = self?.nextAvailableAt, next.timeIntervalSinceNow <= 0 {
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
    
    private func updateTimeRemainingFromServer() {
        if nextAvailableAt == nil && claimed {
            if let lastClaim = UserDefaults.standard.object(forKey: "lastDailyClaim") as? Date {
                let candidate = lastClaim.addingTimeInterval(24 * 3600)
                if candidate.timeIntervalSinceNow > 0 {
                    nextAvailableAt = candidate
                    startCountdownTicker()
                }
            }
        }
        guard let next = nextAvailableAt else {
            timeRemaining = claimed ? "00:00:00" : "Available now!"
            countdownTask?.cancel()
            return
        }
        let remaining = Int(next.timeIntervalSinceNow)
        if remaining > 0 {
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            let seconds = remaining % 60
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            timeRemaining = claimed ? "00:00:00" : "Available now!"
            countdownTask?.cancel()
        }
    }
}

