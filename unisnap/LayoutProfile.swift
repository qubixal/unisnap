//
//  LayoutProfile.swift
//  Profile layout definitions
//  unisnap
//
//

import Cocoa
import Combine

// MARK: - Grid Zone (column/row based, max 4 columns × 3 rows)

struct Zone: Codable, Identifiable {
    var id = UUID()
    var column: Int      // 0-based
    var row: Int         // 0-based (0 = bottom)
    var columnSpan: Int  // how many columns
    var rowSpan: Int     // how many rows

    func absoluteFrame(columns: Int, rows: Int, on screen: NSRect) -> NSRect {
        let colWidth = screen.width / CGFloat(columns)
        let rowHeight = screen.height / CGFloat(rows)
        return NSRect(
            x: screen.origin.x + CGFloat(column) * colWidth,
            y: screen.origin.y + CGFloat(row) * rowHeight,
            width: colWidth * CGFloat(columnSpan),
            height: rowHeight * CGFloat(rowSpan)
        )
    }

    func cellRect(cellW: CGFloat, cellH: CGFloat, rows: Int) -> CGRect {
        CGRect(
            x: CGFloat(column) * cellW,
            y: CGFloat(rows - 1 - row - rowSpan + 1) * cellH,
            width: cellW * CGFloat(columnSpan),
            height: cellH * CGFloat(rowSpan)
        )
    }
}

// MARK: - Hotkey Combo

struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    static let modifierMask: UInt = NSEvent.ModifierFlags([.control, .option, .shift, .command]).rawValue

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
    }

    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        switch code {
        case 0: return "A"  case 1: return "S"  case 2: return "D"
        case 3: return "F"  case 4: return "H"  case 5: return "G"
        case 6: return "Z"  case 7: return "X"  case 8: return "C"
        case 9: return "V"  case 11: return "B"  case 12: return "Q"
        case 13: return "W" case 14: return "E"  case 15: return "R"
        case 16: return "Y" case 17: return "T"  case 18: return "1"
        case 19: return "2" case 20: return "3"  case 21: return "4"
        case 22: return "6" case 23: return "5"  case 25: return "P"
        case 26: return "L" case 27: return "J"  case 29: return "K"
        case 30: return ";" case 32: return "I"  case 33: return "O"
        case 35: return "N" case 37: return "M"  case 41: return ","
        case 42: return "." case 43: return "/"  case 44: return "Space"
        case 49: return "⏎" case 50: return "`"  case 51: return "⌫"
        case 53: return "esc"
        case 123: return "←" case 124: return "→"
        case 125: return "↓" case 126: return "↑"
        default: return String(format: "%X", code)
        }
    }
}

// MARK: - Layout Profile

struct LayoutProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var zones: [Zone]
    var hotkey: HotkeyCombo?
    var columns: Int   // 1...4
    var rows: Int      // 1...3
    var isFavourite: Bool

    init(name: String, zones: [Zone], hotkey: HotkeyCombo? = nil, columns: Int = 1, rows: Int = 1, isFavourite: Bool = false) {
        self.name = name
        self.zones = zones
        self.hotkey = hotkey
        self.columns = min(max(columns, 1), 4)
        self.rows = min(max(rows, 1), 3)
        self.isFavourite = isFavourite
    }

    func menuBarImage() -> NSImage {
        let size = NSSize(width: 22, height: 17)
        let inset: CGFloat = 2
        let gridW = size.width - inset * 2
        let gridH = size.height - inset * 2
        let cellW = gridW / CGFloat(columns)
        let cellH = gridH / CGFloat(rows)

        return NSImage(size: size, flipped: true) { _ in
            NSColor.clear.set()
            NSRect(origin: .zero, size: size).fill()

            for zone in zones {
                let x = inset + CGFloat(zone.column) * cellW
                let y = inset + CGFloat(rows - zone.row - zone.rowSpan) * cellH
                let w = cellW * CGFloat(zone.columnSpan)
                let h = cellH * CGFloat(zone.rowSpan)
                let zoneRect = NSRect(x: x, y: y, width: w, height: h)

                NSColor.black.withAlphaComponent(0.15).setFill()
                zoneRect.fill()

                NSColor.black.setStroke()
                let border = NSBezierPath(roundedRect: zoneRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 1.5, yRadius: 1.5)
                border.lineWidth = 1.2
                border.stroke()
            }
            return true
        }
    }

    static func defaultMenuBarImage() -> NSImage {
        let size = NSSize(width: 22, height: 17)
        let inset: CGFloat = 2
        let rect = NSRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)

        return NSImage(size: size, flipped: true) { _ in
            NSColor.clear.set()
            NSRect(origin: .zero, size: size).fill()

            NSColor.black.setStroke()
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            border.lineWidth = 1.5
            border.stroke()
            return true
        }
    }
}

