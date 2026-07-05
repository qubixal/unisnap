//
//  WindowListHelper.swift
//  Window detections, read/write AXUIElement helpers + enumeration
//  unisnap
//

import Cocoa

// MARK: - Window Info

struct WindowInfo: Identifiable {
    let id = UUID()
    let appName: String
    let windowTitle: String
    let element: AXUIElement
}

// MARK: - Debug Log

private func snapLog(_ message: String) {
    NSLog("[unisnap] \(message)")
}

// MARK: - Screen Helpers

func screenUsableFrame() -> NSRect? {
    guard let screen = NSScreen.main else { return nil }
    let fullFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    let topGap = fullFrame.maxY - visibleFrame.maxY
    let bottomGap = visibleFrame.minY - fullFrame.minY
    return NSRect(
        x: fullFrame.origin.x,
        y: fullFrame.origin.y + bottomGap,
        width: fullFrame.width,
        height: fullFrame.height - topGap - bottomGap
    )
}

// MARK: - Minimum Size Detection

func getMinimumWindowSize(_ element: AXUIElement) -> CGSize? {
    var minSizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, "AXMinimumSize" as CFString, &minSizeRef) == .success else {
        return nil
    }
    guard let axValue = minSizeRef else { return nil }
    var minSize = CGSize.zero
    guard AXValueGetValue(axValue as! AXValue, .cgSize, &minSize) else { return nil }
    return minSize
}

// MARK: - Zone Fit Check

func zoneSize(for zone: Zone, profile: LayoutProfile) -> CGSize? {
    guard let usableFrame = screenUsableFrame() else { return nil }
    return zone.absoluteFrame(columns: profile.columns, rows: profile.rows, on: usableFrame).size
}

func canWindowFit(_ window: WindowInfo, in zone: Zone, profile: LayoutProfile) -> Bool {
    guard let zoneSize = zoneSize(for: zone, profile: profile) else { return true }
    let minSize = getMinimumWindowSize(window.element)
        ?? getWindowFrame(window.element)?.size
        ?? CGSize.zero
    return minSize.width <= zoneSize.width && minSize.height <= zoneSize.height
}

// MARK: - Snap to Profile

func snapWindows(to profile: LayoutProfile) {
    let windows = getVisibleWindows()
    guard !windows.isEmpty else {
        snapLog("No windows to arrange")
        return
    }

    var assignments: [(window: WindowInfo, zoneIndex: Int)] = []
    for (i, _) in profile.zones.enumerated() {
        guard i < windows.count else { break }
        assignments.append((window: windows[i], zoneIndex: i))
    }

    for i in assignments.indices {
        let window = assignments[i].window
        let zoneIdx = assignments[i].zoneIndex
        let zone = profile.zones[zoneIdx]

        if !canWindowFit(window, in: zone, profile: profile) {
            guard let ourSize = zoneSize(for: zone, profile: profile) else { continue }
            snapLog("  \(window.appName) min-size exceeds zone \(zoneIdx), seeking swap")

            var bestJ: Int?
            var bestArea: CGFloat = 0
            for j in assignments.indices where j != i {
                let otherZone = profile.zones[assignments[j].zoneIndex]
                guard let theirSize = zoneSize(for: otherZone, profile: profile) else { continue }
                let theirArea = theirSize.width * theirSize.height
                guard theirArea > bestArea,
                      canWindowFit(assignments[j].window, in: zone, profile: profile)
                else { continue }
                bestArea = theirArea
                bestJ = j
            }

            if let j = bestJ {
                let theirSize = zoneSize(for: profile.zones[assignments[j].zoneIndex], profile: profile) ?? .zero
                guard (theirSize.width * theirSize.height) > (ourSize.width * ourSize.height) else { continue }
                snapLog("  Swap: \(window.appName) ↔ \(assignments[j].window.appName)")
                let tmp = assignments[i].zoneIndex
                assignments[i].zoneIndex = assignments[j].zoneIndex
                assignments[j].zoneIndex = tmp
            }
        }
    }

    for a in assignments {
        positionWindow(a.window, at: profile.zones[a.zoneIndex], profile: profile)
    }
}

