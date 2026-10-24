import Foundation

struct Playlist: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var songs: [Song]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, songs: [Song] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.songs = songs
        self.createdAt = createdAt
    }
}

/// 已下载到本地的歌曲索引
struct LocalTrack: Codable, Hashable, Identifiable {
    let id: String
    var song: Song
    var fileName: String
    var format: String?
    var bitrate: String?
    var size: Int64
    var downloadedAt: Date
    var lyricFileName: String?

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// library.json 的整体结构
struct LibraryData: Codable {
    var favorites: [Song] = []
    var playlists: [Playlist] = []
    var locals: [LocalTrack] = []
    var searchHistory: [String] = []
}
