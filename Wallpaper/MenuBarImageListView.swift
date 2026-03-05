import SwiftUI

struct MenuBarImageListView: View {
    private enum ListMode: String, CaseIterable, Identifiable {
        case all = "全部"
        case favorites = "收藏夹"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: ImageViewModel
    @State private var listMode: ListMode = .all

    private var displayedImages: [ImageItem] {
        switch listMode {
        case .all:
            return viewModel.images
        case .favorites:
            return viewModel.favoriteImages
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Picsum 图片")
                    .font(.headline)
                Spacer()
                Button("随机壁纸") {
                    Task { await viewModel.fetchAndSetRandomWallpaper() }
                }
                .disabled(viewModel.isSettingWallpaper)
                Button("刷新") {
                    Task { await viewModel.refresh() }
                }
                .disabled(viewModel.isLoading)
            }

            Picker("列表", selection: $listMode) {
                ForEach(ListMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.categories.isEmpty {
                Text("分类加载中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("分类", selection: $viewModel.selectedCategoryId) {
                    ForEach(viewModel.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("自动换壁纸", selection: $viewModel.selectedInterval) {
                ForEach(WallpaperInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            .pickerStyle(.menu)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(displayedImages) { item in
                        VStack(spacing: 10) {
                            ZStack(alignment: .bottomTrailing) {
                                RemoteImageView(url: URL(string: item.download_url), contentMode: .fill)
                                    .frame(width: 160, height: 118)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    viewModel.toggleFavorite(item)
                                } label: {
                                    Image(systemName: viewModel.isFavorite(item) ? "heart.fill" : "heart")
                                        .font(.caption2)
                                        .foregroundStyle(viewModel.isFavorite(item) ? .red : .white)
                                        .padding(5)
                                        .background(.black.opacity(0.5), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                            }
                            .contextMenu {
                                Button("设为桌面壁纸") {
                                    Task { await viewModel.setWallpaper(for: item) }
                                }
                                Button(viewModel.isFavorite(item) ? "取消收藏" : "收藏") {
                                    viewModel.toggleFavorite(item)
                                }
                            }

                            Text("作者：" + item.author)
                                .lineLimit(1)
                                .font(.subheadline)

                            Spacer()
                        }
                    }

                    if listMode == .all && viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }

                    if listMode == .all && viewModel.canLoadMore && !viewModel.isLoading {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await viewModel.loadMoreImages() }
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 180, height: 480)
        }
        .padding(12)
        .task {
            await viewModel.loadCategories()
            if viewModel.images.isEmpty {
                await viewModel.loadMoreImages()
            }
        }
    }
}

#Preview {
    MenuBarImageListView(viewModel: ImageViewModel())
}
