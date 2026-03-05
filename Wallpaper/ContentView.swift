//
//  ContentView.swift
//  Wallpaper
//
//  Created by dj on 2026/3/4.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var viewModel: ImageViewModel
    @State private var previewItem: ImageItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if viewModel.categories.isEmpty {
                            Text("分类加载中…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.categories) { category in
                                Button {
                                    viewModel.selectedCategoryId = category.id
                                } label: {
                                    Text(category.name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewModel.selectedCategoryId == category.id
                                            ? .blue.opacity(0.2)
                                            : .gray.opacity(0.15)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                        ForEach(viewModel.images) { item in
                            ZStack(alignment: .bottomTrailing) {
                                RemoteImageView(url: URL(string: item.download_url), contentMode: .fit)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 2)
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                    .onTapGesture {
                                        previewItem = item
                                    }

                                HStack(spacing: 8) {
                                    Button {
                                        Task { await viewModel.downloadImage(for: item) }
                                    } label: {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.black.opacity(0.45), in: Circle())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        viewModel.copyImageLink(for: item)
                                    } label: {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .padding(8)
                                            .background(.black.opacity(0.45), in: Circle())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        viewModel.toggleFavorite(item)
                                    } label: {
                                        Image(systemName: viewModel.isFavorite(item) ? "heart.fill" : "heart")
                                            .font(.headline)
                                            .foregroundStyle(viewModel.isFavorite(item) ? .red : .white)
                                            .padding(8)
                                            .background(.black.opacity(0.45), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                            }
                        }
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding()
                    
                    if viewModel.canLoadMore && !viewModel.isLoading {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await viewModel.loadMoreImages() }
                            }
                    }
                }
            }
            .navigationTitle("Picsum 图片")
            .toolbar {
                ToolbarItem {
                    Button("刷新") {
                        Task { await viewModel.refresh() }
                    }
                }
                ToolbarItem {
                    Button("随机壁纸") {
                        Task { await viewModel.fetchAndSetRandomWallpaper() }
                    }
                    .disabled(viewModel.isSettingWallpaper)
                }
                
                ToolbarItem(placement: .principal) {
                    Picker("自动换壁纸", selection: $viewModel.selectedInterval) {
                        ForEach(WallpaperInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)           // 或 .segmented（空间够的话）
                    .frame(minWidth: 140)
                }
                
                ToolbarItem {
                    if viewModel.isSettingWallpaper {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .overlay {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await viewModel.loadCategories()
                await viewModel.loadMoreImages()
            }
            .sheet(item: $previewItem) { item in
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()

                    RemoteImageView(url: URL(string: item.url.isEmpty ? item.download_url : item.url), contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()

                    Button("关闭") {
                        previewItem = nil
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    ContentView(viewModel: ImageViewModel())
}
