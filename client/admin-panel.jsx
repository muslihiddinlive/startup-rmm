import { useState, useEffect, useCallback, useRef } from "react";

const ACCENT = "var(--fill-accent)";

function Badge({ color, children }) {
  const map = {
    red:    { bg: "var(--bg-danger)",  text: "var(--text-danger)"  },
    green:  { bg: "var(--bg-success)", text: "var(--text-success)" },
    amber:  { bg: "var(--bg-warning)", text: "var(--text-warning)" },
    blue:   { bg: "var(--bg-accent)",  text: "var(--text-accent)"  },
    purple: { bg: "var(--bg-pro)",     text: "var(--text-pro)"     },
  };
  const s = map[color] || map.blue;
  return (
    <span style={{
      background: s.bg, color: s.text,
      fontSize: 11, fontWeight: 500, padding: "2px 7px",
      borderRadius: 99, whiteSpace: "nowrap"
    }}>{children}</span>
  );
}

function Btn({ label, icon, variant = "default", onClick, full, sm }) {
  const variants = {
    default: { bg: "var(--surface-2)",    border: "0.5px solid var(--border-strong)",  color: "var(--text-primary)" },
    danger:  { bg: "var(--bg-danger)",     border: "0.5px solid var(--border-danger)",  color: "var(--text-danger)"  },
    warning: { bg: "var(--bg-warning)",    border: "0.5px solid var(--border-warning)", color: "var(--text-warning)" },
    success: { bg: "var(--bg-success)",    border: "0.5px solid var(--border-success)", color: "var(--text-success)" },
    accent:  { bg: "var(--fill-accent)",   border: "none",                              color: "var(--on-accent)"    },
    ghost:   { bg: "transparent",          border: "0.5px solid var(--border)",         color: "var(--text-secondary)"},
  };
  const v = variants[variant];
  return (
    <button onClick={onClick} style={{
      display: "flex", alignItems: "center", justifyContent: "center",
      gap: 5, padding: sm ? "4px 10px" : "6px 12px",
      background: v.bg, border: v.border, color: v.color,
      borderRadius: "var(--radius)", cursor: "pointer",
      fontSize: sm ? 12 : 13, fontWeight: 500,
      width: full ? "100%" : undefined,
      fontFamily: "var(--font-sans)", transition: "opacity .15s"
    }}
      onMouseEnter={e => e.currentTarget.style.opacity = ".8"}
      onMouseLeave={e => e.currentTarget.style.opacity = "1"}
    >
      {icon && <i className={`ti ti-${icon}`} aria-hidden="true" style={{ fontSize: 14 }} />}
      {label}
    </button>
  );
}

function Section({ title, icon, children }) {
  return (
    <div style={{
      background: "var(--surface-1)", border: "0.5px solid var(--border)",
      borderRadius: 12, padding: "12px 14px", marginBottom: 8
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10 }}>
        <i className={`ti ti-${icon}`} aria-hidden="true"
          style={{ fontSize: 14, color: "var(--text-muted)" }} />
        <span style={{ fontSize: 11, fontWeight: 500, color: "var(--text-muted)", letterSpacing: ".03em" }}>
          {title}
        </span>
      </div>
      {children}
    </div>
  );
}

function TextInput({ value, onChange, placeholder, mono }) {
  return (
    <input value={value} onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      style={{
        width: "100%", boxSizing: "border-box",
        fontFamily: mono ? "var(--font-mono)" : "var(--font-sans)",
        fontSize: 13
      }}
    />
  );
}

