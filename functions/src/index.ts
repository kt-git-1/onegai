import {randomBytes} from "node:crypto";
import {initializeApp} from "firebase-admin/app";
import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2/options";

initializeApp();
setGlobalOptions({region: "asia-northeast1", maxInstances: 10});

const db = getFirestore();
const CHARIN_UNDO_WINDOW_MS = 10_000;

type BankType = "personal" | "shared";

type CharinResult = {
  recordId: string;
  groupId: string;
  userId: string;
  requestId: string;
  piggyBankId: string;
  piggyBankName: string;
  title: string;
  iconEmoji: string;
  coinAmount: number;
  balanceBefore: number;
  balanceAfter: number;
  requestStatus: string;
  completionCount: number;
  createdAt: string;
  targetReward: {
    id: string;
    title: string;
    iconEmoji: string;
    remainingCoins: number;
    isExchangeable: boolean;
    becameExchangeable: boolean;
  } | null;
};

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

function normalizeInviteIdentifier(value: unknown): string {
  if (typeof value !== "string") return "";
  const trimmed = value.trim();
  const compact = trimmed.toUpperCase().replace(/[^A-Z0-9]/g, "");
  return compact.length === 8 ? `${compact.slice(0, 4)}-${compact.slice(4)}` : trimmed;
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

export const resolveInvite = onCall(async (request) => {
  const identifier = normalizeInviteIdentifier(request.data?.identifier);
  if (!identifier) {
    throw new HttpsError("invalid-argument", "招待コードを確認してください。");
  }

  let inviteSnapshot = await db.collection("invites").doc(identifier).get();
  if (!inviteSnapshot.exists) {
    const matches = await db.collection("invites").where("code", "==", identifier).limit(1).get();
    inviteSnapshot = matches.docs[0];
  }
  if (!inviteSnapshot?.exists) {
    throw new HttpsError("not-found", "招待コードを確認してください。");
  }

  const invite = inviteSnapshot.data();
  if (!invite) {
    throw new HttpsError("not-found", "招待コードを確認してください。");
  }
  const status = invite?.status;
  const expiresAt = invite?.expiresAt as Timestamp | undefined;
  if (status !== "active") {
    throw new HttpsError("failed-precondition", status === "used" ? "この招待はすでに使用されています。" : "この招待は使用できません。");
  }
  if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError("deadline-exceeded", "この招待は期限切れです。");
  }

  const [groupSnapshot, inviterSnapshot] = await Promise.all([
    db.collection("groups").doc(String(invite.groupId)).get(),
    db.collection("users").doc(String(invite.createdBy)).get(),
  ]);
  if (!groupSnapshot.exists || groupSnapshot.get("status") !== "active") {
    throw new HttpsError("failed-precondition", "この招待は使用できません。");
  }
  const memberIds = groupSnapshot.get("memberIds") as string[] | undefined;
  if ((memberIds?.length ?? 0) >= 2) {
    throw new HttpsError("resource-exhausted", "この招待は使用できません。");
  }

  return {
    id: inviteSnapshot.id,
    code: invite.code,
    inviterName: inviterSnapshot.get("displayName") || "相手",
    inviterEmoji: inviterSnapshot.get("iconEmoji") || null,
    expiresAt: expiresAt.toDate().toISOString(),
  };
});

