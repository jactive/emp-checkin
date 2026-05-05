import SwiftUI

struct QianMainView: View {
    let volunteers: [Volunteer]
    let store: CheckInStore
    @State private var query = ""
    @State private var filterMode = 0 // 0=not checked in, 1=checked in, 2=all
    @State private var selected: Volunteer?
    @State private var showExport = false
    @State private var exportURL: URL?
    @State private var showDashboard = false
    @State private var showExportConfirm = false

    private var filtered: [Volunteer] {
        var r = query.trimmingCharacters(in: .whitespaces).isEmpty
            ? volunteers : SearchService.searchVolunteers(volunteers, query: query)
        switch filterMode {
        case 0: r = r.filter { !store.isCheckedIn($0.id) }
        case 1: r = r.filter { store.isCheckedIn($0.id) }
        default: break
        }
        return r
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { v in
                        volunteerCard(v).onTapGesture { selected = v }
                    }
                }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 100)
            }.background(Color(.systemGroupedBackground))
        }
        .sheet(item: $selected) { v in confirmSheet(v) }
        .sheet(isPresented: $showExport) { if let u = exportURL { ExportShareSheet(fileURL: u) } }
        .sheet(isPresented: $showDashboard) { QianDashboardView(volunteers: volunteers, store: store) }
        .sheet(isPresented: $showExportConfirm) {
            ExportConfirmView(
                checkInCount: store.checkedInCount,
                accentColor: .deepPurple,
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
            Text("EmP 签").font(.title2).fontWeight(.bold).foregroundStyle(.white)
            Spacer()
            Text("\(store.checkedInCount)/\(volunteers.count)").font(.subheadline).foregroundStyle(.white.opacity(0.9))
            Button { showDashboard = true } label: {
                Image(systemName: "chart.bar.fill").foregroundStyle(.white)
            }
            Button { showExportConfirm = true } label: {
                Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(LinearGradient(colors: [.deepPurpleDark, .deepPurple], startPoint: .leading, endPoint: .trailing))
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search volunteer name...", text: $query)
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
                .background(Capsule().fill(active ? Color.deepPurple : .clear))
                .foregroundStyle(active ? .white : .secondary)
                .overlay(Capsule().strokeBorder(active ? .clear : .secondary.opacity(0.3), lineWidth: 1.5))
        }
    }

    private func volunteerCard(_ v: Volunteer) -> some View {
        let checked = store.isCheckedIn(v.id)
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(v.name).font(.body).fontWeight(.semibold).foregroundStyle(checked ? .secondary : .primary)
                Text(v.role).font(.caption).foregroundStyle(Color.deepPurple).fontWeight(.medium).lineLimit(2)
            }
            Spacer()
            if checked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.deepPurple)
            } else {
                Text("Check In").font(.caption).fontWeight(.semibold).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.deepPurple))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(checked ? Color(.systemGray6) : .white).shadow(color: .black.opacity(0.04), radius: 2, y: 1))
        .opacity(checked ? 0.6 : 1)
    }

    private func confirmSheet(_ v: Volunteer) -> some View {
        VStack(spacing: 16) {
            Text(v.name).font(.title2).fontWeight(.bold).padding(.top, 24)
            Text(v.role).font(.subheadline).foregroundStyle(Color.deepPurple).fontWeight(.semibold)
            if store.isCheckedIn(v.id) {
                Label("Checked in", systemImage: "checkmark.circle.fill").foregroundStyle(Color.deepPurple).font(.headline)
                Button { store.undoCheckIn(personId: v.id); selected = nil } label: {
                    Text("↩ Undo").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.bordered).tint(.red)
            } else {
                Button { store.checkIn(personId: v.id); selected = nil } label: {
                    Text("✓ Confirm Check-In").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                }.buttonStyle(.borderedProminent).tint(.deepPurple)
            }
            Button("Cancel") { selected = nil }.foregroundStyle(.secondary)
            Spacer()
        }.padding(.horizontal, 24).presentationDetents([.medium]).presentationDragIndicator(.visible)
    }
}