// MARK: - Defaults

extension LayoutProfile {
    static let defaultLeftRight = LayoutProfile(
        name: "Left / Right",
        zones: [
            Zone(column: 0, row: 0, columnSpan: 1, rowSpan: 1),
            Zone(column: 1, row: 0, columnSpan: 1, rowSpan: 1)
        ],
        columns: 2, rows: 1, isFavourite: true
    )

    static let defaultThirds = LayoutProfile(
        name: "Thirds",
        zones: [
            Zone(column: 0, row: 0, columnSpan: 1, rowSpan: 1),
            Zone(column: 1, row: 0, columnSpan: 1, rowSpan: 1),
            Zone(column: 2, row: 0, columnSpan: 1, rowSpan: 1)
        ],
        columns: 3, rows: 1, isFavourite: true
    )

    static let defaultQuadrants = LayoutProfile(
        name: "Quadrants",
        zones: [
            Zone(column: 0, row: 1, columnSpan: 1, rowSpan: 1),
            Zone(column: 1, row: 1, columnSpan: 1, rowSpan: 1),
            Zone(column: 0, row: 0, columnSpan: 1, rowSpan: 1),
            Zone(column: 1, row: 0, columnSpan: 1, rowSpan: 1)
        ],
        columns: 2, rows: 2, isFavourite: true
    )

    static let defaultWide = LayoutProfile(
        name: "Main + 2 Side",
        zones: [
            Zone(column: 0, row: 0, columnSpan: 2, rowSpan: 2),
            Zone(column: 2, row: 1, columnSpan: 2, rowSpan: 1),
            Zone(column: 2, row: 0, columnSpan: 2, rowSpan: 1)
        ],
        columns: 4, rows: 2, isFavourite: true
    )
}

// MARK: - Profile Store (UserDefaults Persistence)

final class ProfileStore: ObservableObject {
    @Published var profiles: [LayoutProfile] = []
    @Published var quickswapHotkey: HotkeyCombo?
    @Published var quickswapReverseHotkey: HotkeyCombo?
    @Published var organiseHotkey: HotkeyCombo?

    private let profilesKey = "unisnap_profiles"
    private let quickswapKey = "unisnap_quickswap_hotkey"
    private let quickswapReverseKey = "unisnap_quickswap_reverse_hotkey"
    private let organiseKey = "unisnap_organise_hotkey"

    init() { load() }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([LayoutProfile].self, from: data) {
            profiles = decoded
        } else {
            profiles = [
                .defaultLeftRight,
                .defaultThirds,
                .defaultQuadrants,
                .defaultWide
            ]
        }
        if let data = UserDefaults.standard.data(forKey: quickswapKey),
           let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            quickswapHotkey = decoded
        }
        if let data = UserDefaults.standard.data(forKey: quickswapReverseKey),
           let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            quickswapReverseHotkey = decoded
        }
        if let data = UserDefaults.standard.data(forKey: organiseKey),
           let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            organiseHotkey = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
        if let hotkey = quickswapHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: quickswapKey)
        } else {
            UserDefaults.standard.removeObject(forKey: quickswapKey)
        }
        if let hotkey = quickswapReverseHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: quickswapReverseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: quickswapReverseKey)
        }
        if let hotkey = organiseHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            UserDefaults.standard.set(data, forKey: organiseKey)
        } else {
            UserDefaults.standard.removeObject(forKey: organiseKey)
        }
    }

    func addProfile(_ profile: LayoutProfile) {
        profiles.append(profile)
        save()
    }

    func toggleFavourite(for id: UUID) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[idx].isFavourite.toggle()
        save()
    }
}