export const acceptInvite = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const inviteId = typeof request.data?.inviteId === "string" ? request.data.inviteId : "";
  if (!inviteId) {
    throw new HttpsError("invalid-argument", "招待が指定されていません。");
  }

  const inviteRef = db.collection("invites").doc(inviteId);
  const userRef = db.collection("users").doc(userId);
  const personalBankRef = db.collection("piggyBanks").doc();

  await db.runTransaction(async (transaction) => {
    const [inviteSnapshot, userSnapshot] = await Promise.all([
      transaction.get(inviteRef),
      transaction.get(userRef),
    ]);
    if (!inviteSnapshot.exists) {
      throw new HttpsError("not-found", "招待コードを確認してください。");
    }
    if (!userSnapshot.exists || !String(userSnapshot.get("displayName") ?? "").trim()) {
      throw new HttpsError("failed-precondition", "プロフィールを先に設定してください。");
    }

    const groupId = String(inviteSnapshot.get("groupId") ?? "");
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
    const [groupSnapshot, memberSnapshot] = await Promise.all([
      transaction.get(groupRef),
      transaction.get(memberRef),
    ]);
    if (!groupSnapshot.exists || groupSnapshot.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "この招待は使用できません。");
    }

    const existingGroupId = userSnapshot.get("activeGroupId");
    if (existingGroupId) {
      if (existingGroupId === groupId && memberSnapshot.exists) return;
      throw new HttpsError("already-exists", "すでに別の相手と連携しています。");
    }
    if (inviteSnapshot.get("createdBy") === userId) {
      throw new HttpsError("failed-precondition", "自分の招待には参加できません。");
    }
    if (inviteSnapshot.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "この招待はすでに使用されています。");
    }
    const expiresAt = inviteSnapshot.get("expiresAt") as Timestamp | undefined;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "この招待は期限切れです。");
    }

    const memberIds = (groupSnapshot.get("memberIds") as string[] | undefined) ?? [];
    if (memberIds.length >= 2) {
      throw new HttpsError("resource-exhausted", "この招待は使用できません。");
    }

    const now = Timestamp.now();
    transaction.create(memberRef, {
      id: memberRef.id,
      groupId,
      userId,
      role: "member",
      status: "active",
      joinedAt: now,
      leftAt: null,
      notificationRewardExchangeEnabled: true,
    });
    transaction.create(personalBankRef, {
      id: personalBankRef.id,
      groupId,
      ownerType: "personal",
      ownerUserId: userId,
      name: `${String(userSnapshot.get("displayName")).trim()}の貯金箱`,
      balance: 0,
      targetRewardId: null,
      status: "active",
      createdAt: now,
      updatedAt: now,
    });
    transaction.update(groupRef, {memberIds: [...memberIds, userId], updatedAt: now});
    transaction.update(userRef, {activeGroupId: groupId, updatedAt: now});
    transaction.update(inviteRef, {status: "used", usedAt: now, usedBy: userId});
  });

  return {groupId: (await userRef.get()).get("activeGroupId")};
});