export default function AdminPanel() {
  const [server, setServer]   = useState("");
  const [token, setToken]     = useState("");
  const [ready, setReady]     = useState(false);

  const [clients, setClients] = useState([]);
  const [selected, setSelected] = useState(new Set());
  const [loading, setLoading] = useState(false);
  const [status, setStatus]   = useState("Tayyor");
  const [autoRef, setAutoRef] = useState(true);
  const [err, setErr]         = useState("");

  const [blockMin, setBlockMin]   = useState(0);
  const [msgText, setMsgText]     = useState("");
  const [imgUrl, setImgUrl]       = useState("");
  const [cmdText, setCmdText]     = useState("");

  const timerRef = useRef(null);
  const hdrs = { "x-token": token, "Content-Type": "application/json" };

  const fetchClients = useCallback(async () => {
    if (!server || !token) return;
    setLoading(true);
    try {
      const r = await fetch(`${server}/clients-list`, { headers: hdrs });
      if (!r.ok) throw new Error(r.status);
      const d = await r.json();
      setClients(d.clients || []);
      setStatus(`${(d.clients||[]).length} ta kompyuter ulangan — ${new Date().toLocaleTimeString()}`);
      setErr("");
    } catch {
      setErr("Server bilan bog'lanib bo'lmadi");
      setStatus("Xato");
    }
    setLoading(false);
  }, [server, token]);

  useEffect(() => {
    if (!ready) return;
    fetchClients();
    if (autoRef) {
      timerRef.current = setInterval(fetchClients, 10000);
    }
    return () => clearInterval(timerRef.current);
  }, [ready, autoRef, fetchClients]);

  const getIds = () => [...selected];

  const send = async (type, data = "", minutes = 0) => {
    const ids = getIds();
    if (!ids.length) { setStatus("Avval kompyuter tanlang"); return; }
    const body = { type };
    if (data) body.data = data;
    if (minutes > 0) body.minutes = minutes;
    try {
      const isAll = ids.length === clients.length && clients.length > 0;
      if (isAll) {
        await fetch(`${server}/push/all`, { method:"POST", headers:hdrs, body:JSON.stringify(body) });
      } else {
        await Promise.all(ids.map(id =>
          fetch(`${server}/push/${id}`, { method:"POST", headers:hdrs, body:JSON.stringify(body) })
        ));
      }
      setStatus(`${type} → ${ids.length} ta kompyuterga yuborildi`);
    } catch { setStatus("Yuborishda xato"); }
  };

  const toggle = id => setSelected(p => {
    const n = new Set(p);
    n.has(id) ? n.delete(id) : n.add(id);
    return n;
  });

  // ── LOGIN SCREEN ──────────────────────────────────────────
  if (!ready) return (
    <div style={{
      minHeight: 420, display: "flex", alignItems: "center",
      justifyContent: "center", padding: "2rem 0"
    }}>
      <div style={{
        background: "var(--surface-2)", border: "0.5px solid var(--border)",
        borderRadius: 16, padding: "2rem", width: 340
      }}>
        <div style={{ textAlign: "center", marginBottom: "1.5rem" }}>
          <i className="ti ti-device-desktop" aria-hidden="true"
            style={{ fontSize: 36, color: "var(--text-accent)" }} />
          <h2 style={{ margin: "8px 0 4px", fontSize: 20, fontWeight: 500 }}>Startup RMM</h2>
          <p style={{ margin: 0, color: "var(--text-secondary)", fontSize: 13 }}>Admin panel</p>
        </div>

        <div style={{ marginBottom: 12 }}>
          <label style={{ fontSize: 12, color: "var(--text-secondary)", display: "block", marginBottom: 4 }}>
            Server URL
          </label>
          <TextInput value={server} onChange={setServer} placeholder="https://yourapp.onrender.com" />
        </div>
        <div style={{ marginBottom: 20 }}>
          <label style={{ fontSize: 12, color: "var(--text-secondary)", display: "block", marginBottom: 4 }}>
            Secret token
          </label>
          <input type="password" value={token} onChange={e => setToken(e.target.value)}
            placeholder="your-secret-token"
            style={{ fontFamily: "var(--font-mono)", fontSize: 13, width: "100%", boxSizing: "border-box" }}
          />
        </div>
        {err && <p style={{ color: "var(--text-danger)", fontSize: 12, marginBottom: 10 }}>{err}</p>}
        <Btn
          label="Kirish" icon="arrow-right" variant="accent" full
          onClick={() => { if (server && token) { setReady(true); } else setErr("URL va token kiriting"); }}
        />
      </div>
    </div>
  );

  // ── MAIN PANEL ────────────────────────────────────────────
  const selCount = selected.size;

  return (
    <div style={{ display: "flex", flexDirection: "column", minHeight: 500 }}>
      <h2 className="sr-only">Startup RMM — 14 ta kompyuterni boshqarish paneli</h2>

      {/* Header */}
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: "10px 14px", borderBottom: "0.5px solid var(--border)",
        background: "var(--surface-1)"
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <i className="ti ti-device-desktop" aria-hidden="true"
            style={{ fontSize: 18, color: "var(--text-accent)" }} />
          <span style={{ fontWeight: 500, fontSize: 15 }}>Startup RMM</span>
          {selCount > 0 && <Badge color="blue">{selCount} tanlangan</Badge>}
          {loading && <i className="ti ti-loader-2" aria-label="yuklanmoqda"
            style={{ fontSize: 14, color: "var(--text-muted)", animation: "spin 1s linear infinite" }} />}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <label style={{ display: "flex", alignItems: "center", gap: 5,
            fontSize: 12, color: "var(--text-secondary)", cursor: "pointer" }}>
            <input type="checkbox" checked={autoRef} onChange={e => setAutoRef(e.target.checked)} />
            Auto (10s)
          </label>
          <Btn label="Yangilash" icon="refresh" sm onClick={fetchClients} />
          <Btn label="Chiqish" icon="logout" sm variant="ghost" onClick={() => setReady(false)} />
        </div>
      </div>

      {/* Body: table + actions */}
      <div style={{ display: "flex", flex: 1, overflow: "hidden" }}>

        {/* Computer table */}
        <div style={{ flex: 1, overflow: "auto", minWidth: 0 }}>
          {/* Select bar */}
          <div style={{
            display: "flex", alignItems: "center", gap: 8, padding: "6px 14px",
            borderBottom: "0.5px solid var(--border)", background: "var(--surface-1)"
          }}>
            <Btn label="Hammasini" icon="checkbox" sm
              onClick={() => setSelected(new Set(clients.map(c => c.id)))} />
            <Btn label="Bekor" icon="square" sm variant="ghost"
              onClick={() => setSelected(new Set())} />
            <span style={{ fontSize: 12, color: "var(--text-muted)", marginLeft: "auto" }}>
              {clients.length} ta ulangan
            </span>
          </div>

          {err && (
            <div style={{
              margin: 12, padding: "10px 14px",
              background: "var(--bg-danger)", border: "0.5px solid var(--border-danger)",
              borderRadius: "var(--radius)", color: "var(--text-danger)", fontSize: 13
            }}>
              <i className="ti ti-alert-circle" aria-hidden="true" style={{ marginRight: 6 }} />
              {err}
            </div>
          )}

          {clients.length === 0 && !err ? (
            <div style={{ textAlign: "center", padding: "3rem 1rem",
              color: "var(--text-muted)", fontSize: 13 }}>
              <i className="ti ti-plug-x" aria-hidden="true" style={{ fontSize: 32, display: "block", marginBottom: 8 }} />
              {loading ? "Yuklanmoqda..." : "Ulangan kompyuter yo'q"}
            </div>
          ) : (
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
              <thead>
                <tr style={{ background: "var(--surface-1)" }}>
                  {["", "#", "Kompyuter", "Foydalanuvchi", "IP", "Oxirgi", ""].map((h, i) => (
                    <th key={i} style={{
                      padding: "8px 10px", textAlign: "left", fontWeight: 500,
                      color: "var(--text-secondary)", fontSize: 12,
                      borderBottom: "0.5px solid var(--border)",
                      width: i === 0 ? 32 : i === 1 ? 32 : i === 6 ? 40 : undefined
                    }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {clients.map((c, i) => {
                  const sel = selected.has(c.id);
                  return (
                    <tr key={c.id} onClick={() => toggle(c.id)}
                      style={{
                        cursor: "pointer",
                        background: sel ? "var(--bg-accent)" : i % 2 === 0 ? "var(--surface-2)" : "var(--surface-1)",
                        borderBottom: "0.5px solid var(--border)"
                      }}
                      onMouseEnter={e => { if (!sel) e.currentTarget.style.background = "var(--fill-ghost-hover)"; }}
                      onMouseLeave={e => { e.currentTarget.style.background = sel ? "var(--bg-accent)" : i % 2 === 0 ? "var(--surface-2)" : "var(--surface-1)"; }}
                    >
                      {/* Checkbox */}
                      <td style={{ padding: "8px 10px" }}>
                        <div style={{
                          width: 16, height: 16, borderRadius: 4,
                          border: sel ? "none" : "0.5px solid var(--border-strong)",
                          background: sel ? "var(--fill-accent)" : "transparent",
                          display: "flex", alignItems: "center", justifyContent: "center"
                        }}>
                          {sel && <i className="ti ti-check" aria-hidden="true"
                            style={{ fontSize: 11, color: "var(--on-accent)" }} />}
                        </div>
                      </td>
                      <td style={{ padding: "8px 10px", color: "var(--text-muted)" }}>{i + 1}</td>
                      <td style={{ padding: "8px 10px", fontWeight: 500 }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                          <i className="ti ti-device-desktop" aria-hidden="true"
                            style={{ fontSize: 14, color: sel ? "var(--text-accent)" : "var(--text-muted)" }} />
                          {c.hostname}
                        </div>
                      </td>
                      <td style={{ padding: "8px 10px", color: "var(--text-secondary)" }}>{c.username}</td>
                      <td style={{ padding: "8px 10px", color: "var(--text-muted)",
                        fontFamily: "var(--font-mono)", fontSize: 12 }}>{c.ip}</td>
                      <td style={{ padding: "8px 10px", color: "var(--text-muted)", fontSize: 12 }}>{c.last_seen}</td>
                      <td style={{ padding: "8px 10px", textAlign: "center" }}>
                        {c.pending > 0 && <Badge color="amber">{c.pending}</Badge>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </div>

        {/* Actions panel */}
        <div style={{
          width: 240, overflow: "auto", borderLeft: "0.5px solid var(--border)",
          padding: "10px 10px 20px", background: "var(--surface-0)", flexShrink: 0
        }}>

          {/* Quvvat */}
          <Section title="Quvvat" icon="bolt">
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6, marginBottom: 6 }}>
              <Btn label="O'chirish" icon="power" variant="danger"
                onClick={() => { if (window.confirm(`${selCount} ta o'chirilsinmi?`)) send("shutdown"); }} />
              <Btn label="Uxlatish" icon="zzz" variant="warning"
                onClick={() => send("sleep")} />
            </div>
            <Btn label="Qayta yuklash" icon="refresh" full
              onClick={() => { if (window.confirm(`${selCount} ta restart?`)) send("restart"); }} />
          </Section>

          {/* Bloklash */}
          <Section title="Bloklash" icon="lock">
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 8 }}>
              <span style={{ fontSize: 12, color: "var(--text-secondary)", whiteSpace: "nowrap" }}>Daqiqa:</span>
              <input type="number" min="0" max="480" value={blockMin}
                onChange={e => setBlockMin(Number(e.target.value))}
                style={{ width: 64, fontFamily: "var(--font-mono)", fontSize: 13 }} />
              <span style={{ fontSize: 11, color: "var(--text-muted)" }}>0=∞</span>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
              <Btn label="Bloklash" icon="lock" variant="warning"
                onClick={() => send("block", "", blockMin)} />
              <Btn label="Ochish" icon="lock-open" variant="success"
                onClick={() => send("unblock")} />
            </div>
          </Section>

          {/* Ekran */}
          <Section title="Ekran" icon="message">
            <TextInput value={msgText} onChange={setMsgText} placeholder="Xabar matni..." />
            <div style={{ marginTop: 6, marginBottom: 10 }}>
              <Btn label="Xabar chiqarish" icon="message-circle" variant="accent" full
                onClick={() => { if (!msgText.trim()) { setStatus("Matn kiriting"); return; } send("show", msgText); }} />
            </div>
            <TextInput value={imgUrl} onChange={setImgUrl} placeholder="Rasm URL (https://...)" />
            <div style={{ marginTop: 6 }}>
              <Btn label="Rasm ko'rsatish" icon="photo" full
                onClick={() => { if (!imgUrl.trim()) { setStatus("URL kiriting"); return; } send("img", imgUrl); }} />
            </div>
          </Section>

          {/* CMD */}
          <Section title="CMD" icon="terminal">
            <TextInput value={cmdText} onChange={setCmdText}
              placeholder="ipconfig, tasklist..." mono />
            <div style={{ marginTop: 6 }}>
              <Btn label="Bajar" icon="player-play" variant="accent" full
                onClick={() => { if (!cmdText.trim()) { setStatus("Buyruq kiriting"); return; } send("cmd", cmdText); }} />
            </div>
            <p style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 6, marginBottom: 0, textAlign: "center" }}>
              natija Telegramga keladi
            </p>
          </Section>
        </div>
      </div>

      {/* Status bar */}
      <div style={{
        padding: "6px 14px", borderTop: "0.5px solid var(--border)",
        background: "var(--surface-1)", fontSize: 12,
        color: err ? "var(--text-danger)" : "var(--text-secondary)"
      }}>
        {err || status}
      </div>

      <style>{`@keyframes spin { to { transform: rotate(360deg) }}`}</style>
    </div>
  );
}
