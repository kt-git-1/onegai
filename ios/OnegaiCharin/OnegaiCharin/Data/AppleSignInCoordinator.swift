import AuthenticationServices
import CryptoKit
import Foundation
import Security

struct AppleSignInResult {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private let presentationAnchor: ASPresentationAnchor
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var rawNonce: String?

    init(presentationAnchor: ASPresentationAnchor) {
        self.presentationAnchor = presentationAnchor
    }

    func signIn() async throws -> AppleSignInResult {
        let nonce = try randomNonce()
        rawNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func randomNonce(length: Int = 32) throws -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var randomBytes = [UInt8](repeating: 0, count: 16)

        while result.count < length {
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            for byte in randomBytes where result.count < length && byte < characters.count {
                result.append(characters[Int(byte)])
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func finish(with result: Result<AppleSignInResult, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        rawNonce = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let rawNonce
        else {
            finish(with: .failure(AppRepositoryError.invalidBackendResponse))
            return
        }

        finish(with: .success(AppleSignInResult(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: credential.fullName
        )))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(with: .failure(CancellationError()))
        } else {
            finish(with: .failure(error))
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }
}
