//
//  WindowListHelper.swift
//  unisnap
//
//  Created by unisnap on 3/7/2026.
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

func screenHeight() -> CGFloat {
    NSScreen.main?.frame.height ?? 0
}

// MARK: - Snap to Profile

func snapWindows(to profile: LayoutProfile) {
    guard let usableFrame = screenUsableFrame() else {
        snapLog("ERROR: No screen found")
        return
    }

    let screenHeight = screenHeight()

    snapLog("screenHeight: \(screenHeight)")
    snapLog("usableFrame: origin=(\(usableFrame.origin.x),\(usableFrame.origin.y)) size=(\(usableFrame.width),\(usableFrame.height))")

    let windows = getVisibleWindows()
    snapLog("Found \(windows.count) windows")

    guard !windows.isEmpty else {
        snapLog("No windows to arrange")
        return
    }

    for (i, zone) in profile.zones.enumerated() {
        guard i < windows.count else { break }
        let zoneFrame = zone.absoluteFrame(columns: profile.columns, rows: profile.rows, on: usableFrame)

        let axX = zoneFrame.origin.x
        let axY = screenHeight - zoneFrame.origin.y - zoneFrame.height
        let axFrame = CGRect(x: axX, y: axY, width: zoneFrame.width, height: zoneFrame.height)

        snapLog("  [\(i)] \(windows[i].appName): nsscreen=\(zoneFrame) → ax=\(axFrame)")
        setWindowFrame(windows[i].element, frame: axFrame)
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
    let screenHeight = screenHeight()
    let zoneFrame = zone.absoluteFrame(columns: profile.columns, rows: profile.rows, on: usableFrame)
    let axX = zoneFrame.origin.x
    let axY = screenHeight - zoneFrame.origin.y - zoneFrame.height
    let axFrame = CGRect(x: axX, y: axY, width: zoneFrame.width, height: zoneFrame.height)
    setWindowFrame(window.element, frame: axFrame)
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
