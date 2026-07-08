# ふたりちゃりん（仮）開発タスク一覧 v1.0

## Phase 0：プロジェクト準備

- [ ] Xcodeプロジェクト作成
- [ ] SwiftUI構成作成
- [ ] Firebaseプロジェクト作成
- [ ] Firebase Auth有効化
- [ ] Firestore有効化
- [ ] Cloud Functions環境作成
- [ ] FCM設定
- [ ] Analytics設定
- [ ] iOS bundle id設定
- [ ] Apple Sign In設定
- [ ] Google Sign In設定
- [ ] ダークモード対応用Color Assets作成
- [ ] SwiftLint導入検討

---

## Phase 1：SwiftUI画面モック

Firebase接続前に、まず画面を作る。

- [ ] 共通テーマ作成
- [ ] 下部タブ作成
- [ ] オンボーディング3画面
- [ ] 登録画面
- [ ] プロフィール設定画面
- [ ] テンプレート適用画面
- [ ] 招待画面
- [ ] ホーム画面
- [ ] 貯金箱カード
- [ ] 横スワイプ貯金箱
- [ ] お願いカード
- [ ] ちゃりん確認ダイアログ
- [ ] ちゃりん演出画面
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

- [ ] Firebase Auth連携
- [ ] Appleログイン
- [ ] Googleログイン
- [ ] メール登録
- [ ] users作成
- [ ] プロフィール保存
- [ ] createInitialTemplate実装
- [ ] group作成
- [ ] groupMember作成
- [ ] piggyBanks作成
- [ ] requests作成
- [ ] rewards作成
- [ ] invite作成
- [ ] activeGroupId設定

---

## Phase 3：招待

- [ ] 招待コード生成
- [ ] 招待リンク生成
- [ ] LINE共有
- [ ] リンク受信処理
- [ ] 招待コード入力処理
- [ ] 招待された側の登録/ログイン
- [ ] group参加
- [ ] 2人制限チェック
- [ ] 招待済み状態表示
- [ ] 招待後の相手情報表示

---

## Phase 4：ホーム

- [ ] piggyBanks取得
- [ ] 自分の貯金箱表示
- [ ] ふたりの貯金箱表示
- [ ] 横スワイプ
- [ ] 目標ごほうび券表示
- [ ] 残りコイン計算
- [ ] 進捗ゲージ
- [ ] よく使うお願い3件表示
- [ ] 最近のきろく表示
- [ ] スタンプ表示
- [ ] 交換可能状態表示
- [ ] 招待前導線表示

---

## Phase 5：お願い

- [ ] requests一覧取得
- [ ] お願い/ふたりのお願いタブ
- [ ] よく使う順並び替え
- [ ] お願い作成
- [ ] お願い編集
- [ ] 作成者だけ編集可能
- [ ] 非表示処理
- [ ] 1回限り完了後非表示
- [ ] ちゃりん確認ダイアログ
- [ ] charinRequest Function連携
- [ ] ちゃりん演出
- [ ] 30秒取り消し
- [ ] cancelCharin Function連携

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
