import SwiftUI

/// 歌词滚动视图：当前行居中高亮，点击任意行跳转播放位置
struct LyricsView: View {
    let lines: [LyricLine]
    let currentIndex: Int?
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        Group {
            if lines.isEmpty {
                EmptyStateView(systemImage: "music.quarternote.3", title: "暂无歌词")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(lines) { line in
                                let isCurrent = line.id == currentIndex
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(isCurrent ? .title3.weight(.semibold) : .body)
                                    .foregroundStyle(
                                        isCurrent ? Color.primary : Color.secondary.opacity(0.75)
                                    )
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .id(line.id)
                                    .onTapGesture { onSeek(line.time) }
                            }
                        }
                        .padding(.vertical, 120)
                    }
                    .mask(fadeMask)
                    .onChange(of: currentIndex) { newValue in
                        if let target = newValue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        if let current = currentIndex {
                            proxy.scrollTo(current, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
