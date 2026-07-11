import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

const projectId = "onegai-charin-dev";
const email = `integration-${Date.now()}@example.com`;
const password = "password123";

const signupResponse = await fetch(
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key",
  {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify({email, password, returnSecureToken: true}),
  },
);
if (!signupResponse.ok) {
  throw new Error(`Auth signup failed: ${await signupResponse.text()}`);
}
const auth = await signupResponse.json();

async function signUp(address) {
  const response = await fetch(
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key",
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email: address, password, returnSecureToken: true}),
    },
  );
  if (!response.ok) throw new Error(`Auth signup failed: ${await response.text()}`);
  return response.json();
}

async function callFunction(name, data, idToken) {
  const response = await fetch(
    `http://127.0.0.1:5001/${projectId}/asia-northeast1/${name}`,
    {
      method: "POST",
      headers: {
        ...(idToken ? {authorization: `Bearer ${idToken}`} : {}),
        "content-type": "application/json",
      },
      body: JSON.stringify({data}),
    },
  );
  const body = await response.json();
  if (!response.ok || body.error) throw new Error(`${name} failed: ${JSON.stringify(body)}`);
  return body.result;
}

initializeApp({projectId});
const db = getFirestore();
await db.collection("users").doc(auth.localId).set({
  id: auth.localId,
  displayName: "テストユーザー",
  iconEmoji: null,
  email,
  activeGroupId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  deletedAt: null,
});