export const charinRequest = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const groupId = typeof request.data?.groupId === "string" ? request.data.groupId : "";
  const requestId = typeof request.data?.requestId === "string" ? request.data.requestId : "";
  if (!groupId || !requestId) {
    throw new HttpsError("invalid-argument", "お願いが指定されていません。");
  }

  const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
  const requestRef = db.collection("requests").doc(requestId);
  const recordRef = db.collection("records").doc();
  let result: CharinResult | undefined;

  await db.runTransaction(async (transaction) => {
    const [memberSnapshot, requestSnapshot, bankSnapshots, rewardSnapshots, ticketSnapshots] = await Promise.all([
      transaction.get(memberRef),
      transaction.get(requestRef),
      transaction.get(db.collection("piggyBanks").where("groupId", "==", groupId)),
      transaction.get(db.collection("rewards").where("groupId", "==", groupId)),
      transaction.get(db.collection("tickets").where("groupId", "==", groupId)),
    ]);
    if (!memberSnapshot.exists || memberSnapshot.get("status") !== "active") {
      throw new HttpsError("permission-denied", "このお願いをちゃりんできません。");
    }
    if (!requestSnapshot.exists || requestSnapshot.get("groupId") !== groupId) {
      throw new HttpsError("not-found", "お願いが見つかりません。");
    }
    if (requestSnapshot.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "このお願いは現在ちゃりんできません。");
    }

    const bankType = requestSnapshot.get("piggyBankType") as BankType | undefined;
    const createdBy = String(requestSnapshot.get("createdBy") ?? "");
    const bankSnapshot = bankSnapshots.docs.find((snapshot) => {
      if (snapshot.get("status") !== "active" || snapshot.get("ownerType") !== bankType) return false;
      return bankType === "shared" || snapshot.get("ownerUserId") === createdBy;
    });
    if (!bankSnapshot) {
      throw new HttpsError("failed-precondition", "入金先の貯金箱が見つかりません。");
    }

    const coinAmount = Number(requestSnapshot.get("coinAmount") ?? 0);
    if (!Number.isSafeInteger(coinAmount) || coinAmount <= 0) {
      throw new HttpsError("failed-precondition", "コイン数が正しくありません。");
    }
    const balanceBefore = Number(bankSnapshot.get("balance") ?? 0);
    const balanceAfter = balanceBefore + coinAmount;
    const completionCount = Number(requestSnapshot.get("completionCount") ?? 0) + 1;
    const repeatType = String(requestSnapshot.get("repeatType") ?? "repeat");
    const requestStatus = repeatType === "oneTime" ? "hidden" : "active";
    const now = Timestamp.now();

    const exchangedRewardIds = new Set(ticketSnapshots.docs
      .filter((snapshot) => snapshot.get("status") !== "canceled")
      .map((snapshot) => String(snapshot.get("rewardId") ?? "")));
    const targetRewardSnapshot = rewardSnapshots.docs
      .filter((snapshot) => {
        if (snapshot.get("status") !== "active" || snapshot.get("piggyBankType") !== bankType) return false;
        if (bankType === "personal" && snapshot.get("createdBy") !== bankSnapshot.get("ownerUserId")) return false;
        return !exchangedRewardIds.has(snapshot.id);
      })
      .sort((lhs, rhs) => {
        const lhsRequired = Number(lhs.get("requiredCoins") ?? 0);
        const rhsRequired = Number(rhs.get("requiredCoins") ?? 0);
        const remainingDifference = Math.max(lhsRequired - balanceAfter, 0) - Math.max(rhsRequired - balanceAfter, 0);
        return remainingDifference !== 0 ? remainingDifference : lhsRequired - rhsRequired;
      })[0];
    const requiredCoins = Number(targetRewardSnapshot?.get("requiredCoins") ?? 0);
    const targetReward = targetRewardSnapshot && requiredCoins > 0 ? {
      id: targetRewardSnapshot.id,
      title: String(targetRewardSnapshot.get("title") ?? "ごほうび券"),
      iconEmoji: String(targetRewardSnapshot.get("iconEmoji") ?? "🎁"),
      remainingCoins: Math.max(requiredCoins - balanceAfter, 0),
      isExchangeable: balanceAfter >= requiredCoins,
      becameExchangeable: balanceBefore < requiredCoins && balanceAfter >= requiredCoins,
    } : null;

    transaction.update(bankSnapshot.ref, {balance: balanceAfter, updatedAt: now});
    transaction.update(requestRef, {
      completionCount,
      lastCompletedAt: now,
      status: requestStatus,
      updatedAt: now,
    });
    const title = String(requestSnapshot.get("title") ?? "お願い");
    const iconEmoji = String(requestSnapshot.get("iconEmoji") ?? "✨");
    const piggyBankName = String(bankSnapshot.get("name") ?? "貯金箱");
    transaction.create(recordRef, {
      id: recordRef.id,
      groupId,
      userId,
      type: "charin",
      targetType: "request",
      targetId: requestId,
      title,
      iconEmoji,
      coinDelta: coinAmount,
      piggyBankId: bankSnapshot.id,
      piggyBankName,
      balanceBefore,
      balanceAfter,
      status: "active",
      createdAt: now,
      canceledAt: null,
    });

    result = {
      recordId: recordRef.id,
      groupId,
      userId,
      requestId,
      piggyBankId: bankSnapshot.id,
      piggyBankName,
      title,
      iconEmoji,
      coinAmount,
      balanceBefore,
      balanceAfter,
      requestStatus,
      completionCount,
      createdAt: now.toDate().toISOString(),
      targetReward,
    };
  });

  if (!result) throw new HttpsError("internal", "ちゃりん結果を取得できませんでした。");
  return result;
});

