import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        NavigationStack {
            Group {
                if store.favorites.isEmpty {
                    EmptyStateView(
                        systemImage: "heart",
                        title: "还没有收藏",
                        subtitle: "在搜索结果点「··· → 收藏」添加喜欢的歌"
                    )
                } else {
                    List {
                        ForEach(store.favorites) { song in
                            SongRow(song: song, queue: store.favorites)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.toggleFavorite(store.favorites[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("收藏")
            .toolbar {
                if !store.favorites.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            player.play(store.favorites[0], in: store.favorites)
                        } label: {
                            Label("播放全部", systemImage: "play.circle.fill")
                        }
                    }
                }
            }
        }
    }
}