const callableResponse = await fetch(
  `http://127.0.0.1:5001/${projectId}/asia-northeast1/createInitialTemplate`,
  {
    method: "POST",
    headers: {
      authorization: `Bearer ${auth.idToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({data: {}}),
  },
);
if (!callableResponse.ok) {
  throw new Error(`Callable failed: ${await callableResponse.text()}`);
}
const callable = await callableResponse.json();
const result = callable.result;
if (!result?.groupId || !result?.invite?.code) {
  throw new Error(`Invalid callable response: ${JSON.stringify(callable)}`);
}

const [group, members, banks, requests, rewards, invites, user] = await Promise.all([
  db.collection("groups").doc(result.groupId).get(),
  db.collection("groupMembers").where("groupId", "==", result.groupId).get(),
  db.collection("piggyBanks").where("groupId", "==", result.groupId).get(),
  db.collection("requests").where("groupId", "==", result.groupId).get(),
  db.collection("rewards").where("groupId", "==", result.groupId).get(),
  db.collection("invites").where("groupId", "==", result.groupId).get(),
  db.collection("users").doc(auth.localId).get(),
]);

const checks = {
  group: group.exists,
  members: members.size === 1,
  piggyBanks: banks.size === 2,
  requests: requests.size === 6,
  rewards: rewards.size === 3,
  invites: invites.size === 1,
  activeGroupId: user.get("activeGroupId") === result.groupId,
};
const failed = Object.entries(checks).filter(([, passed]) => !passed);
if (failed.length > 0) {
  throw new Error(`Integration checks failed: ${JSON.stringify(checks)}`);
}

const preview = await callFunction("resolveInvite", {identifier: result.invite.code});
if (preview.id !== result.invite.id || preview.inviterName !== "テストユーザー") {
  throw new Error(`Invalid invite preview: ${JSON.stringify(preview)}`);
}

const inviteeEmail = `invitee-${Date.now()}@example.com`;
const inviteeAuth = await signUp(inviteeEmail);
await db.collection("users").doc(inviteeAuth.localId).set({
  id: inviteeAuth.localId,
  displayName: "招待された人",
  iconEmoji: null,
  email: inviteeEmail,
  activeGroupId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  deletedAt: null,
});
await callFunction("acceptInvite", {inviteId: result.invite.id}, inviteeAuth.idToken);

const [joinedGroup, joinedMembers, joinedBanks, usedInvite, inviteeUser] = await Promise.all([
  db.collection("groups").doc(result.groupId).get(),
  db.collection("groupMembers").where("groupId", "==", result.groupId).get(),
  db.collection("piggyBanks").where("groupId", "==", result.groupId).get(),
  db.collection("invites").doc(result.invite.id).get(),
  db.collection("users").doc(inviteeAuth.localId).get(),
]);
const joinChecks = {
  memberIds: joinedGroup.get("memberIds")?.length === 2,
  members: joinedMembers.size === 2,
  piggyBanks: joinedBanks.size === 3,
  inviteUsed: usedInvite.get("status") === "used" && usedInvite.get("usedBy") === inviteeAuth.localId,
  activeGroupId: inviteeUser.get("activeGroupId") === result.groupId,
};
const failedJoinChecks = Object.entries(joinChecks).filter(([, passed]) => !passed);
if (failedJoinChecks.length > 0) {
  throw new Error(`Invite join checks failed: ${JSON.stringify(joinChecks)}`);
}

const personalRequest = requests.docs.find((document) => document.get("piggyBankType") === "personal");
if (!personalRequest) throw new Error("Personal request was not created");
const ownerBank = banks.docs.find(
  (document) => document.get("ownerType") === "personal" && document.get("ownerUserId") === auth.localId,
);
if (!ownerBank) throw new Error("Owner bank was not created");

const charin = await callFunction(
  "charinRequest",
  {groupId: result.groupId, requestId: personalRequest.id},
  inviteeAuth.idToken,
);
const [bankAfterCharin, requestAfterCharin, recordAfterCharin] = await Promise.all([
  ownerBank.ref.get(),
  personalRequest.ref.get(),
  db.collection("records").doc(charin.recordId).get(),
]);
const charinChecks = {
  targetBank: charin.piggyBankId === ownerBank.id,
  balance: bankAfterCharin.get("balance") === personalRequest.get("coinAmount"),
  completionCount: requestAfterCharin.get("completionCount") === 1,
  recordUser: recordAfterCharin.get("userId") === inviteeAuth.localId,
  recordActive: recordAfterCharin.get("status") === "active",
};
if (Object.values(charinChecks).some((passed) => !passed)) {
  throw new Error(`Charin checks failed: ${JSON.stringify(charinChecks)}`);
}

await callFunction("cancelCharin", {recordId: charin.recordId}, inviteeAuth.idToken);
const [bankAfterCancel, requestAfterCancel, recordAfterCancel] = await Promise.all([
  ownerBank.ref.get(),
  personalRequest.ref.get(),
  db.collection("records").doc(charin.recordId).get(),
]);
const cancelChecks = {
  balance: bankAfterCancel.get("balance") === 0,
  completionCount: requestAfterCancel.get("completionCount") === 0,
  recordCanceled: recordAfterCancel.get("status") === "canceled",
};
if (Object.values(cancelChecks).some((passed) => !passed)) {
  throw new Error(`Cancel checks failed: ${JSON.stringify(cancelChecks)}`);
}

await personalRequest.ref.update({repeatType: "oneTime", status: "active"});
const oneTimeCharin = await callFunction(
  "charinRequest",
  {groupId: result.groupId, requestId: personalRequest.id},
  inviteeAuth.idToken,
);
const hiddenRequest = await personalRequest.ref.get();
await callFunction("cancelCharin", {recordId: oneTimeCharin.recordId}, inviteeAuth.idToken);
const restoredRequest = await personalRequest.ref.get();
const oneTimeChecks = {
  hiddenAfterCharin: hiddenRequest.get("status") === "hidden",
  activeAfterCancel: restoredRequest.get("status") === "active",
};
if (Object.values(oneTimeChecks).some((passed) => !passed)) {
  throw new Error(`One-time request checks failed: ${JSON.stringify(oneTimeChecks)}`);
}

console.log(JSON.stringify({
  status: "passed",
  checks,
  joinChecks,
  charinChecks,
  cancelChecks,
  oneTimeChecks,
  inviteCode: result.invite.code,
}, null, 2));
