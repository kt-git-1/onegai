import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  BatteryMedium,
  Check,
  ChevronRight,
  CircleUserRound,
  Clock3,
  Coffee,
  Copy,
  Gift,
  Heart,
  Home,
  ListChecks,
  LoaderCircle,
  Mail,
  Plus,
  RotateCcw,
  Settings,
  Share2,
  Sparkles,
  Ticket,
  Users,
  Wifi,
} from "lucide-react";

const mascot = "/assets/piggy-bank.png";

const screenGroups = [
  {
    label: "初回導線",
    items: [
      ["onboarding1", "オンボーディング 1"],
      ["onboarding2", "オンボーディング 2"],
      ["onboarding3", "オンボーディング 3"],
      ["auth", "登録 / ログイン"],
      ["email", "メール登録"],
      ["profile", "プロフィール設定"],
      ["template", "テンプレート適用"],
      ["invite", "招待"],
      ["inviteWait", "招待待ち"],
      ["inviteJoin", "招待参加"],
    ],
  },
  {
    label: "本体",
    items: [
      ["homeOwn", "ホーム：自分"],
      ["homeShared", "ホーム：ふたり"],
      ["requests", "お願い"],
      ["charinConfirm", "ちゃりん確認"],
      ["charinResult", "ちゃりん演出"],
      ["rewards", "ごほうび券"],
      ["tickets", "持っている券"],
      ["records", "きろく"],
    ],
  },
];

const requests = [
  { icon: "💆", title: "マッサージ10分", coins: 100, note: "繰り返し" },
  { icon: "🧽", title: "皿洗い", coins: 50, note: "繰り返し" },
  { icon: "🛒", title: "買い出しに行く", coins: 100, note: "1回限り" },
  { icon: "🍽️", title: "デートプランを考える", coins: 200, note: "繰り返し" },
];

const sharedRequests = [
  { icon: "🧹", title: "ふたりで部屋を片付ける", coins: 200, note: "繰り返し" },
  { icon: "🗓️", title: "デートの予定を決める", coins: 300, note: "繰り返し" },
];

const rewards = [
  { icon: "☕", title: "スタバごほうび券", cost: 700, balance: 520, bank: "自分" },
  { icon: "🍖", title: "焼肉デートごほうび券", cost: 5000, balance: 2800, bank: "ふたり" },
  { icon: "✈️", title: "旅行ごほうび券", cost: 10000, balance: 2800, bank: "ふたり" },
];

function StatusBar() {
  return (
    <div className="status-bar" aria-hidden="true">
      <span>9:41</span>
      <div><Wifi size={13} /><BatteryMedium size={16} /></div>
    </div>
  );
}

function Mascot({ size = "medium", panel = false }) {
  return (
    <div className={panel ? "mascot-panel" : "mascot-free"}>
      <img className={`mascot mascot-${size}`} src={mascot} alt="おねがいチャリンの貯金箱キャラクター" />
    </div>
  );
}

function PrimaryButton({ children, onClick, disabled = false, loading = false, className = "" }) {
  return (
    <button className={`button button-primary ${className}`} onClick={onClick} disabled={disabled || loading}>
      <span>{children}</span>{loading && <LoaderCircle className="spin" size={17} />}
    </button>
  );
}

function SecondaryButton({ children, onClick, icon: Icon, className = "" }) {
  return (
    <button className={`button button-secondary ${className}`} onClick={onClick}>
      {Icon && <Icon size={17} />}<span>{children}</span>
    </button>
  );
}

function AppHeader({ title = "おねがいチャリン", onSettings, right }) {
  return (
    <header className="app-header">
      <h1>{title}</h1>
      {right || <button className="icon-button" onClick={onSettings} aria-label="設定"><Settings size={20} /></button>}
    </header>
  );
}

function BottomTabs({ active, go }) {
  const tabs = [
    ["home", "ホーム", Home, "homeOwn"],
    ["requests", "お願い", Heart, "requests"],
    ["rewards", "ごほうび", Gift, "rewards"],
    ["records", "きろく", ListChecks, "records"],
  ];
  return (
    <nav className="bottom-tabs">
      {tabs.map(([id, label, Icon, target]) => (
        <button key={id} className={active === id ? "active" : ""} onClick={() => go(target)}>
          <Icon size={20} /><span>{label}</span>
        </button>
      ))}
    </nav>
  );
}

