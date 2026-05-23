import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))

            content
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(width: 500, height: 110)
        .opacity(viewModel.isPaused ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.showLyrics {
            VStack(spacing: 2) {
                // Current line
                VStack(spacing: 2) {
                    if !viewModel.currentPinyin.isEmpty {
                        Text(viewModel.currentPinyin)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Text(viewModel.currentHanzi)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .id(viewModel.currentHanzi)

                // Next line preview
                if !viewModel.nextHanzi.isEmpty {
                    VStack(spacing: 1) {
                        if !viewModel.nextPinyin.isEmpty {
                            Text(viewModel.nextPinyin)
                                .font(.caption2)
                                .foregroundColor(Color.gray.opacity(0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        Text(viewModel.nextHanzi)
                            .font(.callout)
                            .foregroundColor(Color.white.opacity(0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .transition(.opacity)
                    .id("next-\(viewModel.nextHanzi)")
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentHanzi)
            .animation(.easeInOut(duration: 0.2), value: viewModel.nextHanzi)
        } else {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.statusMessage)
        }
    }
}
