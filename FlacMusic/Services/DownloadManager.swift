import Foundation
import UIKit

/// 下载管理：解析直链 → URLSession 下载 → 落盘 Documents/Music → 自动抓歌词
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    /// songID → 进度 0~1
    @Published var active: [String: Double] = [:]
    @Published var lastError: String?

    static let musicDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func fileURL(named name: String) -> URL {
        musicDirectory.appendingPathComponent(name)
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 10 * 60
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var pending: [Int: (song: Song, info: MInfo)] = [:]
    private var taskBySongID: [String: URLSessionDownloadTask] = [:]

    func download(_ song: Song, quality: MInfo) {
        guard active[song.id] == nil else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await MusicAPI.shared.streamURL(
                    for: song,
                    format: quality.format ?? "mp3",
                    bitrate: quality.bitrate ?? "320"
                )
                self.active[song.id] = 0
                let task = self.session.downloadTask(with: url)
                self.pending[task.taskIdentifier] = (song, quality)
                self.taskBySongID[song.id] = task
                task.resume()
            } catch {
                self.lastError = "下载失败：\(error.localizedDescription)"
            }
        }
    }

    func cancel(_ songID: String) {
        if let task = taskBySongID[songID] {
            pending[task.taskIdentifier] = nil
            task.cancel()
        }
        taskBySongID[songID] = nil
        active[songID] = nil
    }

    /// 删除音频文件与歌词文件，并清除索引
    func deleteTrack(_ track: LocalTrack) {
        for name in [track.fileName, track.lyricFileName].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: Self.fileURL(named: name))
        }
        Task { @MainActor in
            LibraryStore.shared.removeLocal(id: track.id)
        }
    }

    // MARK: - 文件名

    static func sanitizedFileName(for song: Song, format: String) -> String {
        var base = "\(song.displayArtist) - \(song.name)"
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        base = base.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.count > 80 { base = String(base.prefix(80)) }
        if base.isEmpty { base = "未知歌曲" }
        return "\(base) [\(format.uppercased())].\(format.lowercased())"
    }

    static func uniqueFileURL(for song: Song, format: String) -> URL {
        let base = fileURL(named: sanitizedFileName(for: song, format: format))
        guard FileManager.default.fileExists(atPath: base.path) else { return base }
        let stem = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        for i in 2...100 {
            let candidate = musicDirectory.appendingPathComponent("\(stem) (\(i)).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return base
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let (song, _) = pending[downloadTask.taskIdentifier],
              totalBytesExpectedToWrite > 0 else { return }
        active[song.id] = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let (song, quality) = pending[downloadTask.taskIdentifier] else { return }
        pending[downloadTask.taskIdentifier] = nil
        taskBySongID[song.id] = nil
        defer { active[song.id] = nil }

        let format = (quality.format ?? "mp3").lowercased()
        let destination = Self.uniqueFileURL(for: song, format: format)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            lastError = "保存文件失败：\(error.localizedDescription)"
            return
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let track = LocalTrack(
            id: song.id,
            song: song,
            fileName: destination.lastPathComponent,
            format: quality.format,
            bitrate: quality.bitrate,
            size: size,
            downloadedAt: Date(),
            lyricFileName: nil
        )
        Task { @MainActor in
            LibraryStore.shared.addLocal(track)
            if let lyric = try? await MusicAPI.shared.lyric(for: song), !lyric.isEmpty {
                let lrcURL = destination.deletingPathExtension().appendingPathExtension("lrc")
                try? lyric.data(using: .utf8)?.write(to: lrcURL, options: .atomic)
                LibraryStore.shared.setLyricFile(for: song.id, fileName: lrcURL.lastPathComponent)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        guard let downloadTask = task as? URLSessionDownloadTask,
              let (song, _) = pending[downloadTask.taskIdentifier] else { return }
        pending[downloadTask.taskIdentifier] = nil
        taskBySongID[song.id] = nil
        active[song.id] = nil
        if (error as NSError).code == NSURLErrorCancelled { return }
        lastError = "下载失败：\(error.localizedDescription)"
    }
}
