//
//  unisnapApp.swift
//  unisnap
//
//  Created by qubixal on 3/7/2026.
//

import SwiftUI

@main
struct unisnapApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
