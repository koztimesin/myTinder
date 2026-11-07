//
//  AgeRangeSlider.swift
//  myTinder
//
//  Created by Codex on 07.11.2026.
//

import SwiftUI

/// Единый ползунок диапазона с отдельными нижним и верхним бегунками.
struct AgeRangeSlider: View {

    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double

    private let bounds: ClosedRange<Double>
    private let step: Double

    private let thumbDiameter: CGFloat = 28
    private let controlHeight: CGFloat = AppTheme.Size.minTapTarget

    /// Создаёт ползунок диапазона.
    /// - Parameters:
    ///   - lowerValue: нижняя выбранная граница.
    ///   - upperValue: верхняя выбранная граница.
    ///   - bounds: полный допустимый диапазон.
    ///   - step: шаг изменения.
    init(
        lowerValue: Binding<Double>,
        upperValue: Binding<Double>,
        in bounds: ClosedRange<Double>,
        step: Double = 1
    ) {
        _lowerValue = lowerValue
        _upperValue = upperValue
        self.bounds = bounds
        self.step = step
    }

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width - thumbDiameter, 1)
            let lowerX = position(for: lowerValue, trackWidth: trackWidth)
            let upperX = position(for: upperValue, trackWidth: trackWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Colors.surfaceMuted)
                    .frame(height: 6)
                    .padding(.horizontal, thumbDiameter / 2)

                Capsule()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: max(upperX - lowerX, 0), height: 6)
                    .offset(x: lowerX)

                thumb(
                    label: "Минимальный возраст",
                    value: lowerValue,
                    position: lowerX,
                    onDrag: { updateLowerValue(at: $0, trackWidth: trackWidth) },
                    onAdjust: adjustLowerValue
                )

                thumb(
                    label: "Максимальный возраст",
                    value: upperValue,
                    position: upperX,
                    onDrag: { updateUpperValue(at: $0, trackWidth: trackWidth) },
                    onAdjust: adjustUpperValue
                )
            }
            .coordinateSpace(.named("ageRangeSlider"))
        }
        .frame(height: controlHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Возрастной диапазон")
    }

    /// Строит доступный бегунок с областью нажатия не меньше 44 pt.
    /// - Parameters:
    ///   - label: название границы.
    ///   - value: текущее значение.
    ///   - position: положение центра на шкале.
    ///   - onDrag: обработчик горизонтального перетаскивания.
    ///   - onAdjust: обработчик действий VoiceOver.
    /// - Returns: бегунок диапазона.
    private func thumb(
        label: String,
        value: Double,
        position: CGFloat,
        onDrag: @escaping (CGFloat) -> Void,
        onAdjust: @escaping (AccessibilityAdjustmentDirection) -> Void
    ) -> some View {
        Circle()
            .fill(AppTheme.Colors.surface)
            .frame(width: thumbDiameter, height: thumbDiameter)
            .overlay(Circle().stroke(AppTheme.Colors.accent, lineWidth: 3))
            .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
            .frame(width: controlHeight, height: controlHeight)
            .contentShape(Rectangle())
            .position(x: position, y: controlHeight / 2)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("ageRangeSlider"))
                    .onChanged { onDrag($0.location.x) }
            )
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value)) лет")
            .accessibilityAdjustableAction(onAdjust)
    }

    /// Переводит значение в координату центра бегунка.
    /// - Parameters:
    ///   - value: значение диапазона.
    ///   - trackWidth: полезная ширина шкалы.
    /// - Returns: координата по горизонтали.
    private func position(for value: Double, trackWidth: CGFloat) -> CGFloat {
        let fraction = (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return thumbDiameter / 2 + CGFloat(fraction) * trackWidth
    }

    /// Переводит координату жеста в значение с учётом шага.
    /// - Parameters:
    ///   - location: координата жеста внутри области бегунка.
    ///   - trackWidth: полезная ширина шкалы.
    /// - Returns: новое значение.
    private func value(at location: CGFloat, trackWidth: CGFloat) -> Double {
        let fraction = min(max((location - thumbDiameter / 2) / trackWidth, 0), 1)
        let rawValue = bounds.lowerBound + Double(fraction) * (bounds.upperBound - bounds.lowerBound)
        return (rawValue / step).rounded() * step
    }

    /// Обновляет нижнюю границу жестом.
    /// - Parameters:
    ///   - location: координата жеста внутри бегунка.
    ///   - trackWidth: полезная ширина шкалы.
    private func updateLowerValue(at location: CGFloat, trackWidth: CGFloat) {
        lowerValue = min(value(at: location, trackWidth: trackWidth), upperValue)
    }

    /// Обновляет верхнюю границу жестом.
    /// - Parameters:
    ///   - location: координата жеста внутри бегунка.
    ///   - trackWidth: полезная ширина шкалы.
    private func updateUpperValue(at location: CGFloat, trackWidth: CGFloat) {
        upperValue = max(value(at: location, trackWidth: trackWidth), lowerValue)
    }

    /// Изменяет нижнюю границу действием VoiceOver.
    /// - Parameter direction: направление изменения.
    private func adjustLowerValue(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: lowerValue = min(lowerValue + step, upperValue)
        case .decrement: lowerValue = max(lowerValue - step, bounds.lowerBound)
        @unknown default: break
        }
    }

    /// Изменяет верхнюю границу действием VoiceOver.
    /// - Parameter direction: направление изменения.
    private func adjustUpperValue(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: upperValue = min(upperValue + step, bounds.upperBound)
        case .decrement: upperValue = max(upperValue - step, lowerValue)
        @unknown default: break
        }
    }
}
