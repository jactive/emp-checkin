import SwiftUI

struct TongRootView: View {
    @State private var athletes: [Athlete]?
    @State private var volunteers: [Volunteer]?

    var body: some View {
        if let athletes, let volunteers {
            TongMainView(athletes: athletes, volunteers: volunteers)
        } else {
            LoginView(
                appCharacter: "通",
                subtitle: "Admin Lookup · Full Contact Info",
                accentColor: .warmSlate,
                gradientColors: [.warmSlateDark, .warmSlate, .warmSlateLight]
            ) { _, password in
                self.athletes = try CryptoService.decryptRoster([Athlete].self, from: EmbeddedData.athletesTongData, password: password)
                self.volunteers = try CryptoService.decryptRoster([Volunteer].self, from: EmbeddedData.volunteersTongData, password: password)
            }
        }
    }
}
