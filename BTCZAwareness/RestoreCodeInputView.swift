import SwiftUI

struct RestoreCodeInputView: View {
    @State private var code: String = ""
    @State private var isRestoring = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showAlert = false

    @ObservedObject private var pointsManager = PointsManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter Restore Code")
                .font(.title2.bold())
            TextField("Restore Code", text: $code)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(.horizontal)
            Button(action: restore) {
                if isRestoring {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Restore")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRestoring)
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Text("Use the restore code you generated on your previous device to recover your progress.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func restore() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isRestoring = true
        ApiService.registerWithRestore(restoreCode: trimmed) { success, message in
            DispatchQueue.main.async {
                self.isRestoring = false
                if success {
                    self.alertTitle = "Success"
                    self.alertMessage = message
                    self.showAlert = true
                    // Refresh points from server as the source of truth
                    self.pointsManager.syncWithServer()
                } else {
                    self.alertTitle = "Restore Failed"
                    self.alertMessage = message
                    self.showAlert = true
                }
            }
        }
    }
}
