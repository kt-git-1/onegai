import {randomBytes} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";

initializeApp();
setGlobalOptions({region: "asia-northeast1", maxInstances: 10});

const db = getFirestore();

type BankType = "personal" | "shared";

const personalRequests = [
  {title: "マッサージ10分", iconEmoji: "💆", coinAmount: 100},
  {title: "皿洗い", iconEmoji: "🧽", coinAmount: 50},
  {title: "買い出し", iconEmoji: "🛍️", coinAmount: 80},
];

const sharedRequests = [
  {title: "ふたりで部屋を片付ける", iconEmoji: "🧹", coinAmount: 200},
  {title: "デートの予定を決める", iconEmoji: "🥢", coinAmount: 300},
];

const rewards = [
  {title: "スタバごほうび券", iconEmoji: "☕️", requiredCoins: 700, bankType: "personal" as BankType},
  {title: "映画ごほうび券", iconEmoji: "🎬", requiredCoins: 1200, bankType: "personal" as BankType},
  {title: "焼肉デートごほうび券", iconEmoji: "🍖", requiredCoins: 5000, bankType: "shared" as BankType},
];

function requireUserId(auth: {uid: string} | undefined): string {
  if (!auth) {
    throw new HttpsError("unauthenticated", "ログインが必要です。");
  }
  return auth.uid;
}

function createInviteCode(): string {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes(8);
  const value = Array.from(bytes, (byte) => alphabet[byte % alphabet.length]).join("");
  return `${value.slice(0, 4)}-${value.slice(4)}`;
}

export const createInitialTemplate = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const userRef = db.collection("users").doc(userId);
  const groupRef = db.collection("groups").doc();
  const memberRef = db.collection("groupMembers").doc(`${groupRef.id}_${userId}`);
  const personalBankRef = db.collection("piggyBanks").doc();
  const sharedBankRef = db.collection("piggyBanks").doc();
  const inviteRef = db.collection("invites").doc();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000);

  const requestRefs = [...personalRequests, ...sharedRequests].map(() => db.collection("requests").doc());
  const rewardRefs = rewards.map(() => db.collection("rewards").doc());

  await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "プロフィールを先に設定してください。");
    }
    if (userSnapshot.get("activeGroupId")) {
      throw new HttpsError("already-exists", "初期設定はすでに作成されています。");
    }

    const displayName = String(userSnapshot.get("displayName") ?? "").trim();
    if (!displayName) {
      throw new HttpsError("failed-precondition", "プロフィール名が必要です。");
    }

    transaction.create(groupRef, {
      id: groupRef.id,
      name: `${displayName}とパートナー`,
      type: "couple",
      status: "active",
      memberIds: [userId],
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      archivedAt: null,
    });
    transaction.create(memberRef, {
      id: memberRef.id,
      groupId: groupRef.id,
      userId,
      role: "owner",
      status: "active",
      joinedAt: now,
      leftAt: null,
      notificationRewardExchangeEnabled: true,
    });
    transaction.create(personalBankRef, {
      id: personalBankRef.id,
      groupId: groupRef.id,
      ownerType: "personal",
      ownerUserId: userId,
      name: `${displayName}の貯金箱`,
      balance: 0,
      targetRewardId: null,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });
    transaction.create(sharedBankRef, {
      id: sharedBankRef.id,
      groupId: groupRef.id,
      ownerType: "shared",
      ownerUserId: null,
      name: "ふたりの貯金箱",
      balance: 0,
      targetRewardId: null,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });

    [...personalRequests, ...sharedRequests].forEach((item, index) => {
      const bankType: BankType = index < personalRequests.length ? "personal" : "shared";
      const ref = requestRefs[index];
      transaction.create(ref, {
        id: ref.id,
        groupId: groupRef.id,
        createdBy: userId,
        title: item.title,
        iconEmoji: item.iconEmoji,
        coinAmount: item.coinAmount,
        piggyBankType: bankType,
        repeatType: "repeat",
        status: "active",
        completionCount: 0,
        lastCompletedAt: null,
        createdAt: now,
        updatedAt: now,
      });
    });

    rewards.forEach((item, index) => {
      const ref = rewardRefs[index];
      transaction.create(ref, {
        id: ref.id,
        groupId: groupRef.id,
        createdBy: userId,
        title: item.title,
        iconEmoji: item.iconEmoji,
        requiredCoins: item.requiredCoins,
        piggyBankType: item.bankType,
        isTarget: false,
        expiresInType: "none",
        expiresInDays: null,
        expiresAt: null,
        status: "active",
        createdAt: now,
        updatedAt: now,
      });
    });

    transaction.create(inviteRef, {
      id: inviteRef.id,
      groupId: groupRef.id,
      code: createInviteCode(),
      createdBy: userId,
      status: "active",
      expiresAt,
      createdAt: now,
      usedAt: null,
      usedBy: null,
    });
    transaction.update(userRef, {activeGroupId: groupRef.id, updatedAt: FieldValue.serverTimestamp()});
  });

  const inviteSnapshot = await inviteRef.get();
  return {
    groupId: groupRef.id,
    personalPiggyBankId: personalBankRef.id,
    sharedPiggyBankId: sharedBankRef.id,
    invite: {
      id: inviteRef.id,
      code: inviteSnapshot.get("code"),
      expiresAt: expiresAt.toDate().toISOString(),
    },
  };
});

export const reissueInvite = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const groupId = typeof request.data?.groupId === "string" ? request.data.groupId : "";
  if (!groupId) {
    throw new HttpsError("invalid-argument", "groupIdが必要です。");
  }

  const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
  const newInviteRef = db.collection("invites").doc();
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + 24 * 60 * 60 * 1000);

  await db.runTransaction(async (transaction) => {
    const memberSnapshot = await transaction.get(memberRef);
    if (!memberSnapshot.exists || memberSnapshot.get("status") !== "active") {
      throw new HttpsError("permission-denied", "このグループの招待は作成できません。");
    }

    const activeInvites = await transaction.get(
      db.collection("invites").where("groupId", "==", groupId).where("status", "==", "active"),
    );
    activeInvites.docs.forEach((snapshot) => {
      transaction.update(snapshot.ref, {status: "revoked"});
    });
    transaction.create(newInviteRef, {
      id: newInviteRef.id,
      groupId,
      code: createInviteCode(),
      createdBy: userId,
      status: "active",
      expiresAt,
      createdAt: now,
      usedAt: null,
      usedBy: null,
    });
  });

  const snapshot = await newInviteRef.get();
  return {
    id: newInviteRef.id,
    code: snapshot.get("code"),
    expiresAt: expiresAt.toDate().toISOString(),
  };
});
