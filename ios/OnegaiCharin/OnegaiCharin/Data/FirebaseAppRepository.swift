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

    func signIn(email: String, password: String) async throws -> AuthUser {
        let result = try await auth.signIn(withEmail: email, password: password)
        return AuthUser(id: result.user.uid, email: result.user.email)
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func loadSession() async throws -> AppSession {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        let userDocument = try await firestore.collection("users").document(userId).getDocument()
        guard userDocument.exists else {
            return AppSession(profile: nil, initialTemplate: nil)
        }

        let profile = mapUserProfile(userDocument)
        guard let groupId = profile.activeGroupId else {
            return AppSession(profile: profile, initialTemplate: nil)
        }

        async let groupDocument = firestore.collection("groups").document(groupId).getDocument()
        async let bankDocuments = firestore.collection("piggyBanks").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let requestDocuments = firestore.collection("requests").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let rewardDocuments = firestore.collection("rewards").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let inviteDocuments = firestore.collection("invites").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let recordDocuments = firestore.collection("records").whereField("groupId", isEqualTo: groupId).getDocuments()
        async let ticketDocuments = firestore.collection("tickets").whereField("groupId", isEqualTo: groupId).getDocuments()
        let (groupSnapshot, bankSnapshot, requestSnapshot, rewardSnapshot, inviteSnapshot, recordSnapshot, ticketSnapshot) = try await (
            groupDocument,
            bankDocuments,
            requestDocuments,
            rewardDocuments,
            inviteDocuments,
            recordDocuments,
            ticketDocuments
        )

        let group = try mapGroup(groupSnapshot)
        let partnerProfile: UserProfile?
        if let partnerId = group.memberIds.first(where: { $0 != userId }) {
            let partnerDocument = try await firestore.collection("users").document(partnerId).getDocument()
            partnerProfile = partnerDocument.exists ? mapUserProfile(partnerDocument) : nil
        } else {
            partnerProfile = nil
        }
        let invites = try inviteSnapshot.documents.map(mapInvite)
        guard let invite = invites.max(by: { $0.createdAt < $1.createdAt }) else {
            throw AppRepositoryError.invalidBackendResponse
        }
        let initialTemplate = InitialTemplateResult(
            group: group,
            piggyBanks: try bankSnapshot.documents.map(mapPiggyBank),
            requests: try requestSnapshot.documents.map(mapRequest),
            rewards: try rewardSnapshot.documents.map(mapReward),
            invite: invite
        )
        let records = try recordSnapshot.documents
            .map(mapRecord)
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
        let tickets = try ticketSnapshot.documents
            .map(mapTicket)
            .sorted { $0.issuedAt > $1.issuedAt }
        return AppSession(
            profile: profile,
            initialTemplate: initialTemplate,
            partnerProfile: partnerProfile,
            records: records,
            tickets: tickets
        )
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

    func resolveInvite(identifier: String) async throws -> InvitePreview {
        let response = try await functions.httpsCallable("resolveInvite").call(["identifier": identifier])
        guard
            let data = response.data as? [String: Any],
            let id = data["id"] as? String,
            let code = data["code"] as? String,
            let inviterName = data["inviterName"] as? String,
            let expiresAtValue = data["expiresAt"] as? String,
            let expiresAt = parseISO8601(expiresAtValue)
        else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return InvitePreview(
            id: id,
            code: code,
            inviterName: inviterName,
            inviterEmoji: data["inviterEmoji"] as? String,
            expiresAt: expiresAt
        )
    }

    func acceptInvite(id: String) async throws {
        _ = try await functions.httpsCallable("acceptInvite").call(["inviteId": id])
    }

    func createRequest(_ draft: RequestDraft) async throws -> RequestItem {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        let user = try await firestore.collection("users").document(userId).getDocument()
        guard let groupId = user.get("activeGroupId") as? String else {
            throw AppRepositoryError.invalidBackendResponse
        }
        let normalized = try normalizedDraft(draft)
        let reference = firestore.collection("requests").document()
        let now = Date()
        let request = RequestItem(
            id: reference.documentID,
            groupId: groupId,
            createdBy: userId,
            title: normalized.title,
            iconEmoji: normalized.iconEmoji,
            coinAmount: normalized.coinAmount,
            piggyBankType: normalized.piggyBankType,
            repeatType: normalized.repeatType,
            status: .active,
            completionCount: 0,
            lastCompletedAt: nil,
            createdAt: now,
            updatedAt: now
        )
        try await reference.setData(requestData(request))
        return request
    }

    func updateRequest(_ request: RequestItem, draft: RequestDraft) async throws -> RequestItem {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        guard request.createdBy == userId else { throw AppRepositoryError.requestNotOwned }
        let normalized = try normalizedDraft(draft)
        var updated = request
        updated.title = normalized.title
        updated.iconEmoji = normalized.iconEmoji
        updated.coinAmount = normalized.coinAmount
        updated.piggyBankType = normalized.piggyBankType
        updated.repeatType = normalized.repeatType
        updated.updatedAt = Date()
        try await firestore.collection("requests").document(request.id).setData(requestData(updated), merge: true)
        return updated
    }

    func hideRequest(_ request: RequestItem) async throws -> RequestItem {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        guard request.createdBy == userId else { throw AppRepositoryError.requestNotOwned }
        var hidden = request
        hidden.status = .hidden
        hidden.updatedAt = Date()
        try await firestore.collection("requests").document(request.id).updateData([
            "status": hidden.status.rawValue,
            "updatedAt": Timestamp(date: hidden.updatedAt),
        ])
        return hidden
    }

    func createReward(_ draft: RewardDraft) async throws -> Reward {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        let user = try await firestore.collection("users").document(userId).getDocument()
        guard let groupId = user.get("activeGroupId") as? String else {
            throw AppRepositoryError.invalidBackendResponse
        }
        let normalized = try normalizedRewardDraft(draft)
        let reference = firestore.collection("rewards").document()
        let now = Date()
        let reward = Reward(
            id: reference.documentID,
            groupId: groupId,
            createdBy: userId,
            title: normalized.title,
            iconEmoji: normalized.iconEmoji,
            requiredCoins: normalized.requiredCoins,
            piggyBankType: normalized.piggyBankType,
            isTarget: false,
            expiresInType: normalized.expiresInType,
            expiresInDays: normalized.expiresInDays,
            expiresAt: normalized.expiresAt,
            status: .active,
            createdAt: now,
            updatedAt: now
        )
        try await reference.setData(rewardData(reward))
        return reward
    }

    func updateReward(_ reward: Reward, draft: RewardDraft) async throws -> Reward {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        guard reward.createdBy == userId else { throw AppRepositoryError.rewardNotOwned }
        let normalized = try normalizedRewardDraft(draft)
        var updated = reward
        updated.title = normalized.title
        updated.iconEmoji = normalized.iconEmoji
        updated.requiredCoins = normalized.requiredCoins
        updated.piggyBankType = normalized.piggyBankType
        updated.expiresInType = normalized.expiresInType
        updated.expiresInDays = normalized.expiresInDays
        updated.expiresAt = normalized.expiresAt
        updated.updatedAt = Date()
        try await firestore.collection("rewards").document(reward.id).setData(rewardData(updated), merge: true)
        return updated
    }

    func hideReward(_ reward: Reward) async throws -> Reward {
        guard let userId = auth.currentUser?.uid else { throw AppRepositoryError.unauthenticated }
        guard reward.createdBy == userId else { throw AppRepositoryError.rewardNotOwned }
        var hidden = reward
        hidden.status = .hidden
        hidden.updatedAt = Date()
        try await firestore.collection("rewards").document(reward.id).updateData([
            "status": hidden.status.rawValue,
            "updatedAt": Timestamp(date: hidden.updatedAt),
        ])
        return hidden
    }

    func exchangeReward(groupId: String, rewardId: String, piggyBankId: String) async throws -> RewardExchangeResult {
        let response = try await functions.httpsCallable("exchangeReward").call([
            "groupId": groupId,
            "rewardId": rewardId,
            "piggyBankId": piggyBankId,
        ])
        guard let data = response.data as? [String: Any],
              let ticketData = data["ticket"] as? [String: Any],
              let recordData = data["record"] as? [String: Any],
              let ticket = ticket(from: ticketData),
              let record = record(from: recordData)
        else { throw AppRepositoryError.invalidBackendResponse }
        return RewardExchangeResult(ticket: ticket, record: record)
    }

    func useTicket(ticketId: String) async throws -> TicketUseResult {
        let response = try await functions.httpsCallable("useTicket").call(["ticketId": ticketId])
        guard let data = response.data as? [String: Any],
              let ticketData = data["ticket"] as? [String: Any],
              let recordData = data["record"] as? [String: Any],
              let ticket = ticket(from: ticketData),
              let record = ticketUseRecord(from: recordData)
        else { throw AppRepositoryError.invalidBackendResponse }
        return TicketUseResult(ticket: ticket, record: record)
    }

    func charinRequest(groupId: String, requestId: String) async throws -> CharinResult {
        let response = try await functions.httpsCallable("charinRequest").call([
            "groupId": groupId,
            "requestId": requestId,
        ])
        guard
            let data = response.data as? [String: Any],
            let recordId = data["recordId"] as? String,
            let resultGroupId = data["groupId"] as? String,
            let userId = data["userId"] as? String,
            let resultRequestId = data["requestId"] as? String,
            let piggyBankId = data["piggyBankId"] as? String,
            let piggyBankName = data["piggyBankName"] as? String,
            let title = data["title"] as? String,
            let iconEmoji = data["iconEmoji"] as? String,
            let coinAmount = integer(data["coinAmount"]),
            let balanceBefore = integer(data["balanceBefore"]),
            let balanceAfter = integer(data["balanceAfter"]),
            let requestStatusValue = data["requestStatus"] as? String,
            let requestStatus = RequestItem.Status(rawValue: requestStatusValue),
            let completionCount = integer(data["completionCount"]),
            let createdAtValue = data["createdAt"] as? String,
            let createdAt = parseISO8601(createdAtValue)
        else { throw AppRepositoryError.invalidBackendResponse }

        let targetReward: TargetRewardProgress?
        if let value = data["targetReward"] as? [String: Any],
           let id = value["id"] as? String,
           let rewardTitle = value["title"] as? String,
           let rewardEmoji = value["iconEmoji"] as? String,
           let remainingCoins = integer(value["remainingCoins"]),
           let isExchangeable = value["isExchangeable"] as? Bool,
           let becameExchangeable = value["becameExchangeable"] as? Bool {
            targetReward = TargetRewardProgress(
                id: id,
                title: rewardTitle,
                iconEmoji: rewardEmoji,
                remainingCoins: remainingCoins,
                isExchangeable: isExchangeable,
                becameExchangeable: becameExchangeable
            )
        } else {
            targetReward = nil
        }

        let record = ActivityRecord(
            id: recordId,
            groupId: resultGroupId,
            userId: userId,
            type: .charin,
            targetType: "request",
            targetId: resultRequestId,
            title: title,
            iconEmoji: iconEmoji,
            coinDelta: coinAmount,
            piggyBankId: piggyBankId,
            piggyBankName: piggyBankName,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            status: .active,
            createdAt: createdAt,
            canceledAt: nil
        )
        return CharinResult(
            record: record,
            requestId: resultRequestId,
            requestStatus: requestStatus,
            completionCount: completionCount,
            targetReward: targetReward
        )
    }

    func cancelCharin(recordId: String) async throws -> CharinCancellationResult {
        let response = try await functions.httpsCallable("cancelCharin").call(["recordId": recordId])
        guard
            let data = response.data as? [String: Any],
            let resultRecordId = data["recordId"] as? String,
            let requestId = data["requestId"] as? String,
            let piggyBankId = data["piggyBankId"] as? String,
            let balanceAfter = integer(data["balanceAfter"]),
            let requestStatusValue = data["requestStatus"] as? String,
            let requestStatus = RequestItem.Status(rawValue: requestStatusValue),
            let completionCount = integer(data["completionCount"])
        else { throw AppRepositoryError.invalidBackendResponse }
        return CharinCancellationResult(
            recordId: resultRecordId,
            requestId: requestId,
            piggyBankId: piggyBankId,
            balanceAfter: balanceAfter,
            requestStatus: requestStatus,
            completionCount: completionCount
        )
    }

    func observeGroupMemberCount(
        groupId: String,
        onChange: @escaping (Result<Int, Error>) -> Void
    ) -> AppObservation {
        let registration = firestore.collection("groups").document(groupId).addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error {
                    onChange(.failure(error))
                    return
                }
                guard let snapshot, snapshot.exists else {
                    onChange(.failure(AppRepositoryError.invalidBackendResponse))
                    return
                }
                onChange(.success((snapshot.get("memberIds") as? [String])?.count ?? 0))
            }
        }
        return AppObservation { registration.remove() }
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

    private func mapUserProfile(_ snapshot: DocumentSnapshot) -> UserProfile {
        let data = snapshot.data() ?? [:]
        return UserProfile(
            id: snapshot.documentID,
            displayName: data["displayName"] as? String ?? "",
            iconEmoji: data["iconEmoji"] as? String,
            photoURL: (data["photoURL"] as? String).flatMap(URL.init(string:)),
            email: data["email"] as? String,
            activeGroupId: data["activeGroupId"] as? String,
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"]),
            deletedAt: optionalDate(data["deletedAt"])
        )
    }

    private func mapInvite(_ snapshot: QueryDocumentSnapshot) throws -> Invite {
        let data = snapshot.data()
        guard let status = Invite.Status(rawValue: data["status"] as? String ?? "") else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return Invite(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            code: data["code"] as? String ?? "",
            createdBy: data["createdBy"] as? String ?? "",
            status: status,
            expiresAt: date(data["expiresAt"]),
            createdAt: date(data["createdAt"]),
            usedAt: optionalDate(data["usedAt"]),
            usedBy: data["usedBy"] as? String
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
            title: data["title"] as? String ?? "おねがい",
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

    private func normalizedDraft(_ draft: RequestDraft) throws -> RequestDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draft.iconEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !emoji.isEmpty, draft.coinAmount > 0 else {
            throw AppRepositoryError.invalidRequest
        }
        return RequestDraft(
            title: title,
            iconEmoji: emoji,
            coinAmount: draft.coinAmount,
            piggyBankType: draft.piggyBankType,
            repeatType: draft.repeatType
        )
    }

    private func normalizedRewardDraft(_ draft: RewardDraft) throws -> RewardDraft {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draft.iconEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let expiryIsValid = switch draft.expiresInType {
        case .none: true
        case .days: draft.expiresInDays.map { $0 > 0 } ?? false
        case .date: draft.expiresAt.map { $0 > Date() } ?? false
        }
        guard !title.isEmpty, !emoji.isEmpty, draft.requiredCoins > 0, expiryIsValid else {
            throw AppRepositoryError.invalidReward
        }
        return RewardDraft(
            title: title,
            iconEmoji: emoji,
            requiredCoins: draft.requiredCoins,
            piggyBankType: draft.piggyBankType,
            expiresInType: draft.expiresInType,
            expiresInDays: draft.expiresInType == .days ? draft.expiresInDays : nil,
            expiresAt: draft.expiresInType == .date ? draft.expiresAt : nil
        )
    }

    private func requestData(_ request: RequestItem) -> [String: Any] {
        [
            "groupId": request.groupId,
            "createdBy": request.createdBy,
            "title": request.title,
            "iconEmoji": request.iconEmoji,
            "coinAmount": request.coinAmount,
            "piggyBankType": request.piggyBankType.rawValue,
            "repeatType": request.repeatType.rawValue,
            "status": request.status.rawValue,
            "completionCount": request.completionCount,
            "lastCompletedAt": request.lastCompletedAt.map(Timestamp.init(date:)) ?? NSNull(),
            "createdAt": Timestamp(date: request.createdAt),
            "updatedAt": Timestamp(date: request.updatedAt),
        ]
    }

    private func rewardData(_ reward: Reward) -> [String: Any] {
        [
            "groupId": reward.groupId,
            "createdBy": reward.createdBy,
            "title": reward.title,
            "iconEmoji": reward.iconEmoji,
            "requiredCoins": reward.requiredCoins,
            "piggyBankType": reward.piggyBankType.rawValue,
            "isTarget": reward.isTarget,
            "expiresInType": reward.expiresInType.rawValue,
            "expiresInDays": reward.expiresInDays ?? NSNull(),
            "expiresAt": reward.expiresAt.map(Timestamp.init(date:)) ?? NSNull(),
            "status": reward.status.rawValue,
            "createdAt": Timestamp(date: reward.createdAt),
            "updatedAt": Timestamp(date: reward.updatedAt),
        ]
    }

    private func mapTicket(_ snapshot: QueryDocumentSnapshot) throws -> Ticket {
        let data = snapshot.data()
        guard let ticketType = PiggyBank.OwnerType(rawValue: data["ticketType"] as? String ?? ""),
              let status = Ticket.Status(rawValue: data["status"] as? String ?? "")
        else { throw AppRepositoryError.invalidBackendResponse }
        return Ticket(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            rewardId: data["rewardId"] as? String ?? "",
            issuedBy: data["issuedBy"] as? String ?? "",
            ownerUserId: data["ownerUserId"] as? String,
            piggyBankId: data["piggyBankId"] as? String ?? "",
            ticketType: ticketType,
            title: data["title"] as? String ?? "ごほうび券",
            iconEmoji: data["iconEmoji"] as? String ?? "🎁",
            spentCoins: integer(data["spentCoins"]) ?? 0,
            status: status,
            issuedAt: date(data["issuedAt"]),
            usedAt: optionalDate(data["usedAt"]),
            usedBy: data["usedBy"] as? String,
            expiresAt: optionalDate(data["expiresAt"]),
            createdAt: date(data["createdAt"]),
            updatedAt: date(data["updatedAt"])
        )
    }

    private func ticket(from data: [String: Any]) -> Ticket? {
        guard let id = data["id"] as? String,
              let groupId = data["groupId"] as? String,
              let rewardId = data["rewardId"] as? String,
              let issuedBy = data["issuedBy"] as? String,
              let piggyBankId = data["piggyBankId"] as? String,
              let typeValue = data["ticketType"] as? String,
              let ticketType = PiggyBank.OwnerType(rawValue: typeValue),
              let title = data["title"] as? String,
              let iconEmoji = data["iconEmoji"] as? String,
              let spentCoins = integer(data["spentCoins"]),
              let statusValue = data["status"] as? String,
              let status = Ticket.Status(rawValue: statusValue),
              let issuedAtValue = data["issuedAt"] as? String,
              let issuedAt = parseISO8601(issuedAtValue)
        else { return nil }
        let expiresAt = (data["expiresAt"] as? String).flatMap(parseISO8601)
        let usedAt = (data["usedAt"] as? String).flatMap(parseISO8601)
        let createdAt = (data["createdAt"] as? String).flatMap(parseISO8601) ?? issuedAt
        let updatedAt = (data["updatedAt"] as? String).flatMap(parseISO8601) ?? issuedAt
        return Ticket(id: id, groupId: groupId, rewardId: rewardId, issuedBy: issuedBy,
                      ownerUserId: data["ownerUserId"] as? String, piggyBankId: piggyBankId,
                      ticketType: ticketType, title: title, iconEmoji: iconEmoji,
                      spentCoins: spentCoins, status: status, issuedAt: issuedAt,
                      usedAt: usedAt, usedBy: data["usedBy"] as? String, expiresAt: expiresAt,
                      createdAt: createdAt, updatedAt: updatedAt)
    }

    private func record(from data: [String: Any]) -> ActivityRecord? {
        guard let id = data["id"] as? String,
              let groupId = data["groupId"] as? String,
              let userId = data["userId"] as? String,
              let targetId = data["targetId"] as? String,
              let title = data["title"] as? String,
              let iconEmoji = data["iconEmoji"] as? String,
              let coinDelta = integer(data["coinDelta"]),
              let piggyBankId = data["piggyBankId"] as? String,
              let piggyBankName = data["piggyBankName"] as? String,
              let balanceBefore = integer(data["balanceBefore"]),
              let balanceAfter = integer(data["balanceAfter"]),
              let createdAtValue = data["createdAt"] as? String,
              let createdAt = parseISO8601(createdAtValue)
        else { return nil }
        return ActivityRecord(id: id, groupId: groupId, userId: userId, type: .rewardExchange,
                              targetType: "reward", targetId: targetId, title: title,
                              iconEmoji: iconEmoji, coinDelta: coinDelta, piggyBankId: piggyBankId,
                              piggyBankName: piggyBankName, balanceBefore: balanceBefore,
                              balanceAfter: balanceAfter, status: .active, createdAt: createdAt,
                              canceledAt: nil)
    }

    private func ticketUseRecord(from data: [String: Any]) -> ActivityRecord? {
        guard let id = data["id"] as? String,
              let groupId = data["groupId"] as? String,
              let userId = data["userId"] as? String,
              let targetId = data["targetId"] as? String,
              let title = data["title"] as? String,
              let iconEmoji = data["iconEmoji"] as? String,
              let piggyBankId = data["piggyBankId"] as? String,
              let piggyBankName = data["piggyBankName"] as? String,
              let balance = integer(data["balanceAfter"]),
              let createdAtValue = data["createdAt"] as? String,
              let createdAt = parseISO8601(createdAtValue)
        else { return nil }
        return ActivityRecord(id: id, groupId: groupId, userId: userId, type: .ticketUsed,
                              targetType: "ticket", targetId: targetId, title: title,
                              iconEmoji: iconEmoji, coinDelta: 0, piggyBankId: piggyBankId,
                              piggyBankName: piggyBankName, balanceBefore: balance,
                              balanceAfter: balance, status: .active, createdAt: createdAt,
                              canceledAt: nil)
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }

    private func mapRecord(_ snapshot: QueryDocumentSnapshot) throws -> ActivityRecord {
        let data = snapshot.data()
        guard
            let type = ActivityRecord.RecordType(rawValue: data["type"] as? String ?? ""),
            let status = ActivityRecord.Status(rawValue: data["status"] as? String ?? "")
        else {
            throw AppRepositoryError.invalidBackendResponse
        }
        return ActivityRecord(
            id: snapshot.documentID,
            groupId: data["groupId"] as? String ?? "",
            userId: data["userId"] as? String ?? "",
            type: type,
            targetType: data["targetType"] as? String ?? "",
            targetId: data["targetId"] as? String ?? "",
            title: data["title"] as? String ?? "きろく",
            iconEmoji: data["iconEmoji"] as? String ?? "🪙",
            coinDelta: data["coinDelta"] as? Int ?? 0,
            piggyBankId: data["piggyBankId"] as? String ?? "",
            piggyBankName: data["piggyBankName"] as? String ?? "貯金箱",
            balanceBefore: data["balanceBefore"] as? Int ?? 0,
            balanceAfter: data["balanceAfter"] as? Int ?? 0,
            status: status,
            createdAt: date(data["createdAt"]),
            canceledAt: optionalDate(data["canceledAt"])
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
