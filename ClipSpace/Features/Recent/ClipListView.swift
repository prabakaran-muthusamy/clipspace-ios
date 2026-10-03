import SwiftUI

enum ClipListMode {
    case library
    case pinned
}

struct ClipListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var model: ClipLibraryViewModel
    let clips: [ClipItem]
    let showsSuggestions: Bool
    @Binding var selection: ClipItem?
    var mode: ClipListMode = .library

    @State private var isSelecting = false
    @State private var selectedIDs: Set<ClipItem.ID> = []
    @State private var showsAddClip = false
    @State private var showsDeleteConfirmation = false
    @State private var showsCopyConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if horizontalSizeClass != .compact {
                        ClipListInlineActions(
                            isSelecting: isSelecting,
                            hasVisibleClips: !visibleClips.isEmpty,
                            allVisibleClipsSelected: !visibleClips.isEmpty && selectedIDs.count == visibleClips.count,
                            selectAction: { isSelecting = true },
                            selectAllAction: { selectedIDs = Set(visibleClips.map(\.id)) },
                            doneAction: endSelection,
                            addAction: { showsAddClip = true }
                        )
                    }
                    ClipSearchField(text: $model.query)
                        .disabled(isSelecting)
                        .opacity(isSelecting ? 0.55 : 1)
                    FilterBar(selection: $model.category)
                        .disabled(isSelecting)
                        .opacity(isSelecting ? 0.55 : 1)
                    if showsSuggestions && !model.suggestions.isEmpty {
                        SuggestionSection(
                            clips: model.suggestions,
                            model: model,
                            selection: $selection,
                            isSelecting: isSelecting,
                            selectedIDs: $selectedIDs
                        )
                    }
                    RecentClipSection(
                        title: sectionTitle,
                        clips: clips,
                        model: model,
                        selection: $selection,
                        isSelecting: isSelecting,
                        selectedIDs: $selectedIDs
                    )
                }
                .padding(.vertical, 8)
                .padding(.bottom, 72)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if !model.isLoading && clips.isEmpty && (!showsSuggestions || model.suggestions.isEmpty) {
                    EmptyStateView(
                        title: mode == .pinned ? "No Pinned Clips" : "No Clips",
                        message: mode == .pinned
                            ? "Pin a clip to keep it close at hand."
                            : "Save a text or link clip to see it here.",
                        symbol: mode == .pinned ? "pin" : "clipboard"
                    )
                }
            }

            if isSelecting {
                ClipSelectionActionBar(
                    selectedCount: selectedIDs.count,
                    showsPinAction: mode != .pinned,
                    canPin: mode != .pinned && selectedClips.contains { !$0.isPinned },
                    canUnpin: selectedClips.contains { $0.isPinned },
                    pinAction: { updateSelectedPins(true) },
                    unpinAction: { updateSelectedPins(false) },
                    deleteAction: { showsDeleteConfirmation = true }
                )
            }
        }
        .background(ClipSpaceStyle.page)
        .sensoryFeedback(.success, trigger: model.copyFeedbackCount)
        .overlay(alignment: .top) {
            if showsCopyConfirmation {
                Label("Copied", systemImage: "checkmark")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("copyConfirmation")
                    .transition(.opacity)
            }
        }
        .onChange(of: model.copyFeedbackCount) {
            showsCopyConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                showsCopyConfirmation = false
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if horizontalSizeClass == .compact {
                    if isSelecting {
                        Button("Select All") {
                            selectedIDs = Set(visibleClips.map(\.id))
                        }
                        .disabled(visibleClips.isEmpty || selectedIDs.count == visibleClips.count)

                        Button("Done") {
                            endSelection()
                        }
                    } else {
                        Button("Select", systemImage: "checkmark.circle") {
                            isSelecting = true
                        }
                        .disabled(visibleClips.isEmpty)

                        Button("Add Clip", systemImage: "plus") {
                            showsAddClip = true
                        }
                        .accessibilityIdentifier("addClipButton")
                    }
                }
            }
        }
        .sheet(isPresented: $showsAddClip) {
            AddClipView(model: model, startsPinned: mode == .pinned)
        }
        .alert("ClipSpace", isPresented: errorIsPresented) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "Something went wrong.")
        }
        .confirmationDialog(
            "Delete selected clips?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if selectedIDs.count == 1 {
                Button("Delete Clip", role: .destructive) {
                    deleteSelected()
                }
            } else {
                Button("Delete \(selectedIDs.count) Clips", role: .destructive) {
                    deleteSelected()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var visibleClips: [ClipItem] {
        var result = clips
        if showsSuggestions {
            result.append(contentsOf: model.suggestions)
        }
        return result
    }

    private var sectionTitle: LocalizedStringKey {
        if mode == .pinned {
            "Pinned Clips"
        } else {
            showsSuggestions ? "Recent" : "Clips"
        }
    }

    private var selectedClips: [ClipItem] {
        model.clips.filter { selectedIDs.contains($0.id) }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorMessage = nil
                }
            }
        )
    }

    private func updateSelectedPins(_ isPinned: Bool) {
        let clips = selectedClips
        Task {
            await model.setPinned(isPinned, clips: clips)
            endSelection()
        }
    }

    private func deleteSelected() {
        let clips = selectedClips
        Task {
            await model.delete(clips)
            endSelection()
        }
    }

    private func endSelection() {
        selectedIDs.removeAll()
        isSelecting = false
    }
}

