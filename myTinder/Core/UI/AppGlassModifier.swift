//
//  AppGlassModifier.swift
//  myTinder
//
//  Created by Ismail on 26.10.2026.
//

import SwiftUI

struct AppGlassModifier<S: Shape>: ViewModifier {

    /// Форма, в которую вписывается стекло.
    let shape: S

    /// Применяет стекло к содержимому с учётом версии системы.
    /// - Parameter content: оборачиваемое содержимое.
    /// - Returns: содержимое на стеклянной подложке.
    @ViewBuilder
    func body(content: Content) -> some View {
        
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(AppTheme.Colors.glassBorder, lineWidth: 1))
        }
    }
}

extension View {

    /// Кладёт вью на стеклянную подложку заданной формы.
    /// - Parameter shape: форма стекла, например `Capsule()` или `Circle()`.
    /// - Returns: вью на стеклянной подложке.
    func appGlass<S: Shape>(in shape: S) -> some View {
        modifier(AppGlassModifier(shape: shape))
    }
}
