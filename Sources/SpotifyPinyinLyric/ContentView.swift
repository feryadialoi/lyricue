import SwiftUI

private struct RowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))

            content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 520, height: 130)
        .opacity(viewModel.isPaused ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
    }

    @ViewBuilder
    private var content: some View {
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
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
        }
    }
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
                            .font(.system(size: pinyinSize))
                            .foregroundColor(dimmed ? Color.gray.opacity(0.4) : .gray)
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
