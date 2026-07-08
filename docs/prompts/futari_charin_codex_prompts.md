# ふたりちゃりん（仮）Codex実装依頼プロンプト集 v1.0

## 使い方

Codexには、以下の順番で貼る。  
一度に全部貼って「全部実装して」と依頼するより、Phaseごとに進める方が安全。

---

# Prompt 0：全体コンテキスト共有

あなたはiOSアプリ開発に強いシニアエンジニアです。  
SwiftUI + Firebaseで「ふたりちゃりん（仮）」というiPhoneアプリのMVPを実装します。

アプリ概要：

ふたりちゃりんは、カップルで使えるごほうび貯金箱アプリです。  
マッサージ、皿洗い、買い出しなどの「お願い」を実行したら「ちゃりんする」ことでコインが貯まります。  
貯まったコインは、スタバごほうび券、映画デート券、焼肉デート券などの「ごほうび券」と交換できます。

実際のお金や決済は扱いません。  
コインはアプリ内の仮想単位です。

技術スタック：

- iOS
- Swift
- SwiftUI
- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Firebase Cloud Messaging
- Firebase Analytics
- ダークモード対応
- iPhoneのみ
- 日本語UI

まず、実装前に以下を提示してください。

1. ディレクトリ構成
2. 主要Model
3. 主要View
4. ViewModel構成
5. Firebase Service構成
6. Cloud Functions構成
7. Phaseごとの実装計画

まだ実装は開始せず、設計案を提示してください。

---

# Prompt 1：Phase 1 SwiftUI画面モック

Phase 1として、Firebase接続なしでSwiftUI画面モックを実装してください。

目的：

まずUIと画面遷移を確認できる状態にします。  
FirestoreやAuthにはまだ接続しないでください。  
モックデータで動作するようにしてください。

実装する画面：

1. オンボーディング3画面
2. 登録 / ログイン画面
3. プロフィール設定画面
4. テンプレート適用画面
5. 招待画面
6. ホーム画面
7. お願い画面
8. ごほうび画面
9. 持っている券画面
10. きろく画面
11. 設定画面
12. ちゃりん演出画面
13. 交換確認ダイアログ
14. チケット詳細画面

下部タブ：

- ホーム
- お願い
- ごほうび
- きろく

設定はホーム右上の歯車から開きます。

デザイン方針：

- かわいい
- 少しおしゃれ
- ゲームっぽい
- クリーム背景
- コイン系イエロー/オレンジ
- 文字はブラウン系
- ダークモード対応
- アイコンは絵文字

ライトテーマ例：

- Background: #FFF7E8
- Primary: #F6B73C
- Accent: #FF9A5C
- Heart: #F86F8F
- Text: #4A3426
- Card: #FFFFFF

ダークテーマ例：

- Background: #1F1A17
- Card: #2B241F
- Primary: #F6B73C
- Accent: #FF9A5C
- Text: #FFF7E8

オンボーディング文言：

1枚目：

見出し：
「お願いを叶えたら、ちゃりんしよう。」

本文：
「マッサージ、皿洗い、買い出し。ふたりの毎日の“してくれて嬉しい”をコインにできます。」

2枚目：

見出し：
「やさしさが、ちゃりんと貯まる。」

本文：
「お願いをちゃりんすると、貯金箱にコインが入ります。」

3枚目：

見出し：
「貯まったコインで、ごほうび券を交換。」

本文：
「スタバ、映画、焼肉デート。ふたりで決めたごほうびを楽しく使えます。」

ホーム画面：

- 自分の貯金箱
- ふたりの貯金箱
- 横スワイプ切り替え
- 現在コイン
- 目標ごほうび券
- あと何コイン
- 進捗ゲージ
- よく使うお願い3件
- 最近のきろく
- スタンプ
- 招待前は相手招待導線

お願い画面：

上部タブ：

- お願い
- ふたりのお願い

カード表示：

