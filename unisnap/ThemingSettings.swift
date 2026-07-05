//
//  ThemingSettings.swift
//  Theming settings
//  unisnap
//

import SwiftUI

final class ThemingSettings: ObservableObject {
    static let shared = ThemingSettings()

    @Published var autoAdaptToSystem: Bool {
        didSet { UserDefaults.standard.set(autoAdaptToSystem, forKey: Keys.autoAdapt) }
    }

    @Published var customColor1: Color {
        didSet { save() }
    }

    @Published var customColor2: Color {
        didSet { save() }
    }

    @Published var gradientOpacity: Double {
        didSet { UserDefaults.standard.set(gradientOpacity, forKey: Keys.opacity) }
    }

    private struct Keys {
        static let autoAdapt = "unisnap_theming_autoAdapt"
        static let color1 = "unisnap_theming_color1"
        static let color2 = "unisnap_theming_color2"
        static let opacity = "unisnap_theming_opacity"
    }

    private init() {
        self.autoAdaptToSystem = UserDefaults.standard.object(forKey: Keys.autoAdapt) as? Bool ?? false
        self.gradientOpacity = UserDefaults.standard.object(forKey: Keys.opacity) as? Double ?? 0.25

        if let data = UserDefaults.standard.data(forKey: Keys.color1),
           let c = try? JSONDecoder().decode(ColorData.self, from: data) {
            self.customColor1 = Color(red: c.r, green: c.g, blue: c.b)
        } else {
            self.customColor1 = Color(red: 0.133, green: 0.208, blue: 0.459)
        }

        if let data = UserDefaults.standard.data(forKey: Keys.color2),
           let c = try? JSONDecoder().decode(ColorData.self, from: data) {
            self.customColor2 = Color(red: c.r, green: c.g, blue: c.b)
        } else {
            self.customColor2 = Color(red: 0.373, green: 0.235, blue: 0.431)
        }
    }

    func activeColors(systemColors: [Color]) -> [Color] {
        autoAdaptToSystem ? systemColors : [customColor1, customColor2]
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ColorData(from: customColor1)) {
            UserDefaults.standard.set(data, forKey: Keys.color1)
        }
        if let data = try? JSONEncoder().encode(ColorData(from: customColor2)) {
            UserDefaults.standard.set(data, forKey: Keys.color2)
        }
    }
}

private struct ColorData: Codable {
    var r: Double, g: Double, b: Double

    init(from color: Color) {
        let ns = NSColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r)
        self.g = Double(g)
        self.b = Double(b)
    }
}
