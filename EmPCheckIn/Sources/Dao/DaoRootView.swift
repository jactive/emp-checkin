import SwiftUI

struct DaoRootView: View {
    @State private var athletes: [Athlete]?
    @State private var store: CheckInStore?

    var body: some View {
        if let athletes, let store {
            DaoMainView(athletes: athletes, store: store)
        } else {
            LoginView(
                appCharacter: "到",
                subtitle: "Athlete Check-In · 2026 Track & Field",
                accentColor: .emeraldGreen,
                gradientColors: [.emeraldDark, .emeraldGreen, .emeraldLight]
            ) { name, password in
                let loaded = try CryptoService.decryptRoster([Athlete].self, from: EmbeddedData.athletesDaoData, password: password)
                self.athletes = loaded
                self.store = CheckInStore(operatorName: name, filename: "dao_log.json", appPrefix: "dao")
            }
        }
    }
}
