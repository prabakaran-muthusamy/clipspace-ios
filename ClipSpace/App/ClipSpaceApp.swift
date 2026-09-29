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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearance) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
