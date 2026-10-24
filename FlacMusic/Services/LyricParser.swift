import Foundation

struct LyricLine: Identifiable, Hashable {
    let id: Int
    let time: TimeInterval
    let text: String
}

enum LyricParser {
    private static let tagRegex = try? NSRegularExpression(
        pattern: #"\[(\d{1,3}):(\d{1,2}(?:[.,:]\d{1,3})?)\]"#
    )

    /// 解析 LRC：多时间戳行自动展开为多行，按时间排序
    static func parse(_ lrc: String) -> [LyricLine] {
        guard let regex = tagRegex else { return [] }
        var entries: [(time: TimeInterval, text: String)] = []

        for rawLine in lrc.components(separatedBy: .newlines) {
            let lineNS = rawLine as NSString
            guard lineNS.length > 0 else { continue }
            let matches = regex.matches(
                in: rawLine, range: NSRange(location: 0, length: lineNS.length)
            )
            guard !matches.isEmpty else { continue }

            var stripped = rawLine
            for match in matches.reversed() {
                stripped = (stripped as NSString)
                    .replacingCharacters(in: match.range, with: "")
            }
            let text = stripped.trimmingCharacters(in: .whitespaces)

            for match in matches {
                let minutes = Double(lineNS.substring(with: match.range(at: 1))) ?? 0
                let secString = lineNS
                    .substring(with: match.range(at: 2))
                    .replacingOccurrences(of: ",", with: ".")
                let seconds = Double(secString) ?? 0
                entries.append((minutes * 60 + seconds, text))
            }
        }

        entries.sort { $0.time < $1.time }
        return entries.enumerated().map { index, item in
            LyricLine(id: index, time: item.time, text: item.text)
        }
    }

    /// 当前时间对应的歌词行下标（最后一行 time <= 播放位置）
    static func currentIndex(at time: TimeInterval, in lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty else { return nil }
        var result: Int?
        for (index, line) in lines.enumerated() where line.time <= time + 0.05 {
            result = index
        }
        return result
    }
}
