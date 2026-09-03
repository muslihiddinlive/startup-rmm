"""
Startup RMM Server
  FastAPI  — client uchun REST API
  aiogram  — Telegram orqali admin boshqaruvi
"""

import os
import logging
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from aiogram import Bot, Dispatcher, Router
from aiogram.types import Update, Message
from aiogram.filters import Command
from aiogram.fsm.storage.memory import MemoryStorage

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

# ─── Config ───────────────────────────────────────────────────
SECRET   = os.environ["SECRET_TOKEN"]
TG_TOKEN = os.environ["TELEGRAM_TOKEN"]
ADMIN_ID = int(os.environ["ADMIN_ID"])
BASE_URL = os.environ["RENDER_URL"]

# ─── State ────────────────────────────────────────────────────
clients   : dict = {}   # id → {hostname, user, ip, last_seen}
cmd_queue : dict = {}   # id → [cmd, ...]

# ─── Bot ──────────────────────────────────────────────────────
bot    = Bot(token=TG_TOKEN)
dp     = Dispatcher(storage=MemoryStorage())
router = Router()
dp.include_router(router)

def is_admin(msg: Message) -> bool:
    return msg.from_user.id == ADMIN_ID

def push(cid: str, cmd: dict):
    cmd_queue.setdefault(cid, []).append(cmd)

def push_all(cmd: dict):
    for cid in clients:
        push(cid, cmd)

def cname(cid: str) -> str:
    return clients.get(cid, {}).get("hostname", cid)

def parse_target(parts: list, min_parts: int) -> tuple[str | None, str | None]:
    """parts[1] = id yoki 'all', qolganlar = data. None qaytarsa xato."""
    if len(parts) < min_parts:
        return None, None
    return parts[1], " ".join(parts[2:]) if len(parts) > 2 else ""

# ── Yordamchi: bir yoki hammaga yuborish ──────────────────────
async def dispatch(msg: Message, cid_or_all: str, cmd: dict, label: str):
    if cid_or_all == "all":
        if not clients:
            await msg.answer("❌ Ulangan kompyuter yo'q")
            return
        push_all(cmd)
        await msg.answer(f"{label} → <b>hamma</b> ({len(clients)} ta)", parse_mode="HTML")
    else:
        if cid_or_all not in clients:
            await msg.answer(f"❌ <code>{cid_or_all}</code> topilmadi. /clients tekshiring.", parse_mode="HTML")
            return
        push(cid_or_all, cmd)
        await msg.answer(f"{label} → <b>{cname(cid_or_all)}</b>", parse_mode="HTML")

# ── /start ────────────────────────────────────────────────────
@router.message(Command("start"))
async def on_start(msg: Message):
    if not is_admin(msg): return
    await msg.answer(
        "🖥 <b>Startup RMM</b>\n\n"
        "<b>Asosiy buyruqlar:</b>\n"
        "/clients — ro'yxat\n"
        "/cmd <code>&lt;id|all&gt; &lt;buyruq&gt;</code>\n"
        "/show <code>&lt;id|all&gt; &lt;matn&gt;</code>\n"
        "/img <code>&lt;id|all&gt; &lt;url&gt;</code>\n\n"
        "<b>Boshqaruv:</b>\n"
        "/shutdown <code>&lt;id|all&gt;</code> — o'chirish\n"
        "/sleep <code>&lt;id|all&gt;</code> — uxlatish\n"
        "/restart <code>&lt;id|all&gt;</code> — qayta yuklash\n"
        "/block <code>&lt;id|all&gt; [daqiqa]</code> — bloklash\n"
        "/unblock <code>&lt;id|all&gt;</code> — blokni ochish\n\n"
        "<i>id o'rniga</i> <code>all</code> <i>= hammaga</i>",
        parse_mode="HTML"
    )

# ── /clients ──────────────────────────────────────────────────
@router.message(Command("clients"))
async def on_clients(msg: Message):
    if not is_admin(msg): return
    if not clients:
        await msg.answer("❌ Hech qanday kompyuter ulanmagan")
        return
    lines = ["🖥 <b>Ulangan kompyuterlar:</b>\n"]
    for cid, info in clients.items():
        q = len(cmd_queue.get(cid, []))
        lines.append(
            f"• <b>{info['hostname']}</b> <code>{cid}</code>\n"
            f"  👤 {info['username']}  🌐 {info['ip']}\n"
            f"  🕐 {info['last_seen']}  📋 navbat: {q}\n"
        )
    await msg.answer("\n".join(lines), parse_mode="HTML")

# ── /cmd ──────────────────────────────────────────────────────
@router.message(Command("cmd"))
async def on_cmd(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=2)
    if len(parts) < 3:
        await msg.answer("❗ /cmd <code>&lt;id|all&gt; &lt;buyruq&gt;</code>", parse_mode="HTML"); return
    target, command = parts[1], parts[2]
    await dispatch(msg, target, {"type": "cmd", "data": command},
                   f"📤 <code>{command}</code>")

