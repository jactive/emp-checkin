import SwiftUI

struct QianRootView: View {
    @State private var volunteers: [Volunteer]?
    @State private var store: CheckInStore?

    var body: some View {
        if let volunteers, let store {
            QianMainView(volunteers: volunteers, store: store)
        } else {
            LoginView(
                appCharacter: "签",
                subtitle: "Volunteer Check-In · 2026 Track & Field",
                accentColor: .deepPurple,
                gradientColors: [.deepPurpleDark, .deepPurple, .deepPurpleLight]
            ) { name, password in
                let loaded = try CryptoService.decryptRoster([Volunteer].self, from: EmbeddedData.volunteersQianData, password: password)
                self.volunteers = loaded
                self.store = CheckInStore(operatorName: name, filename: "qian_log.json", appPrefix: "qian")
            }
        }
    }
}