private struct ClipListInlineActions: View {
    let isSelecting: Bool
    let hasVisibleClips: Bool
    let allVisibleClipsSelected: Bool
    let selectAction: () -> Void
    let selectAllAction: () -> Void
    let doneAction: () -> Void
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            if isSelecting {
                Button("Select All", systemImage: "checkmark.circle", action: selectAllAction)
                    .disabled(allVisibleClipsSelected)
                Button("Done", action: doneAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Select", systemImage: "checkmark.circle", action: selectAction)
                    .disabled(!hasVisibleClips)
                Button("Add Clip", systemImage: "plus", action: addAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 16)
    }
}

private struct SuggestionSection: View {
    let clips: [ClipItem]
    let model: ClipLibraryViewModel
    @Binding var selection: ClipItem?
    let isSelecting: Bool
    @Binding var selectedIDs: Set<ClipItem.ID>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Suggestions")
            VStack(spacing: 0) {
                ForEach(clips) { clip in
                    ClipNavigationRow(
                        clip: clip,
                        model: model,
                        selection: $selection,
                        isSelecting: isSelecting,
                        selectedIDs: $selectedIDs
                    )
                    if clip.id != clips.last?.id {
                        Divider().padding(.leading, isSelecting ? 84 : 50)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(ClipSpaceStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 16)
    }
}

private struct RecentClipSection: View {
    let title: LocalizedStringKey
    let clips: [ClipItem]
    let model: ClipLibraryViewModel
    @Binding var selection: ClipItem?
    let isSelecting: Bool
    @Binding var selectedIDs: Set<ClipItem.ID>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: title)
            VStack(spacing: 0) {
                ForEach(clips) { clip in
                    ClipNavigationRow(
                        clip: clip,
                        model: model,
                        selection: $selection,
                        isSelecting: isSelecting,
                        selectedIDs: $selectedIDs
                    )
                    if clip.id != clips.last?.id {
                        Divider().padding(.leading, isSelecting ? 84 : 50)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(ClipSpaceStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

private struct ClipNavigationRow: View {
    let clip: ClipItem
    let model: ClipLibraryViewModel
    @Binding var selection: ClipItem?
    let isSelecting: Bool
    @Binding var selectedIDs: Set<ClipItem.ID>

    var body: some View {
        if isSelecting {
            Button {
                toggleSelection()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedIDs.contains(clip.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedIDs.contains(clip.id) ? ClipSpaceStyle.blue : Color.secondary)
                        .accessibilityHidden(true)
                    ClipRow(
                        clip: clip,
                        showsActions: false
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(clip.title)
            .accessibilityValue(selectedIDs.contains(clip.id) ? "Selected" : "Not selected")
        } else {
            NavigationLink(value: clip) {
                ClipRow(
                    clip: clip,
                    copyAction: { model.copy(clip) },
                    pinAction: { Task { await model.togglePin(clip) } }
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clipRow_\(clip.title)")
            .simultaneousGesture(TapGesture().onEnded { selection = clip })
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") {
                    model.copy(clip)
                }
                Button(
                    clip.isPinned ? "Unpin" : "Pin",
                    systemImage: clip.isPinned ? "pin.slash" : "pin"
                ) {
                    Task { await model.togglePin(clip) }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task { await model.delete(clip) }
                }
            }
        }
    }

    private func toggleSelection() {
        if selectedIDs.contains(clip.id) {
            selectedIDs.remove(clip.id)
        } else {
            selectedIDs.insert(clip.id)
        }
    }
}

private struct ClipSelectionActionBar: View {
    let selectedCount: Int
    let showsPinAction: Bool
    let canPin: Bool
    let canUnpin: Bool
    let pinAction: () -> Void
    let unpinAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack {
            if showsPinAction {
                SelectionActionButton(title: "Pin", symbol: "pin", action: pinAction)
                    .disabled(!canPin)
            }
            SelectionActionButton(title: "Unpin", symbol: "pin.slash", action: unpinAction)
                .disabled(!canUnpin)
            SelectionActionButton(
                title: "Delete",
                symbol: "trash",
                tint: .red,
                action: deleteAction
            )
        }
        .disabled(selectedCount == 0)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
        .accessibilityLabel("\(selectedCount) clips selected")
    }
}

private struct SelectionActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    var tint: Color = ClipSpaceStyle.blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct AddClipView: View {
    let model: ClipLibraryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var kind: ClipKind = .text
    @State private var sourceApp: ClipSourceApp = .unknown
    @State private var isPinned = false
    @State private var isSensitive = false
    @State private var isSaving = false
    @State private var showsSaveError = false
    @State private var saveErrorMessage = ""

    init(model: ClipLibraryViewModel, startsPinned: Bool) {
        self.model = model
        _isPinned = State(initialValue: startsPinned)
        _isSensitive = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--ui-testing-sensitive-clip")
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Clip") {
                    Picker("Type", selection: $kind) {
                        ForEach([ClipKind.text, .link], id: \.self) { kind in
                            Label(kind.rawValue, systemImage: kind.symbolName)
                                .tag(kind)
                        }
                    }
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("clipTitleField")
                    TextField("Paste or type content", text: $content, axis: .vertical)
                        .accessibilityIdentifier("clipContentField")
                        .lineLimit(5...10)
                }

                Section("Source") {
                    Picker("Copied from", selection: $sourceApp) {
                        ForEach(ClipSourceApp.allCases) { app in
                            Text(app.rawValue).tag(app)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Pin Clip", systemImage: "pin", isOn: $isPinned)
                    Toggle("Sensitive Content", systemImage: "eye.slash", isOn: $isSensitive)
                        .accessibilityIdentifier("sensitiveContentToggle")
                }
            }
            .navigationTitle("Add Clip")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .alert("Couldn’t Add Clip", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveErrorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .accessibilityLabel("Adding Clip")
                        } else {
                            Text("Add")
                                .accessibilityIdentifier("saveClipButton")
                        }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        isSaving = true
        Task {
            let didSave = await model.addClip(
                title: title,
                content: content,
                kind: kind,
                sourceApp: sourceApp,
                isPinned: isPinned,
                isSensitive: isSensitive
            )
            isSaving = false
            if didSave {
                dismiss()
            } else {
                saveErrorMessage = model.errorMessage ?? "Please try again."
                model.errorMessage = nil
                showsSaveError = true
            }
        }
    }
}