function Segmented({ items, value, onChange }) {
  return (
    <div className="segmented">
      {items.map((item) => <button key={item} className={value === item ? "selected" : ""} onClick={() => onChange(item)}>{item}</button>)}
    </div>
  );
}

function Onboarding({ page, go }) {
  const content = [
    ["お願いを叶えたら、\nちゃりんしよう。", "マッサージ、皿洗い、買い出し。\nふたりの毎日の“してくれて嬉しい”を\nコインにできます。"],
    ["やさしさが、\nちゃりんと貯まる。", "お願いをちゃりんすると、\n貯金箱にコインが入ります。"],
    ["貯まったコインで、\nごほうび券を交換。", "スタバ、映画、焼肉デート。\nふたりで決めたごほうびを\n楽しく使えます。"],
  ][page - 1];
  return (
    <div className="screen onboarding-screen">
      <div className="page-count">{page} / 3</div>
      <Mascot size="large" panel />
      <div className="onboarding-copy">
        <h2>{content[0].split("\n").map((line) => <span key={line}>{line}</span>)}</h2>
        <p>{content[1].split("\n").map((line) => <span key={line}>{line}</span>)}</p>
      </div>
      <PrimaryButton className="bottom-cta" onClick={() => go(page < 3 ? `onboarding${page + 1}` : "auth")}>
        {page < 3 ? "次へ" : "はじめる"}
      </PrimaryButton>
    </div>
  );
}

function Auth({ go }) {
  return (
    <div className="screen auth-screen">
      <div className="brand-block">
        <Mascot size="auth" />
        <h2>おねがいチャリン</h2>
        <p>やさしさが、ちゃりんと貯まる。</p>
      </div>
      <div className="auth-actions">
        <SecondaryButton>Appleで続ける</SecondaryButton>
        <SecondaryButton>Googleで続ける</SecondaryButton>
        <PrimaryButton onClick={() => go("email")}>メールで登録</PrimaryButton>
        <button className="text-button">すでにアカウントをお持ちの方はログイン</button>
        <p className="legal">利用規約 ・ プライバシーポリシー</p>
      </div>
    </div>
  );
}

function PageTitle({ title, subtitle, back }) {
  return (
    <div className="page-title">
      {back && <button className="icon-button back" onClick={back} aria-label="戻る"><ArrowLeft size={20} /></button>}
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
    </div>
  );
}

function EmailRegistration({ go }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const valid = email.includes("@") && password.length >= 8 && password === confirm;
  return (
    <div className="screen form-screen">
      <PageTitle title="メールで登録" subtitle="メールアドレスとパスワードを入力してください。" back={() => go("auth")} />
      <div className="form-stack">
        <label>メールアドレス<input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="name@example.com" /></label>
        <label>パスワード<input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="8文字以上" /></label>
        <label>パスワード確認<input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="もう一度入力" /></label>
        {submitted && !valid && <p className="form-error">入力内容を確認してください。</p>}
        <p className="form-note">登録すると、利用規約とプライバシーポリシーに同意したことになります。</p>
      </div>
      <PrimaryButton className="bottom-cta" disabled={!valid} onClick={() => { setSubmitted(true); if (valid) go("profile"); }}>登録する</PrimaryButton>
    </div>
  );
}

function Profile({ go }) {
  const [name, setName] = useState("");
  const [emoji, setEmoji] = useState("");
  return (
    <div className="screen form-screen">
      <PageTitle title="プロフィールを設定しよう" subtitle="相手に表示される名前とアイコンです。" />
      <div className="profile-picker">
        <div className="avatar-preview">{emoji || <CircleUserRound size={48} />}</div>
        <p>{emoji ? "選択済み" : "未選択でも進めます"}</p>
        <div className="emoji-options">
          {["😊", "🌷", "☕", "🍀", "🌙"].map((item) => <button key={item} className={emoji === item ? "selected" : ""} onClick={() => setEmoji(emoji === item ? "" : item)}>{item}</button>)}
        </div>
      </div>
      <label className="single-field">名前<input value={name} onChange={(e) => setName(e.target.value)} placeholder="例：花男" /></label>
      <PrimaryButton className="bottom-cta" disabled={!name.trim()} onClick={() => go("template")}>保存して次へ</PrimaryButton>
    </div>
  );
}

