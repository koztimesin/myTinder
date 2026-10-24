//
//  OnboardingView.swift
//  myTinder
//
//  Created by Ismail on 24.10.2026.
//

import SwiftUI
import PhotosUI

struct OnboardingView<ViewModel: OnboardingViewModelProtocol>: View {
    
    /// Модель экрана. Единственная зависимость View.
    @State private var viewModel: ViewModel
    /// Элементы, выбранные в пикере; после обработки очищаются.
    @State private var pickerItems: [PhotosPickerItem] = []
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    /// - Parameter viewModel: модель экрана; создаётся снаружи (например, фабрикой `AppContainer`).
    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        // @Bindable даёт привязки ($vm.name) к полям @Observable-модели.
        @Bindable var vm = viewModel
        
        NavigationStack {
            Form {
                Section("Фото (до \(ProfileValidation.maxPhotos))") {
                    photoGrid
                }
                
                Section("О вас") {
                    TextField("Имя", text: $vm.name)
                        .textContentType(.givenName)
                    
                    DatePicker(
                        "Дата рождения",
                        selection: $vm.birthDate,
                        in: ...vm.latestBirthDate,
                        displayedComponents: .date
                    )
                }
                
                Section("Ваш пол") {
                    // Тег только у реальных значений: пока выбор не сделан, ни один сегмент не подсвечен.
                    Picker("Ваш пол", selection: $vm.gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.title).tag(Gender?.some(gender))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section("Кого ищете") {
                    Picker("Кого ищете", selection: $vm.interest) {
                        ForEach(InterestOption.allCases) { option in
                            Text(option.title).tag(InterestOption?.some(option))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section {
                    TextField("Расскажите о себе", text: $vm.bio, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("О себе")
                } footer: {
                    Text("\(vm.bio.count)/500")
                        .foregroundStyle(vm.isBioTooLong ? .red : .secondary)
                }
                
                if let message = vm.errorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
                
                Section {
                    submitButton
                    uploadProgress
                }
            }
            .navigationTitle("Создайте профиль")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Выйти", role: .destructive) { vm.signOut() }
                        .disabled(vm.isSubmitting)
                }
            }
            // Пока идёт отправка, форму трогать нельзя.
            .disabled(vm.isSubmitting)
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                
                Task {
                    await vm.addPhotos(from: items)
                    pickerItems = []
                }
            }
        }
    }
    
    // MARK: Части экрана
    
    /// Кнопка «Готово». Неактивна, пока форма не заполнена; во время отправки показывает индикатор.
    private var submitButton: some View {
        Button {
            Task { await viewModel.submit() }
        } label: {
            HStack {
                Spacer()
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text("Готово").bold()
                }
                Spacer()
            }
        }
        .disabled(!viewModel.canSubmit)
    }
    
    @ViewBuilder
    private var uploadProgress: some View {
        if viewModel.isSubmitting {
            ProgressView(
                value: Double(viewModel.uploadedCount),
                total: Double(max(viewModel.photos.count, 1))
            ) {
                Text("Загружаем фото: \(viewModel.uploadedCount) из \(viewModel.photos.count)")
                    .font(.footnote)
            }
        }
    }
    
    /// Сетка выбранных фото, индикатор обработки и кнопка «Добавить».
    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                photoTile(photo, index: index)
            }
            
            if viewModel.isLoadingPhotos {
                tilePlaceholder { ProgressView() }
            }
            
            if viewModel.remainingSlots > 0 {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: viewModel.remainingSlots,
                    matching: .images
                ) {
                    tilePlaceholder { Image(systemName: "plus").font(.title) }
                }
                .accessibilityLabel("Добавить фото")
                
            }
        }
        // Внутри Form без этого нажатие на одну кнопку строки срабатывает на все.
        .buttonStyle(.borderless)
    }
    
    private func photoTile(_ photo: LocalPhoto, index: Int) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .background {
                Image(uiImage: photo.preview)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.removePhoto(photo)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding(6)
                .accessibilityLabel("Удалить фото \(index + 1)")
            }
            .overlay(alignment: .bottomLeading) {
                if index == 0 {
                    Text("Главное")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                        .padding(6)
                }
            }
            .accessibilityElement(children: .contain)
    }
    
    nonisolated private func tilePlaceholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay(content())
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
