import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum ClipSpaceStyle {
    static let blue = Color(red: 0.10, green: 0.42, blue: 0.96)
    static let page = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct ClipTypeIcon: View {
    let kind: ClipKind

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconColor)
            .frame(width: 38, height: 38)
            .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }

    private var iconColor: Color {
        switch kind {
        case .text: .indigo
        case .link: .blue
        case .image: .orange
        case .file: .purple
        }
    }
}

struct ClipRow: View {
    @AppStorage("maskSensitiveContent") private var masksSensitiveContent = true

    let clip: ClipItem
    var showsActions = true
    var copyAction: () -> Void = { }
    var pinAction: () -> Void = { }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SourceAppIcon(sourceApp: clip.sourceApp, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(clip.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(clip.displayContent(maskingSensitiveContent: masksSensitiveContent))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .privacySensitive(clip.isSensitive)
                ClipRowFooter(
                    sourceAppName: clip.sourceApp.rawValue,
                    sourceDevice: clip.sourceDevice,
                    copiedAt: clip.createdAt
                )
            }
            Spacer(minLength: 4)
            if showsActions {
                VStack(spacing: 6) {
                    ClipRowActionButton(title: "Copy", symbol: "doc.on.doc", tint: ClipSpaceStyle.blue, action: copyAction)
                    ClipRowActionButton(
                        title: clip.isPinned ? "Unpin" : "Pin",
                        symbol: clip.isPinned ? "pin.slash" : "pin",
                        tint: .orange,
                        action: pinAction
                    )
                }
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct ClipRowFooter: View {
    let sourceAppName: String
    let sourceDevice: String
    let copiedAt: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MetadataColumn(
                title: "Copied from",
                value: "\(sourceAppName) · \(sourceDevice)",
                alignment: .leading
            )
            Spacer(minLength: 4)
            MetadataColumn(
                title: "Copied at",
                value: DateFormatterHelper.previewString(for: copiedAt),
                alignment: .trailing
            )
        }
        .padding(.top, 3)
    }
}

private struct MetadataColumn: View {
    let title: LocalizedStringKey
    let value: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct SourceAppIcon: View {
    let sourceApp: ClipSourceApp
    let size: CGFloat

    var body: some View {
#if canImport(AppKit)
        if let sourceAppIcon {
            Image(nsImage: sourceAppIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityHidden(true)
        } else {
            fallbackIcon
        }
#else
        fallbackIcon
#endif
    }

    @ViewBuilder
    private var fallbackIcon: some View {
        if let assetName = sourceApp.assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Image(systemName: sourceApp.symbolName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.gray, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityHidden(true)
        }
    }

#if canImport(AppKit)
    private var sourceAppIcon: NSImage? {
        guard
            let bundleIdentifier = sourceApp.bundleIdentifier,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else {
            return NSImage(named: NSImage.applicationIconName)
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
#endif
}

private struct ClipRowActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.09), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct ClipSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search your clips", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    text = ""
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .padding(.horizontal, 16)
    }
}

struct FilterBar: View {
    @Binding var selection: ClipCategory

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                ForEach(ClipCategory.allCases) { category in
                    Button {
                        selection = category
                    } label: {
                        Label(category.rawValue, systemImage: category.symbolName)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selection == category ? Color.white : Color.primary)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(
                        selection == category ? AnyShapeStyle(ClipSpaceStyle.blue) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
                        in: Capsule()
                    )
                    .overlay {
                        if selection != category {
                            Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        }
                    }
                    .accessibilityAddTraits(selection == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

struct SectionHeading: View {
    let title: LocalizedStringKey
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let action {
                Button("See All", action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
    }
}

struct SyncStatusView: View {
    let state: SyncState

    var body: some View {
        Label(state.rawValue, systemImage: state == .synced ? "checkmark.circle.fill" : "arrow.trianglehead.2.clockwise")
            .font(.caption)
            .foregroundStyle(state == .synced ? Color.green : Color.secondary)
    }
}
