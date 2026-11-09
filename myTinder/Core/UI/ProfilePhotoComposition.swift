import PhotosUI
import SwiftUI

/// Фотокомпозиция редактора: одно крупное фото и три компактных слота.
struct ProfilePhotoComposition: View {

    let tiles: [PhotoTileViewModel]
    let remainingSlots: Int
    @Binding var pickerItems: [PhotosPickerItem]

    var body: some View {
        GeometryReader { proxy in
            let spacing = AppTheme.Spacing.s
            let mainWidth = (proxy.size.width - spacing) * 0.62

            HStack(spacing: spacing) {
                slot(at: 0)
                    .frame(width: mainWidth)

                VStack(spacing: spacing) {
                    slot(at: 1)
                    slot(at: 2)
                    slot(at: 3)
                }
            }
        }
        .frame(height: 336)
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let cornerRadius = AppTheme.Radius.medium
        let surfaceColor = AppTheme.Colors.surfaceMuted
        let borderColor = AppTheme.Colors.border
        let accentColor = AppTheme.Colors.accentText

        if tiles.indices.contains(index) {
            PhotoTileView(viewModel: tiles[index], fillsAvailableSpace: true)
        } else {
            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: remainingSlots,
                matching: .images
            ) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surfaceColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(.title2, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .disabled(remainingSlots == 0)
            .accessibilityLabel("Добавить фото в слот \(index + 1)")
        }
    }
}
