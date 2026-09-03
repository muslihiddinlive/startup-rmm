# 🖥 Startup RMM

14 ta kompyuterni Telegram orqali boshqarish tizimi.

**Stack:** Python (FastAPI + aiogram) · PowerShell · Render · Cloudflare · UptimeRobot

---

## ⚙️ 1-qadam — Telegram Bot yaratish

1. [@BotFather](https://t.me/BotFather) → `/newbot`
2. Token oling → `TELEGRAM_TOKEN`
3. Admin ID: [@userinfobot](https://t.me/userinfobot) yuboring → `ADMIN_ID`

---

## 🚀 2-qadam — Render ga Deploy

1. **GitHub** ga `server/` papkasini push qiling
2. [render.com](https://render.com) → **New Web Service** → reponi tanlang
3. `Root Directory`: `server`
4. **Environment Variables** qo'shing:

| Key | Qiymat |
|-----|--------|
| `SECRET_TOKEN` | o'zingiz o'ylab topadigan parol (masalan: `abc123xyz`) |
| `TELEGRAM_TOKEN` | BotFather tokeni |
| `ADMIN_ID` | Telegram ID raqamingiz |
| `RENDER_URL` | Deploy tugagandan keyin Render bergan URL |

5. Deploy tugasin, URL ni oling → `RENDER_URL` ga kiriting → **Save** → Redeploy

---

## 🔄 3-qadam — UptimeRobot (Render uxlab qolmasligi uchun)

1. [uptimerobot.com](https://uptimerobot.com) → New Monitor
2. Type: **HTTP(s)**
3. URL: `https://yourapp.onrender.com/`
4. Interval: **5 minutes**

---

## ☁️ 4-qadam — Cloudflare (ixtiyoriy, lekin tavsiya)

1. Domen yoki subdomain yarating → Render URL ga CNAME point qiling
2. SSL/TLS → Full
3. DDoS himoyasi avtomatik yoqiladi

---

## 💻 5-qadam — Client o'rnatish (har bir kompyuterda)

1. `client/client.ps1` faylini oching
2. Quyidagilarni o'zgartiring:
   ```powershell
   $SERVER = "https://yourapp.onrender.com"   # Render URL
   $TOKEN  = "abc123xyz"                       # SECRET_TOKEN
   ```
3. Ikkala fayl (`client.ps1` + `install.ps1`) ni USB yoki tarmoq papkasiga ko'piring
4. Har bir kompyuterda `install.ps1` ni **Right-click → Run as Administrator**
5. Tayyor! Bot ga `/clients` yuboring

---

## 📱 Telegram Buyruqlar

| Buyruq | Nima qiladi |
|--------|-------------|
| `/clients` | Ulanganlar ro'yxati |
| `/cmd abc12345 ipconfig` | Bitta kompyuterga CMD |
| `/show abc12345 Tushlikka boring!` | Ekranga popup xabar |
| `/img abc12345 https://...jpg` | Ekranga rasm (fullscreen) |
| `/all shutdown /r /t 60` | Hammaga CMD |
| `/allshow Ish tugadi, kompyuterlarni o'chiring` | Hammaga xabar |

---

## 🔐 Xavfsizlik

- Barcha client↔server muloqoti `x-token` header orqali himoyalangan
- Bot faqat `ADMIN_ID` buyruqlariga javob beradi
- Client ID kompyuterda `%APPDATA%\rmm\client_id.txt` da saqlanadi
- HTTPS (Render + Cloudflare)

---

## 🐛 Muammolar

**Client ulanmadi:**
- `%APPDATA%\rmm\client_id.txt` bor-yo'qligini tekshiring
- Task Scheduler → `StartupRMM-Client` running turganini tekshiring
- PowerShell: `Invoke-RestMethod https://yourapp.onrender.com/` ishlaydimi?

**Bot javob bermayapti:**
- Render loglarini tekshiring (Dashboard → Logs)
- Webhook to'g'ri o'rnatilganmi: `https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