function Template({ go }) {
  return (
    <div className="screen content-screen">
      <PageTitle title="まずはテンプレートで始めよう" subtitle="カップル向けのお願いとごほうび券を用意しました。" />
      <div className="card template-card">
        <TemplateSection title="お願い" items={["💆 マッサージ10分", "🧽 皿洗い"]} />
        <TemplateSection title="ふたりのお願い" items={["🧹 ふたりで部屋を片付ける"]} />
        <TemplateSection title="ごほうび券" items={["🍰 コンビニスイーツごほうび券", "☕ スタバごほうび券"]} />
      </div>
      <PrimaryButton className="bottom-cta" onClick={() => go("invite")}>カップル向けテンプレートを使う</PrimaryButton>
    </div>
  );
}

function TemplateSection({ title, items }) {
  return <section><h3>{title}</h3>{items.map((item) => <p key={item}>{item}</p>)}</section>;
}

function Invite({ go }) {
  return (
    <div className="screen content-screen">
      <PageTitle title="相手を招待しよう" subtitle="ふたりで使うために、招待リンクを送ります。" />
      <div className="card invite-code-card"><span>招待コード</span><strong>ABCD-1234</strong><SecondaryButton icon={Copy}>コードをコピー</SecondaryButton></div>
      <div className="bottom-actions">
        <PrimaryButton onClick={() => go("inviteWait")}>LINEで送る</PrimaryButton>
        <SecondaryButton icon={Share2} onClick={() => go("inviteWait")}>招待リンクをコピー</SecondaryButton>
      </div>
    </div>
  );
}

function InviteWait({ go, expired, setExpired }) {
  return (
    <div className="screen invite-wait-screen">
      <Mascot size="large" panel />
      <div className="center-copy"><h2>{expired ? "招待の期限が切れました" : "相手の参加を待っています"}</h2><p>{expired ? "新しい招待を発行して、もう一度送れます。" : "相手が参加すると、ふたりの貯金箱を始められます。"}</p></div>
      <div className="card invite-code-card"><span>招待コード</span><strong>{expired ? "期限切れ" : "ABCD-1234"}</strong></div>
      <div className="bottom-actions">
        {expired ? <PrimaryButton onClick={() => setExpired(false)}>新しい招待を発行する</PrimaryButton> : <><PrimaryButton>LINEで再送する</PrimaryButton><SecondaryButton icon={Copy}>招待リンクをコピー</SecondaryButton></>}
        <button className="text-button" onClick={() => go("auth")}>ログアウト</button>
      </div>
    </div>
  );
}

function InviteJoin({ go }) {
  return (
    <div className="screen invite-wait-screen">
      <Mascot size="large" panel />
      <div className="center-copy"><h2>おねがいチャリンに<br />招待されました</h2><p>花男さんからの招待です。参加すると、ふたりの貯金箱を一緒に使えます。</p></div>
      <PrimaryButton className="bottom-cta" onClick={() => go("homeOwn")}>参加する</PrimaryButton>
    </div>
  );
}

