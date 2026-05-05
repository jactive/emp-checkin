import SwiftUI

/// Pre-export confirmation sheet with PIN gate.
/// Shown before the system AirDrop share sheet.
struct ExportConfirmView: View {
    let checkInCount: Int
    let accentColor: Color
    let onSend: () -> Void
    let onCancel: () -> Void

    @State private var digits: [String] = ["", "", "", ""]
    @FocusState private var focusedField: Int?

    private let correctPin = Secrets.exportPIN

    private var enteredPin: String { digits.joined() }
    private var isPinCorrect: Bool { enteredPin == correctPin }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("📤 Send check-in records")
                    .font(.title3).fontWeight(.semibold)
                Text("\(checkInCount) check-ins on this device")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            VStack(spacing: 10) {
                Text("Enter PIN").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(0..<4) { i in
                        pinBox(i)
                    }
                }
            }

            Spacer()

            Button {
                onSend()
            } label: {
                Text("Send via AirDrop")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
            .disabled(!isPinCorrect)

            Button("Not now") { onCancel() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = 0
            }
        }
    }

    private func pinBox(_ index: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[index] },
            set: { new in
                // Keep only digits, max 1 char
                let filtered = new.filter(\.isNumber)
                if filtered.count > 1 {
                    // Handle paste — fill subsequent boxes
                    for (j, c) in filtered.prefix(4 - index).enumerated() {
                        if index + j < 4 { digits[index + j] = String(c) }
                    }
                    focusedField = min(index + filtered.count, 3)
                } else {
                    digits[index] = String(filtered.prefix(1))
                    if !filtered.isEmpty && index < 3 {
                        focusedField = index + 1
                    }
                }
            }
        ))
        .keyboardType(.numberPad)
        .textContentType(.none)
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .multilineTextAlignment(.center)
        .frame(width: 60, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .strokeBorder(
                    focusedField == index ? accentColor : Color.clear,
                    lineWidth: 2
                )
        )
        .focused($focusedField, equals: index)
    }
}
