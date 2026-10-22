//
//  AuthView.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import SwiftUI

struct AuthView<ViewModel: AuthViewModelProtocol>: View {
    
    @State private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        
        VStack(spacing: 16) {
            
            Text("myTinder")
                .font(.largeTitle.bold())
            
            Picker("", selection: $viewModel.modeState) {
                Text("Вход").tag(AuthViewModel.Mode.signIn)
                Text("Регистрация").tag(AuthViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)
            
            TextField("Email", text: $viewModel.emailText)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            
            SecureField("Пароль (от 6 символов)", text: $viewModel.passwordText)
                .textContentType(viewModel.modeState == .signUp ? .newPassword : .password)
                .textFieldStyle(.roundedBorder)
            
            errorMessageView
            
            infoMessageView
            
            signInOrCreateButton
        }
        .padding(24)
    }
    
    private var signInOrCreateButton: some View {
        Button {
            Task {
                await viewModel.submit()
            }
        } label: {
            signInOrCreateButtonLabel
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSubmit)
    }
    
    private var signInOrCreateButtonLabel: some View {
        
        Group {
            if viewModel.isLoadingState {
                ProgressView()
            } else {
                Text(viewModel.modeState == .signIn ? "Войти" : "Создать аккаунт")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        
        if let error = viewModel.errorMessageText {
            Text(error)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
    
    @ViewBuilder
    private var infoMessageView: some View {
        
        if let info = viewModel.infoMessageText {
            Text(info)
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}