function BankCard({ shared = false, targetState = "normal", go }) {
  const balance = shared ? 2800 : 520;
  const target = shared ? "焼肉デートごほうび券" : "スタバごほうび券";
  const cost = shared ? 5000 : 700;
  const progress = Math.min(100, Math.round((balance / cost) * 100));
  if (targetState === "none") {
    return (
      <div className="card bank-card bank-empty">
        <Mascot size="small" />
        <h2>{balance.toLocaleString()}コイン</h2>
        <p>目標のごほうび券を選ぼう</p>
        <SecondaryButton icon={Gift} onClick={() => go("rewards")}>ごほうび券を選ぶ</SecondaryButton>
      </div>
    );
  }
  return (
    <div className="card bank-card">
      <Mascot size="small" />
      <h2>{balance.toLocaleString()}コイン</h2>
      <p>目標：{shared ? "🍖" : "☕"} {target}</p>
      {targetState === "exchange" ? <strong className="exchange-label">交換できます</strong> : <strong className="remaining">あと{(cost - balance).toLocaleString()}コイン</strong>}
      <div className="progress"><span style={{ width: `${targetState === "exchange" ? 100 : progress}%` }} /></div>
      {targetState === "exchange" && <PrimaryButton onClick={() => go("rewards")}>交換する</PrimaryButton>}
    </div>
  );
}

function HomeScreen({ shared, go, targetState, undoVisible, setUndoVisible }) {
  const list = shared ? sharedRequests : requests.slice(0, 2);
  return (
    <div className="screen app-screen">
      <AppHeader />
      <Segmented items={["自分", "ふたり"]} value={shared ? "ふたり" : "自分"} onChange={(value) => go(value === "自分" ? "homeOwn" : "homeShared")} />
      <div className="screen-scroll">
        <BankCard shared={shared} targetState={targetState} go={go} />
        <section className="section-block"><h3>{shared ? "ふたりのお願い" : "よく使うお願い"}</h3><div className="card rows-card">{list.map((item) => <RequestRow key={item.title} item={item} compact onCharin={() => go("charinConfirm")} />)}</div></section>
        <section className="section-block"><h3>{shared ? "最近のふたりのきろく" : "最近のきろく"}</h3><div className="card recent-row"><span>{list[0].icon}</span><div><strong>{list[0].title}</strong><small>今日 20:12</small></div><b>+{list[0].coins}</b></div></section>
      </div>
      {undoVisible && <div className="undo-toast"><span>ちゃりんしました</span><button onClick={() => setUndoVisible(false)}>取り消す</button></div>}
      <BottomTabs active="home" go={go} />
    </div>
  );
}

function RequestRow({ item, compact = false, onCharin, onSelect }) {
  return (
    <div className={`request-row ${compact ? "compact" : ""}`} onClick={onSelect}>
      <span className="content-emoji">{item.icon}</span>
      <div><strong>{item.title}</strong><small>+{item.coins}コイン・{item.note}</small></div>
      <button className="mini-primary" onClick={(e) => { e.stopPropagation(); onCharin?.(); }}>ちゃりん</button>
    </div>
  );
}

function RequestsScreen({ go }) {
  const [tab, setTab] = useState("お願い");
  const [selected, setSelected] = useState(null);
  const list = tab === "お願い" ? requests : sharedRequests;
  return (
    <div className="screen app-screen">
      <AppHeader title="お願い" right={<button className="icon-button" aria-label="お願いを追加"><Plus size={21} /></button>} />
      <Segmented items={["お願い", "ふたりのお願い"]} value={tab} onChange={setTab} />
      <div className="screen-scroll request-list"><p className="sort-note">よく使う順</p>{list.map((item) => <div className="card" key={item.title}><RequestRow item={item} onCharin={() => go("charinConfirm")} onSelect={() => setSelected(item.title)} />{selected === item.title && <button className="edit-action">作成者のみ編集できます <ChevronRight size={16} /></button>}</div>)}</div>
      <BottomTabs active="requests" go={go} />
    </div>
  );
}

function CharinConfirm({ go }) {
  return (
    <div className="screen modal-screen">
      <div className="modal-backdrop"><div className="modal-card">
        <h2>このお願いを<br />ちゃりんしますか？</h2>
        <div className="confirm-target"><span>💆</span><div><strong>マッサージ10分</strong><b>+100コイン</b></div></div>
        <p>花男の貯金箱に入ります</p>
        <div className="goal-note"><small>あと80コインで</small><strong>☕ スタバごほうび券</strong></div>
        <div className="modal-actions"><SecondaryButton onClick={() => go("requests")}>キャンセル</SecondaryButton><PrimaryButton onClick={() => go("charinResult")}>ちゃりんする</PrimaryButton></div>
      </div></div>
    </div>
  );
}

