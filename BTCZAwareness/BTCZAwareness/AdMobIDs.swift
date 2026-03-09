import Foundation

struct AdMobIDs {
    // Live AdMob unit IDs
    static let rewarded = "ca-app-pub-5181471839265609/9052584196"
    static let banner = "ca-app-pub-5181471839265609/5152049399"

    // Google sample test unit IDs
    private static let testRewarded = "ca-app-pub-3940256099942544/5224354917"
    private static let testBanner = "ca-app-pub-3940256099942544/2934735716"

    // Environment-aware getters
    static var rewardedAdaptive: String {
        if FeatureFlags.useTestAds { return testRewarded }
        return rewarded
    }

    static var bannerAdaptive: String {
        if FeatureFlags.useTestAds { return testBanner }
        return banner
    }
}
