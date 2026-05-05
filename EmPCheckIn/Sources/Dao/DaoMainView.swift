import SwiftUI

struct DaoMainView: View {
    let athletes: [Athlete]
    let store: CheckInStore
    @State private var query = ""
    @State private var filterMode = 0 // 0=not checked in, 1=checked in, 2=all
    @State private var selected: Athlete?
    @State private var disambigInput = ""
    @FocusState private var disambigFocused: Bool
    @State private var showExport = false
    @State private var exportURL: URL?
    @State private var showExportConfirm = false

    private var filtered: [Athlete] {
        var r = query.trimmingCharacters(in: .whitespaces).isEmpty
            ? athletes : SearchService.searchAthletes(athletes, query: query)
        switch filterMode {
        case 0: r = r.filter { !store.isCheckedIn($0.id) }
        case 1: r = r.filter { store.isCheckedIn($0.id) }
        default: break
        }
        return r
    }

    private var dupeGroup: [Athlete]? {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return DisambiguationService.findDuplicateGroups(filtered).first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            if let dupes = dupeGroup, dupes.count > 1 { disambigBanner(dupes) }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { a in
                        let isDupe = dupeGroup?.contains(where: { $0.id == a.id }) ?? false
                        athleteCard(a, disabled: isDupe).onTapGesture {
                            if isDupe {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    disambigFocused = true
                                }
                            } else {
                                selected = a
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
            }.background(Color(.systemGroupedBackground))
        }
        .sheet(item: $selected) { a in confirmSheet(a) }
        .sheet(isPresented: $showExport) { if let u = exportURL { ExportShareSheet(fileURL: u) } }
        .sheet(isPresented: $showExportConfirm) {
            ExportConfirmView(
                checkInCount: store.checkedInCount,
                accentColor: .emeraldGreen,
                onSend: {
                    showExportConfirm = false
                    exportURL = store.exportLogToFile()
                    if exportURL != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showExport = true
                        }
                    }
                },
                onCancel: { showExportConfirm = false }
            )
            .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack {
            Text("EmP 到").font(.title2).fontWeight(.bold).foregroundStyle(.white)
            Spacer()
            Text("\(store.checkedInCount)/\(athletes.count)").font(.subheadline).foregroundStyle(.white.opacity(0.9))
            Button { showExportConfirm = true } label: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(LinearGradient(colors: [.emeraldDark, .emeraldGreen], startPoint: .leading, endPoint: .trailing))
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search athlete name...", text: $query)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            .padding(.horizontal, 16).padding(.vertical, 8)
            HStack(spacing: 8) {
                pill("Not checked in", active: filterMode == 0) { filterMode = 0 }
                pill("Checked in", active: filterMode == 1) { filterMode = 1 }
                pill("All", active: filterMode == 2) { filterMode = 2 }
                Spacer()
            }.padding(.horizontal, 16).padding(.bottom, 8)
        }.background(.white)
    }

    private func pill(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption).fontWeight(.medium)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(active ? Color.emeraldGreen : .clear))
                .foregroundStyle(active ? .white : .secondary)
                .overlay(Capsule().strokeBorder(active ? .clear : .secondary.opacity(0.3), lineWidth: 1.5))
        }
    }

    private func disambigBanner(_ candidates: [Athlete]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(candidates.count) matches — same name, age & gender", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
            Text("Ask: \"Last 4 digits of phone?\"").font(.caption2).foregroundStyle(.secondary)
            TextField("e.g. 4859", text: $disambigInput)
                .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                .focused($disambigFocused)
                .onChange(of: disambigInput) { _, v in
                    if let r = DisambiguationService.resolve(input: v, candidates: candidates) { selected = r; disambigInput = "" }
                }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.08)).strokeBorder(Color.orange.opacity(0.3)))
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func athleteCard(_ a: Athlete, disabled: Bool = false) -> some View {
        let checked = store.isCheckedIn(a.id)
        return HStack(spacing: 12) {
            // Bib number badge
            VStack(spacing: 0) {
                Text("#\(a.bibNumber)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(checked ? .secondary : Color.emeraldGreen)
            }
            .frame(width: 52, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(checked ? Color(.systemGray5) : Color.emeraldGreen.opacity(0.1))
            )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(a.fullName).font(.body).fontWeight(.semibold).foregroundStyle(checked ? .secondary : .primary)
                Text("Age \(a.age) · \(a.gender)").font(.caption).foregroundStyle(.secondary)
                if !a.events.isEmpty { Text(a.events.joined(separator: ", ")).font(.caption2).foregroundStyle(Color.emeraldGreen).fontWeight(.medium) }
            }
            Spacer()
            if checked { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.emeraldGreen) }
            else if disabled {
                Text("Verify first").font(.caption).fontWeight(.medium).foregroundStyle(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange))
            }
            else { Text("Check In").font(.caption).fontWeight(.semibold).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.emeraldGreen)) }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(checked ? Color(.systemGray6) : .white).shadow(color: .black.opacity(0.04), radius: 2, y: 1))
        .opacity(checked ? 0.6 : 1)
    }

    private func confirmSheet(_ a: Athlete) -> some View {
        VStack(spacing: 16) {
            Text(a.fullName).font(.title3).fontWeight(.semibold).padding(.top, 20)
            Text("Age \(a.age) · \(a.gender)").font(.subheadline).foregroundStyle(.secondary)
            
            // Prominent bib number
            VStack(spacing: 4) {
                Text("Bib Number").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Text("#\(a.bibNumber)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.emeraldGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.emeraldGreen.opacity(0.08))
                    .strokeBorder(Color.emeraldGreen.opacity(0.3), lineWidth: 2)
            )
            
            if !a.events.isEmpty {
                Text("Events: \(a.events.joined(separator: ", "))").font(.subheadline).foregroundStyle(Color.emeraldGreen).fontWeight(.semibold)
            }
            if store.isCheckedIn(a.id) {
                Label("Checked in", systemImage: "checkmark.circle.fill").foregroundStyle(Color.emeraldGreen).font(.headline)
                Button { store.undoCheckIn(personId: a.id); selected = nil } label: {
                    Text("↩ Undo").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.bordered).tint(.red)
            } else {
                Button { store.checkIn(personId: a.id); selected = nil } label: {
                    Text("✓ Confirm Check-In").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.borderedProminent).tint(.emeraldGreen)
            }
            Button("Cancel") { selected = nil }.foregroundStyle(.secondary)
            Spacer()
        }.padding(.horizontal, 24).presentationDetents([.large]).presentationDragIndicator(.visible)
    }
}