export const exchangeReward = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const groupId = typeof request.data?.groupId === "string" ? request.data.groupId : "";
  const rewardId = typeof request.data?.rewardId === "string" ? request.data.rewardId : "";
  const piggyBankId = typeof request.data?.piggyBankId === "string" ? request.data.piggyBankId : "";
  if (!groupId || !rewardId || !piggyBankId) {
    throw new HttpsError("invalid-argument", "交換するごほうび券が指定されていません。");
  }

  const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
  const rewardRef = db.collection("rewards").doc(rewardId);
  const bankRef = db.collection("piggyBanks").doc(piggyBankId);
  const ticketRef = db.collection("tickets").doc();
  const recordRef = db.collection("records").doc();
  let response: Record<string, unknown> | undefined;

  await db.runTransaction(async (transaction) => {
    const [memberSnapshot, rewardSnapshot, bankSnapshot, existingTicketSnapshots] = await Promise.all([
      transaction.get(memberRef),
      transaction.get(rewardRef),
      transaction.get(bankRef),
      transaction.get(db.collection("tickets").where("rewardId", "==", rewardId)),
    ]);
    if (!memberSnapshot.exists || memberSnapshot.get("status") !== "active") {
      throw new HttpsError("permission-denied", "このごほうび券は交換できません。");
    }
    if (!rewardSnapshot.exists || rewardSnapshot.get("groupId") !== groupId || rewardSnapshot.get("status") !== "active") {
      throw new HttpsError("not-found", "ごほうび券が見つかりません。");
    }
    if (!bankSnapshot.exists || bankSnapshot.get("groupId") !== groupId || bankSnapshot.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "貯金箱が見つかりません。");
    }
    if (existingTicketSnapshots.docs.some((snapshot) =>
      snapshot.get("groupId") === groupId && snapshot.get("status") !== "canceled")) {
      throw new HttpsError("already-exists", "このごほうび券はすでに交換済みです。");
    }
    const bankType = rewardSnapshot.get("piggyBankType") as BankType | undefined;
    if (bankSnapshot.get("ownerType") !== bankType ||
        (bankType === "personal" && bankSnapshot.get("ownerUserId") !== rewardSnapshot.get("createdBy"))) {
      throw new HttpsError("failed-precondition", "この貯金箱では交換できません。");
    }

    const requiredCoins = Number(rewardSnapshot.get("requiredCoins") ?? 0);
    const balanceBefore = Number(bankSnapshot.get("balance") ?? 0);
    if (!Number.isSafeInteger(requiredCoins) || requiredCoins <= 0) {
      throw new HttpsError("failed-precondition", "必要コイン数が正しくありません。");
    }
    if (!Number.isSafeInteger(balanceBefore) || balanceBefore < requiredCoins) {
      throw new HttpsError("failed-precondition", "交換に必要なコインが足りません。");
    }

    const now = Timestamp.now();
    const balanceAfter = balanceBefore - requiredCoins;
    const expiryType = String(rewardSnapshot.get("expiresInType") ?? "none");
    let expiresAt: Timestamp | null = null;
    if (expiryType === "days") {
      const days = Number(rewardSnapshot.get("expiresInDays") ?? 0);
      if (Number.isSafeInteger(days) && days > 0) {
        expiresAt = Timestamp.fromMillis(now.toMillis() + days * 24 * 60 * 60 * 1000);
      }
    } else if (expiryType === "date") {
      expiresAt = rewardSnapshot.get("expiresAt") as Timestamp | null;
    }

    const title = String(rewardSnapshot.get("title") ?? "ごほうび券");
    const iconEmoji = String(rewardSnapshot.get("iconEmoji") ?? "🎁");
    const piggyBankName = String(bankSnapshot.get("name") ?? "貯金箱");
    const ticket = {
      id: ticketRef.id, groupId, rewardId, issuedBy: userId,
      ownerUserId: bankType === "personal" ? bankSnapshot.get("ownerUserId") : null,
      piggyBankId, ticketType: bankType, title, iconEmoji, spentCoins: requiredCoins,
      status: "unused", issuedAt: now, usedAt: null, usedBy: null, expiresAt,
      createdAt: now, updatedAt: now,
    };
    const record = {
      id: recordRef.id, groupId, userId, type: "rewardExchange", targetType: "reward",
      targetId: rewardId, title, iconEmoji, coinDelta: -requiredCoins,
      piggyBankId, piggyBankName, balanceBefore, balanceAfter,
      status: "active", createdAt: now, canceledAt: null,
    };
    transaction.update(bankRef, {balance: balanceAfter, updatedAt: now});
    transaction.create(ticketRef, ticket);
    transaction.create(recordRef, record);

    response = {
      ticket: {...ticket, issuedAt: now.toDate().toISOString(), expiresAt: expiresAt?.toDate().toISOString() ?? null},
      record: {...record, createdAt: now.toDate().toISOString()},
    };
  });

  if (!response) throw new HttpsError("internal", "交換結果を取得できませんでした。");
  return response;
});

