import SwiftUI

struct DaoRootView: View {
    // Step 1: Age selection (before login)
    @State private var availableAges: [Int] = []
    @State private var selectedAges: Set<Int> = []
    @State private var ageSelectionComplete = false
    
    // Step 2: Login and main view
    @State private var allAthletes: [Athlete]?
    @State private var store: CheckInStore?

    var body: some View {
        if let allAthletes, let store {
            // Step 3: Main check-in view
            DaoMainView(
                athletes: allAthletes,
                store: store,
                selectedAges: selectedAges
            )
        } else if ageSelectionComplete {
            // Step 2: Login screen
            LoginView(
                appCharacter: "到",
                subtitle: "Athlete Check-In · 2026 Track & Field",
                accentColor: .emeraldGreen,
                gradientColors: [.emeraldDark, .emeraldGreen, .emeraldLight]
            ) { name, password in
                let loaded = try CryptoService.decryptRoster([Athlete].self, from: EmbeddedData.athletesDaoData, password: password)
                self.allAthletes = loaded
                self.store = CheckInStore(operatorName: name, filename: "dao_log.json", appPrefix: "dao")
            }
        } else {
            // Step 1: Age selection screen (before login)
            AgeSelectionView(
                availableAges: availableAges,
                selectedAges: $selectedAges,
                onContinue: { ageSelectionComplete = true }
            )
            .onAppear { loadAvailableAges() }
        }
    }
    
    private func loadAvailableAges() {
        // Load ages from embedded data (generated from roster)
        if availableAges.isEmpty {
            availableAges = EmbeddedData.availableAgesDao
        }
    }
}

// MARK: - Age Selection View

struct AgeSelectionView: View {
    let availableAges: [Int]
    @Binding var selectedAges: Set<Int>
    let onContinue: () -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    private var allSelected: Bool {
        selectedAges.count == availableAges.count && !availableAges.isEmpty
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.emeraldDark, .emeraldGreen, .emeraldLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Header
                VStack(spacing: 6) {
                    Text("EmP 到")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Select Ages / 选择年龄")
                        .font(.headline).foregroundStyle(.white.opacity(0.9))
                    Text("Tap ages you will check in")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text("点击您负责签到的年龄")
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                
                // Age grid + All button
                VStack(spacing: 10) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(availableAges, id: \.self) { age in
                            ageButton(age)
                        }
                        // "All" button in the same grid
                        allButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.15))
                )
                .padding(.horizontal, 20)
                
                // Selected summary
                if !selectedAges.isEmpty {
                    let sortedAges = selectedAges.sorted()
                    let agesText = allSelected ? "All ages / 所有年龄" : sortedAges.map(String.init).joined(separator: ", ")
                    Text("Selected: \(agesText)")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
                
                Spacer()
                
                // Continue button
                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
                        Text("继续")
                            .foregroundStyle(.white.opacity(0.8))
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedAges.isEmpty ? Color.white.opacity(0.3) : Color.white.opacity(0.4))
                    )
                }
                .disabled(selectedAges.isEmpty)
                .padding(.horizontal, 40)
                
                Text("Cannot change after login. Close app to restart.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
                Text("登录后无法更改。关闭应用重新开始。")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
                
                Spacer().frame(height: 30)
            }
        }
    }
    
    private func ageButton(_ age: Int) -> some View {
        let isSelected = selectedAges.contains(age)
        return Button {
            if isSelected {
                selectedAges.remove(age)
            } else {
                selectedAges.insert(age)
            }
        } label: {
            Text("\(age)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                )
                .foregroundStyle(isSelected ? Color.emeraldGreen : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Color.emeraldGreen : Color.clear, lineWidth: 2)
                )
        }
    }
    
    private var allButton: some View {
        Button {
            if allSelected {
                selectedAges.removeAll()
            } else {
                selectedAges = Set(availableAges)
            }
        } label: {
            Text("All")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(allSelected ? Color.white : Color.white.opacity(0.3))
                )
                .foregroundStyle(allSelected ? Color.emeraldGreen : .white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(allSelected ? Color.emeraldGreen : Color.clear, lineWidth: 2)
                )
        }
    }
}
