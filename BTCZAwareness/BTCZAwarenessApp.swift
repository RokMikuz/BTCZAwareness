import SwiftUI

@main
struct BTCZAwarenessApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    PointsManager.shared.syncWithServer()
                }
                .onChange(of: scenePhase) { newPhase in // POPRAVLJENO za iOS 17+
                    if newPhase == .active {
                        PointsManager.shared.syncWithServer()
                    }
                }
        }
    }
}
