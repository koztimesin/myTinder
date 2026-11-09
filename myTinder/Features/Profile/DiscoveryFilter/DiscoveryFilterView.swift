//
//  DiscoveryFilterView.swift
//  myTinder
//
//  Created by Ismail on 09.11.2026.
//

import SwiftUI

struct DiscoveryFilterView: View {

    @State private var viewModel: DiscoveryFilterViewModel
    let onClose: @MainActor () -> Void

    init(
        viewModel: DiscoveryFilterViewModel,
        onClose: @escaping @MainActor () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            filterHeader

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        Text("Кого показывать")
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        InterestSelectionControl(selection: $vm.interest)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        HStack {
                            Text("Предпочтительный возраст")
                            Spacer()
                            Text("\(Int(vm.minAge))–\(Int(vm.maxAge))")
                        }
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                        AgeRangeSlider(
                            lowerValue: $vm.minAge,
                            upperValue: $vm.maxAge,
                            in: Double(ProfileValidation.minimumDiscoveryAge)...Double(ProfileValidation.maximumDiscoveryAge)
                        )
                    }

                    if let message = vm.errorMessage {
                        ErrorBannerView(viewModel: ErrorBannerViewModel(message: message))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.top, AppTheme.Spacing.l)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .scrollDisabled(vm.isSaving)
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await vm.apply() }
                } label: {
                    if vm.isSaving {
                        ProgressView().tint(AppTheme.Colors.onAccent)
                    } else {
                        Text("Применить фильтры")
                    }
                }
                .font(AppTheme.Typography.button)
                .foregroundStyle(AppTheme.Colors.background)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(AppTheme.Colors.secondaryAccent, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                .opacity(vm.canApply ? 1 : 0.48)
                .disabled(!vm.canApply)
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.Colors.filterBackground)
            }
        }
        .background(AppTheme.Colors.filterBackground.ignoresSafeArea())
    }

    private var filterHeader: some View {
        HStack {
            Text("Фильтры")
                .font(AppTheme.Typography.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.Colors.surfaceMuted, in: Circle())
            }
            .accessibilityLabel("Закрыть фильтры")
        }
        .padding(.horizontal, AppTheme.Spacing.l)
        .padding(.top, AppTheme.Spacing.m)
        .padding(.bottom, AppTheme.Spacing.s)
    }
}

/// Крупные кнопки выбора вместо системного segmented picker.
private struct InterestSelectionControl: View {

    @Binding var selection: InterestOption?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            ForEach(InterestOption.allCases) { option in
                let isSelected = selection == option

                Button {
                    selection = option
                } label: {
                    Text(option.title)
                        .font(AppTheme.Typography.button)
                        .foregroundStyle(isSelected ? AppTheme.Colors.background : AppTheme.Colors.accent)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(isSelected ? AppTheme.Colors.accent : Color.clear, in: Capsule())
                        .overlay {
                            if !isSelected {
                                Capsule().stroke(AppTheme.Colors.accent, lineWidth: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Кого показывать")
    }
}
