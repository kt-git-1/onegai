# おねがいチャリン開発タスク一覧 v1.0

## Phase 0：プロジェクト準備

- [x] Xcodeプロジェクト作成
- [x] SwiftUI構成作成
- [x] Firebaseプロジェクト作成
- [x] Firebase Auth有効化
- [x] Firestore有効化
- [x] Cloud Functions環境作成
- [ ] FCM設定
- [x] Analytics設定
- [x] iOS bundle id設定
- [x] Apple Sign In設定
- [x] Google Sign In設定
- [ ] ダークモード対応用Color Assets作成
- [ ] SwiftLint導入検討

開発環境メモ：
- Firebase開発プロジェクト：`onegai-charin-dev`
- Firestore / Functionsリージョン：`asia-northeast1`
- メール / パスワード認証：有効
- Google認証：有効。サポートメールは `taniguchidev33@gmail.com`
- Apple認証：有効。Developer Team IDは `QSZR732YXD`、Sign in with Apple capability設定済み
- Functions：Emulator統合テスト済み。課金しない方針のためクラウドデプロイは対象外
- 課金は行わず、開発中はAuth / Firestore / Functions Emulatorを使用する
- TestFlight以降のFunctions相当処理は、無料枠で運用できる構成を実装前に決定する

---

## Phase 1：SwiftUI画面モック

Firebase接続前に、まず画面を作る。

- [x] 共通テーマ作成
- [x] 下部タブ作成
- [x] オンボーディング3画面
- [x] 登録画面
- [x] プロフィール設定画面
- [x] テンプレート適用画面
- [x] 招待画面
- [x] ホーム画面
- [x] 貯金箱カード
- [ ] 横スワイプ貯金箱
- [x] お願いカード
- [x] ちゃりん確認ダイアログ
- [x] ちゃりん演出画面
- [ ] ごほうび券カード
- [ ] 交換確認ダイアログ
- [ ] 発行完了画面
- [ ] チケット詳細
- [ ] きろくタイムライン
- [ ] スタンプUI
- [ ] 設定画面
- [ ] ダークモード表示確認

---

## Phase 2：認証・初期化

- [x] Firebase Auth連携
- [x] Appleログイン
- [x] Googleログイン
- [x] メール登録
- [x] メールログイン
- [x] パスワード再設定メール
- [x] ログイン後の状態復元と画面振り分け
- [x] users作成
- [x] プロフィール保存
- [x] createInitialTemplate実装
- [x] group作成
- [x] groupMember作成
- [x] piggyBanks作成
- [x] requests作成
- [x] rewards作成
- [x] invite作成
- [x] activeGroupId設定

---

## Phase 3：招待

- [x] 招待コード生成
- [x] 招待リンク生成
- [x] Universal Link / Associated Domains / AASA設定
- [x] アプリ未インストール時の招待案内ページ
- [x] LINE共有（OS共有シート）
- [x] リンク受信処理
- [x] 招待コード入力処理
- [x] 招待内容の認証前プレビュー
- [x] 登録/ログイン・プロフィール設定中の招待情報保持
- [x] 招待された側の登録/ログイン
- [x] 招待された側のプロフィール未設定フロー
- [x] 招待された側のテンプレート・招待作成スキップ
- [x] group参加
- [x] 2人制限チェック
- [x] 招待待ち状態表示
- [x] 相手参加のリアルタイム検知とホーム自動遷移
- [ ] 招待後の相手情報表示
- [x] 招待期限切れ表示
- [x] 招待待ち画面内での再発行
- [x] 再発行時に既存active inviteを無効化

---

## Phase 4：ホーム

- [x] piggyBanks取得
- [x] 自分の貯金箱表示
- [x] ふたりの貯金箱表示
- [x] 横スワイプ
- [x] 目標ごほうび券表示
- [x] 目標未設定時のごほうび券選択CTA
- [x] 残りコイン計算
- [x] 進捗ゲージ
- [x] よく使うお願い3件表示
- [x] 最近のきろく表示
- [ ] スタンプ表示
- [ ] 交換可能状態表示
- [ ] 招待前導線表示

---

## Phase 5：お願い

- [x] requests一覧取得
- [x] お願い/ふたりのお願いタブ
- [x] よく使う順並び替え
- [x] お願い作成
- [x] お願い編集
- [x] 作成者だけ編集可能
- [x] 非表示処理
- [x] 1回限り完了後非表示
- [x] ちゃりん確認ダイアログ
- [x] charinRequest Function連携
- [x] ちゃりん演出
- [x] 30秒取り消し
- [x] ホーム遷移後の取り消しトースト継続
- [x] cancelCharin Function連携

---

## Phase 6：ごほうび券

- [ ] rewards一覧取得
- [ ] 目標中/交換可能/すべて表示
- [ ] 貯金箱フィルター
- [ ] ごほうび券作成
- [ ] ごほうび券編集
- [ ] 作成者だけ編集可能
- [ ] 非表示処理
- [ ] 交換可能判定
- [ ] 交換確認
- [ ] exchangeReward Function連携
- [ ] チケット発行完了画面
- [ ] FCM通知送信
- [ ] tickets一覧取得
- [ ] 使える券/使った券表示
- [ ] チケット詳細
- [ ] useTicket Function連携
- [ ] 共同チケット表示

---

## Phase 7：きろく・スタンプ

- [ ] records一覧取得
- [ ] 日付ごとタイムライン
- [ ] 月次ちゃりん合計
- [ ] 自分/相手フィルター
- [ ] 貯金箱フィルター
- [ ] ごほうび券関連詳細遷移
- [ ] canceled record非表示
- [ ] reactions作成
- [ ] reactions更新
- [ ] 自分のrecordには押せない制御
- [ ] ホーム最近のきろくにも反映

---

## Phase 8：設定

- [ ] 設定トップ
- [ ] プロフィール編集
- [ ] カップル名編集
- [ ] 通知設定
- [ ] FCM token保存
- [ ] 音設定
- [ ] テーマ設定
- [ ] 相手情報画面
- [ ] 相手解除
- [ ] アカウント削除
- [ ] ログアウト
- [ ] 利用規約リンク
- [ ] プライバシーポリシーリンク
- [ ] 問い合わせフォームリンク

---

## Phase 9：Analytics

- [ ] sign_up_completed
- [ ] template_applied
- [ ] invite_screen_viewed
- [ ] invite_sent
- [ ] invite_joined
- [ ] charin_completed
- [ ] charin_canceled
- [ ] reward_exchanged
- [ ] ticket_used
- [ ] reaction_added
- [ ] day_1_retention
- [ ] day_7_retention

---

## Phase 10：TestFlight準備

- [ ] App icon作成
- [ ] Launch screen
- [ ] Privacy Manifest確認
- [ ] Firebase設定本番/開発分離
- [ ] TestFlightビルド
- [ ] 身内テスト
- [ ] クラッシュ確認
- [ ] Analytics確認
- [ ] Push通知確認
- [ ] ダークモード確認
- [ ] アカウント削除確認

---

## 推奨実装順

1. SwiftUI画面モック
2. Firebase Auth
3. 初期テンプレート作成
4. ホーム
5. お願い
6. ちゃりん
7. ごほうび券
8. きろく
9. スタンプ
10. 設定
11. Push通知
12. TestFlight
