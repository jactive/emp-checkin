import SwiftUI

struct LoginView: View {
    let appCharacter: String
    let subtitle: String
    let accentColor: Color
    let gradientColors: [Color]
    let onLogin: (String, String) throws -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isReady = false

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            if isReady {
                loginContent
            } else {
                VStack(spacing: 12) {
                    Text("EmP \(appCharacter)")
                        .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                    ProgressView().tint(.white)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.2)) { isReady = true }
            }
        }
    }

    private var loginContent: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 4) {
                Text("EmP \(appCharacter)")
                    .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            }
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("First Name").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        TextField("e.g. Jackie", text: $firstName)
                            .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Name").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        TextField("e.g. Chan", text: $lastName)
                            .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password").font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    TextField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                if let err = errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button { login() } label: {
                    if isLoading { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 14) }
                    else { Text("Unlock & Start →").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14) }
                }
                .buttonStyle(.borderedProminent).tint(accentColor)
                .disabled(firstName.isEmpty || lastName.isEmpty || password.isEmpty || isLoading)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24).fill(.regularMaterial))
            .padding(.horizontal, 24)
            Text("Data stored locally. No internet required.")
                .font(.caption2).foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
    }

    private func login() {
        isLoading = true; errorMessage = nil
        let first = firstName.trimmingCharacters(in: .whitespaces).capitalized
        let last = lastName.trimmingCharacters(in: .whitespaces).capitalized
        let fullName = "\(first) \(last)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            do { try onLogin(fullName, password) }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }
}