- 絵文字
- 名前
- コイン数
- 繰り返し/1回限り
- ちゃりんするボタン

ちゃりん確認ダイアログ：

「このお願いをちゃりんしますか？」

表示：

- お願い名
- コイン数
- 入る貯金箱
- 目標ごほうび券までの残り

ちゃりん後：

- 全画面演出
- 30秒だけ取り消し可能なトースト

ごほうび画面：

上部タブ：

- ごほうび券
- 持っている券

ごほうび券一覧：

- 目標中
- 交換できる
- すべて

フィルター：

- すべて
- 自分の貯金箱
- ふたりの貯金箱

持っている券：

- 使える券
- 使った券

チケット詳細：

- LINEクーポン風
- かわいいチケット風
- QRコード風飾りは入れない
- 使用済みにするボタン

きろく画面：

- 今月のちゃりん合計
- 日付ごとのタイムライン
- ちゃりん履歴
- ごほうび券交換履歴
- 使用済み履歴

スタンプ：

- 🙏 ありがとう
- ✨ 最高
- 🥹 たすかった
- 🫶 すき
- 👑 神

設定画面：

- プロフィール
- ふたり設定
- 相手情報
- 相手解除
- 招待
- 通知設定
- 音設定
- 表示設定
- ダークモード
- お問い合わせ
- 利用規約
- プライバシーポリシー
- アカウント削除
- ログアウト

このPhaseでは、SwiftUIの画面とモックデータのみを実装してください。  
完了後、次にFirebase接続へ進めるように、ViewModelとServiceは差し替えやすい構造にしてください。

---

# Prompt 2：Phase 2 Firebase Auth + 初期データ

Phase 2として、Firebase Authと初期データ作成を実装してください。

前提：

Phase 1でSwiftUI画面モックは実装済みです。  
ここでは実データ接続を始めます。

実装対象：

1. Firebase Auth連携
2. Appleログイン
3. Googleログイン
4. メール登録 / ログイン
5. users作成
6. プロフィール保存
7. createInitialTemplate Cloud Function
8. group作成
9. groupMember作成
10. personal piggyBank作成
11. shared piggyBank作成
12. initial requests作成
13. initial rewards作成
14. invite作成
15. users.activeGroupId設定

Firestoreコレクション：

- users
- groups
- groupMembers
- piggyBanks
- requests
- rewards
- invites

初期テンプレートはアプリ内ローカル定義を使用してください。

個人のお願い：

- 💆 マッサージ10分 / 100 / repeat / personal
- 🧽 皿洗い / 50 / repeat / personal
- 🛒 買い出しに行く / 150 / repeat / personal
- 🗓️ デートプランを考える / 200 / repeat / personal
- 🫶 相手のお願いを1つ叶える / 150 / repeat / personal

ふたりのお願い：

- 🧹 ふたりで部屋を片付ける / 200 / repeat / shared
- ✈️ デート/旅行の予定を決める / 300 / repeat / shared

個人ごほうび券：

- 🍰 コンビニスイーツごほうび券 / 300 / personal
- ☕ スタバごほうび券 / 700 / personal
- 🍜 好きなご飯リクエスト券 / 1000 / personal
- 🎬 映画デートごほうび券 / 2000 / personal
- 🍖 焼肉ごほうび券 / 5000 / personal

ふたりごほうび券：

- 🍖 焼肉デートごほうび券 / 5000 / shared
- ✈️ 旅行ごほうび券 / 10000 / shared

注意：

- UI上は1グループのみですが、DB上は将来複数グループを持てる設計にしてください。
- テンプレート適用後のデータは本データとして保存してください。
- 招待画面は登録直後に表示します。
- 相手が未招待でも、ホームとテンプレートデータは使えるようにしてください。

---

# Prompt 3：Phase 3 招待機能

Phase 3として、相手招待機能を実装してください。

実装対象：

