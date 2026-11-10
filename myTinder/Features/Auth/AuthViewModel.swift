//
//  AuthViewModel.swift
//  myTinder
//
//  Created by Ismail on 16.10.2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    
    enum Mode: Equatable {
        
        case signIn
        case signUp
    }
    
    var mode: Mode = .signIn
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isAwaitingEmailConfirmation = false
    
    private let auth: AuthRepositoryProtocol
    
    init(auth: AuthRepositoryProtocol) {
        self.auth = auth
    }
    
    
}

extension AuthViewModel: AuthViewModelProtocol {
    
    var modeState: Mode {
        get {
            mode
        }
        set {
            guard mode != newValue else { return }
            mode = newValue
            password = ""
            passwordConfirmation = ""
            errorMessage = nil
            isAwaitingEmailConfirmation = false
        }
    }
    
    var emailText: String {
        get {
            email
        }
        set {
            email = newValue
        }
    }
    
    var passwordText: String {
        get {
            password
        }
        set {
            password = newValue
        }
    }

    var passwordConfirmationText: String {
        get {
            passwordConfirmation
        }
        set {
            passwordConfirmation = newValue
        }
    }

    var passwordConfirmationError: String? {
        guard mode == .signUp,
              !passwordConfirmation.isEmpty,
              passwordConfirmation != password
        else { return nil }

        return "Пароли не совпадают."
    }
    
    
    var isLoadingState: Bool {
        isLoading
    }
    
    var errorMessageText: String? {
        errorMessage
    }
    
    var canSubmit: Bool {
        let minimumPasswordLength = mode == .signUp ? 8 : 6
        let isConfirmationValid = mode == .signIn || passwordConfirmation == password
        return email.contains("@")
            && password.count >= minimumPasswordLength
            && isConfirmationValid
            && !isLoading
    }

    func switchMode() {
        modeState = mode == .signIn ? .signUp : .signIn
    }

    func showSignIn() {
        mode = .signIn
        password = ""
        passwordConfirmation = ""
        errorMessage = nil
        isAwaitingEmailConfirmation = false
    }
    
    func submit() async {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            
            switch mode {
                
            case .signIn:
                try await auth.signIn(email: email, password: password)
                
            case .signUp:
                if try await auth.signUp(email: email, password: password) == .needsEmailConfirmation {
                    password = ""
                    passwordConfirmation = ""
                    isAwaitingEmailConfirmation = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
protocol AuthViewModelProtocol: Observable, AnyObject {
    
    
    var modeState: AuthViewModel.Mode { get set }
    var emailText: String { get set }
    var passwordText: String { get set }
    var passwordConfirmationText: String { get set }
    var passwordConfirmationError: String? { get }
    var canSubmit: Bool { get }
    var isLoadingState: Bool { get }
    var errorMessageText: String? { get }
    var isAwaitingEmailConfirmation: Bool { get }
    
    func switchMode()
    func showSignIn()
    func submit() async
}
