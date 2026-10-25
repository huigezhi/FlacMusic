import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var downloader: DownloadManager

    @State private var platform: MusicPlatform = .kuwo
    @State private var keyword = ""
    @State private var results: [Song] = []
    @State private var total = 0
    @State private var page = 1
    @State private var isLoading = false
    @State private var reachedEnd = false
    @State private var didSearch = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                platformPicker
                searchBar

                if results.isEmpty {
                    if isLoading {
                        ProgressView("正在搜索…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorText {
                        errorView(errorText)
                    } else if didSearch {
                        EmptyStateView(
                            systemImage: "magnifyingglass",
                            title: "没有找到相关歌曲",
                            subtitle: "换个关键词或切换音源试试"
                        )
                    } else if !store.searchHistory.isEmpty {
                        historyView
                    } else {
                        EmptyStateView(
                            systemImage: "music.note",
                            title: "搜索你想听的歌",
                            subtitle: "支持酷我 / 网易云双音源，可试听与下载无损 FLAC"
                        )
                    }
                } else {
                    resultList
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 输入区

    private var platformPicker: some View {
        Picker("音源", selection: $platform) {
            ForEach(MusicPlatform.allCases) { p in
                Text(p.label).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .onChange(of: platform) { _ in
            if didSearch, !keyword.trimmingCharacters(in: .whitespaces).isEmpty {
                Task { await search(reset: true) }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("歌曲 / 歌手 / 专辑", text: $keyword)
                    .submitLabel(.search)
                    .onSubmit { Task { await search(reset: true) } }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glassAdaptive(in: RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await search(reset: true) }
            } label: {
                Text("搜索")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(keyword.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("搜索历史")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清空") { store.clearHistory() }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            FlowLayout(spacing: 8) {
                ForEach(store.searchHistory, id: \.self) { item in
                    Button(item) {
                        keyword = item
                        Task { await search(reset: true) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - 结果列表

    private var resultList: some View {
        List {
            ForEach(results) { song in
                SongRow(song: song, queue: results, downloadProgress: downloader.active[song.id])
            }

            if !reachedEnd {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("上拉加载更多")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .onAppear { Task { await loadMore() } }
            } else if !results.isEmpty {
                Text("共 \(total) 条结果，没有更多了")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await search(reset: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 请求

    private func search(reset: Bool) async {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return }
        if reset {
            page = 1
            reachedEnd = false
            didSearch = true
            store.pushHistory(kw)
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let data = try await MusicAPI.shared.search(
                platform: platform, keyword: kw, page: page
            )
            let list = data.list ?? []
            total = data.total ?? total
            results = reset ? list : results + list
            reachedEnd = list.count < 20 || (data.total ?? 0) <= results.count
        } catch {
            if reset { results = [] }
            errorText = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !isLoading, !reachedEnd, !results.isEmpty else { return }
        page += 1
        await search(reset: false)
    }
}
