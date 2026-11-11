import SwiftUI
import AppKit

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: LyricsViewModel
    @ObservedObject var settings: DisplaySettings

    var body: some View {
        switch settings.mode {
        case .corner:
            CornerCard(viewModel: viewModel)
        default:
            FloatingPill(viewModel: viewModel)
        }
    }
}

// MARK: - Floating pill

struct FloatingPill: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        ZStack {
            PanelBackground(cornerRadius: 18, tint: 0.45)

            Group {
                if viewModel.showLyrics {
                    VStack(spacing: 6) {
                        AlignedLyricLine(text: viewModel.currentHanzi)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                            .id(viewModel.currentHanzi)

                        if !viewModel.nextHanzi.isEmpty {
                            AlignedLyricLine(text: viewModel.nextHanzi, scale: 0.6, dimmed: true)
                                .transition(.opacity)
                                .id("next-\(viewModel.nextHanzi)")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentHanzi)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.nextHanzi)
                } else {
                    StatusText(message: viewModel.statusMessage, size: 13)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .frame(width: OverlayLayout.floatingSize.width, height: OverlayLayout.floatingSize.height)
        .opacity(viewModel.isPaused ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
    }
}

// MARK: - Corner card

/// Larger, higher-contrast card for the bottom-right corner.
struct CornerCard: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        ZStack {
            PanelBackground(cornerRadius: 16, tint: 0.7)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPaused ? "pause.fill" : "music.note")
                        .font(.system(size: 10, weight: .semibold))
                    Text(trackLine)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundColor(Color.white.opacity(0.5))

                Group {
                    if viewModel.showLyrics {
                        VStack(spacing: 6) {
                            AlignedLyricLine(text: viewModel.currentHanzi, scale: 1.25)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .id(viewModel.currentHanzi)

                            if !viewModel.nextHanzi.isEmpty {
                                AlignedLyricLine(text: viewModel.nextHanzi, scale: 0.7, dimmed: true)
                                    .transition(.opacity)
                                    .id("next-\(viewModel.nextHanzi)")
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentHanzi)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.nextHanzi)
                    } else {
                        StatusText(message: viewModel.statusMessage, size: 15)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(14)
        }
        .frame(width: OverlayLayout.cornerSize.width, height: OverlayLayout.cornerSize.height)
        .opacity(viewModel.isPaused ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
    }

    private var trackLine: String {
        if viewModel.trackTitle.isEmpty { return "Lyricue" }
        if viewModel.trackArtist.isEmpty { return viewModel.trackTitle }
        return "\(viewModel.trackTitle) · \(viewModel.trackArtist)"
    }
}

// MARK: - Shared pieces

enum OverlayLayout {
    static let floatingSize = CGSize(width: 520, height: 130)
    static let cornerSize = CGSize(width: 380, height: 140)
}

struct StatusText: View {
    let message: String
    let size: CGFloat

    var body: some View {
        Text(message)
            .font(.system(size: size))
            .foregroundColor(Color.white.opacity(0.6))
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: message)
    }
}

/// Dark frosted-glass panel: blurs what is behind the window, adds a dark tint
/// for legibility and a hairline border.
struct PanelBackground: View {
    let cornerRadius: CGFloat
    let tint: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            VisualEffectBlur()
            Color.black.opacity(tint)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Renders a lyric line with pinyin syllables aligned directly above each Hanzi character.
struct AlignedLyricLine: View {
    let text: String
    var scale: CGFloat = 1.0
    var dimmed: Bool = false

    private var tokens: [LyricToken] { tokenize(text) }
    private var hanziSize: CGFloat { 20 * scale }
    private var pinyinSize: CGFloat { 11 * scale }

    var body: some View {
        GeometryReader { geo in
            let row = rowView
            row
                .fixedSize()                          // measure natural size
                .background(
                    GeometryReader { inner in
                        Color.clear.preference(
                            key: RowWidthKey.self,
                            value: inner.size.width
                        )
                    }
                )
                .scaleEffect(
                    min(1.0, (geo.size.width) / max(1, naturalWidth)),
                    anchor: .center
                )
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity)
        .frame(height: (hanziSize + pinyinSize + 4))  // fixed row height
        .onPreferenceChange(RowWidthKey.self) { naturalWidth = $0 }
    }

    @State private var naturalWidth: CGFloat = 1

    private var rowView: some View {
        HStack(alignment: .bottom, spacing: 2 * scale) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                VStack(spacing: 1) {
                    if !token.pinyin.isEmpty {
                        Text(token.pinyin)
                            .font(.system(size: pinyinSize, design: .rounded))
                            .foregroundColor(Color.white.opacity(dimmed ? 0.3 : 0.6))
                            .lineLimit(1)
                    } else {
                        Color.clear
                            .frame(width: 1, height: pinyinSize + 1)
                    }

                    Text(token.text)
                        .font(.system(size: hanziSize, weight: dimmed ? .regular : .medium))
                        .foregroundColor(dimmed ? Color.white.opacity(0.35) : .white)
                        .lineLimit(1)
                }
            }
        }
    }
}
