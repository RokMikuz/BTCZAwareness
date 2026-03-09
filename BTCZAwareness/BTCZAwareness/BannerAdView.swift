import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    let adUnitId: String

    init(adUnitId: String = AdMobIDs.bannerAdaptive) {
        self.adUnitId = adUnitId
    }

    var body: some View {
        GeometryReader { geo in
            BannerRepresentable(adUnitId: adUnitId, availableWidth: geo.size.width)
                .frame(width: geo.size.width, height: 0)
        }
        .frame(height: 60) // provide reasonable space; SDK will size the banner height
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    let adUnitId: String
    let availableWidth: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = adUnitId
        banner.rootViewController = rootViewController()
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // Clamp width to a sensible minimum/maximum for adaptive banners
        let width = max(320, min(availableWidth, UIScreen.main.bounds.width))
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        if uiView.adSize.size != adSize.size {
            uiView.adSize = adSize
            uiView.load(Request())
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func rootViewController() -> UIViewController? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.rootViewController
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {}
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner failed to load: \(error.localizedDescription)")
        }
    }
}
