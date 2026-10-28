//
//  EditProfileView.swift
//  myTinder
//
//  Created by Ismail on 25.10.2026.
//

import PhotosUI
import SwiftUI

struct EditProfileView<ViewModel: EditProfileViewModelProtocol>: View {
    
    @State private var viewModel: ViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        @Bindable var vm = viewModel
        
        NavigationStack {
            Form {
                Section("Фото (до \(ProfileValidation.maxPhotos))") {
                    photoGrid
                }
                
                bioSection
                
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
            }
            .navigationTitle("Мой профиль")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Выйти", role: .destructive) { vm.signOut() }
                        .disabled(vm.isBusy)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") { Task { await vm.save() } }
                        .disabled(!vm.canSave)
                }
            }
            // Пока идёт операция, форму трогать нельзя.
            .disabled(vm.isBusy)
            .overlay {
                if vm.isBusy {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task { await vm.load() }
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
    
    private var bioSection: some View {
        Section {
            LabeledContent("Имя", value: viewModel.name)
            LabeledContent("Пол", value: viewModel.genderTitle)
            LabeledContent("Дата рождения", value: viewModel.birthDateText)
        } header: {
            Text("О вас")
        } footer: {
            Text("Имя, пол и дату рождения изменить нельзя.")
        }
    }
    
    /// Сетка фото профиля и кнопка «Добавить».
    private var photoGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.tiles) { tile in
                PhotoTileView(viewModel: tile)
            }
            
            if viewModel.remainingSlots > 0 {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: viewModel.remainingSlots,
                    matching: .images
                ) {
                    // Собираем из системных вью без вызова методов экрана:
                    // замыкание лейбла пикера не привязано к главному потоку.
                    Color.clear
                        .aspectRatio(PhotoTileMetrics.aspectRatio, contentMode: .fit)
                        .overlay { Image(systemName: "plus").font(.title) }
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: PhotoTileMetrics.cornerRadius))
                }
                .accessibilityLabel("Добавить фото")
            }
        }
        // Внутри Form без этого нажатие на одну кнопку строки срабатывает на все.
        .buttonStyle(.borderless)
    }
}
