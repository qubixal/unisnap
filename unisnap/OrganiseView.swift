//
//  OrganiseView.swift
//  Overlay to organise windows into the zones
//  unisnap
//

import SwiftUI

// MARK: - Organise View

struct OrganiseView: View {
    let profile: LayoutProfile
    let windows: [WindowInfo]
    var onDone: () -> Void

    @State private var zoneAssignments: [Int: WindowInfo] = [:]
    @State private var selectedZoneIndex: Int?
    @State private var availableWindows: [WindowInfo] = []

    private struct GridDimensions {
        let gridHeight: CGFloat
        let cellW: CGFloat
        let cellH: CGFloat

        init(containerWidth: CGFloat, containerHeight: CGFloat, columns: Int, rows: Int) {
            self.gridHeight = containerHeight * 0.7
            self.cellW = containerWidth / CGFloat(columns)
            self.cellH = gridHeight / CGFloat(rows)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedZoneIndex = nil
                    }

                zoneGrid(geo: geo)

                if let idx = selectedZoneIndex {
                    windowPicker(for: idx, geo: geo)
                }

                doneButton
            }
        }
        .onAppear {
            availableWindows = windows
            matchWindowsToZones()
        }
        .onKeyPress(.escape) {
            if selectedZoneIndex != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedZoneIndex = nil
                }
            } else {
                onDone()
            }
            return .handled
        }
        .onKeyPress(.return) {
            if selectedZoneIndex != nil {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedZoneIndex = nil
                }
            } else {
                onDone()
            }
            return .handled
        }
    }

    // MARK: - Zone Grid

    private func zoneGrid(geo: GeometryProxy) -> some View {
        let dims = GridDimensions(containerWidth: geo.size.width, containerHeight: geo.size.height,
                                  columns: profile.columns, rows: profile.rows)

        return VStack(spacing: 0) {
            Text(profile.name)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top, 20)

            Spacer()

            ZStack {
                ForEach(Array(profile.zones.enumerated()), id: \.element.id) { i, zone in
                    let rect = zone.cellRect(cellW: dims.cellW, cellH: dims.cellH, rows: profile.rows)

                    zoneCard(zone: zone, index: i)
                        .frame(width: rect.width - 16, height: rect.height - 16)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            .frame(width: geo.size.width, height: dims.gridHeight)

            Spacer()
        }
    }

    // MARK: - Zone Card

    private func zoneCard(zone: Zone, index: Int) -> some View {
        let isSelected = selectedZoneIndex == index
        let assigned = zoneAssignments[index]

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedZoneIndex = (selectedZoneIndex == index) ? nil : index
            }
        }) {
            VStack(spacing: 4) {
                if let window = assigned {
                    if let icon = appIcon(for: window.appName) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 36, height: 36)
                    }
                    Text(window.appName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !window.windowTitle.isEmpty {
                        Text(window.windowTitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Empty")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.2), lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Window Picker

    private func windowPicker(for zoneIndex: Int, geo: GeometryProxy) -> some View {
        let dims = GridDimensions(containerWidth: geo.size.width, containerHeight: geo.size.height,
                                  columns: profile.columns, rows: profile.rows)
        let zone = profile.zones[zoneIndex]
        let rect = zone.cellRect(cellW: dims.cellW, cellH: dims.cellH, rows: profile.rows)

        let pickerWidth: CGFloat = 240
        let itemCount = CGFloat(availableWindows.count)
        let rowHeight: CGFloat = 36
        let headerHeight: CGFloat = 34
        let pickerHeight = headerHeight + itemCount * rowHeight + 8

        return VStack(alignment: .leading, spacing: 0) {
            Text("Pick a window")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.12))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(availableWindows) { window in
                        Button(action: {
                            assignWindow(window)
                        }) {
                            HStack(spacing: 8) {
                                if let icon = appIcon(for: window.appName) {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(window.appName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                    if !window.windowTitle.isEmpty {
                                        Text(window.windowTitle)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if window.id != availableWindows.last?.id {
                            Divider().background(Color.white.opacity(0.08))
                        }
                    }
                }
            }
        }
        .frame(width: pickerWidth, height: pickerHeight)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .position(x: rect.midX, y: rect.midY)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.15), value: selectedZoneIndex)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 24)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Actions

    private func assignWindow(_ window: WindowInfo) {
        guard let targetIndex = selectedZoneIndex else { return }

        let targetOccupant = zoneAssignments[targetIndex]

        if targetOccupant?.id == window.id {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedZoneIndex = nil
            }
            return
        }

        if let sourceIndex = zoneAssignments.first(where: { $0.value.id == window.id })?.key {
            zoneAssignments[targetIndex] = window
            zoneAssignments[sourceIndex] = targetOccupant
        } else {
            zoneAssignments[targetIndex] = window
        }

        applyAssignments()
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedZoneIndex = nil
        }
    }

    private func applyAssignments() {
        for (zoneIndex, window) in zoneAssignments {
            guard zoneIndex < profile.zones.count else { continue }
            let zone = profile.zones[zoneIndex]
            positionWindow(window, at: zone, profile: profile)
        }
    }

    // MARK: - Matching

    private func matchWindowsToZones() {
        guard let usableFrame = screenUsableFrame() else { return }

        var assignments: [Int: WindowInfo] = [:]
        var usedWindowIDs = Set<UUID>()

        for (i, zone) in profile.zones.enumerated() {
            let zoneFrame = zone.absoluteFrame(columns: profile.columns, rows: profile.rows, on: usableFrame)

            for window in windows {
                guard !usedWindowIDs.contains(window.id) else { continue }
                if let windowFrame = getWindowFrame(window.element) {
                    let center = CGPoint(
                        x: windowFrame.origin.x + windowFrame.width / 2,
                        y: windowFrame.origin.y + windowFrame.height / 2
                    )
                    if zoneFrame.contains(center) {
                        assignments[i] = window
                        usedWindowIDs.insert(window.id)
                        break
                    }
                }
            }
        }

        zoneAssignments = assignments
    }

    // MARK: - Geometry Helpers

    private func appIcon(for appName: String) -> NSImage? {
        let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier(for: appName))?.path ?? ""
        guard !path.isEmpty else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }

    private func bundleIdentifier(for appName: String) -> String {
        switch appName.lowercased() {
        case "safari": return "com.apple.Safari"
        case "finder": return "com.apple.finder"
        case "mail": return "com.apple.mail"
        case "messages": return "com.apple.MobileSMS"
        case "photos": return "com.apple.Photos"
        case "music": return "com.apple.Music"
        case "calendar": return "com.apple.iCal"
        case "notes": return "com.apple.Notes"
        case "reminders": return "com.apple.Reminders"
        case "maps": return "com.apple.Maps"
        case "terminal": return "com.apple.Terminal"
        case "system preferences", "system settings": return "com.apple.SystemPreferences"
        case "preview": return "com.apple.Preview"
        case "textedit": return "com.apple.TextEdit"
        case "xcode": return "com.apple.dt.Xcode"
        case "code", "visual studio code": return "com.microsoft.VSCode"
        case "slack": return "com.tinyspeck.slackmacgap"
        case "discord": return "com.hhopkins.Discord"
        case "spotify": return "com.spotify.client"
        case "firefox": return "org.mozilla.firefox"
        case "google chrome": return "com.google.Chrome"
        case "brave": return "com.brave.Browser"
        case "notion": return "notion.id"
        case "figma": return "com.figma.Desktop"
        case "whatsapp": return "net.whatsapp.WhatsApp"
        case "telegram": return "ru.keepcoder.Telegram"
        default: return "com.apple.finder"
        }
    }
}
