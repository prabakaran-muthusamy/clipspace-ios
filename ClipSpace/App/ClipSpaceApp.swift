//
//  ClipSpaceApp.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

@main
struct ClipSpaceApp: App {
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue

    init() {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        try? FileManager.default.removeItem(at: Self.uiTestStoreURL)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }

    private static var uiTestStoreURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ClipSpaceUITests.json")
    }

    private var colorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearance) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
