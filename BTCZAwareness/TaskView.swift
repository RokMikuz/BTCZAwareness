// TasksView.swift – 100 % CELOTNA – Z BTCZ LOGOM V HEADERJU + PULSE ANIMACIJO
import SwiftUI
import UIKit

struct TasksView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    @State private var tasks: [AppTask] = []
    @State private var isLoading = true
    @StateObject private var dailyLoginStatus = DailyLoginStatus()
    @State private var quizAvailable = true
    @State private var showQuiz = false
    
    @State private var showServerError = false
    @State private var serverErrorMessage = "Server is currently unavailable. Please try again later."
    
    // HASHTAGI IZ CONFIGA
    @State private var shareHashtags = "#BTCZ #BitcoinZ #PrivacyCoin"
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // HEADER Z BACK GUMBOM + BTCZ LOGO
                    HStack {
                        Spacer()
                        
                        // BTCZ LOGO Z RAHLIM PULSE EFEKTOM
                        Image("btcz_logo")  // tvoj logo v Assets
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .shadow(color: .yellow.opacity(0.6), radius: 10)
                            .symbolEffect(.pulse)
                        
                        Spacer(minLength: 15)
                        
                        Text("Tasks")
                            .font(.largeTitle.bold())
                            .foregroundStyle(
                                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                        
                        Spacer()
                        
                        // Invisible placeholder za centriranje
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.clear)
                            .padding()
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    
                    if isLoading {
                        ProgressView("Loading tasks...")
                            .scaleEffect(1.5)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if tasks.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 80))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No active tasks")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(tasks) { task in
                                    TaskCard(
                                        task: task,
                                        dailyLoginStatus: dailyLoginStatus,
                                        quizAvailable: quizAvailable,
                                        showQuiz: $showQuiz,
                                        shareHashtags: shareHashtags
                                    )
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(task.id) * 0.1), value: isLoading)
                                }
                            }
                            .padding(20)
                            .padding(.bottom, 60)
                        }
                    }
                    
                    // Banner at bottom (adaptive, centered)
                    HStack {
                        BannerAdView(adUnitId: AdMobIDs.banner)
                            .frame(maxWidth: 600) // cap width for tablets
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
//            .navigationBarHidden(true)
            .onAppear {
                loadTasks()
                
                ApiService.onServerError = { message in
                    self.serverErrorMessage = message
                    self.showServerError = true
                }
                
                // Naloži hashtags iz configa
                ApiService.getConfig { config in
                    if let hashtags = config["share_hashtags"] as? String, !hashtags.isEmpty {
                        DispatchQueue.main.async {
                            self.shareHashtags = hashtags
                        }
                    }
                }
            }
            .refreshable {
                loadTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DailyLoginClaimedNotification"))) { _ in
                dailyLoginStatus.refresh()
                loadTasks()
            }
            .navigationDestination(isPresented: $showQuiz) {
                SimpleQuestionsView()
            }
            .alert("Server Error", isPresented: $showServerError) {
                Button("OK") { }
            } message: {
                Text(serverErrorMessage)
            }
            .navigationBarBackButtonHidden(true)
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
    }
    
    private func loadTasks() {
        isLoading = true
        ApiService.fetchTasks { fetchedTasks in
            DispatchQueue.main.async {
                self.tasks = fetchedTasks
                self.isLoading = false
                
                ApiService.isQuizCompleted { done in
                    DispatchQueue.main.async {
                        self.quizAvailable = !done
                    }
                }
            }
        }
    }
}

// TASK CARD – DODANA NAGRADA ZA SHARE TASKE + NATIVE SHARE
struct TaskCard: View {
    let task: AppTask
    @ObservedObject var dailyLoginStatus: DailyLoginStatus
    let quizAvailable: Bool
    @Binding var showQuiz: Bool
    let shareHashtags: String
    
    @State private var isTapped = false
    @State private var lockedGlow = false
    
    @Environment(\.openURL) private var openURL
    
    var isLocked: Bool {
        if task.type == "daily_login" || task.type == "daily" {
            return dailyLoginStatus.claimed
        } else if task.type == "quiz" {
            return !quizAvailable
        } else {
            return false
        }
    }
    
    // PRIVZETA SLIKA PO PLATFORMI ALI TIPU
    private var defaultImageName: String {
        if task.platform?.lowercased() == "facebook" || task.type == "share_fb" {
            return "facebook.logo"
        } else if task.platform?.lowercased() == "x" || task.platform?.lowercased() == "twitter" || task.type == "share_x" {
            return "x.logo"
        } else {
            return "photo"
        }
    }
    