function CharinResult({ go, setUndoVisible }) {
  useEffect(() => {
    const timer = window.setTimeout(() => {
      setUndoVisible(true);
      go("homeOwn");
    }, 1800);
    return () => window.clearTimeout(timer);
  }, [go, setUndoVisible]);
  return (
    <div className="screen charin-result-screen">
      <Mascot size="result" />
      <div className="charin-copy"><h2>ちゃりん！</h2><strong>+100コイン</strong><b>520 → 620</b><p>あと80コインで<br />スタバごほうび券</p></div>
      <div className="undo-toast"><span>ちゃりんしました</span><button onClick={() => go("homeOwn")}>取り消す</button></div>
    </div>
  );
}

function RewardCard({ item }) {
  const remaining = Math.max(0, item.cost - item.balance);
  const progress = Math.min(100, Math.round((item.balance / item.cost) * 100));
  return (
    <div className="card reward-card">
      <div className="reward-title"><span className="content-emoji">{item.icon}</span><div><strong>{item.title}</strong><small>{item.cost.toLocaleString()}コイン・{item.bank}</small></div></div>
      <div className="progress"><span style={{ width: `${progress}%` }} /></div>
      <div className="reward-footer"><span>{remaining ? `あと${remaining.toLocaleString()}コイン` : "交換できます"}</span>{!remaining && <PrimaryButton>交換する</PrimaryButton>}</div>
    </div>
  );
}

function RewardsScreen({ go }) {
  const [category, setCategory] = useState("すべて");
  return (
    <div className="screen app-screen">
      <AppHeader title="ごほうび" right={<button className="icon-button"><Plus size={21} /></button>} />
      <Segmented items={["ごほうび券", "持っている券"]} value="ごほうび券" onChange={(v) => v === "持っている券" && go("tickets")} />
      <div className="filter-chips">{["目標中", "交換できる", "すべて"].map((v) => <button key={v} className={category === v ? "active" : ""} onClick={() => setCategory(v)}>{v}</button>)}</div>
      <div className="filter-chips subtle"><button className="active">すべて</button><button>自分</button><button>ふたり</button></div>
      <div className="screen-scroll reward-list">{rewards.filter((item) => category === "すべて" || category === "目標中").map((item) => <RewardCard key={item.title} item={item} />)}</div>
      <BottomTabs active="rewards" go={go} />
    </div>
  );
}

function TicketsScreen({ go }) {
  return (
    <div className="screen app-screen">
      <AppHeader title="ごほうび" right={<button className="icon-button"><Plus size={21} /></button>} />
      <Segmented items={["ごほうび券", "持っている券"]} value="持っている券" onChange={(v) => v === "ごほうび券" && go("rewards")} />
      <div className="filter-chips"><button className="active">使える券</button><button>使った券</button></div>
      <div className="screen-scroll reward-list">
        {[rewards[0], rewards[1]].map((item, index) => <div className="card ticket-row" key={item.title}><span className="content-emoji">{item.icon}</span><div><strong>{item.title}</strong><small>{index ? "2026/08/18まで" : "期限なし"}</small></div><SecondaryButton icon={Ticket}>券を表示</SecondaryButton></div>)}
      </div>
      <BottomTabs active="rewards" go={go} />
    </div>
  );
}

