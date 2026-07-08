# ふたりちゃりん（仮）Firebase DB設計 v1.0

## 1. 技術構成

- iOS: SwiftUI
- Auth: Firebase Auth
- DB: Cloud Firestore
- Functions: Cloud Functions
- Push: Firebase Cloud Messaging
- Analytics: Firebase Analytics
- Storage: MVPでは原則不要
- Remote Config: 将来テンプレート管理で検討

---

## 2. コレクション構成

```text
users
groups
groupMembers
piggyBanks
requests
rewards
tickets
records
reactions
invites
devices
```

---

## 3. users

```json
{
  "id": "uid",
  "displayName": "花男",
  "iconEmoji": "😊",
  "photoURL": null,
  "email": "user@example.com",
  "activeGroupId": "groupId",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "deletedAt": null
}
```

### 補足
- `photoURL` は将来対応用
- MVPでは `iconEmoji` を使用
- UIでは1グループのみだが、DB上は将来複数グループ可能

---

## 4. groups

```json
{
  "id": "groupId",
  "name": "花男と〇〇",
  "type": "couple",
  "status": "active",
  "memberIds": ["uid1", "uid2"],
  "createdBy": "uid1",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "archivedAt": null
}
```

### status
- active
- archived
- deleted

---

## 5. groupMembers

```json
{
  "id": "groupId_uid",
  "groupId": "groupId",
  "userId": "uid",
  "role": "owner",
  "status": "active",
  "joinedAt": "timestamp",
  "leftAt": null,
  "notificationRewardExchangeEnabled": true
}
```

### role
- owner
- member

MVPでは権限差はほぼなし。

---

## 6. piggyBanks

