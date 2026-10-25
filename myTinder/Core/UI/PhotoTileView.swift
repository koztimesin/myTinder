//
//  PhotoTileView.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import SwiftUI

/// Общие размеры плиток фото.
enum PhotoTileMetrics {
    
    /// Соотношение сторон: ширина к высоте.
    static let aspectRatio: CGFloat = 3 / 4
    /// Радиус скругления.
    static let cornerRadius: CGFloat = 12
}

struct PhotoTileView: View {
    
    private let viewModel: PhotoTileViewModel
    
    init(viewModel: PhotoTileViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Color.clear
            .aspectRatio(PhotoTileMetrics.aspectRatio, contentMode: .fit)
            .overlay {
                image
            }
            .clipShape(RoundedRectangle(cornerRadius: PhotoTileMetrics.cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: PhotoTileMetrics.cornerRadius))
            .overlay(alignment: .topTrailing) {
                deletePhotoButton
            }
            .overlay(alignment: .bottomLeading) {
                mainPhotoTag
            }
            .overlay(alignment: .bottomTrailing) {
                makePhotoMain
            }
            .accessibilityElement(children: .contain)
    }
    
    @ViewBuilder
    private var deletePhotoButton: some View {
        if viewModel.canRemove {
            Button(action: viewModel.onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(6)
            .accessibilityLabel("Удалить фото \(viewModel.position)")
        }
    }
    
    @ViewBuilder
    private var mainPhotoTag: some View {
        if viewModel.isMain {
            Text("Главное")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
                .padding(6)
        }
    }
    
    @ViewBuilder
    private var makePhotoMain: some View {
        if !viewModel.isMain {
            Button(action: viewModel.onMakeMain) {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(6)
            .accessibilityLabel("Сделать фото \(viewModel.position) главным")
        }
    }
    
    /// Картинка плитки: локальная сразу, серверная по ссылке (спиннер пока грузится, значок при ошибке).
    @ViewBuilder
    private var image: some View {
        switch viewModel.source {
        case .local(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
            
        case .remote(let url?):
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            
        case .remote(nil):
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }
}
