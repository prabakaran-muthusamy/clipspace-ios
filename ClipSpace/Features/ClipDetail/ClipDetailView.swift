//
//  ClipDetailView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

struct ClipDetailView: View {
    let clip: ClipItem
    let copyAction: () -> Void
    let pinAction: () async -> Void
    @State private var revealsSensitiveContent = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ClipDetailHeader(clip: clip)
                ClipDetailActions(
                    clip: clip,
                    copyAction: copyAction,
                    openAction: openClip,
                    pinAction: pinAction
                )
                ClipPreviewCard(clip: clip, revealsSensitiveContent: $revealsSensitiveContent)
                ClipDetailsCard(clip: clip)
            }
            .padding(16)
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(ClipSpaceStyle.page)
        .navigationTitle("Clip Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("More", systemImage: "ellipsis.circle") { }
            }
        }
    }

    private func openClip() {
        guard let url = URL(string: clip.content) else { return }
        openURL(url)
    }
}

private struct ClipDetailHeader: View {
    let clip: ClipItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ClipTypeIcon(kind: clip.kind)
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(clip.displayContent)
                    .font(.subheadline)
                    .foregroundStyle(ClipSpaceStyle.blue)
                    .lineLimit(2)
                Text("Copied \(DateFormatterHelper.previewString(for: clip.createdAt)) · \(clip.sourceDevice)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ClipDetailActions: View {
    let clip: ClipItem
    let copyAction: () -> Void
    let openAction: () -> Void
    let pinAction: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            DetailActionButton(title: "Copy", symbol: "doc.on.doc", action: copyAction)
            if clip.kind == .link {
                DetailActionButton(title: "Open", symbol: "safari", action: openAction)
            }
            ShareLink(item: clip.content) {
                DetailActionLabel(title: "Share", symbol: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            Button {
                Task { await pinAction() }
            } label: {
                DetailActionLabel(title: clip.isPinned ? "Unpin" : "Pin", symbol: clip.isPinned ? "pin.slash" : "pin")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct DetailActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DetailActionLabel(title: title, symbol: symbol)
        }
        .buttonStyle(.plain)
    }
}

private struct DetailActionLabel: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(ClipSpaceStyle.blue)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(ClipSpaceStyle.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct ClipPreviewCard: View {
    let clip: ClipItem
    @Binding var revealsSensitiveContent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview").font(.headline)
            Group {
                if clip.isSensitive && !revealsSensitiveContent {
                    Button {
                        revealsSensitiveContent = true
                    } label: {
                        Label("Reveal sensitive content", systemImage: "eye")
                            .frame(maxWidth: .infinity, minHeight: 110)
                    }
                } else if clip.kind == .image {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 42))
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .foregroundStyle(.secondary)
                } else {
                    Text(clip.content)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .privacySensitive(clip.isSensitive)
                }
            }
            .padding(16)
            .background(ClipSpaceStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct ClipDetailsCard: View {
    let clip: ClipItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details").font(.headline)
            VStack(spacing: 0) {
                DetailRow(title: "Type", value: clip.kind.rawValue)
                Divider()
                DetailRow(title: "Source", value: clip.sourceDevice)
                Divider()
                DetailRow(title: "Copied at", value: DateFormatterHelper.previewString(for: clip.createdAt))
                Divider()
                DetailRow(title: "Size", value: ByteCountFormatter.string(fromByteCount: Int64(clip.byteCount), countStyle: .file))
            }
            .padding(.horizontal, 14)
            .background(ClipSpaceStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct DetailRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }
}
