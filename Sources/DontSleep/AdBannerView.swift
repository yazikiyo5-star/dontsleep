import SwiftUI

/// Bottom-right sponsored banner. Renders whatever `AdBannerModel.current`
/// holds at the moment. When `current` is nil, shows a subtle
/// "Loading ad…" placeholder that AdWindowController hides almost
/// immediately by ordering the window out until a creative is available.
struct AdBannerView: View {

    @ObservedObject var model: AdBannerModel
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            contentLayer
            closeButton
        }
        .frame(width: 320, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Main content

    @ViewBuilder
    private var contentLayer: some View {
        if let creative = model.current {
            Button(action: { open(creative.clickURL) }) {
                HStack(spacing: 12) {
                    iconView(for: creative)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        attributionBadge(creative.attribution)
                        Text(creative.headline)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if let body = creative.body, !body.isEmpty {
                            Text(body)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("広告を読み込み中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func iconView(for creative: AdCreative) -> some View {
        if let url = creative.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                default:
                    fallbackIcon(creative.fallbackSymbol)
                }
            }
        } else {
            fallbackIcon(creative.fallbackSymbol)
        }
    }

    private func fallbackIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 26))
            .foregroundStyle(.secondary)
    }

    private func attributionBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                )
            Spacer(minLength: 0)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .help("閉じる")
    }

    // MARK: - Actions

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
