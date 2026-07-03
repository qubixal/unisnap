//
//  HotkeyManager.swift
//  unisnap
//
//  Created by qubixal on 3/7/2026.
//

import Cocoa

// MARK: - Hotkey Manager

final class HotkeyManager {
    private var eventMonitor: Any?
    private var profileStore: ProfileStore
    private var onQuickswap: () -> Void
    private var onProfileHotkey: (UUID) -> Void
    private var onOrganise: () -> Void

    init(profileStore: ProfileStore, onQuickswap: @escaping () -> Void, onProfileHotkey: @escaping (UUID) -> Void, onOrganise: @escaping () -> Void) {
        self.profileStore = profileStore
        self.onQuickswap = onQuickswap
        self.onProfileHotkey = onProfileHotkey
        self.onOrganise = onOrganise
    }

    func start() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        let combo = HotkeyCombo(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue)

        if let quickswap = profileStore.quickswapHotkey, combo == quickswap {
            onQuickswap()
            return
        }

        if let organise = profileStore.organiseHotkey, combo == organise {
            onOrganise()
            return
        }

        for profile in profileStore.profiles {
            if let hotkey = profile.hotkey, combo == hotkey {
                onProfileHotkey(profile.id)
                return
            }
        }
    }
}

// MARK: - Hotkey Recording

final class HotkeyRecorder: ObservableObject {
    private var localMonitor: Any?

    func startRecording(completion: @escaping (HotkeyCombo?) -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        let handler: (NSEvent) -> NSEvent = { [weak self] event in
            guard self != nil else { return event }

            let combo = HotkeyCombo(keyCode: event.keyCode, modifiers: event.modifierFlags.rawValue)

            if event.keyCode == 53 {
                DispatchQueue.main.async { completion(nil) }
            } else {
                DispatchQueue.main.async { completion(combo) }
            }
            return event
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    func stopRecording() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}
