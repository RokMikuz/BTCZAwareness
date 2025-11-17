// RewardedVideoManager.swift – 100 % DELUJOČA, BREZ EXC_BAD_ACCESS
import GoogleMobileAds
import UIKit
import Combine

struct FeatureFlags {
    // Enable test ads (sample AdMob ad unit) for Debug and TestFlight builds.
    // In App Store production installs, use real ads.
    // Additionally: allow a one-time simulator probe with real ads for debugging.

    // Key used to persist that we've already attempted a real-ads-in-simulator probe.
    private static let simulatorProbeTriedKey = "RealAdsSimulatorProbeTried"

    // Set this to true temporarily if you want to force a single real-ads attempt on simulator.
    // After the first attempt (regardless of success/failure), we mark it as tried and revert to normal behavior.
    static var enableOneTimeRealAdsProbeOnSimulator: Bool {
        get { UserDefaults.standard.bool(forKey: "EnableOneTimeRealAdsProbeOnSimulator") }
        set { UserDefaults.standard.set(newValue, forKey: "EnableOneTimeRealAdsProbeOnSimulator") }
    }

    // Whether we have already tried the probe at least once on this device/simulator.
    static var hasTriedSimulatorProbe: Bool {
        get { UserDefaults.standard.bool(forKey: simulatorProbeTriedKey) }
        set { UserDefaults.standard.set(newValue, forKey: simulatorProbeTriedKey) }
    }

    // Global verbose logging toggle for ads.
    #if DEBUG
    static var verboseAdLogging: Bool = true
    #else
    static var verboseAdLogging: Bool = false
    #endif

    #if DEBUG
    static var forceRealAdsOverride: Bool = true
    #else
    static var forceRealAdsOverride: Bool = false
    #endif

    // Computed flag that decides if we should use test ads for this run.
    static var useTestAds: Bool {
        if forceRealAdsOverride {
            if verboseAdLogging { print("[ADS][FLAGS] forceRealAdsOverride=TRUE -> using REAL ads.") }
            return false
        }
        #if targetEnvironment(simulator)
        // On simulator: normally test ads. If a one-time probe is enabled and not yet tried, allow real ads once.
        if enableOneTimeRealAdsProbeOnSimulator && !hasTriedSimulatorProbe {
            if verboseAdLogging { print("[ADS][FLAGS] Simulator one-time real-ads probe is ENABLED and not yet tried -> using REAL ads for this attempt.") }
            return false // use real ads for this one attempt
        }
        if verboseAdLogging { print("[ADS][FLAGS] Simulator -> using TEST ads.") }
        return true
        #else
        #if DEBUG
        if verboseAdLogging { print("[ADS][FLAGS] DEBUG build on device -> using TEST ads.") }
        return true
        #else
        // TestFlight builds have a sandbox receipt; App Store builds have a production receipt
        let isSandboxReceipt = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        if verboseAdLogging { print("[ADS][FLAGS] Device build -> sandboxReceipt=\(isSandboxReceipt) -> \(isSandboxReceipt ? "TEST" : "REAL") ads.") }
        return isSandboxReceipt
        #endif
        #endif
    }
}

