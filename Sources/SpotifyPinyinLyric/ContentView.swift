import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LyricsViewModel

    var body: some View {
        ZStack {
            // Semi-transparent dark pill background.
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))

            content
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 500, height: 100)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.showLyrics {
            VStack(spacing: 4) {
                if !viewModel.currentPinyin.isEmpty {
                    Text(viewModel.currentPinyin)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.opacity)
                }

                Text(viewModel.currentHanzi)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.currentHanzi)
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
