import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class FirebaseAppRepository: AppRepository {
    private lazy var auth = Auth.auth()
    private lazy var firestore = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "asia-northeast1")

    func signIn(with provider: AuthenticationProvider) async throws -> AuthUser {
        switch provider {
        case .apple:
            return try await signInWithApple()
        case .google:
            return try await signInWithGoogle()
        }
    }

    func register(email: String, password: String) async throws -> AuthUser {
        let result = try await auth.createUser(withEmail: email, password: password)
        return AuthUser(id: result.user.uid, email: result.user.email)
    }

    func saveProfile(displayName: String, iconEmoji: String?) async throws -> UserProfile {
        guard let user = auth.currentUser else { throw AppRepositoryError.unauthenticated }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw AppRepositoryError.profileMissing }

        let reference = firestore.collection("users").document(user.uid)
        let previous = try await reference.getDocument()
        let now = Date()
        let createdAt = (previous.get("createdAt") as? Timestamp)?.dateValue() ?? now
        let profile = UserProfile(
            id: user.uid,
            displayName: trimmedName,
            iconEmoji: iconEmoji,
            photoURL: user.photoURL,
            email: user.email,
            activeGroupId: previous.get("activeGroupId") as? String,
            createdAt: createdAt,
            updatedAt: now,
            deletedAt: nil
        )
        try await reference.setData([
            "id": profile.id,
            "displayName": profile.displayName,
            "iconEmoji": firestoreValue(profile.iconEmoji),
            "photoURL": firestoreValue(profile.photoURL?.absoluteString),
            "email": firestoreValue(profile.email),
            "activeGroupId": firestoreValue(profile.activeGroupId),
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt),
            "deletedAt": NSNull(),
        ], merge: true)
        return profile
    }

    func createInitialTemplate() async throws -> InitialTemplateResult {
        let response = try await functions.httpsCallable("createInitialTemplate").call()
        guard
            let data = response.data as? [String: Any],
            let groupId = data["groupId"] as? String,
            let inviteData = data["invite"] as? [String: Any],
            let inviteId = inviteData["id"] as? String,
            let inviteCode = inviteData["code"] as? String,
            let expiresAtValue = inviteData["expiresAt"] as? String,
            let expiresAt = parseISO8601(expiresAtValue),
            let userId = auth.currentUser?.uid
        else {
            throw AppRepositoryError.invalidBackendResponse
        }

        async let groupDocument = firestore.collection("groups").document(groupId).getDocument()
        async let bankDocuments = firestore.collection("piggyBanks").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let requestDocuments = firestore.collection("requests").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let rewardDocuments = firestore.collection("rewards").whereField("groupId", isEqualTo: groupId).getDocuments()
        let (groupSnapshot, bankSnapshot, requestSnapshot, rewardSnapshot) = try await (groupDocument, bankDocuments, requestDocuments, rewardDocuments)

        let group = try mapGroup(groupSnapshot)
        let banks = try bankSnapshot.documents.map(mapPiggyBank)
        let requests = try requestSnapshot.documents.map(mapRequest)
        let rewards = try rewardSnapshot.documents.map(mapReward)
        let invite = Invite(
            id: inviteId,
            groupId: groupId,
            code: inviteCode,
            createdBy: userId,
            status: .active,
            expiresAt: expiresAt,
            createdAt: Date(),
            usedAt: nil,
            usedBy: nil
        )
        return InitialTemplateResult(group: group, piggyBanks: banks, requests: requests, rewards: rewards, invite: invite)
    }

    func reissueInvite() async throws -> Invite {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        let user = try await firestore.collection("users").document(userId).getDocument()
        guard let groupId = user.get("activeGroupId") as? String else { throw AppRepositoryError.inviteUnavailable }
        let response = try await functions.httpsCallable("reissueInvite").call(["groupId": groupId])
        guard
            let data = response.data as? [String: Any],
            let id = data["id"] as? String,
            let code = data["code"] as? String,
            let expiresAtValue = data["expiresAt"] as? String,
            let expiresAt = parseISO8601(expiresAtValue)
        else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return Invite(id: id, groupId: groupId, code: code, createdBy: userId, status: .active, expiresAt: expiresAt, createdAt: Date(), usedAt: nil, usedBy: nil)
    }

    func completeInviteForPreview() async throws {
        throw AppRepositoryError.providerNotConfigured
    }

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try auth.signOut()
    }

    private func signInWithGoogle() async throws -> AuthUser {
        guard
            let clientID = FirebaseApp.app()?.options.clientID,
            let presentingViewController = presentingViewController()
        else {
            throw AppRepositoryError.providerNotConfigured
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AppRepositoryError.invalidBackendResponse
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await auth.signIn(with: credential)
            return AuthUser(id: authResult.user.uid, email: authResult.user.email)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw CancellationError()
        }
    }

    private func signInWithApple() async throws -> AuthUser {
        guard let window = keyWindow() else {
            throw AppRepositoryError.providerNotConfigured
        }

        let result = try await AppleSignInCoordinator(presentationAnchor: window).signIn()
        let credential = OAuthProvider.appleCredential(
            withIDToken: result.idToken,
            rawNonce: result.rawNonce,
            fullName: result.fullName
        )
        let authResult = try await auth.signIn(with: credential)
        return AuthUser(id: authResult.user.uid, email: authResult.user.email)
    }

    private func presentingViewController() -> UIViewController? {
        let root = keyWindow()?.rootViewController
        return topViewController(from: root)
    }

    private func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first { $0.isKeyWindow }
    }

    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let presented = viewController?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return viewController
    }

    private func mapGroup(_ snapshot: DocumentSnapshot) throws -> CoupleGroup {
        guard let data = snapshot.data() else { throw AppRepositoryError.invalidBackendResponse }
        return CoupleGroup(
            id: snapshot.documentID,
            name: data["name"] as? String ?? "ふたり",
            type: data["type"] as? String ?? "couple",
            status: CoupleGroup.Status(rawValue: data["status"] as? String ?? "") ?? .active,
            memberIds: data["memberIds"] as? [String] ?? [],
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"]),
            archivedAt: optionalDate(data["archivedAt"])
        )
    }

    private func mapPiggyBank(_ snapshot: QueryDocumentSnapshot) throws -> PiggyBank {
        let data = snapshot.data()
        guard let ownerType = PiggyBank.OwnerType(rawValue: data["ownerType"] as? String ?? "") else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return PiggyBank(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            ownerType: ownerType,
            ownerUserId: data["ownerUserId"] as? String,
            name: data["name"] as? String ?? "貯金箱",
            balance: data["balance"] as? Int ?? 0,
            targetRewardId: data["targetRewardId"] as? String,
            status: PiggyBank.Status(rawValue: data["status"] as? String ?? "") ?? .active,
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"])
        )
    }

    private func mapRequest(_ snapshot: QueryDocumentSnapshot) throws -> RequestItem {
        let data = snapshot.data()
        guard
            let bankType = PiggyBank.OwnerType(rawValue: data["piggyBankType"] as? String ?? ""),
            let repeatType = RequestItem.RepeatType(rawValue: data["repeatType"] as? String ?? "")
        else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return RequestItem(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            createdBy: data["createdBy"] as? String ?? "",
            title: data["title"] as? String ?? "お願い",
            iconEmoji: data["iconEmoji"] as? String ?? "✨",
            coinAmount: data["coinAmount"] as? Int ?? 0,
            piggyBankType: bankType,
            repeatType: repeatType,
            status: RequestItem.Status(rawValue: data["status"] as? String ?? "") ?? .active,
            completionCount: data["completionCount"] as? Int ?? 0,
            lastCompletedAt: optionalDate(data["lastCompletedAt"]),
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"])
        )
    }

    private func mapReward(_ snapshot: QueryDocumentSnapshot) throws -> Reward {
        let data = snapshot.data()
        guard let bankType = PiggyBank.OwnerType(rawValue: data["piggyBankType"] as? String ?? "") else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return Reward(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            createdBy: data["createdBy"] as? String ?? "",
            title: data["title"] as? String ?? "ごほうび券",
            iconEmoji: data["iconEmoji"] as? String ?? "🎫",
            requiredCoins: data["requiredCoins"] as? Int ?? 0,
            piggyBankType: bankType,
            isTarget: data["isTarget"] as? Bool ?? false,
            expiresInType: Reward.ExpiryType(rawValue: data["expiresInType"] as? String ?? "") ?? .none,
            expiresInDays: data["expiresInDays"] as? Int,
            expiresAt: optionalDate(data["expiresAt"]),
            status: Reward.Status(rawValue: data["status"] as? String ?? "") ?? .active,
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"])
        )
    }

    private func date(_ value: Any?) -> Date {
        (value as? Timestamp)?.dateValue() ?? Date()
    }

    private func optionalDate(_ value: Any?) -> Date? {
        (value as? Timestamp)?.dateValue()
    }

    private func firestoreValue(_ value: String?) -> Any {
        value ?? NSNull()
    }

    private func parseISO8601(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
