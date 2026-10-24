import Foundation

enum MusicPlatform: String, CaseIterable, Identifiable {
    case kuwo
    case wyy

    var id: String { rawValue }
    var label: String { self == .kuwo ? "酷我 K" : "网易云 W" }
}

enum APIError: LocalizedError {
    case network(String)
    case server(String)
    case badData

    var errorDescription: String? {
        switch self {
        case .network(let m): return "网络请求失败：\(m)"
        case .server(let m): return m
        case .badData: return "接口返回数据异常"
        }
    }
}

private struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let msg: String?
    let data: T?
}

struct SearchData: Decodable {
    var list: [Song]?
    let total: Int?
}

private struct StreamURLData: Decodable {
    let url: String?
}

@MainActor
final class MusicAPI {
    static let shared = MusicAPI()
    /// 站点接口若有变更，改这里即可
    static let baseURLString = "https://flac.music.hi.cn/ajax.php"

    private let session: URLSession
    /// 解析出的 CDN 直链有效期约 1 小时，与站点网页端策略一致
    private var urlCache: [String: (url: URL, expire: Date)] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    private func call<T: Decodable>(_ act: String, params: [String: String]) async throws -> T {
        guard let base = URLValidator.validURL(Self.baseURLString) else { throw APIError.badData }
        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded;charset=UTF-8",
            forHTTPHeaderField: "Content-Type"
        )

        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = comps.percentEncodedQuery?.data(using: .utf8)

        let raw: Data
        let response: URLResponse
        do {
            (raw, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.network("HTTP \(code)")
        }
        let envelope: APIEnvelope<T>
        do {
            envelope = try JSONDecoder().decode(APIEnvelope<T>.self, from: raw)
        } catch {
            throw APIError.badData
        }
        guard envelope.code == 0 else {
            throw APIError.server(envelope.msg ?? "接口返回错误")
        }
        guard let data = envelope.data else { throw APIError.badData }
        return data
    }

    func search(
        platform: MusicPlatform, keyword: String, page: Int, size: Int = 20
    ) async throws -> SearchData {
        var result: SearchData = try await call("search", params: [
            "platform": platform.rawValue,
            "keyword": keyword,
            "page": String(page),
            "size": String(size),
        ])
        result.list = (result.list ?? []).map { song in
            var s = song
            s.platform = platform.rawValue
            return s
        }
        return result
    }

    /// 解析播放/下载直链
    func streamURL(for song: Song, format: String, bitrate: String) async throws -> URL {
        let key = song.id
        if let cached = urlCache[key], cached.expire > Date() { return cached.url }

        let data: StreamURLData = try await call("getUrl", params: [
            "platform": song.platform ?? MusicPlatform.kuwo.rawValue,
            "songid": song.songID,
            "format": format,
            "bitrate": bitrate,
            "time": String(song.time ?? 0),
            "sign": song.sign ?? "",
        ])
        guard let url = URLValidator.validURL(data.url) else {
            throw APIError.server("未获取到有效的播放地址")
        }
        urlCache[key] = (url, Date().addingTimeInterval(3600))
        return url
    }

    /// 歌词（标准 LRC 文本）
    func lyric(for song: Song) async throws -> String {
        try await call("getLyric", params: [
            "platform": song.platform ?? MusicPlatform.kuwo.rawValue,
            "songid": song.songID,
            "time": String(song.time ?? 0),
            "sign": song.sign ?? "",
        ])
    }
}
