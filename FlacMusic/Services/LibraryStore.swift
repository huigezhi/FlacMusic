import Foundation
import SwiftUI

/// 收藏 / 歌单 / 本地索引 / 搜索历史，全部持久化在 Documents/library.json
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [Song] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var locals: [LocalTrack] = []
    @Published private(set) var searchHistory: [String] = []

    private var data = LibraryData()
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("library.json")
        load()
    }

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode(LibraryData.self, from: raw) {
            data = loaded
            favorites = loaded.favorites
            playlists = loaded.playlists
            locals = loaded.locals
            searchHistory = loaded.searchHistory
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? encoder.encode(data) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - 收藏

    func isFavorite(_ song: Song) -> Bool {
        favorites.contains { $0.id == song.id }
    }

    func toggleFavorite(_ song: Song) {
        if isFavorite(song) {
            favorites.removeAll { $0.id == song.id }
        } else {
            favorites.insert(song, at: 0)
        }
        save()
    }

    // MARK: - 歌单

    @discardableResult
    func createPlaylist(named name: String) -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(name: trimmed.isEmpty ? "新建歌单" : trimmed)
        playlists.insert(playlist, at: 0)
        save()
        return playlist
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        save()
    }

    func playlist(with id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    /// 已存在返回 false（不重复添加）
    @discardableResult
    func addToPlaylist(_ song: Song, playlistID: UUID) -> Bool {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return false }
        guard !playlists[index].songs.contains(where: { $0.id == song.id }) else { return false }
        playlists[index].songs.append(song)
        save()
        return true
    }

    func removeFromPlaylist(_ song: Song, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].songs.removeAll { $0.id == song.id }
        save()
    }

    // MARK: - 本地下载索引

    func localTrack(for song: Song) -> LocalTrack? {
        locals.first { $0.id == song.id }
    }

    func isDownloaded(_ song: Song) -> Bool {
        localTrack(for: song) != nil
    }

    func addLocal(_ track: LocalTrack) {
        locals.removeAll { $0.id == track.id }
        locals.insert(track, at: 0)
        save()
    }

    func removeLocal(id: String) {
        locals.removeAll { $0.id == id }
        save()
    }

    func setLyricFile(for songID: String, fileName: String?) {
        guard let index = locals.firstIndex(where: { $0.id == songID }) else { return }
        locals[index].lyricFileName = fileName
        save()
    }

    // MARK: - 搜索历史

    func pushHistory(_ keyword: String) {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        searchHistory.removeAll { $0 == kw }
        searchHistory.insert(kw, at: 0)
        if searchHistory.count > 20 {
            searchHistory = Array(searchHistory.prefix(20))
        }
        save()
    }

    func clearHistory() {
        searchHistory = []
        save()
    }
}
