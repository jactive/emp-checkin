import SwiftUI

struct DaoMainView: View {
    let athletes: [Athlete]  // All athletes
    let store: CheckInStore
    let selectedAges: Set<Int>  // Ages this volunteer can check in
    
    @State private var query = ""
    @State private var filterMode = 0 // 0=not checked in, 1=checked in, 2=all
    @State private var selected: Athlete?
    @State private var disambigInput = ""
    @FocusState private var disambigFocused: Bool
    @State private var showExport = false
    @State private var exportURL: URL?
    @State private var showExportConfirm = false
    @State private var showExportError = false
    
    // Alert for wrong age group
    @State private var wrongAgeAthlete: Athlete?
    @State private var showWrongAgeAlert = false

    // Athletes filtered by selected ages
    private var ageFilteredAthletes: [Athlete] {
        if selectedAges.isEmpty { return athletes }
        return athletes.filter { selectedAges.contains($0.age) }
    }
    
    private var filtered: [Athlete] {
        var r = query.trimmingCharacters(in: .whitespaces).isEmpty
            ? ageFilteredAthletes : SearchService.searchAthletes(ageFilteredAthletes, query: query)
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
    
    // Counts for filter pills
    private var notCheckedInCount: Int {
        ageFilteredAthletes.filter { !store.isCheckedIn($0.id) }.count
    }
    
    private var checkedInCount: Int {
        ageFilteredAthletes.filter { store.isCheckedIn($0.id) }.count
    }
    
    private var totalCount: Int {
        ageFilteredAthletes.count
    }
    
    // Display text for selected ages
    private var selectedAgesText: String {
        let availableCount = EmbeddedData.availableAgesDao.count
        if selectedAges.count == availableCount {
            return "All"
        }
        let sorted = selectedAges.sorted()
        if sorted.count <= 3 {
            return sorted.map(String.init).joined(separator: ",")
        }
        return "\(sorted.prefix(2).map(String.init).joined(separator: ","))..."
    }
    
    // Short label for filter scope
    private var filterScopeLabel: String {
        let availableCount = EmbeddedData.availableAgesDao.count
        if selectedAges.count == availableCount {
            return "all ages"
        }
        let sorted = selectedAges.sorted()
        if sorted.count == 1 {
            return "age \(sorted[0])"
        }
        if sorted.count <= 3 {
            return "ages \(sorted.map(String.init).joined(separator: ","))"
        }
        return "ages \(sorted.first!)–\(sorted.last!)"
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
                                handleAthleteSelection(a)
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
                checkInCount: checkedInCount,
                accentColor: .emeraldGreen,
                onSend: {
                    showExportConfirm = false
                    exportURL = store.exportLogToFile()
                    if exportURL != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showExport = true
                        }
                    } else {
                        showExportError = true
                    }
                },
                onCancel: { showExportConfirm = false }
            )
            .presentationDetents([.medium])
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text("Could not create export file. Make sure you have at least one check-in.")
        }
        .alert("Wrong Age Group / 年龄组不对", isPresented: $showWrongAgeAlert, presenting: wrongAgeAthlete) { _ in
            Button("OK / 好的") { wrongAgeAthlete = nil }
        } message: { athlete in
            Text("This athlete is age \(athlete.age).\nPlease go to the Age \(athlete.age) check-in station.\n\n该运动员\(athlete.age)岁。\n请前往\(athlete.age)岁签到站。")
        }
    }
    
    // MARK: - Handle athlete selection with age validation
    
    private func handleAthleteSelection(_ athlete: Athlete) {
        // If already checked in, show confirm sheet (which has undo option)
        // Don't block with alert - let them undo if needed
        selected = athlete
    }
    
    /// Search across ALL athletes (not just selected ages) to help redirect
    private func searchAllAthletes(query: String) -> Athlete? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return SearchService.searchAthletes(athletes, query: trimmed).first
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("EmP 到").font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Age: \(selectedAgesText)")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text("\(checkedInCount)/\(totalCount)").font(.subheadline).foregroundStyle(.white.opacity(0.9))
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
                if !query.isEmpty {
                    // Search all button - helps find athletes in other age groups
                    Button {
                        if let found = searchAllAthletes(query: query) {
                            if !selectedAges.contains(found.age) {
                                // Found in different age group
                                wrongAgeAthlete = found
                                showWrongAgeAlert = true
                            } else {
                                // Found in our age group - show confirm sheet
                                selected = found
                            }
                        }
                    } label: {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundStyle(Color.emeraldGreen)
                    }
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
            .padding(.horizontal, 16).padding(.vertical, 8)
            
            // Hint when not found in selected ages
            if !query.isEmpty && filtered.isEmpty {
                HStack {
                    Image(systemName: "info.circle").foregroundStyle(.orange)
                    Text("Not found in your ages. Tap 🔍 to search all.")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 4)
                .foregroundStyle(.orange)
                
                HStack {
                    Text("在您的年龄组中未找到。点击 🔍 搜索全部。")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 8)
                .foregroundStyle(.orange)
            }
            
            // Hide filter pills when searching but no results in selected ages
            if query.isEmpty || !filtered.isEmpty {
                HStack(spacing: 8) {
                    pill("Pending (\(notCheckedInCount))", active: filterMode == 0) { filterMode = 0 }
                    pill("Done (\(checkedInCount))", active: filterMode == 1) { filterMode = 1 }
                    pill("All (\(totalCount))", active: filterMode == 2) { filterMode = 2 }
                    Spacer()
                }.padding(.horizontal, 16)
                
                // Scope label
                Text("in \(filterScopeLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
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
            Label("Same name found / 重名了 (\(candidates.count))", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline).fontWeight(.bold).foregroundStyle(.orange)
            Text("Ask: \"Last 4 digits of phone?\"\n请问电话后四位是？").font(.caption).foregroundStyle(.secondary)
            TextField("e.g. 4859", text: $disambigInput)
                .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                .keyboardType(.numberPad)
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
