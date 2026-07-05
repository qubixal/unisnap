//
//  SettingsView.swift
//  Setting sidebar View -> Sidebar -> Content
//  unisnap
//

import SwiftUI

// MARK: - NSVisualEffectView Wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let isEmphasized: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.isEmphasized = isEmphasized
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.isEmphasized = isEmphasized
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var store: ProfileStore
    @StateObject private var systemTheme = SystemThemeProvider()
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
                VisualEffectView(
                    material: .underWindowBackground,
                    blendingMode: .behindWindow,
                    isEmphasized: true
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: theming.activeColors(systemColors: systemTheme.systemColors).map { $0.opacity(theming.gradientOpacity * 0.6) },
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
            VisualEffectView(
                material: .sidebar,
                blendingMode: .behindWindow,
                isEmphasized: false
            )
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
            .padding(.top, 4)
            .padding(.bottom, 2)

            List(store.profiles, selection: $selectedProfileID) { profile in
                ProfileRow(profile: profile, store: store)
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
            ThemingContent(systemTheme: systemTheme, theming: theming)
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

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: LayoutProfile
    @ObservedObject var store: ProfileStore
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggleFavourite) {
                Image(systemName: profile.isFavourite ? "star.fill" : "star")
                    .foregroundStyle(profile.isFavourite ? .yellow : .secondary)
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .opacity(isHovering || profile.isFavourite ? 1 : 0)

            Text(profile.name)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func toggleFavourite() {
        store.toggleFavourite(for: profile.id)
    }
}

// MARK: - Section Header

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.title3).fontWeight(.semibold)
}

// MARK: - Theming Content

struct ThemingContent: View {
    @ObservedObject var systemTheme: SystemThemeProvider
    @ObservedObject var theming: ThemingSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Appearance")
                .padding(.bottom, 4)

            glassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $theming.autoAdaptToSystem) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-adapt to system")
                            Text("Derive gradient from your accent colour and appearance")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)

                    if theming.autoAdaptToSystem {
                        systemPreview
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
                    let colors = theming.activeColors(systemColors: systemTheme.systemColors)
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

    private var systemPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System colours")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(systemTheme.systemColors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color)
                        .frame(width: 44, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(systemTheme.isDarkMode ? "Dark Mode" : "Light Mode")
                        .font(.caption).fontWeight(.medium)
                    Text("Accent colour")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var manualColorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom colours")
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quickcycle")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Press a hotkey to cycle through all your layout profiles.")
                        .font(.caption).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 6) {
                        HotkeyRecorderRow(
                            label: "Forward:",
                            displayString: store.quickswapHotkey?.displayString,
                            set: { store.quickswapHotkey = $0; store.save() },
                            clear: { store.quickswapHotkey = nil; store.save() }
                        )
                        HotkeyRecorderRow(
                            label: "Backward:",
                            displayString: store.quickswapReverseHotkey?.displayString,
                            set: { store.quickswapReverseHotkey = $0; store.save() },
                            clear: { store.quickswapReverseHotkey = nil; store.save() }
                        )
                    }
                }
            }

            glassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Organise Windows")
                        .font(.subheadline).fontWeight(.medium)
                    Text("Press this hotkey to open the window organisation overlay after snapping. Click a zone, then pick an opened window to place there.")
                        .font(.caption).foregroundStyle(.secondary)
                    HotkeyRecorderRow(
                        label: "Shortcut:",
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