export const useTicket = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const ticketId = typeof request.data?.ticketId === "string" ? request.data.ticketId : "";
  if (!ticketId) throw new HttpsError("invalid-argument", "使用する券が指定されていません。");

  const ticketRef = db.collection("tickets").doc(ticketId);
  const recordRef = db.collection("records").doc();
  let response: Record<string, unknown> | undefined;

  await db.runTransaction(async (transaction) => {
    const ticketSnapshot = await transaction.get(ticketRef);
    if (!ticketSnapshot.exists) throw new HttpsError("not-found", "ごほうび券が見つかりません。");
    if (ticketSnapshot.get("status") !== "unused") {
      throw new HttpsError("failed-precondition", "このごほうび券は使用できません。");
    }
    const groupId = String(ticketSnapshot.get("groupId") ?? "");
    const piggyBankId = String(ticketSnapshot.get("piggyBankId") ?? "");
    const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
    const bankRef = db.collection("piggyBanks").doc(piggyBankId);
    const [memberSnapshot, bankSnapshot] = await Promise.all([
      transaction.get(memberRef),
      transaction.get(bankRef),
    ]);
    if (!memberSnapshot.exists || memberSnapshot.get("status") !== "active") {
      throw new HttpsError("permission-denied", "このごほうび券は使用できません。");
    }
    if (!bankSnapshot.exists || bankSnapshot.get("groupId") !== groupId) {
      throw new HttpsError("failed-precondition", "貯金箱が見つかりません。");
    }
    const ticketType = String(ticketSnapshot.get("ticketType") ?? "");
    if (ticketType === "personal" && ticketSnapshot.get("ownerUserId") !== userId) {
      throw new HttpsError("permission-denied", "このごほうび券は使用できません。");
    }

    const now = Timestamp.now();
    const title = String(ticketSnapshot.get("title") ?? "ごほうび券");
    const iconEmoji = String(ticketSnapshot.get("iconEmoji") ?? "🎁");
    const balance = Number(bankSnapshot.get("balance") ?? 0);
    const record = {
      id: recordRef.id, groupId, userId, type: "ticketUsed", targetType: "ticket",
      targetId: ticketId, title, iconEmoji, coinDelta: 0,
      piggyBankId, piggyBankName: String(bankSnapshot.get("name") ?? "貯金箱"),
      balanceBefore: balance, balanceAfter: balance, status: "active",
      createdAt: now, canceledAt: null,
    };
    transaction.update(ticketRef, {status: "used", usedAt: now, usedBy: userId, updatedAt: now});
    transaction.create(recordRef, record);

    const issuedAt = ticketSnapshot.get("issuedAt") as Timestamp;
    const createdAt = ticketSnapshot.get("createdAt") as Timestamp;
    const expiresAt = ticketSnapshot.get("expiresAt") as Timestamp | null;
    response = {
      ticket: {
        id: ticketId, groupId, rewardId: ticketSnapshot.get("rewardId"),
        issuedBy: ticketSnapshot.get("issuedBy"), ownerUserId: ticketSnapshot.get("ownerUserId") ?? null,
        piggyBankId, ticketType, title, iconEmoji, spentCoins: ticketSnapshot.get("spentCoins"),
        status: "used", issuedAt: issuedAt.toDate().toISOString(),
        usedAt: now.toDate().toISOString(), usedBy: userId,
        expiresAt: expiresAt?.toDate().toISOString() ?? null,
        createdAt: createdAt.toDate().toISOString(), updatedAt: now.toDate().toISOString(),
      },
      record: {...record, createdAt: now.toDate().toISOString()},
    };
  });

  if (!response) throw new HttpsError("internal", "使用結果を取得できませんでした。");
  return response;
});

