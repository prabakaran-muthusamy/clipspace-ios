//
//  ClipLibraryViewModel.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

struct ClipListView: View {
    @Bindable var model: ClipLibraryViewModel
    let clips: [ClipItem]
    let showsSuggestions: Bool
    @Binding var selection: ClipItem?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ClipSearchField(text: $model.query)
                FilterBar(selection: $model.category)
                if showsSuggestions && !model.suggestions.isEmpty {
                    SuggestionSection(clips: model.suggestions, model: model, selection: $selection)
                }
                RecentClipSection(title: showsSuggestions ? "Recent" : "Clips",
                                  clips: clips,
                                  model: model,
                                  selection: $selection)
            }
            .padding(.vertical, 8)
            .padding(.bottom, 72)
        }
        .background(ClipSpaceStyle.page)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if !model.isLoading && clips.isEmpty && (!showsSuggestions || model.suggestions.isEmpty) {
                EmptyStateView(title: "No Clips", message: "Copied items matching your search will appear here.", symbol: "clipboard")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Select", systemImage: "checkmark.circle") { }
                Button("Add Clip", systemImage: "plus") { }
            }
        }
    }
}

private struct SuggestionSection: View {
    let clips: [ClipItem]
    let model: ClipLibraryViewModel
    @Binding var selection: ClipItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Suggestions")
            VStack(spacing: 0) {
                ForEach(clips) { clip in
                    ClipNavigationRow(clip: clip, model: model, selection: $selection)
                    if clip.id != clips.last?.id { Divider().padding(.leading, 50) }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: title)
            VStack(spacing: 0) {
                ForEach(clips) { clip in
                    ClipNavigationRow(clip: clip, model: model, selection: $selection)
                        .swipeActions(edge: .leading) {
                            Button(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin") {
                                Task { await model.togglePin(clip) }
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await model.delete(clip) }
                            }
                        }
                    if clip.id != clips.last?.id { Divider().padding(.leading, 50) }
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
    
    var body: some View {
        NavigationLink(value: clip) {
            ClipRow(
                clip: clip,
                copyAction: { model.copy(clip) },
                pinAction: { Task { await model.togglePin(clip) } }
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { selection = clip })
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc") { model.copy(clip) }
            Button(clip.isPinned ? "Unpin" : "Pin", systemImage: clip.isPinned ? "pin.slash" : "pin") {
                Task { await model.togglePin(clip) }
            }
        }
    }
}