@MainActor
class RewardedVideoManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var isAdReady: Bool = false
    
    private static var rewardedAdUnitId: String {
        if FeatureFlags.useTestAds {
            // Google sample rewarded ad unit ID (always returns test ads)
            return "ca-app-pub-3940256099942544/5224354917"
        } else {
            return AdMobIDs.rewarded
        }
    }
    
    static let shared = RewardedVideoManager()
    
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var pendingCompletion: ((Bool, Error?) -> Void)?
    private var hasClaimedRewardForCurrentAd = false
    
    private var activePresentationCompletion: ((Bool, Error?) -> Void)?
    private var pendingPresentationResult: (Bool, Error?)?
    
    private func consumeSimulatorProbeIfNeeded() {
        #if targetEnvironment(simulator)
        if FeatureFlags.enableOneTimeRealAdsProbeOnSimulator && !FeatureFlags.hasTriedSimulatorProbe {
            if FeatureFlags.verboseAdLogging { print("[ADS][PROBE] Consuming simulator real-ads probe flag (this run will be considered the one attempt).") }
            FeatureFlags.hasTriedSimulatorProbe = true
            FeatureFlags.enableOneTimeRealAdsProbeOnSimulator = false
        }
        #endif
    }
    
    private override init() {
        super.init()
        if FeatureFlags.verboseAdLogging {
            print("[ADS][INIT] RewardedVideoManager init. useTestAds=\(FeatureFlags.useTestAds)")
        }
        loadAd()
    }
    
    func loadAd() {
        guard !isLoading else { return }
        isLoading = true
        isAdReady = false
        
        if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Starting load. mode=\(FeatureFlags.useTestAds ? "TEST" : "REAL")") }
        if FeatureFlags.verboseAdLogging {
            print("[ADS][STATE] isLoading=\(isLoading), isAdReady=\(isAdReady), pendingCompletion != nil? \(pendingCompletion != nil)")
        }
        consumeSimulatorProbeIfNeeded()
        
        if FeatureFlags.useTestAds {
            if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Configuring test device identifiers for simulator/test.") }
            MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [ "SIMULATOR" ]
        } else {
            if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Using REAL ad unit id: \(Self.rewardedAdUnitId)") }
        }
        
        let request = Request()
        // Enable non-personalized ads (NPA) as a global fallback to improve fill in strict regions.
        // If you later want to make this conditional on consent, move this behind a check.
        if true {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        
        if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Calling RewardedAd.load with unitId=\(Self.rewardedAdUnitId)") }
        RewardedAd.load(with: Self.rewardedAdUnitId, request: request) { [weak self] ad, error in
            // Hop to the main actor before mutating any @MainActor-isolated state
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoading = false
                
                if let ad = ad {
                    if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Ad loaded successfully.") }
                    self.rewardedAd = ad
                    self.rewardedAd?.fullScreenContentDelegate = self
                    self.isAdReady = true
                    self.hasClaimedRewardForCurrentAd = false
                    
                    if FeatureFlags.verboseAdLogging {
                        print("[ADS][STATE] After load success: isLoading=\(self.isLoading), isAdReady=\(self.isAdReady), hasClaimedRewardForCurrentAd=\(self.hasClaimedRewardForCurrentAd)")
                    }
                    
                    if let completion = self.pendingCompletion {
                        completion(false, NSError(domain: "RewardedVideoManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Ad loaded; waiting for presenter"]))
                        self.pendingCompletion = nil
                    }
                } else if let error = error {
                    if FeatureFlags.verboseAdLogging { print("[ADS][LOAD] Failed to load ad: \(error.localizedDescription)") }
                    if FeatureFlags.verboseAdLogging {
                        print("[ADS][RETRY] Scheduling reload in 5s due to load error.")
                    }
                    self.isAdReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.loadAd()
                    }
                }
            }
        }
    }
    
    func showAd(from presenter: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        if FeatureFlags.verboseAdLogging { print("[ADS][SHOW] showAd called. isAdReady=\(isAdReady), rewardedAd != nil? \(rewardedAd != nil)") }
        if let ad = rewardedAd {
            presentAdIfReady(from: presenter, completion: completion)
        } else {
            if FeatureFlags.verboseAdLogging { print("[ADS][SHOW] No ad yet. Setting pendingCompletion and calling loadAd().") }
            // print("Oglas še ni naložen – čakam...")
            pendingCompletion = { [weak self, weak presenter] success, error in
                guard let self = self, let presenter = presenter else { return }
                if success {
                    completion(true, nil)
                } else if let ad = self.rewardedAd {
                    self.presentAdIfReady(from: presenter, completion: completion)
                } else {
                    completion(false, error)
                }
            }
            loadAd()
        }
    }
    
    private func presentAdIfReady(from presenter: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let ad = rewardedAd else {
            if FeatureFlags.verboseAdLogging { print("[ADS][PRESENT] ERROR: No ad loaded; cannot present.") }
            let error = NSError(domain: "RewardedVideoManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ad loaded"])
            completion(false, error)
            return
        }
        
        if FeatureFlags.verboseAdLogging { print("[ADS][PRESENT] About to present. isAdReady(before)=\(isAdReady)") }
        if FeatureFlags.verboseAdLogging { print("[ADS][PRESENT] Presenting ad from presenter. useTestAds=\(FeatureFlags.useTestAds)") }
        isAdReady = false
        self.activePresentationCompletion = completion
        ad.present(from: presenter) {
            // Ensure we only claim once per ad presentation
            if FeatureFlags.verboseAdLogging { print("[ADS][REWARD] Reward closure entered. hasClaimed=\(self.hasClaimedRewardForCurrentAd)") }
            guard !self.hasClaimedRewardForCurrentAd else {
                // Already claimed for this ad; do nothing here
                return
            }
            self.hasClaimedRewardForCurrentAd = true
            
            if FeatureFlags.verboseAdLogging { print("[ADS][REWARD] Reward triggered. Calling ApiService.rewardVideo...") }
            ApiService.rewardVideo { success, message, newPoints in
                if FeatureFlags.verboseAdLogging { print("[ADS][REWARD] ApiService.rewardVideo completed. success=\(success), message=\(message ?? "nil")") }
                DispatchQueue.main.async {
                    if success {
                        if let np = newPoints {
                            PointsManager.shared.currentPoints = np
                        } else {
                            PointsManager.shared.syncWithServer()
                        }
                    }
                    // Defer notifying the caller until the ad is dismissed; store the result now.
                    let err: Error? = success ? nil : NSError(domain: "RewardedVideoManager", code: -3, userInfo: [NSLocalizedDescriptionKey: message ?? "Reward failed"])
                    self.pendingPresentationResult = (success, err)
                }
            }
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if FeatureFlags.verboseAdLogging { print("[ADS][DISMISS] Ad dismissed. hasClaimedRewardForCurrentAd=\(hasClaimedRewardForCurrentAd)") }
        if hasClaimedRewardForCurrentAd {
            // Use stored result from reward flow if available; default to success if nil
            let result = pendingPresentationResult ?? (true, nil)
            activePresentationCompletion?(result.0, result.1)
            activePresentationCompletion = nil
            pendingPresentationResult = nil
        } else {
            if FeatureFlags.verboseAdLogging { print("[ADS][DISMISS] No reward claimed before dismiss. Reporting failure to caller.") }
            let err = NSError(domain: "RewardedVideoManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Ad dismissed before reward"])
            activePresentationCompletion?(false, err)
            activePresentationCompletion = nil
        }
        if FeatureFlags.verboseAdLogging { print("[ADS][DISMISS] Ad dismissed. isAdReady(before)=\(isAdReady). Reloading…") }
        // print("Oglas zaprt – ponovno nalagam")
        isAdReady = false
        loadAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        if FeatureFlags.verboseAdLogging { print("[ADS][FAIL] didFailToPresent with error=\(error.localizedDescription). isAdReady(before)=\(isAdReady)") }
        // print("Napaka pri prikazu oglasa: \(error.localizedDescription)")
        pendingCompletion?(false, error)
        pendingCompletion = nil
        activePresentationCompletion?(false, error)
        activePresentationCompletion = nil
        isAdReady = false
        loadAd()
    }
}

