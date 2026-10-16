//
//  AuthView.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import SwiftUI

struct AuthView: View {
    
    @State var viewModel: AuthViewModel
    
    init(viewModel: AuthViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        
        VStack(spacing: 16) {
            
            Text("myTinder")
                .font(.largeTitle.bold())
            
            Picker("", selection: $viewModel.mode) {
                Text("Вход").tag(AuthViewModel.Mode.signIn)
                Text("Регистрация").tag(AuthViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)
            
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            
            SecureField("Пароль (от 6 символов)", text: $viewModel.password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)
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
            if viewModel.isLoading {
                ProgressView()
            } else {
                Text(viewModel.mode == .signIn ? "Войти" : "Создать аккаунт")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var errorMessageView: some View {
        
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
    
    @ViewBuilder
    private var infoMessageView: some View {
        
        if let info = viewModel.infoMessage {
            Text(info)
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
    }
}