function RecordsScreen({ go }) {
  const [stampFor, setStampFor] = useState(null);
  const records = [
    { icon: "💆", title: "マッサージ10分", by: "相手がちゃりん", amount: "+100", time: "20:12", stamp: true },
    { icon: "☕", title: "スタバごほうび券", by: "あなたが交換", amount: "-700", time: "18:40" },
    { icon: "🧽", title: "皿洗い", by: "あなたがちゃりん", amount: "+50", time: "12:05" },
  ];
  return (
    <div className="screen app-screen">
      <AppHeader title="きろく" right={<button className="icon-button"><Plus size={21} /></button>} />
      <div className="card monthly-summary"><span>今月のちゃりん</span><strong>1,850コイン</strong></div>
      <div className="filter-chips"><button className="active">すべて</button><button>自分</button><button>相手</button></div>
      <div className="screen-scroll timeline"><h3>今日</h3><div className="card">{records.map((record) => <div className="record-row" key={record.title}><span className="content-emoji">{record.icon}</span><div><strong>{record.title}</strong><small>{record.by}・{record.time}</small></div><b className={record.amount.startsWith("+") ? "positive" : "negative"}>{record.amount}</b>{record.stamp && <button className="stamp-button" onClick={() => setStampFor(stampFor ? null : record.title)}><Sparkles size={17} /></button>}{stampFor === record.title && <div className="stamp-popover">{["👏", "🥰", "✨", "💛", "🙌"].map((s) => <button key={s} onClick={() => setStampFor(null)}>{s}</button>)}</div>}</div>)}</div></div>
      <BottomTabs active="records" go={go} />
    </div>
  );
}

function ScreenRenderer({ screen, go, inviteExpired, setInviteExpired, targetState, setTargetState, undoVisible, setUndoVisible }) {
  if (screen.startsWith("onboarding")) return <Onboarding page={Number(screen.at(-1))} go={go} />;
  const screens = {
    auth: <Auth go={go} />,
    email: <EmailRegistration go={go} />,
    profile: <Profile go={go} />,
    template: <Template go={go} />,
    invite: <Invite go={go} />,
    inviteWait: <InviteWait go={go} expired={inviteExpired} setExpired={setInviteExpired} />,
    inviteJoin: <InviteJoin go={go} />,
    homeOwn: <HomeScreen go={go} targetState={targetState} undoVisible={undoVisible} setUndoVisible={setUndoVisible} />,
    homeShared: <HomeScreen shared go={go} targetState={targetState} undoVisible={undoVisible} setUndoVisible={setUndoVisible} />,
    requests: <RequestsScreen go={go} />,
    charinConfirm: <CharinConfirm go={go} />,
    charinResult: <CharinResult go={go} setUndoVisible={setUndoVisible} />,
    rewards: <RewardsScreen go={go} />,
    tickets: <TicketsScreen go={go} />,
    records: <RecordsScreen go={go} />,
  };
  return screens[screen] || screens.homeOwn;
}

export function App() {
  const params = useMemo(() => new URLSearchParams(window.location.search), []);
  const [screen, setScreen] = useState(params.get("screen") || "onboarding1");
  const [inviteExpired, setInviteExpired] = useState(false);
  const [targetState, setTargetState] = useState("normal");
  const [undoVisible, setUndoVisible] = useState(false);
  const go = (next) => { setScreen(next); window.history.replaceState({}, "", `?screen=${next}`); };
  return (
    <main className="prototype-stage">
      <aside className="review-rail">
        <div className="review-brand"><img src={mascot} alt="" /><div><strong>Priority 1</strong><span>高精細プレビュー</span></div></div>
        {screenGroups.map((group) => <section key={group.label}><h2>{group.label}</h2>{group.items.map(([id, label]) => <button key={id} className={screen === id ? "active" : ""} onClick={() => go(id)}><span>{label}</span><ChevronRight size={15} /></button>)}</section>)}
        {screen === "inviteWait" && <button className="rail-state" onClick={() => setInviteExpired(!inviteExpired)}><Clock3 size={15} />{inviteExpired ? "待機中に戻す" : "期限切れを表示"}</button>}
        {(screen === "homeOwn" || screen === "homeShared") && <div className="rail-home-states"><span>ホーム状態</span>{[["normal", "通常"], ["none", "目標なし"], ["exchange", "交換可能"]].map(([state, label]) => <button key={state} className={targetState === state ? "active" : ""} onClick={() => setTargetState(state)}>{label}</button>)}</div>}
      </aside>
      <section className="phone-wrap">
        <div className="mobile-prototype">
          <StatusBar />
          <ScreenRenderer screen={screen} go={go} inviteExpired={inviteExpired} setInviteExpired={setInviteExpired} targetState={targetState} setTargetState={setTargetState} undoVisible={undoVisible} setUndoVisible={setUndoVisible} />
        </div>
      </section>
    </main>
  );
}