# ── /show ─────────────────────────────────────────────────────
@router.message(Command("show"))
async def on_show(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=2)
    if len(parts) < 3:
        await msg.answer("❗ /show <code>&lt;id|all&gt; &lt;matn&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "show", "data": parts[2]}, "💬 Xabar")

# ── /img ──────────────────────────────────────────────────────
@router.message(Command("img"))
async def on_img(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=2)
    if len(parts) < 3:
        await msg.answer("❗ /img <code>&lt;id|all&gt; &lt;url&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "img", "data": parts[2]}, "🖼 Rasm")

# ── /shutdown ─────────────────────────────────────────────────
@router.message(Command("shutdown"))
async def on_shutdown(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=1)
    if len(parts) < 2:
        await msg.answer("❗ /shutdown <code>&lt;id|all&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "shutdown"}, "🔴 O'chirish")

# ── /sleep ────────────────────────────────────────────────────
@router.message(Command("sleep"))
async def on_sleep(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=1)
    if len(parts) < 2:
        await msg.answer("❗ /sleep <code>&lt;id|all&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "sleep"}, "😴 Uxlatish")

# ── /restart ──────────────────────────────────────────────────
@router.message(Command("restart"))
async def on_restart(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=1)
    if len(parts) < 2:
        await msg.answer("❗ /restart <code>&lt;id|all&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "restart"}, "🔄 Qayta yuklash")

# ── /block ────────────────────────────────────────────────────
@router.message(Command("block"))
async def on_block(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=2)
    if len(parts) < 2:
        await msg.answer(
            "❗ /block <code>&lt;id|all&gt; [daqiqa]</code>\n"
            "Misol: /block abc12345 10  → 10 daqiqa\n"
            "       /block all          → ochguncha blok",
            parse_mode="HTML"
        ); return
    target = parts[1]
    minutes = 0
    if len(parts) == 3:
        try:
            minutes = int(parts[2])
        except ValueError:
            await msg.answer("❗ Daqiqa raqam bo'lishi kerak"); return

    label_time = f"{minutes} daqiqa" if minutes > 0 else "ochguncha"
    await dispatch(msg, target,
                   {"type": "block", "minutes": minutes},
                   f"🔒 Bloklash ({label_time})")

# ── /unblock ──────────────────────────────────────────────────
@router.message(Command("unblock"))
async def on_unblock(msg: Message):
    if not is_admin(msg): return
    parts = msg.text.split(maxsplit=1)
    if len(parts) < 2:
        await msg.answer("❗ /unblock <code>&lt;id|all&gt;</code>", parse_mode="HTML"); return
    await dispatch(msg, parts[1], {"type": "unblock"}, "🔓 Blok ochildi")

# ─── FastAPI ──────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    await bot.set_webhook(f"{BASE_URL}/webhook")
    yield
    await bot.delete_webhook()
    await bot.session.close()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

def auth(x_token: str = Header(None)):
    if x_token != SECRET:
        raise HTTPException(status_code=403)

class RegisterReq(BaseModel):
    client_id: str
    hostname:  str
    username:  str
    ip:        str

class ResultReq(BaseModel):
    command: str
    output:  str
    success: bool

@app.post("/register")
async def register(req: RegisterReq, x_token: str = Header(None)):
    auth(x_token)
    clients[req.client_id] = {
        "hostname":  req.hostname,
        "username":  req.username,
        "ip":        req.ip,
        "last_seen": datetime.now().strftime("%d.%m %H:%M:%S"),
    }
    cmd_queue.setdefault(req.client_id, [])
    return {"status": "ok"}

@app.get("/poll/{client_id}")
async def poll(client_id: str, x_token: str = Header(None)):
    auth(x_token)
    if client_id in clients:
        clients[client_id]["last_seen"] = datetime.now().strftime("%d.%m %H:%M:%S")
    q = cmd_queue.get(client_id, [])
    return {"command": q.pop(0) if q else None}

@app.post("/result/{client_id}")
async def result(client_id: str, res: ResultReq, x_token: str = Header(None)):
    auth(x_token)
    icon = "✅" if res.success else "❌"
    out  = res.output.strip()[:3500] or "(bo'sh)"
    await bot.send_message(
        ADMIN_ID,
        f"{icon} <b>{cname(client_id)}</b>\n$ <code>{res.command}</code>\n\n<pre>{out}</pre>",
        parse_mode="HTML"
    )
    return {"status": "ok"}

@app.post("/webhook")
async def tg_webhook(request: Request):
    update = Update.model_validate(await request.json())
    await dp.feed_update(bot, update)
    return {"ok": True}

@app.get("/")
async def health():
    return {"status": "ok", "clients": len(clients),
            "time": datetime.now().strftime("%d.%m.%Y %H:%M:%S")}


# ─── Admin Panel uchun qo'shimcha endpointlar ─────────────────

@app.get("/clients-list")
async def clients_list(x_token: str = Header(None)):
    auth(x_token)
    return {
        "clients": [
            {
                "id":        k,
                "hostname":  v["hostname"],
                "username":  v["username"],
                "ip":        v["ip"],
                "last_seen": v["last_seen"],
                "pending":   len(cmd_queue.get(k, []))
            }
            for k, v in clients.items()
        ]
    }

class PushCmd(BaseModel):
    type:    str
    data:    str = ""
    minutes: int = 0

@app.post("/push/{target}")
async def push_command(target: str, cmd: PushCmd, x_token: str = Header(None)):
    auth(x_token)
    payload = {"type": cmd.type}
    if cmd.data:              payload["data"]    = cmd.data
    if cmd.minutes > 0:       payload["minutes"] = cmd.minutes

    if target == "all":
        push_all(payload)
        return {"status": "ok", "count": len(clients)}
    if target not in clients:
        raise HTTPException(status_code=404, detail="Client topilmadi")
    push(target, payload)
    return {"status": "ok"}
