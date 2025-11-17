import SwiftUI

struct TasksView: View {
    @State private var tasks: [AppTask] = []
    @State private var isLoading = false

    var body: some View {
        ZStack {
            gradientBackground
            
            if PointsManager.shared.hasWallet {
                VStack {
                    if isLoading {
                        ProgressView("Loading tasks...")
                            .scaleEffect(1.5)
                            .foregroundStyle(.white)
                    } else if filteredTasks.isEmpty {
                        Text("No active tasks")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible())], spacing: 22) {
                                ForEach(filteredTasks) { task in
                                    TaskCard(task: task, onTap: {
                                        completeTask(task)
                                    })
                                }
                            }
                            .padding()
                        }
                    }
                }
            } else {
                walletRequiredView
            }
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if PointsManager.shared.hasWallet {
                loadTasks()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .walletAdded)) { _ in
            loadTasks()
        }
        .refreshable {
            if PointsManager.shared.hasWallet {
                loadTasks()
            }
        }
    }
    
    // MARK: - Filtriraj taske (brez "Create wallet" taska – ID=1)
    private var filteredTasks: [AppTask] {
        tasks.filter { $0.id != 1 }
    }
    
    // MARK: - Naloži taske
    private func loadTasks() {
        isLoading = true
        ApiService.fetchTasksFromAPI { fetchedTasks in
            DispatchQueue.main.async {
                self.tasks = fetchedTasks
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Opravi task
    private func completeTask(_ task: AppTask) {
        ApiService.completeTask(taskId: String(task.id)) { success in
            DispatchQueue.main.async {
                if success {
                    PointsManager.shared.syncWithServer() // Pridobi nove točke s serverja
                }
            }
        }
    }
    
    // MARK: - Wallet required view
    private var walletRequiredView: some View {
        VStack(spacing: 40) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 120))
                .foregroundStyle(.orange)
            
            Text("Verify Wallet to Unlock Tasks!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            NavigationLink(destination: WalletView()) {
                Text("Verify Wallet & Get 100 BTCZ")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(20)
            }
            .padding(.horizontal, 50)
        }
    }
    
    // MARK: - Gradient
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

// MARK: - TaskCard (ostane enak kot prej)
struct TaskCard: View {
    let task: AppTask
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: taskIcon)
                    .font(.system(size: 60))
                    .foregroundStyle(taskColor)
                
                Text(task.title)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text(task.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("+\(task.points) BTCZ")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.green)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(taskColor.opacity(0.6), lineWidth: 3))
            .shadow(color: taskColor.opacity(0.4), radius: 15)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var taskIcon: String {
        switch task.type?.lowercased() {
        case "daily": return "calendar.circle.fill"
        case "social": return "square.and.arrow.up.fill"
        default: return "star.circle.fill"
        }
    }
    
    private var taskColor: Color {
        switch task.type?.lowercased() {
        case "daily": return .green
        case "social": return .blue
        default: return .yellow
        }
    }
}