    var body: some View {
        ZStack {
            Button(action: {
                isTapped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isTapped = false
                }
                
                if let type = task.type {
                    switch type {
                    case "quiz":
                        showQuiz = true
                        
                    case "social", "share_fb", "share_x":
                        if let link = task.link, !link.isEmpty, let url = URL(string: link) {
                            openURL(url)
                            ApiService.completeTask(taskId: String(task.id)) { success in
                                DispatchQueue.main.async {
                                    if success {
                                        ApiService.getConfig { cfg in
                                            let reward = (cfg["funfact_share_reward"] as? Int) ?? task.points
                                            ApiService.addPoints(amount: reward) { ok, _, newPoints in
                                                if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
                                            }
                                        }
                                    }
                                }
                            }
                            return
                        }
                        
                        if task.platform?.lowercased() == "facebook" || type == "share_fb" {
                            shareOnFacebook(text: task.text ?? "Check out BTCZ Awareness app!", hashtags: shareHashtags) { completed in
                                if completed {
                                    ApiService.completeTask(taskId: String(task.id)) { success in
                                        DispatchQueue.main.async {
                                            if success {
                                                ApiService.getConfig { cfg in
                                                    let reward = (cfg["funfact_share_reward"] as? Int) ?? task.points
                                                    ApiService.addPoints(amount: reward) { ok, _, newPoints in
                                                        if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } else if task.platform?.lowercased() == "x" || task.platform?.lowercased() == "twitter" || type == "share_x" {
                            shareOnX(text: task.text ?? "I'm earning BTCZ with this app!", hashtags: shareHashtags)
                            ApiService.completeTask(taskId: String(task.id)) { success in
                                DispatchQueue.main.async {
                                    if success {
                                        ApiService.getConfig { cfg in
                                            let reward = (cfg["funfact_share_reward"] as? Int) ?? task.points
                                            ApiService.addPoints(amount: reward) { ok, _, newPoints in
                                                if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                    case "daily_login", "daily":
                        ApiService.completeTask(taskId: "101") { success in
                            DispatchQueue.main.async {
                                if success {
                                    UserDefaults.standard.set(Date(), forKey: "lastDailyClaim")
                                    dailyLoginStatus.refresh()
                                    ApiService.getConfig { cfg in
                                        let reward = (cfg["daily_login_reward"] as? Int) ?? task.points
                                        ApiService.addPoints(amount: reward) { ok, _, newPoints in
                                            if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
                                        }
                                    }
                                    NotificationCenter.default.post(name: Notification.Name("DailyLoginClaimedNotification"), object: nil)
                                }
                            }
                        }
                        
                    default:
                        if let link = task.link, let url = URL(string: link) {
                            openURL(url)
                        }
                    }
                }
            }) {
                ZStack {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            if (task.type == "daily_login" || task.type == "daily") && dailyLoginStatus.claimed {
                                Text("Locked for today")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .bold()
                            } else if task.type == "quiz" && !quizAvailable {
                                Text("Quiz completed today")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.8))
                                    .bold()
                            }
                            
                            Text(task.title)
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                            
                            if let subtitle = task.subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            HStack {
                                Image(systemName: "bitcoinsign.circle.fill")
                                    .foregroundStyle(.yellow)
                                Text("+\(task.points) BTCZ")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                            }
                        }
                        
                        Spacer()
                        
                        Group {
                            if let image = task.image, !image.isEmpty {
                                AsyncImage(url: URL(string: ApiService.baseURL + image)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ), lineWidth: 1.5
                                                    )
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                                    .shadow(color: Color.orange.opacity(0.6), radius: 8)
                                            )
                                            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                                    case .failure:
                                        Image(systemName: defaultImageName)
                                            .font(.system(size: 30))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 80, height: 80)
                                            .background(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ), lineWidth: 1.5
                                                    )
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                                    .shadow(color: Color.orange.opacity(0.6), radius: 8)
                                            )
                                            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                                    case .empty:
                                        ProgressView()
                                    @unknown default:
                                        Image(systemName: defaultImageName)
                                            .font(.system(size: 30))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 80, height: 80)
                                            .background(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ), lineWidth: 1.5
                                                    )
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                                    .shadow(color: Color.orange.opacity(0.6), radius: 8)
                                            )
                                            .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                                    }
                                }
                            } else {
                                Image(systemName: defaultImageName)
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 80, height: 80)
                                    .background(Circle().fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ), lineWidth: 1.5
                                            )
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                            .shadow(color: Color.orange.opacity(0.6), radius: 8)
                                    )
                                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.black.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 1.5
                                    )
                            )
                    )
                    .cornerRadius(20)
                    .scaleEffect(isTapped ? 0.95 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isTapped)
                    
                    if isLocked {
                        Color.black.opacity(0.35)
                            .blur(radius: 4)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.red.opacity(0.7), lineWidth: 3)
                                    .shadow(color: Color.red.opacity(0.5), radius: 18)
                                    .scaleEffect(lockedGlow ? 1.05 : 0.95)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: lockedGlow
                                    )
                            )
                            .cornerRadius(20)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.white.opacity(0.8))
                            .scaleEffect(lockedGlow ? 1.1 : 0.9)
                            .animation(
                                Animation.spring(response: 0.5, dampingFraction: 0.5)
                                    .repeatForever(autoreverses: true),
                                value: lockedGlow
                            )
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLocked)
            .onAppear {
                lockedGlow = isLocked
            }
            .onChange(of: isLocked) { newValue in
                lockedGlow = newValue
            }
        }
    }
    
    // NATIVE SHARE ZA FACEBOOK – UIActivityViewController
    private func shareOnFacebook(text: String, hashtags: String, completion: @escaping (Bool) -> Void) {
        let shareText = "\(text)\n\(hashtags)"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .markupAsPDF,
            .print
        ]
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // NATIVE SHARE ZA X
    private func shareOnX(text: String, hashtags: String) {
        let shareText = "\(text)\n\(hashtags)"
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let xAppURL = URL(string: "twitter://post?message=\(encodedText)")!
        let xWebURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)")!
        
        if UIApplication.shared.canOpenURL(xAppURL) {
            openURL(xAppURL)
        } else {
            openURL(xWebURL)
        }
    }
}

#Preview {
    TasksView()
}

