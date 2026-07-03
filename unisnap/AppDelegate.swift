//
//  AppDelegate.swift
//  unisnap
//
//  Created by qubixal on 3/7/2026.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotkeyManager: HotkeyManager?
    private(set) var profileStore: ProfileStore?
    private var currentProfileIndex = 0
    private var editorWindow: NSWindow?
    private var organiseWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var accessibilityPollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusBarIcon(profile: nil)

        let store = ProfileStore()
        self.profileStore = store

        buildMenu()

        store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.buildMenu() }
        }.store(in: &cancellables)

        let trusted = AXIsProcessTrusted()
        NSLog("[unisnap] Accessibility trusted: \(trusted)")
        if !trusted {
            promptForAccessibility()
            startAccessibilityPolling()
        }

        hotkeyManager = HotkeyManager(
            profileStore: store,
            onQuickswap: { [weak self] in
                DispatchQueue.main.async { self?.cycleToNextProfile() }
            },
            onProfileHotkey: { [weak self] id in
                DispatchQueue.main.async { self?.activateProfile(id) }
            },
            onOrganise: { [weak self] in
                DispatchQueue.main.async { self?.showOrganise() }
            }
        )
        if trusted {
            hotkeyManager?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
        accessibilityPollTimer?.invalidate()
    }

    // MARK: - Accessibility Polling

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if AXIsProcessTrusted() {
                NSLog("[unisnap] Accessibility permission granted!")
                self?.accessibilityPollTimer?.invalidate()
                self?.accessibilityPollTimer = nil
                self?.hotkeyManager?.start()
            }
        }
    }

    // MARK: - Status Bar Icon

    private func updateStatusBarIcon(profile: LayoutProfile?) {
        if let button = statusItem.button {
            let image = profile?.menuBarImage() ?? LayoutProfile.defaultMenuBarImage()
            image.isTemplate = true
            button.image = image
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        if let store = profileStore {
            let favourites = store.profiles.filter { $0.isFavourite }
            let others = store.profiles.filter { !$0.isFavourite }

            if let quickswap = store.quickswapHotkey {
                let item = NSMenuItem(title: "Cycle Layouts (\(quickswap.displayString))", action: #selector(cycleLayouts), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            } else {
                let item = NSMenuItem(title: "Cycle Layouts", action: #selector(cycleLayouts), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }

            if !favourites.isEmpty {
                menu.addItem(NSMenuItem.separator())

                for profile in favourites {
                    let title = profile.hotkey != nil ? "\(profile.name) (\(profile.hotkey!.displayString))" : profile.name
                    let item = NSMenuItem(title: title, action: #selector(profileMenuItemClicked(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = profile.id
                    menu.addItem(item)
                }
            }

            if !others.isEmpty {
                let moreMenu = NSMenu()
                for profile in others {
                    let title = profile.hotkey != nil ? "\(profile.name) (\(profile.hotkey!.displayString))" : profile.name
                    let item = NSMenuItem(title: title, action: #selector(profileMenuItemClicked(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = profile.id
                    moreMenu.addItem(item)
                }
                let moreItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
                moreItem.submenu = moreMenu
                menu.addItem(moreItem)
            }

            menu.addItem(NSMenuItem.separator())

            if let organise = store.organiseHotkey {
                let item = NSMenuItem(title: "Organise Windows (\(organise.displayString))", action: #selector(organiseWindows), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            } else {
                let item = NSMenuItem(title: "Organise Windows", action: #selector(organiseWindows), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())

            let editorItem = NSMenuItem(title: "Settings...", action: #selector(showProfileEditorFromMenu), keyEquivalent: ",")
            editorItem.keyEquivalentModifierMask = [.command]
            editorItem.target = self
            menu.addItem(editorItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quitItem)
        }

        statusItem.menu = menu
    }

    @objc private func cycleLayouts() {
        cycleToNextProfile()
    }

    @objc private func profileMenuItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        activateProfile(id)
    }

    @objc private func showProfileEditorFromMenu() {
        showProfileEditor()
    }

    @objc private func organiseWindows() {
        showOrganise()
    }

    // MARK: - Profile Activation

    func cycleToNextProfile() {
        guard let store = profileStore, !store.profiles.isEmpty else { return }
        currentProfileIndex = (currentProfileIndex + 1) % store.profiles.count
        let profile = store.profiles[currentProfileIndex]
        updateStatusBarIcon(profile: profile)
        snapWindows(to: profile)
    }

    func activateProfile(_ id: UUID) {
        guard let store = profileStore,
              let profile = store.profiles.first(where: { $0.id == id }) else { return }
        currentProfileIndex = store.profiles.firstIndex(where: { $0.id == id }) ?? 0
        updateStatusBarIcon(profile: profile)
        snapWindows(to: profile)
    }

    // MARK: - Windows

    func showProfileEditor() {
        guard let store = profileStore else { return }

        if let existing = editorWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(store: store)
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Unisnap Settings"
        window.contentView = hostingView
        window.minSize = NSSize(width: 520, height: 380)
        window.center()
        window.isReleasedWhenClosed = false
        editorWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOrganise() {
        guard let store = profileStore,
              currentProfileIndex < store.profiles.count else { return }

        if let existing = organiseWindow {
            existing.orderOut(nil)
            organiseWindow = nil
        }

        let profile = store.profiles[currentProfileIndex]
        let windows = getVisibleWindows()

        let view = OrganiseView(
            profile: profile,
            windows: windows,
            onDone: { [weak self] in
                DispatchQueue.main.async {
                    self?.organiseWindow?.orderOut(nil)
                    self?.organiseWindow = nil
                }
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? .zero
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        organiseWindow = panel
    }

    // MARK: - Accessibility Permission

    private func promptForAccessibility() {
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Unisnap needs Accessibility access to detect global key presses and move windows.\n\nClick Open to grant permission, then toggle unisnap ON in System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
}
