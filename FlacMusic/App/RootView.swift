import SwiftUI

struct RootView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var downloader: DownloadManager
    @State private var showPlayer = false

    var body: some View {
        TabView {
            SearchView()
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }

            FavoritesView()
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("收藏", systemImage: "heart.fill") }

            LocalView()
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("本地", systemImage: "internaldrive.fill") }

            PlaylistsView()
                .withMiniPlayer(showPlayer: $showPlayer)
                .tabItem { Label("播放列表", systemImage: "music.note.list") }
        }
        .glassTabBehavior()
        .fullScreenCover(isPresented: $showPlayer) {
            NowPlayingView()
        }
        .alert("播放出错", isPresented: Binding(
            get: { player.errorMessage != nil },
            set: { if !$0 { player.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .alert("下载提示", isPresented: Binding(
            get: { downloader.lastError != nil },
            set: { if !$0 { downloader.lastError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(downloader.lastError ?? "")
        }
    }
}

extension View {
    /// 在 Tab 内容底部挂常驻迷你播放条（位于 TabBar 上方）
    func withMiniPlayer(showPlayer: Binding<Bool>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar(showPlayer: showPlayer)
        }
    }
}
