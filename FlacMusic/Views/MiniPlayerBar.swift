import SwiftUI

/// 常驻迷你播放条：悬浮玻璃胶囊，显示在 TabBar 上方，点击进入全屏播放页
struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        Group {
            if player.current != nil {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ArtworkView(urlString: player.current?.picURL, cornerRadius: 8)
                    .frame(width: 42, height: 42)
                    .onTapGesture { showPlayer = true }

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.current?.name ?? "")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(player.current?.displayArtist ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .onTapGesture { showPlayer = true }

                Spacer(minLength: 8)

                if player.buffering {
                    ProgressView()
                        .padding(.horizontal, 6)
                } else {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 2)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(2, proxy.size.width * player.progress), height: 2)
                }
            }
            .frame(height: 2)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .padding(.horizontal, 14)
        }
        .glassAdaptive(in: RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }
}
