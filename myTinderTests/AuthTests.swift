import Testing
@testable import myTinder

@Suite("Authentication")
@MainActor
struct AuthViewModelTests {

    @Test
    func switchingModeKeepsEmailAndClearsTransientState() async {
        let repository = AuthRepositoryStub()
        repository.signInResults = [.failure(TestFailure.expected)]
        let viewModel = AuthViewModel(auth: repository)
        viewModel.emailText = "user@example.com"
        viewModel.passwordText = "secret12"

        await viewModel.submit()
        #expect(viewModel.errorMessageText != nil)

        viewModel.switchMode()
        viewModel.passwordConfirmationText = "another"
        viewModel.switchMode()

        #expect(viewModel.modeState == .signIn)
        #expect(viewModel.emailText == "user@example.com")
        #expect(viewModel.passwordText.isEmpty)
        #expect(viewModel.passwordConfirmationText.isEmpty)
        #expect(viewModel.errorMessageText == nil)
    }

    @Test
    func registrationRequiresMatchingPasswords() async {
        let repository = AuthRepositoryStub()
        let viewModel = AuthViewModel(auth: repository)
        viewModel.switchMode()
        viewModel.emailText = "user@example.com"
        viewModel.passwordText = "password"
        viewModel.passwordConfirmationText = "different"

        #expect(!viewModel.canSubmit)
        #expect(viewModel.passwordConfirmationError == "Пароли не совпадают.")

        await viewModel.submit()
        #expect(repository.signUpCalls.isEmpty)

        viewModel.passwordConfirmationText = "password"
        #expect(viewModel.canSubmit)
        #expect(viewModel.passwordConfirmationError == nil)
    }

    @Test
    func registrationConfirmationShowsSuccessStateAndReturnsToSignIn() async {
        let repository = AuthRepositoryStub()
        repository.signUpResults = [.success(.needsEmailConfirmation)]
        let viewModel = AuthViewModel(auth: repository)
        viewModel.switchMode()
        viewModel.emailText = "user@example.com"
        viewModel.passwordText = "password"
        viewModel.passwordConfirmationText = "password"

        await viewModel.submit()

        #expect(viewModel.isAwaitingEmailConfirmation)
        #expect(viewModel.passwordText.isEmpty)
        #expect(viewModel.passwordConfirmationText.isEmpty)
        #expect(repository.signUpCalls.count == 1)

        viewModel.showSignIn()

        #expect(viewModel.modeState == .signIn)
        #expect(!viewModel.isAwaitingEmailConfirmation)
        #expect(viewModel.emailText == "user@example.com")
    }

    @Test
    func registrationFailureKeepsEnteredCredentialsForRetry() async {
        let repository = AuthRepositoryStub()
        repository.signUpResults = [.failure(TestFailure.expected)]
        let viewModel = AuthViewModel(auth: repository)
        viewModel.switchMode()
        viewModel.emailText = "user@example.com"
        viewModel.passwordText = "password"
        viewModel.passwordConfirmationText = "password"

        await viewModel.submit()

        #expect(!viewModel.isAwaitingEmailConfirmation)
        #expect(viewModel.emailText == "user@example.com")
        #expect(viewModel.passwordText == "password")
        #expect(viewModel.errorMessageText != nil)
    }
}
