import SwiftUI
import AppKit

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

enum TickerLayout {
    static let width: CGFloat = 300
}

/// One-line lyric for the menu bar: the line itself, then its reading.
/// Scrolls when the line is wider than the ticker.
struct MenuBarTicker: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        MarqueeText(key: viewModel.showLyrics ? viewModel.currentHanzi : viewModel.statusMessage) {
            HStack(spacing: 8) {
                if viewModel.showLyrics {
                    Text(viewModel.currentHanzi)
                        .font(.system(size: 13, weight: .medium))
                    let reading = readingOf(viewModel.currentHanzi)
                    if !reading.isEmpty {
                        Text(reading)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .lineLimit(1)
        }
        .opacity(viewModel.isPaused ? 0.5 : 1.0)
        .frame(width: TickerLayout.width, height: 22)
    }

    /// Phonetic reading of a line (pinyin, hiragana or romanized hangul), or empty if none.
    private func readingOf(_ line: String) -> String {
        tokenize(line)
            .map(\.pinyin)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Shows content as-is when it fits; otherwise holds briefly, then scrolls it
/// leftwards in a seamless loop. `key` restarts the scroll when the text changes.
struct MarqueeText<Content: View>: View {
    let key: String
    @ViewBuilder let content: () -> Content

    @State private var contentWidth: CGFloat = 0
    @State private var start = Date()

    private let speed: CGFloat = 35        // points per second
    private let gap: CGFloat = 40          // space between repeats
    private let hold: TimeInterval = 1.2   // pause before scrolling starts

    var body: some View {
        GeometryReader { geo in
            let overflows = contentWidth > geo.size.width
            Group {
                if overflows {
                    TimelineView(.animation) { context in
                        let elapsed = max(0, context.date.timeIntervalSince(start) - hold)
                        let cycle = contentWidth + gap
                        let offset = (CGFloat(elapsed) * speed).truncatingRemainder(dividingBy: cycle)
                        HStack(spacing: gap) {
                            content().fixedSize()
                            content().fixedSize()
                        }
                        .offset(x: -offset)
                    }
                } else {
                    content().fixedSize()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: overflows ? .leading : .center)
            .clipped()
        }
        .background(
            content()
                .fixedSize()
                .hidden()
                .background(GeometryReader { g in
                    Color.clear.preference(key: TextWidthKey.self, value: g.size.width)
                })
        )
        .onPreferenceChange(TextWidthKey.self) { contentWidth = $0 }
        .onChange(of: key) { _ in start = Date() }
    }
}

/// Hosting view that lets clicks fall through to the status item button,
/// so the menu still opens when the ticker is clicked.
final class PassthroughHostingView<V: View>: NSHostingView<V> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
