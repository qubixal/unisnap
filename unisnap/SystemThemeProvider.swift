//
//  SystemThemeProvider.swift
//  theming provider (non-wallpaper-based)
//  unisnap
//

import Cocoa
import SwiftUI

final class SystemThemeProvider: ObservableObject {
    @Published var systemColors: [Color] = [.blue, .blue]
    @Published var isDarkMode: Bool = false

    private var cancellable: Any?

    init() {
        refresh()
        startObserving()
    }

    deinit {
        if let observer = cancellable {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Public

    func refresh() {
        detectAppearance()
        computeColors()
    }

    // MARK: - Appearance Detection

    private func detectAppearance() {
        let appearance = NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        isDarkMode = match == .darkAqua
    }

    // MARK: - Color Derivation

    private func computeColors() {
        let accent = NSColor.controlAccentColor
        let primary = Color(accent)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let nsColor = accent.usingColorSpace(.deviceRGB) ?? accent
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let hsl = rgbToHsl(r: r, g: g, b: b)
        let toned = hslToColor(
            h: hsl.h,
            s: hsl.s * 0.5,
            l: isDarkMode ? min(hsl.l + 0.15, 0.7) : max(hsl.l - 0.05, 0.3)
        )

        systemColors = [primary, toned]
    }

    // MARK: - HSL Helpers

    private struct HSL {
        var h: CGFloat
        var s: CGFloat
        var l: CGFloat
    }

    private func rgbToHsl(r: CGFloat, g: CGFloat, b: CGFloat) -> HSL {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2

        guard maxC != minC else {
            return HSL(h: 0, s: 0, l: l)
        }

        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)

        var h: CGFloat = 0
        switch maxC {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        case b: h = (r - g) / d + 4
        default: break
        }
        h /= 6

        return HSL(h: h, s: s, l: l)
    }

    private func hslToColor(h: CGFloat, s: CGFloat, l: CGFloat) -> Color {
        if s == 0 {
            return Color(white: Double(l))
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        let hue = h

        func hueToRgb(p: Double, q: Double, t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0/6.0 { return p + (q - p) * 6 * t }
            if t < 1.0/2.0 { return q }
            if t < 2.0/3.0 { return p + (q - p) * (2.0/3.0 - t) * 6 }
            return p
        }

        let r = hueToRgb(p: Double(p), q: Double(q), t: Double(hue + 1.0/3.0))
        let g = hueToRgb(p: Double(p), q: Double(q), t: Double(hue))
        let b = hueToRgb(p: Double(p), q: Double(q), t: Double(hue - 1.0/3.0))

        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Observation

    private func startObserving() {
        cancellable = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }
}
