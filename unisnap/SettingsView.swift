//
//  SettingsView.swift
//  unisnap
//
//  Left sidebar navigation: General, Shortcuts, Profiles.
//

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var store: ProfileStore
    @StateObject private var wallpaper = WallpaperColors()
    @StateObject private var theming = ThemingSettings.shared
    @State private var selectedTab: SettingsTab? = .general
    @State private var selectedProfileID: UUID?

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case profiles = "Profiles"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "command"
            case .profiles: return "rectangle.split.2x2"
            }
        }
    }

    var body: some View {
        HSplitView {
            sidebar
            detail
                .frame(minWidth: 480, idealWidth: 480)
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: theming.activeColors(wallpaperColors: wallpaper.colors).map { $0.opacity(theming.gradientOpacity * 0.6) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [.white.opacity(0.04), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = store.profiles.first?.id
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 10)

            Divider().opacity(0.3)

            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)

            Divider().opacity(0.3)

            sidebarDetail
        }
        .background {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 0.5)
                        .frame(maxHeight: .infinity, alignment: .trailing)
                }
        }
        .frame(minWidth: 150, idealWidth: 170)
    }

    @ViewBuilder
    private var sidebarDetail: some View {
        switch selectedTab {
        case .general, .shortcuts:
            EmptyView()
        case .profiles:
            HStack {
                Text("Profiles").font(.headline)
                Spacer()
                Button(action: addProfile) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List(store.profiles, selection: $selectedProfileID) { profile in
                HStack {
                    if profile.isFavourite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                    }
                    Text(profile.name)
                }
                .tag(profile.id)
            }
            .listStyle(.sidebar)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .general:
            ThemingContent(wallpaper: wallpaper, theming: theming)
                .padding(20)
        case .shortcuts:
            ShortcutsContent(store: store)
                .padding(20)
        case .profiles:
            ProfileEditorView(store: store, selectedProfileID: $selectedProfileID)
        case .none:
            Text("Select a section")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func addProfile() {
        let new = LayoutProfile(name: "New Profile",
                                zones: [Zone(column: 0, row: 0, columnSpan: 1, rowSpan: 1)],
                                columns: 1, rows: 1)
        store.addProfile(new)
        selectedProfileID = new.id
    }
}

// MARK: - Section Header

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.title3).fontWeight(.semibold)
}

// MARK: - Theming Content

struct ThemingContent: View {
    @ObservedObject var wallpaper: WallpaperColors
    @ObservedObject var theming: ThemingSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Appearance")
                .padding(.bottom, 4)

            glassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $theming.autoAdaptToWallpaper) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Auto-adapt to wallpaper")
                                Text("Beta")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange.opacity(0.8))
                                    )
                            }
                            Text("Extract dominant colors from your desktop wallpaper")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if theming.autoAdaptToWallpaper {
                        wallpaperPreview
                    } else {
                        manualColorPicker
                    }
                }
            }

            glassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background opacity")
                        .font(.subheadline)
                    HStack {
                        Slider(value: $theming.gradientOpacity, in: 0.0...1.0, step: 0.01)
                        Text("\(Int(theming.gradientOpacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            glassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.subheadline)
                    let colors = theming.activeColors(wallpaperColors: wallpaper.colors)
                    LinearGradient(
                        colors: colors.map { $0.opacity(theming.gradientOpacity) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var wallpaperPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected colors")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(wallpaper.colors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color)
                        .frame(width: 44, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
                Spacer()
            }
        }
    }

    private var manualColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom colors")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                ColorPicker("Color 1", selection: $theming.customColor1)
                ColorPicker("Color 2", selection: $theming.customColor2)
            }
        }
    }
}

// MARK: - Shortcuts Content

struct ShortcutsContent: View {
    @ObservedObject var store: ProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Shortcuts")
                .padding(.bottom, 4)

            glassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quickcycle")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Press this hotkey to cycle through all your layout profiles in order.")
                        .font(.caption).foregroundStyle(.secondary)
                    HotkeyRecorderRow(
                        displayString: store.quickswapHotkey?.displayString,
                        set: { store.quickswapHotkey = $0; store.save() },
                        clear: { store.quickswapHotkey = nil; store.save() }
                    )
                }
            }

            glassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organise Windows")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Press this hotkey to open the window organisation overlay after snapping. Click a zone, then pick an opened window to place there.")
                        .font(.caption).foregroundStyle(.secondary)
                    HotkeyRecorderRow(
                        displayString: store.organiseHotkey?.displayString,
                        set: { store.organiseHotkey = $0; store.save() },
                        clear: { store.organiseHotkey = nil; store.save() }
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }
}
