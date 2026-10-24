import Foundation

/// 一档可选音质（来自搜索结果 minfo）
struct MInfo: Codable, Hashable, Identifiable {
    let bitrate: String?
    let size: String?
    let format: String?

    var id: String { "\(format ?? "?")-\(bitrate ?? "?")" }

    var displayName: String {
        switch format?.lowercased() {
        case "flac":
            return "无损 FLAC · \(size ?? "")"
        case "mp3":
            let tag = bitrate == "320" ? "极高 320K" : "\(bitrate ?? "128")K"
            return "\(tag) MP3 · \(size ?? "")"
        default:
            return "\(format?.uppercased() ?? "音频") \(bitrate ?? "") · \(size ?? "")"
        }
    }

    var shortTag: String {
        switch format?.lowercased() {
        case "flac": return "FLAC"
        case "mp3": return bitrate == "320" ? "320K" : "\(bitrate ?? "128")K"
        default: return (format ?? "").uppercased()
        }
    }
}

/// 一首歌曲。服务器返回的 id 在酷我是字符串、网易云是数字，统一转成 String；
/// platform 是客户端在搜索后补上的，二者拼出跨平台唯一 id。
struct Song: Codable, Hashable, Identifiable {
    let songID: String
    var platform: String?
    let name: String
    let artist: String?
    let albumName: String?
    let picURL: String?
    let duration: Int?
    let minfo: [MInfo]?
    let link: String?
    let time: Int?
    let sign: String?

    enum CodingKeys: String, CodingKey {
        case songID = "id"
        case platform
        case name
        case artist
        case albumName = "album_name"
        case picURL = "pic_url"
        case duration
        case minfo
        case link
        case time
        case sign
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        songID = Self.flexString(c, .songID) ?? ""
        platform = Self.flexString(c, .platform)
        name = Self.flexString(c, .name) ?? "未知歌曲"
        artist = Self.flexString(c, .artist)
        albumName = Self.flexString(c, .albumName)
        picURL = Self.flexString(c, .picURL)
        duration = Self.flexInt(c, .duration)
        minfo = try? c.decode([MInfo].self, forKey: .minfo)
        link = Self.flexString(c, .link)
        time = Self.flexInt(c, .time)
        sign = Self.flexString(c, .sign)
    }

    private static func flexString(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> String? {
        if let s = try? c.decode(String.self, forKey: key) { return s }
        if let i = try? c.decode(Int64.self, forKey: key) { return String(i) }
        if let d = try? c.decode(Double.self, forKey: key) { return String(d) }
        return nil
    }

    private static func flexInt(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> Int? {
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        if let s = try? c.decode(String.self, forKey: key) { return Int(s) }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    var id: String { "\(platform ?? "?")-\(songID)" }

    var displayArtist: String {
        if let artist, !artist.isEmpty { return artist }
        return "未知歌手"
    }

    var displayAlbum: String {
        if let albumName, !albumName.isEmpty { return albumName }
        return "未知专辑"
    }

    var durationText: String { Self.timeText(duration ?? 0) }

    static func timeText(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// 流播默认选最高音质：优先 FLAC，否则第一档
    var bestQuality: (format: String, bitrate: String)? {
        guard let list = minfo, !list.isEmpty else { return nil }
        if let flac = list.first(where: { $0.format?.lowercased() == "flac" }) {
            return (flac.format ?? "flac", flac.bitrate ?? "999")
        }
        let m = list[0]
        return (m.format ?? "mp3", m.bitrate ?? "320")
    }

    /// 列表角标：有 FLAC 显示 FLAC，否则显示最高一档
    var qualityBadge: String? {
        guard let list = minfo, !list.isEmpty else { return nil }
        if list.contains(where: { $0.format?.lowercased() == "flac" }) { return "FLAC" }
        if let m320 = list.first(where: { $0.bitrate == "320" }) { return m320.shortTag }
        return list.first?.shortTag
    }
}
