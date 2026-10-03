//
//  ContentView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

private enum AppDestination: String, CaseIterable, Identifiable {
    case suggestions = "Suggestions"
    case recent = "Recent"
    case pinned = "Pinned"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case files = "Files"
    case devices = "Devices"
    case settings = "Settings"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .suggestions: "sparkles"
        case .recent: "clock"
        case .pinned: "pin"
        case .text: "doc.text"
        case .links: "link"
        case .images: "photo"
        case .files: "doc"
        case .devices: "laptopcomputer.and.iphone"
        case .settings: "gear"
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: ClipLibraryViewModel
    @State private var syncModel: DeviceSyncViewModel
    @State private var selectedClip: ClipItem?
    @State private var destination: AppDestination = .recent
    @State private var compactTab = AppDestination.recent
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init(
        repository: (any ClipRepository)? = nil,
        clipboard: any ClipboardWriting = SystemClipboardWriter()
    ) {
        let resolvedRepository = repository ?? Self.defaultRepository
        _model = State(initialValue: ClipLibraryViewModel(repository: resolvedRepository, clipboard: clipboard))
        _syncModel = State(initialValue: DeviceSyncViewModel(repository: resolvedRepository))
    }

    private static var defaultRepository: any ClipRepository {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClipSpaceUITests.json")
            return LocalClipRepository(fileURL: url)
        }
        return LocalClipRepository()
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                if horizontalSizeClass == .compact {
                    compactNavigation
                } else {
                    expandedNavigation
                }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .task {
            if model.clips.isEmpty {
                await model.load()
            }
            await synchronizeIfEnabled()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await synchronizeIfEnabled() }
        }
    }

    private var compactNavigation: some View {
        TabView(selection: $compactTab) {
            Tab("Recent", systemImage: "clock", value: .recent) {
                NavigationStack {
                    ClipListView(model: model, clips: model.recentClips, showsSuggestions: false, selection: $selectedClip)
                        .navigationTitle("ClipSpace")
                        .navigationBarTitleDisplayMode(.large)
                        .navigationDestination(for: ClipItem.self) { clip in
                            detail(for: clip)
                        }
                }
            }
            Tab("Pinned", systemImage: "pin", value: .pinned) {
                NavigationStack {
                    ClipListView(
                        model: model,
                        clips: model.pinnedClips,
                        showsSuggestions: false,
                        selection: $selectedClip,
                        mode: .pinned
                    )
                        .navigationTitle("Pinned")
                        .navigationBarTitleDisplayMode(.large)
                        .navigationDestination(for: ClipItem.self) { clip in
                            detail(for: clip)
                        }
                }
            }
            Tab("Devices", systemImage: "laptopcomputer.and.iphone", value: .devices) {
                NavigationStack {
                    DevicesView(model: syncModel, clipsDidChange: model.load)
                }
            }
            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView(syncModel: syncModel, libraryModel: model)
                }
            }
        }
    }

    private var expandedNavigation: some View {
        NavigationSplitView {
            List {
                Section {
                    sidebarRow(.recent)
                    sidebarRow(.pinned)
                }
                Section("Types") {
                    sidebarRow(.text)
                    sidebarRow(.links)
                }
                Section {
                    sidebarRow(.devices)
                    sidebarRow(.settings)
                }
            }
            .navigationTitle("ClipSpace")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 480)
        } detail: {
            if let selectedClip {
                detail(for: selectedClip)
            } else {
                EmptyStateView(title: "Select a Clip", message: "Choose a clip to preview its content and details.", symbol: "doc.on.clipboard")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch destination {
        case .devices:
            DevicesView(model: syncModel, clipsDidChange: model.load)
        case .settings:
            SettingsView(syncModel: syncModel, libraryModel: model)
        default:
            ClipListView(
                model: model,
                clips: clips(for: destination),
                showsSuggestions: false,
                selection: $selectedClip,
                mode: destination == .pinned ? .pinned : .library
            )
            .navigationTitle(destination.rawValue)
        }
    }

    private func sidebarRow(_ item: AppDestination) -> some View {
        Button {
            destination = item
            selectedClip = nil
        } label: {
            Label(item.rawValue, systemImage: item.symbol)
                .foregroundStyle(destination == item ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .accessibilityAddTraits(destination == item ? .isSelected : [])
    }

    private func clips(for destination: AppDestination) -> [ClipItem] {
        switch destination {
        case .suggestions:
            model.suggestions
        case .recent:
            model.recentClips
        case .pinned:
            model.pinnedClips
        case .text:
            model.filteredClips.filter { $0.kind == .text }
        case .links:
            model.filteredClips.filter { $0.kind == .link }
        case .images:
            model.filteredClips.filter { $0.kind == .image }
        case .files:
            model.filteredClips.filter { $0.kind == .file }
        case .devices, .settings:
            []
        }
    }

    private func detail(for clip: ClipItem) -> some View {
        ClipDetailView(clip: clip, copyAction: {
            model.copy(clip)
        }, pinAction: {
            await model.togglePin(clip)
        }, deleteAction: {
            await model.delete(clip)
            selectedClip = nil
        })
    }

    private func synchronizeIfEnabled() async {
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        await syncModel.refresh()
        guard syncModel.isConsentGranted,
              syncModel.accountAvailability == .available,
              !syncModel.isSyncing else { return }
        await syncModel.synchronize()
        await model.load()
    }
}

#Preview {
    ContentView()
}