1. 招待コード生成
2. 招待リンク生成
3. 招待リンクコピー
4. LINE共有
5. 招待コード表示
6. 招待リンク受信処理
7. 招待コード入力処理
8. 招待された側の登録 / ログイン
9. group参加
10. 2人制限チェック
11. 招待済み状態表示
12. 招待後の相手情報画面

仕様：

- グループは2人限定です。
- すでに2人いるグループには参加できません。
- 招待された側はリンクを開き、登録/ログイン後にグループ参加します。
- 招待後、相手にも同じお願い・ごほうび券が使えるようになります。
- requests/rewardsはグループ共通で持ちます。
- personal requestを相手がちゃりんした場合、相手の個人貯金箱に入ります。
- shared requestをちゃりんした場合、ふたりの貯金箱に入ります。

招待画面のUI：

- LINEで送る
- 招待リンクをコピー
- 招待コード表示
- あとで招待する

招待済みの場合：

- 招待画面ではなく相手情報画面を表示
- 相手の名前とアイコンを表示
- 相手解除ボタンを表示

---

# Prompt 4：Phase 4 ホーム + お願い + ちゃりん

Phase 4として、ホーム画面・お願い画面・ちゃりん機能を実装してください。

実装対象：

1. piggyBanks取得
2. 自分の貯金箱表示
3. ふたりの貯金箱表示
4. 横スワイプ切り替え
5. 目標ごほうび券表示
6. 残りコイン計算
7. 進捗ゲージ
8. よく使うお願い3件表示
9. 最近のきろく表示
10. requests一覧取得
11. お願い/ふたりのお願いタブ
12. よく使う順並び替え
13. お願い作成
14. お願い編集
15. 作成者だけ編集可能
16. 非表示処理
17. 1回限り完了後非表示
18. ちゃりん確認ダイアログ
19. charinRequest Cloud Function連携
20. ちゃりん演出
21. 30秒取り消し
22. cancelCharin Cloud Function連携

重要：

- 残高更新はアプリ側で直接行わないでください。
- 必ずCloud FunctionsのTransactionで行ってください。
- recordsもCloud Functions側で作成してください。
- ちゃりん取り消しは30秒以内のみ可能です。
- 取り消し時はrecordを削除せず、status = canceled にしてください。
- canceled recordは画面には表示しません。

charinRequest Function仕様：

入力：

```json
{
  "groupId": "groupId",
  "requestId": "requestId"
}
```

処理：

- 認証チェック
- groupMemberチェック
- request取得
- target piggyBank決定
- Transactionでbalance更新
- request completionCount更新
- oneTimeならrequest.status = hidden
- record作成
- balanceBefore/balanceAfterを返却
- 目標ごほうび券までの残りを返却

cancelCharin Function仕様：

入力：

```json
{
  "recordId": "recordId"
}
```

処理：

- recordがcharinであること
- 本人のrecordであること
- 30秒以内であること
- status activeであること
- Transactionでbalanceを戻す
- record.status = canceled
- request completionCountを戻す
- oneTimeでhiddenになっていた場合はactiveに戻す

---

# Prompt 5：Phase 5 ごほうび券 + チケット + Push通知

Phase 5として、ごほうび券、チケット、交換通知を実装してください。

実装対象：

1. rewards一覧取得
2. 目標中/交換可能/すべて表示
3. 貯金箱フィルター
4. ごほうび券作成
5. ごほうび券編集
6. 作成者だけ編集可能
7. 非表示処理
8. 交換可能判定
9. 交換確認
10. exchangeReward Cloud Function連携
11. チケット発行完了画面
12. FCM通知送信
13. tickets一覧取得
14. 使える券/使った券表示
15. チケット詳細
16. useTicket Cloud Function連携
17. 共同チケット表示

重要：