export const cancelCharin = onCall(async (request) => {
  const userId = requireUserId(request.auth);
  const recordId = typeof request.data?.recordId === "string" ? request.data.recordId : "";
  if (!recordId) {
    throw new HttpsError("invalid-argument", "取り消す記録が指定されていません。");
  }

  const recordRef = db.collection("records").doc(recordId);
  let result: {
    recordId: string;
    requestId: string;
    piggyBankId: string;
    balanceAfter: number;
    requestStatus: string;
    completionCount: number;
  } | undefined;

  await db.runTransaction(async (transaction) => {
    const recordSnapshot = await transaction.get(recordRef);
    if (!recordSnapshot.exists || recordSnapshot.get("type") !== "charin") {
      throw new HttpsError("not-found", "ちゃりん記録が見つかりません。");
    }
    if (recordSnapshot.get("userId") !== userId) {
      throw new HttpsError("permission-denied", "このちゃりんは取り消せません。");
    }
    if (recordSnapshot.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "このちゃりんはすでに取り消されています。");
    }
    const createdAt = recordSnapshot.get("createdAt") as Timestamp | undefined;
    if (!createdAt || Date.now() - createdAt.toMillis() > CHARIN_UNDO_WINDOW_MS) {
      throw new HttpsError("deadline-exceeded", "取り消せる時間を過ぎました。");
    }

    const groupId = String(recordSnapshot.get("groupId") ?? "");
    const memberRef = db.collection("groupMembers").doc(`${groupId}_${userId}`);
    const bankRef = db.collection("piggyBanks").doc(String(recordSnapshot.get("piggyBankId") ?? ""));
    const requestRef = db.collection("requests").doc(String(recordSnapshot.get("targetId") ?? ""));
    const [memberSnapshot, bankSnapshot, requestSnapshot] = await Promise.all([
      transaction.get(memberRef),
      transaction.get(bankRef),
      transaction.get(requestRef),
    ]);
    if (!memberSnapshot.exists || memberSnapshot.get("status") !== "active") {
      throw new HttpsError("permission-denied", "このちゃりんは取り消せません。");
    }
    if (!bankSnapshot.exists || !requestSnapshot.exists) {
      throw new HttpsError("failed-precondition", "取り消し対象のデータが見つかりません。");
    }

    const coinAmount = Number(recordSnapshot.get("coinDelta") ?? 0);
    const balanceAfter = Number(bankSnapshot.get("balance") ?? 0) - coinAmount;
    const completionCount = Math.max(Number(requestSnapshot.get("completionCount") ?? 0) - 1, 0);
    const restoresOneTime = requestSnapshot.get("repeatType") === "oneTime" &&
      requestSnapshot.get("status") === "hidden";
    const now = Timestamp.now();

    transaction.update(bankRef, {balance: balanceAfter, updatedAt: now});
    const requestStatus = restoresOneTime ? "active" : String(requestSnapshot.get("status") ?? "active");
    transaction.update(requestRef, {
      completionCount,
      status: requestStatus,
      updatedAt: now,
    });
    transaction.update(recordRef, {status: "canceled", canceledAt: now});
    result = {
      recordId,
      requestId: requestRef.id,
      piggyBankId: bankRef.id,
      balanceAfter,
      requestStatus,
      completionCount,
    };
  });

  if (!result) throw new HttpsError("internal", "取り消し結果を取得できませんでした。");
  return result;
});
