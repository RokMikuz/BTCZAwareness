// ProfileView.swift – 100 % CELOTNA – V POPOLNEM STILU APLIKACIJE – TEMEN GRADIENT, ANIMACIJE, KARTICE – V ANGLEŠČINI!
import SwiftUI

struct ProfileView: View {
    @ObservedObject private var pointsManager = PointsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    @State private var referralStats: [String: Any] = [:] // število referralov
    @State private var completedTasks: [AppTask] = []
    @State private var isLoading = true
    @State private var showShareSheet = false
    @State private var pointsScale = 1.0 // za animacijo točk
    @State private var restoreCode: String = ""

    @State private var showRestoreSheet = false
    @State private var codePart1 = ""
    @State private var codePart2 = ""
    @State private var codePart3 = ""
    @State private var restoreInProgress = false
    @State private var restoreMessage: String? = nil
    
    @State private var showDeleteSheet = false
    @State private var deleteVerificationText = ""
    @State private var isDeleting = false
    @State private var deleteError: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                // TEMNI GRADIENT V STILU APLIKACIJE
                LinearGradient(
                    colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading profile...")
                        .scaleEffect(1.5)
                        .foregroundStyle(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            Spacer().frame(height: 20)
                            
                            // TOČKE – ANIMIRANA
                            VStack(spacing: 10) {
                                Text("Your Balance")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Text("\(pointsManager.currentPoints) BTCZ")
                                    .font(.system(size: 60, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .shadow(color: .orange.opacity(0.8), radius: 20)
                                    .scaleEffect(pointsScale)
                                    .onAppear {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                                            pointsScale = 1.1
                                        }
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3)) {
                                            pointsScale = 1.0
                                        }
                                    }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 15)
                            
                            // REFERRAL SEKCIJA – ANIMIRANA
                            VStack(spacing: 15) {
                                Text("Referral Code")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Text(PointsManager.shared.referralCode)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.cyan)
                                    .scaleEffect(showShareSheet ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showShareSheet)
                                
                                HStack(spacing: 20) {
                                    Button {
                                        UIPasteboard.general.string = PointsManager.shared.referralCode
                                        // Dodaj alert "Copied!"
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.on.doc.fill")
                                            Text("Copy")
                                        }
                                        .font(.headline)
                                        .padding()
                                        .background(.cyan.opacity(0.8))
                                        .foregroundStyle(.black)
                                        .cornerRadius(16)
                                    }
                                    
                                    Button {
                                        showShareSheet = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Share")
                                        }
                                        .font(.headline)
                                        .padding()
                                        .background(.green.opacity(0.8))
                                        .foregroundStyle(.white)
                                        .cornerRadius(16)
                                    }
                                }
                                
                                Text("Referred users: \(referralStats["referred_count"] as? Int ?? 0)")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .cyan.opacity(0.4), radius: 15)
                            
                            // RESTORE KEY – CARD
                            VStack(spacing: 15) {
                                Text("Your Restore Key")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))

                                Text(restoreCode.isEmpty ? "— — —" : restoreCode)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(
                                        restoreCode.isEmpty ? .white.opacity(0.5) : .yellow
                                    )
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.6)

                                HStack(spacing: 20) {
                                    Button {
                                        if !restoreCode.isEmpty { UIPasteboard.general.string = restoreCode }
                                    } label: {
                                        HStack { Image(systemName: "doc.on.doc.fill"); Text("Copy") }
                                            .font(.headline)
                                            .padding()
                                            .background(.yellow.opacity(0.9))
                                            .foregroundStyle(.black)
                                            .cornerRadius(16)
                                    }
                                    .disabled(restoreCode.isEmpty)

                                    Button {
                                        if !restoreCode.isEmpty { showShareSheet = true }
                                    } label: {
                                        HStack { Image(systemName: "square.and.arrow.up"); Text("Share") }
                                            .font(.headline)
                                            .padding()
                                            .background(.purple.opacity(0.9))
                                            .foregroundStyle(.white)
                                            .cornerRadius(16)
                                    }
                                    .disabled(restoreCode.isEmpty)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .yellow.opacity(0.35), radius: 15)

                            // RESTORE ACCOUNT – CARD
                            VStack(spacing: 12) {
                                Text("Restore Account")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("Enter your 9-character restore key to link your account on this device.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Button {
                                    showRestoreSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                        Text("Restore Account")
                                    }
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.orange.opacity(0.9))
                                    .foregroundStyle(.black)
                                    .cornerRadius(16)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 15)
                            
                            // DELETE ACCOUNT – CARD (Apple requirement)
                            VStack(spacing: 12) {
                                Text("Delete Account")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("Permanently delete your account and all associated data. This action cannot be undone.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Button {
                                    deleteVerificationText = ""
                                    deleteError = nil
                                    showDeleteSheet = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Account")
                                    }
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.9))
                                    .foregroundStyle(.white)
                                    .cornerRadius(16)
                                }
                                .accessibilityLabel("Delete Account")
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .red.opacity(0.4), radius: 15)
                            
                            // OPRAVLJENI TASKI – ANIMIRANI
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Completed Tasks")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                
                                if completedTasks.isEmpty {
                                    Text("No completed tasks yet")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.7))
                                } else {
                                    ForEach(completedTasks) { task in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundStyle(.green)
                                                .symbolEffect(.pulse, options: .repeating)
                                            
                                            Text(task.title)
                                                .foregroundStyle(.white)
                                            
                                            Spacer()
                                            
                                            Text("+\(task.points) BTCZ")
                                                .foregroundStyle(.green)
                                        }
                                        .padding()
                                        .background(.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.green.opacity(0.4), lineWidth: 1)
                                        )
                                        .shadow(color: .green.opacity(0.3), radius: 10)
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 15)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { }
                        // Immediate dismiss for responsiveness
                        dismiss()
                        // Optionally reset visual state shortly after
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            backPressed = false
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                            .scaleEffect(backPressed ? 0.96 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: backPressed)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: [shareTextWithRestore])
            }
            .sheet(isPresented: $showRestoreSheet) { restoreSheet }
            .sheet(isPresented: $showDeleteSheet) { deleteSheet }
            .onAppear {
                loadProfileData()
                ApiService.getReferralStats { stats in
                    DispatchQueue.main.async {
                        if let code = stats?["referral_code"] as? String, !code.isEmpty {
                            PointsManager.shared.referralCode = code
                        }
                    }
                }
            }
        }
    }
    
    private func loadProfileData() {
        isLoading = true
        
        // 1. Referral stats – PO SERVERJU!
        ApiService.getReferralStats { stats in
            DispatchQueue.main.async {
                print("[RESTORE][PROFILE] GET /api/referral-stats -> fetching restore_code")
                self.referralStats = stats ?? [:]
                if let rc = stats?["restore_code"] as? String {
                    print("[RESTORE][PROFILE] restore_code=\(rc)")
                    self.restoreCode = rc
                } else {
                    print("[RESTORE][PROFILE] restore_code not present in response")
                }
            }
        }
        
        ApiService.getPointsWithRestore { points, code in
            DispatchQueue.main.async {
                if let code = code, !code.isEmpty {
                    self.restoreCode = code
                }
                // Optionally sync points into PointsManager if needed
                if points != self.pointsManager.currentPoints {
                    PointsManager.shared.currentPoints = points
                }
            }
        }
        
        // 2. Completed tasks – PO SERVERJU!
        ApiService.fetchCompletedTasks { fetchedTasks in
            DispatchQueue.main.async {
                self.completedTasks = fetchedTasks
                self.isLoading = false
            }
        }
    }
    
    private var shareText: String {
        "Join BTCZ and get 50 BTCZ bonus! Use my referral code: \(PointsManager.shared.referralCode)\n\nhttps://btczkviz.btcz.rocks/register?ref=\(PointsManager.shared.referralCode)"
    }
    
    private var shareTextWithRestore: String {
        var base = shareText
        if !restoreCode.isEmpty {
            base += "\n\nMy Restore Key: \(restoreCode)"
        }
        return base
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
    
    private var restoreSheet: some View {
        VStack(spacing: 20) {
            Text("Restore Account")
                .font(.title2.bold())
            Text("Enter your restore key")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TextField("123", text: $codePart1)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.center)
                    .keyboardType(.asciiCapable)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                Text("-")
                    .foregroundStyle(.secondary)
                TextField("123", text: $codePart2)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.center)
                    .keyboardType(.asciiCapable)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                Text("-")
                    .foregroundStyle(.secondary)
                TextField("123", text: $codePart3)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .multilineTextAlignment(.center)
                    .keyboardType(.asciiCapable)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
            }

            if let msg = restoreMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                let p1 = codePart1.trimmingCharacters(in: .whitespacesAndNewlines)
                let p2 = codePart2.trimmingCharacters(in: .whitespacesAndNewlines)
                let p3 = codePart3.trimmingCharacters(in: .whitespacesAndNewlines)
                let code = "\(p1)-\(p2)-\(p3)"
                guard p1.count == 3, p2.count == 3, p3.count == 3 else {
                    restoreMessage = "Please enter all three 3-character parts."
                    return
                }
                restoreInProgress = true
                restoreMessage = "Restoring..."
                ApiService.restoreAccount(restoreCode: code) { success, message in
                    DispatchQueue.main.async {
                        restoreInProgress = false
                        restoreMessage = message
                        if success {
                            // Mark onboarding done and refresh points/settings
                            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                            PointsManager.shared.syncWithServer()
                            // Optionally notify app to close onboarding if shown
                            NotificationCenter.default.post(name: Notification.Name("OnboardingCompletedNotification"), object: nil)
                            showRestoreSheet = false
                        }
                    }
                }
            } label: {
                if restoreInProgress {
                    ProgressView().tint(.white)
                } else {
                    Text("Restore")
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel", role: .cancel) {
                showRestoreSheet = false
            }
        }
        .padding()
    }
    
    private var deleteSheet: some View {
        VStack(spacing: 16) {
            Text("Confirm Deletion")
                .font(.title2.bold())
            Text("Type DELETE to confirm you want to permanently delete your account.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("Type DELETE", text: $deleteVerificationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .keyboardType(.asciiCapable)
                .textFieldStyle(.roundedBorder)
                .onChange(of: deleteVerificationText) { _, newValue in
                    deleteError = nil
                }

            if let err = deleteError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                guard deleteVerificationText.uppercased() == "DELETE" else {
                    deleteError = "Please type DELETE to proceed."
                    return
                }
                isDeleting = true
                deleteError = nil
                ApiService.deleteAccount(verification: deleteVerificationText.uppercased()) { success, message in
                    DispatchQueue.main.async {
                        isDeleting = false
                        if success {
                            // Clear local state, log out, and navigate away
                            PointsManager.shared.currentPoints = 0
                            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                            UserDefaults.standard.removeObject(forKey: "savedBTCZAddress")
                            NotificationCenter.default.post(name: Notification.Name("OnboardingResetRequested"), object: nil)
                            UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
                            NotificationCenter.default.post(name: Notification.Name("UserDeletedAccountNotification"), object: nil)
                            showDeleteSheet = false
                            dismiss()
                        } else {
                            deleteError = message ?? "Failed to delete account. Please try again."
                        }
                    }
                }
            } label: {
                if isDeleting {
                    ProgressView().tint(.white)
                } else {
                    Text("Delete Account")
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel", role: .cancel) {
                showDeleteSheet = false
            }
        }
        .padding()
    }
}

// SHARE SHEET
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ProfileView()
}