- ごほうび券編集は作成者のみ可能です。
- 発行済みticketはreward編集の影響を受けないようにしてください。
- exchangeReward時にtitle/icon/spentCoinsなどをticketへコピーしてください。
- 残高不足チェックはCloud FunctionsのTransactionで行ってください。
- 交換時のみ相手へPush通知を送ってください。
- 交換可能になった瞬間の通知は不要です。
- 使用済み通知は不要です。

exchangeReward Function仕様：

入力：

```json
{
  "groupId": "groupId",
  "rewardId": "rewardId",
  "piggyBankId": "piggyBankId"
}
```

処理：

- 認証チェック
- 残高不足チェック
- Transactionでbalanceを減らす
- ticket作成
- record作成
- 相手へPush通知送信

通知文言：

「〇〇が『スタバごほうび券』を交換しました」

useTicket Function仕様：

入力：

```json
{
  "ticketId": "ticketId"
}
```

処理：

- ticket.statusがunusedであること
- usedに更新
- usedAt/usedBy保存
- record作成
- 通知は送らない

---

# Prompt 6：Phase 6 きろく + スタンプ

Phase 6として、きろく画面とスタンプ機能を実装してください。

実装対象：

1. records一覧取得
2. 日付ごとタイムライン
3. 月次ちゃりん合計
4. 自分/相手フィルター
5. 貯金箱フィルター
6. ごほうび券関連詳細遷移
7. canceled record非表示
8. reactions作成
9. reactions更新
10. 自分のrecordには押せない制御
11. ホーム最近のきろくにも反映

きろく表示対象：

- charin
- rewardExchange
- ticketUsed

スタンプ対象：

- 相手のcharin recordのみ

スタンプ種類：

- arigatou: 🙏 ありがとう
- saikou: ✨ 最高
- tasukatta: 🥹 たすかった
- suki: 🫶 すき
- kami: 👑 神

ルール：

- 1 record に対して 1 user 1 reaction
- 押し直し可能
- 自分のrecordには押せない
- rewardExchange / ticketUsed には押せない
- スタンプ通知は送らない

---

# Prompt 7：Phase 7 設定 + アカウント削除 + ダークモード

Phase 7として、設定画面、相手解除、アカウント削除、ダークモードを実装してください。

実装対象：

1. 設定トップ
2. プロフィール編集
3. カップル名編集
4. 通知設定
5. FCM token保存
6. 音設定
7. テーマ設定
8. 相手情報画面
9. 相手解除
10. アカウント削除
11. ログアウト
12. 利用規約リンク
13. プライバシーポリシーリンク
14. 問い合わせフォームリンク

通知設定：

- ごほうび券交換通知 ON/OFF

音設定：

- ちゃりん音 ON/OFF
- 初期OFF

表示設定：

- 端末設定に合わせる
- ライト
- ダーク

相手解除：

- groupをarchived
- shared piggyBankをarchived
- shared rewardsをarchived
- shared ticketsをarchived
- 相手側には匿名化した履歴を残す
- UIでは共有停止状態にする

アカウント削除：

- Auth削除
- user.deletedAt設定
- displayName匿名化
- iconEmoji匿名化
- 相手側recordsでは匿名表示に変更
- groupMemberをleft/deleted扱い

---

# Prompt 8：Phase 8 Analytics + TestFlight準備

Phase 8として、AnalyticsとTestFlight準備を実装してください。

Analyticsイベント：

- sign_up_completed
- template_applied
- invite_screen_viewed
- invite_sent
- invite_joined
- charin_completed
- charin_canceled
- reward_exchanged
- ticket_used
- reaction_added
- day_1_retention
- day_7_retention

TestFlight準備：

- App icon作成
- Launch screen確認
- Privacy Manifest確認
- Firebase設定本番/開発分離
- TestFlightビルド
- 身内テスト
- クラッシュ確認
- Analytics確認
- Push通知確認
- ダークモード確認
- アカウント削除確認

完了後、TestFlightで自分たちが使える状態にしてください。
