import SwiftUI

@main
struct FlacMusicApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var player = PlayerManager.shared
    @StateObject private var downloader = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(player)
                .environmentObject(downloader)
        }
    }
}
