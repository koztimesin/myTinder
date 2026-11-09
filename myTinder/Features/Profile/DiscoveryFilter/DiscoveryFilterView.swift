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

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                    ProfileFormSection("Кого показывать") {
                        Picker("Кого показывать", selection: $vm.interest) {
                            ForEach(InterestOption.allCases) { option in
                                Text(option.title).tag(InterestOption?.some(option))
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(AppTheme.Colors.accent)
                    }

                    ProfileFormSection(
                        "Возраст",
                        subtitle: "От \(Int(vm.minAge)) до \(Int(vm.maxAge)) лет"
                    ) {
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
                .padding(AppTheme.Spacing.m)
            }
            .scrollDisabled(vm.isSaving)
            .background(AppTheme.Colors.background)
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .frame(width: AppTheme.Size.minTapTarget, height: AppTheme.Size.minTapTarget)
                    }
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityLabel("Закрыть фильтры")
                }
            }
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
                .buttonStyle(.app(.primary))
                .disabled(!vm.canApply)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s)
                .background(AppTheme.Colors.background)
            }
        }
    }
}
