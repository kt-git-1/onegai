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
  requests: requests.size === 5,
  rewards: rewards.size === 3,
  invites: invites.size === 1,
  activeGroupId: user.get("activeGroupId") === result.groupId,
};
const failed = Object.entries(checks).filter(([, passed]) => !passed);
if (failed.length > 0) {
  throw new Error(`Integration checks failed: ${JSON.stringify(checks)}`);
}

console.log(JSON.stringify({status: "passed", checks, inviteCode: result.invite.code}, null, 2));