```json
{
  "id": "piggyBankId",
  "groupId": "groupId",
  "ownerType": "personal",
  "ownerUserId": "uid1",
  "name": "花男の貯金箱",
  "balance": 520,
  "targetRewardId": "rewardId",
  "status": "active",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### ownerType
- personal
- shared

sharedの場合：

```json
{
  "ownerType": "shared",
  "ownerUserId": null,
  "name": "ふたりの貯金箱"
}
```

---

## 7. requests

アプリ内の「お願い」。

```json
{
  "id": "requestId",
  "groupId": "groupId",
  "createdBy": "uid1",
  "title": "マッサージ10分",
  "iconEmoji": "💆",
  "coinAmount": 100,
  "piggyBankType": "personal",
  "repeatType": "repeat",
  "status": "active",
  "completionCount": 3,
  "lastCompletedAt": "timestamp",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### piggyBankType
- personal
- shared

personal の場合、ちゃりんしたユーザーの個人貯金箱に入る。  
shared の場合、ふたりの貯金箱に入る。

### repeatType
- repeat
- oneTime

### status
- active
- hidden
- deleted

MVPでは削除ではなく `hidden`。

### 編集権限
作成者のみ。

---

## 8. rewards

アプリ内の「ごほうび券マスター」。

```json
{
  "id": "rewardId",
  "groupId": "groupId",
  "createdBy": "uid1",
  "title": "スタバごほうび券",
  "iconEmoji": "☕",
  "requiredCoins": 700,
  "piggyBankType": "personal",
  "isTarget": true,
  "expiresInType": "none",
  "expiresInDays": null,
  "expiresAt": null,
  "status": "active",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### piggyBankType
- personal
- shared

### expiresInType
- none
- days
- date

### status
- active
- hidden
- deleted

### 編集権限
作成者のみ。

### 重要
発行済みチケットには編集内容を反映しない。  
交換時に必要情報を `tickets` にコピーする。

---

## 9. tickets

発行済みのごほうび券。

```json
{
  "id": "ticketId",
  "groupId": "groupId",
  "rewardId": "rewardId",
  "issuedBy": "uid1",
  "ownerUserId": "uid1",
  "piggyBankId": "piggyBankId",
  "ticketType": "personal",
  "title": "スタバごほうび券",
  "iconEmoji": "☕",
  "spentCoins": 700,
  "status": "unused",
  "issuedAt": "timestamp",
  "usedAt": null,
  "usedBy": null,
  "expiresAt": null,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### ticketType
- personal
- shared

shared の場合：

```json
{
  "ticketType": "shared",
  "ownerUserId": null
}
```

両者に同じ券として表示。  
どちらかが使用済みにすると `status = used` になる。

### status
- unused
- used
- expired
- canceled

MVPでは主に `unused / used`。

---

## 10. records

きろく。

```json
{
  "id": "recordId",
  "groupId": "groupId",
  "userId": "uid1",
  "type": "charin",
  "targetType": "request",
  "targetId": "requestId",
  "title": "マッサージ10分",
  "iconEmoji": "💆",
  "coinDelta": 100,
  "piggyBankId": "piggyBankId",
  "piggyBankName": "花男の貯金箱",
  "balanceBefore": 520,
  "balanceAfter": 620,
  "status": "active",
  "createdAt": "timestamp",
  "canceledAt": null
}
```

### type
- charin
- rewardExchange
- ticketUsed

### status
- active
- canceled

ちゃりん取り消し時は `status = canceled`。  
画面には表示しない。

### 交換履歴例

```json
{
  "type": "rewardExchange",
  "targetType": "ticket",
  "targetId": "ticketId",
  "title": "スタバごほうび券",
  "iconEmoji": "☕",
  "coinDelta": -700,
  "balanceBefore": 740,
  "balanceAfter": 40
}
```

### 使用済み履歴例

```json
{
  "type": "ticketUsed",
  "targetType": "ticket",
  "targetId": "ticketId",
  "title": "スタバごほうび券",
  "iconEmoji": "☕",
  "coinDelta": 0
}
```

---

## 11. reactions

スタンプ。

```json
{
  "id": "recordId_userId",
  "groupId": "groupId",
  "recordId": "recordId",
  "userId": "uid2",
  "stampType": "suki",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### stampType
- arigatou
- saikou
- tasukatta
- suki
- kami

### ルール
- 1 record に対して 1 user 1 reaction
- 押し直し可能
- 自分の record には押せない
- `record.type = charin` のみ

---

## 12. invites

```json
{
  "id": "inviteId",
  "groupId": "groupId",
  "code": "ABCD-1234",
  "createdBy": "uid1",
  "status": "active",
  "expiresAt": "timestamp",
  "createdAt": "timestamp",
  "usedAt": null,
  "usedBy": null
}
```

### status
- active
- used
- expired
- revoked

---

## 13. devices

Push通知用。

```json
{
  "id": "deviceId",
  "userId": "uid",
  "fcmToken": "token",
  "platform": "ios",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "disabledAt": null
}
```

---

## 14. Cloud Functions

### createInitialTemplate

登録後、テンプレート適用時に呼ぶ。

作成するもの：
- group
- groupMember
- personal piggyBank
- shared piggyBank
- initial requests
- initial shared requests
- initial rewards
- initial shared rewards
- invite

---

### charinRequest

入力：

```json
{
  "groupId": "groupId",
  "requestId": "requestId"
}
```

処理：
1. 認証チェック
2. groupMemberチェック
3. request取得
4. target piggyBank決定
5. Transaction開始
6. balanceBefore取得
7. balanceAfter計算
8. piggyBanks.balance更新
9. requests.completionCount更新
10. oneTimeなら request.status = hidden
11. records作成
12. 結果返却

返却例：

```json
{
  "recordId": "recordId",
  "coinAmount": 100,
  "balanceBefore": 520,
  "balanceAfter": 620,
  "targetReward": {
    "title": "スタバごほうび券",
    "remainingCoins": 80,
    "isExchangeable": false
  }
}
```

---

### cancelCharin

入力：

```json
{
  "recordId": "recordId"
}
```

処理：
1. record取得
2. type = charin であること
3. userId が本人であること
4. createdAtから30秒以内であること
5. status activeであること
6. Transactionで piggyBank.balance を戻す
7. record.status = canceled
8. request.completionCount を戻す
9. oneTimeでhiddenになっていた場合はactiveに戻す

---

### exchangeReward

入力：

```json
{
  "groupId": "groupId",
  "rewardId": "rewardId",
  "piggyBankId": "piggyBankId"
}
```

処理：
1. 認証チェック
2. groupMemberチェック
3. reward取得
4. piggyBank取得
5. 残高不足チェック
6. Transaction開始
7. balance更新
8. ticket作成
9. record作成
10. 相手へPush通知送信

通知文言：
> 〇〇が「スタバごほうび券」を交換しました

---

### useTicket

入力：

```json
{
  "ticketId": "ticketId"
}
```

処理：
1. 認証チェック
2. ticket取得
3. groupMemberチェック
4. status = unused であること
5. status = used に更新
6. usedAt, usedBy を保存
7. record作成
8. 通知は送らない

---

### leaveOrDisconnectPartner

相手解除 / 退出。

処理方針：
- groupをarchived
- shared piggyBankをarchived
- shared rewardsをarchived
- shared ticketsをarchived
- 相手側には匿名化した履歴を残す
- UIでは共有停止状態にする

---

### deleteAccount

処理方針：
- Auth削除
- user.deletedAt設定
- displayName匿名化
- iconEmoji匿名化
- 相手側のrecordsでは匿名表示に変更
- groupMemberをleft / deleted扱い

---

## 15. セキュリティルール方針

- ログイン必須
- 自分が所属するgroupのみ読み取り可能
- usersは本人のみ更新可能
- groupは所属メンバーのみ読み取り可能
- requests/rewardsは所属メンバーのみ読み取り可能
- requests/rewards編集は作成者のみ
- balance更新、ticket発行、record作成はCloud Functions経由
- reactionsは相手のcharin recordにのみ作成可能
- ticketsは所属メンバーのみ読み取り可能
- shared ticketは両者が閲覧可能

---

## 16. 初期テンプレート

### 個人のお願い

```json
[
  {
    "title": "マッサージ10分",
    "iconEmoji": "💆",
    "coinAmount": 100,
    "repeatType": "repeat",
    "piggyBankType": "personal"
  },
  {
    "title": "皿洗い",
    "iconEmoji": "🧽",
    "coinAmount": 50,
    "repeatType": "repeat",
    "piggyBankType": "personal"
  },
  {
    "title": "買い出しに行く",
    "iconEmoji": "🛒",
    "coinAmount": 150,
    "repeatType": "repeat",
    "piggyBankType": "personal"
  },
  {
    "title": "デートプランを考える",
    "iconEmoji": "🗓️",
    "coinAmount": 200,
    "repeatType": "repeat",
    "piggyBankType": "personal"
  },
  {
    "title": "相手のお願いを1つ叶える",
    "iconEmoji": "🫶",
    "coinAmount": 150,
    "repeatType": "repeat",
    "piggyBankType": "personal"
  }
]
```

### ふたりのお願い

```json
[
  {
    "title": "ふたりで部屋を片付ける",
    "iconEmoji": "🧹",
    "coinAmount": 200,
    "repeatType": "repeat",
    "piggyBankType": "shared"
  },
  {
    "title": "デート/旅行の予定を決める",
    "iconEmoji": "✈️",
    "coinAmount": 300,
    "repeatType": "repeat",
    "piggyBankType": "shared"
  }
]
```

### 個人ごほうび券

```json
[
  {
    "title": "コンビニスイーツごほうび券",
    "iconEmoji": "🍰",
    "requiredCoins": 300,
    "piggyBankType": "personal"
  },
  {
    "title": "スタバごほうび券",
    "iconEmoji": "☕",
    "requiredCoins": 700,
    "piggyBankType": "personal"
  },
  {
    "title": "好きなご飯リクエスト券",
    "iconEmoji": "🍜",
    "requiredCoins": 1000,
    "piggyBankType": "personal"
  },
  {
    "title": "映画デートごほうび券",
    "iconEmoji": "🎬",
    "requiredCoins": 2000,
    "piggyBankType": "personal"
  },
  {
    "title": "焼肉ごほうび券",
    "iconEmoji": "🍖",
    "requiredCoins": 5000,
    "piggyBankType": "personal"
  }
]
```

### ふたりごほうび券

```json
[
  {
    "title": "焼肉デートごほうび券",
    "iconEmoji": "🍖",
    "requiredCoins": 5000,
    "piggyBankType": "shared"
  },
  {
    "title": "旅行ごほうび券",
    "iconEmoji": "✈️",
    "requiredCoins": 10000,
    "piggyBankType": "shared"
  }
]
```
