import Foundation
import SwiftUI
import UIKit

@Observable
final class CheckInStore {
    private(set) var events: [CheckInEvent] = []
    private(set) var states: [String: CheckInState] = [:]
    let operatorName: String
    let deviceName: String
    let appPrefix: String
    private let storageURL: URL
    private let deviceShortId: String

    init(operatorName: String, filename: String = "checkin_log.json", appPrefix: String = "emp") {
        self.operatorName = operatorName
        self.deviceName = UIDevice.current.name
        self.appPrefix = appPrefix
        // Short unique device ID from identifierForVendor
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.deviceShortId = String(vendorId.prefix(8))
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // Use unique filename on-device so cable-copy doesn't collide
        let uniqueFilename = "\(appPrefix)_log_\(deviceShortId).json"
        self.storageURL = docs.appendingPathComponent(uniqueFilename)
        loadEvents()
    }

    @discardableResult
    func checkIn(personId: String) -> CheckInEvent {
        let e = CheckInEvent(id: UUID(), personId: personId, action: .checkIn,
                             operatorName: operatorName, device: "\(deviceName)_\(deviceShortId)", timestamp: Date())
        append(e); return e
    }

    @discardableResult
    func undoCheckIn(personId: String) -> CheckInEvent {
        let e = CheckInEvent(id: UUID(), personId: personId, action: .undo,
                             operatorName: operatorName, device: "\(deviceName)_\(deviceShortId)", timestamp: Date())
        append(e); return e
    }

    func isCheckedIn(_ id: String) -> Bool { states[id]?.isCheckedIn ?? false }
    func state(for id: String) -> CheckInState { states[id] ?? CheckInState() }
    var checkedInCount: Int { states.values.filter(\.isCheckedIn).count }

    func exportLogToFile() -> URL? {
        // Return nil if no events to export
        guard !events.isEmpty else { return nil }
        
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        guard let data = try? enc.encode(events) else { return nil }
        let dateStr = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "T", with: "_")
            .prefix(19)
        let safeName = deviceName.replacingOccurrences(of: " ", with: "_")
        let name = "\(appPrefix)_checkin_\(dateStr)_\(safeName)_\(deviceShortId).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }

    private func append(_ e: CheckInEvent) { events.append(e); replay(e.personId); save() }

    private func replay(_ id: String) {
        guard let last = events.last(where: { $0.personId == id }) else { states[id] = CheckInState(); return }
        switch last.action {
        case .checkIn: states[id] = CheckInState(isCheckedIn: true, checkedInAt: last.timestamp, checkedInBy: last.operatorName)
        case .undo: states[id] = CheckInState()
        }
    }

    private func loadEvents() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let loaded = try? dec.decode([CheckInEvent].self, from: data) else { return }
        events = loaded
        for id in Set(events.map(\.personId)) { replay(id) }
    }

    private func save() {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(events) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
