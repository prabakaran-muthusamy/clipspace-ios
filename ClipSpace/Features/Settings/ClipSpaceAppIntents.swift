//
//  OpenClipSpaceIntent.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 03/10/26.
//

import AppIntents

struct OpenClipSpaceIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ClipSpace"
    static let description = IntentDescription("Opens ClipSpace to your clipboard history.")
    static var supportedModes: IntentModes { .foreground }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ClipSpaceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenClipSpaceIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open my clipboard in \(.applicationName)"
            ],
            shortTitle: "Open ClipSpace",
            systemImageName: "rectangle.stack"
        )
    }
}
