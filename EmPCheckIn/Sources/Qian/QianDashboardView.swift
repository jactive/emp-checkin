import SwiftUI

struct QianDashboardView: View {
    let volunteers: [Volunteer]
    let store: CheckInStore
    @State private var showExport = false
    @State private var exportURL: URL?
    @Environment(\.dismiss) private var dismiss

    private var checkedIn: Int { store.checkedInCount }
    private var remaining: Int { volunteers.count - checkedIn }
    private var progress: Double {
        guard !volunteers.isEmpty else { return 0 }
        return Double(checkedIn) / Double(volunteers.count)
    }

    private var roleGroups: [(role: String, checked: Int, total: Int)] {
        let grouped = Dictionary(grouping: volunteers) { $0.role }
        return grouped.keys.sorted().map { role in
            let group = grouped[role]!
            let checked = group.filter { store.isCheckedIn($0.id) }.count
            return (role: role, checked: checked, total: group.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats
                    LazyVGrid(columns: [.init(), .init()], spacing: 12) {
                        statCard("\(checkedIn)", "Checked In", Color.deepPurple)
                        statCard("\(remaining)", "Remaining", .orange)
                        statCard("\(volunteers.count)", "Total", .primary)
                    }.padding(.horizontal, 16)

                    // Progress
                    VStack(spacing: 6) {
                        HStack {
                            Text("Progress").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%").font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: progress).tint(.deepPurple)
                    }.padding(.horizontal, 16)

                    // By role
                    VStack(alignment: .leading, spacing: 10) {
                        Text("By Role").font(.headline)
                        ForEach(roleGroups, id: \.role) { group in
                            HStack {
                                Text(group.role).font(.caption).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(group.checked)/\(group.total)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.padding(.horizontal, 16)

                    // Export
                    Button {
                        exportURL = store.exportLogToFile()
                        if exportURL != nil { showExport = true }
                    } label: {
                        Label("Export Check-In Log", systemImage: "square.and.arrow.up")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent).tint(.deepPurple)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExport) {
                if let url = exportURL { ExportShareSheet(fileURL: url) }
            }
        }
    }

    private func statCard(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 32, weight: .bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white).shadow(color: .black.opacity(0.04), radius: 2, y: 1))
    }
}
