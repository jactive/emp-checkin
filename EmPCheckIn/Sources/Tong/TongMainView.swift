import SwiftUI

struct TongMainView: View {
    let athletes: [Athlete]
    let volunteers: [Volunteer]
    @State private var query = ""
    @State private var tab = 0

    private var filteredAthletes: [Athlete] {
        query.isEmpty ? athletes : SearchService.searchAthletes(athletes, query: query)
    }
    private var filteredVolunteers: [Volunteer] {
        query.isEmpty ? volunteers : SearchService.searchVolunteers(volunteers, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EmP 通").font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Spacer()
                Text("Admin").font(.caption).foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(LinearGradient(colors: [.warmSlateDark, .warmSlate], startPoint: .leading, endPoint: .trailing))

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search name...", text: $query).autocorrectionDisabled().textInputAutocapitalization(.never)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
            }.padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6))).padding(16)

            Picker("", selection: $tab) {
                Text("Athletes (\(filteredAthletes.count))").tag(0)
                Text("Volunteers (\(filteredVolunteers.count))").tag(1)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if tab == 0 { ForEach(filteredAthletes) { a in athleteCard(a) } }
                    else { ForEach(filteredVolunteers) { v in volunteerCard(v) } }
                }.padding(.horizontal, 16).padding(.bottom, 100)
            }.background(Color(.systemGroupedBackground))
        }
    }

    private func athleteCard(_ a: Athlete) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(a.fullName).fontWeight(.semibold); Spacer(); Text("Bib #\(a.bibNumber)").font(.caption).foregroundStyle(.secondary) }
            Text("Age \(a.age) · \(a.gender)").font(.caption).foregroundStyle(.secondary)
            if !a.events.isEmpty { Text(a.events.joined(separator: ", ")).font(.caption).foregroundStyle(Color.emeraldGreen) }
            Divider()
            if !a.contactName.isEmpty { row("person.fill", "Contact", a.contactName) }
            if !a.shippingPhone.isEmpty { phoneRow("phone.fill", "Phone", a.shippingPhone) }
            if !a.contactEmail.isEmpty { row("envelope.fill", "Email", a.contactEmail) }
            if !a.contactWeChat.isEmpty { row("message.fill", "WeChat", a.contactWeChat) }
        }
        .font(.caption).padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white).shadow(color: .black.opacity(0.04), radius: 2, y: 1))
    }

    private func volunteerCard(_ v: Volunteer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { 
                Text(v.name).fontWeight(.semibold)
                Spacer()
                Text("#\(v.volunteerNumber)").font(.system(.caption, design: .rounded, weight: .bold)).foregroundStyle(Color.deepPurple)
            }
            // Display: Task → Other roles → [Group name] → Group info items
            if !v.role.isEmpty {
                Text(v.role).font(.caption).foregroundStyle(Color.deepPurple).fontWeight(.medium)
            }
            if !v.otherRoles.isEmpty {
                Text("Also: \(v.otherRoles)").font(.caption2).foregroundStyle(.secondary)
            }
            if !v.groupName.isEmpty {
                Text("[\(v.groupName)]").font(.caption).foregroundStyle(.orange).fontWeight(.semibold)
            }
            ForEach(v.groupInfo, id: \.self) { info in
                Text(info).font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            if !v.email.isEmpty { row("envelope.fill", "Email", v.email) }
            if !v.phone.isEmpty { phoneRow("phone.fill", "Phone", v.phone) }
            if !v.wechat.isEmpty { row("message.fill", "WeChat", v.wechat) }
        }
        .font(.caption).padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white).shadow(color: .black.opacity(0.04), radius: 2, y: 1))
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
            Text("\(label):").foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
            Spacer()
        }
    }

    private func phoneRow(_ icon: String, _ label: String, _ value: String) -> some View {
        let digits = value.filter(\.isNumber)
        return HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16)
            Text("\(label):").foregroundStyle(.secondary)
            if let url = URL(string: "tel://\(digits)"), !digits.isEmpty {
                Link(value, destination: url)
                    .foregroundStyle(.blue)
            } else {
                Text(value).textSelection(.enabled)
            }
            Spacer()
        }
    }
}