// MARK: - AXUIElement Helpers

func setWindowFrame(_ element: AXUIElement, frame: NSRect) {
    AXUIElementPerformAction(element, kAXRaiseAction as CFString)

    var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
    let posValue = AXValueCreate(.cgPoint, &position)!
    let posResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)

    var size = CGSize(width: frame.width, height: frame.height)
    let sizeValue = AXValueCreate(.cgSize, &size)!
    let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)

    if posResult != .success {
        snapLog("    WARNING: Set position failed (\(posResult.rawValue))")
    }
    if sizeResult != .success {
        snapLog("    WARNING: Set size failed (\(sizeResult.rawValue))")
    }
}

func getWindowFrame(_ element: AXUIElement) -> CGRect? {
    var positionRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success else {
        return nil
    }
    var position = CGPoint.zero
    guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position) else { return nil }

    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else {
        return nil
    }
    var size = CGSize.zero
    guard AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

    return CGRect(origin: position, size: size)
}

func positionWindow(_ window: WindowInfo, at zone: Zone, profile: LayoutProfile) {
    guard let usableFrame = screenUsableFrame() else { return }
    let sh = NSScreen.main?.frame.height ?? 0
    let zoneFrame = zone.absoluteFrame(columns: profile.columns, rows: profile.rows, on: usableFrame)
    let axX = zoneFrame.origin.x
    let axY = sh - zoneFrame.origin.y - zoneFrame.height
    let axFrame = CGRect(x: axX, y: axY, width: zoneFrame.width, height: zoneFrame.height)
    snapLog("  \(window.appName): nsscreen=\(zoneFrame) → ax=\(axFrame)")
    setWindowFrame(window.element, frame: axFrame)

    if let actual = getWindowFrame(window.element) {
        let overX = actual.width - zoneFrame.width
        let overY = actual.height - zoneFrame.height
        if overX > 1 || overY > 1 {
            let cx = axX + (zoneFrame.width - actual.width) / 2
            let cy = axY + (zoneFrame.height - actual.height) / 2
            let adjusted = CGRect(x: cx, y: cy, width: actual.width, height: actual.height)
            snapLog("  \(window.appName): oversized by \(Int(overX))×\(Int(overY)), recentering → \(adjusted)")
            setWindowFrame(window.element, frame: adjusted)
        }
    }
}

// MARK: - Window Enumeration

func getVisibleWindows() -> [WindowInfo] {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications
    let frontApp = workspace.frontmostApplication?.localizedName

    var results: [WindowInfo] = []

    for app in runningApps {
        guard app.activationPolicy == .regular,
              app.processIdentifier > 0
        else { continue }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else { continue }

        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""

            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXSubrole" as CFString, &subroleRef)
            let subrole = subroleRef as? String ?? ""

            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXRole" as CFString, &roleRef)
            let role = roleRef as? String ?? ""

            var minimizedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, "AXMinimized" as CFString, &minimizedRef)
            let isMinimized = minimizedRef as? Bool ?? false
            guard !isMinimized else { continue }

            guard subrole == "AXStandardWindow" ||
                  subrole == "AXDialog" ||
                  subrole == "AXSystemDialog" ||
                  (subrole.isEmpty && role == "AXWindow") ||
                  role == "AXWindow" else { continue }

            results.append(WindowInfo(
                appName: app.localizedName ?? "Unknown",
                windowTitle: title,
                element: window
            ))
        }
    }

    let sorted = results.sorted { a, b in
        if a.appName == frontApp { return true }
        if b.appName == frontApp { return false }
        let aIdx = runningApps.firstIndex(where: { $0.localizedName == a.appName }) ?? Int.max
        let bIdx = runningApps.firstIndex(where: { $0.localizedName == b.appName }) ?? Int.max
        return aIdx < bIdx
    }

    return sorted
}
