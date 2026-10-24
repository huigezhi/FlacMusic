import SwiftUI

enum URLValidator {
    /// 仅允许 http/https 的公网地址，拒绝 localhost、环回、私有与保留网段。
    static func validURL(_ string: String?) -> URL? {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              let url = URL(string: s),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              !host.isEmpty
        else { return nil }

        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return nil
        }
        if host == "::1" || host == "[::1]" || host == "[::]" || host == "0.0.0.0" {
            return nil
        }
        // 点分 IPv4 形态：检查私有/保留网段
        let parts = host.split(separator: ".")
        if parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            let nums = parts.compactMap { Int($0) }
            if nums.count == 4 {
                let a = nums[0], b = nums[1]
                if a == 0 || a == 10 || a == 127
                    || (a == 100 && b >= 64 && b <= 127)      // CGNAT
                    || (a == 169 && b == 254)                  // link-local
                    || (a == 172 && b >= 16 && b <= 31)        // 私有
                    || (a == 192 && b == 168)                  // 私有
                    || a >= 224 {                              // 组播/保留
                    return nil
                }
            }
        }
        return url
    }
}

/// 封面图（含占位）
struct ArtworkView: View {
    let urlString: String?
    var cornerRadius: CGFloat = 6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(uiColor: .secondarySystemFill))
            if let url = URLValidator.validURL(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// 空态占位
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

/// 搜索历史等标签的流式布局（iOS 16 Layout 协议）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == 0 ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
