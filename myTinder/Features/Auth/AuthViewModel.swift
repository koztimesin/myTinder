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
    
    enum Mode {
        
        case signIn
        case signUp
    }
    
    var mode: Mode = .signIn
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var infoMessage: String?
    
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
            mode = newValue
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
    
    
    var isLoadingState: Bool {
        isLoading
    }
    
    var errorMessageText: String? {
        errorMessage
    }
    
    var infoMessageText: String? {
        infoMessage
    }
    
    var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isLoading
    }
    
    func submit() async {
        
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            
            switch mode {
                
            case .signIn:
                try await auth.signIn(email: email, password: password)
                
            case .signUp:
                if try await auth.signUp(email: email, password: password) == .needsEmailConfirmation {
                    infoMessage = "Мы отправили письмо. Подтвердите почту и войдите."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

protocol AuthViewModelProtocol {
    
    
    var modeState: AuthViewModel.Mode { get set }
    var emailText: String { get set }
    var passwordText: String { get set }
    var canSubmit: Bool { get }
    var isLoadingState: Bool { get }
    var errorMessageText: String? { get }
    var infoMessageText: String? { get }
    
    func submit() async
}
