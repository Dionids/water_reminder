"""
AquaTrack Telegram Bot
Команды:
  /start   — приветствие + привязка аккаунта
  /link <firebase_uid>  — привязать Firebase UID к Telegram
  /stats   — статистика за 7 дней
  /today   — прогресс сегодня
  /help    — список команд
"""

import os
import logging
import httpx
from datetime import datetime
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
)
from dotenv import load_dotenv

load_dotenv()

BOT_TOKEN   = os.getenv("TELEGRAM_BOT_TOKEN")
API_BASE    = os.getenv("AQUATRACK_API_URL", "https://lovely-trust-production-ad76.up.railway.app")

logging.basicConfig(
    format="%(asctime)s — %(name)s — %(levelname)s — %(message)s",
    level=logging.INFO,
)
logger = logging.getLogger(__name__)

# Хранилище telegram_id → firebase_uid.
# Сохраняется в файл uid_store.json рядом с bot.py,
# чтобы переживать перезапуски бота на Railway.
import json as _json

_UID_STORE_FILE = os.path.join(os.path.dirname(__file__), "uid_store.json")

def _load_uid_store() -> dict:
    try:
        with open(_UID_STORE_FILE, "r") as f:
            return {int(k): v for k, v in _json.load(f).items()}
    except (FileNotFoundError, ValueError, _json.JSONDecodeError):
        return {}

def _save_uid_store(store: dict) -> None:
    try:
        with open(_UID_STORE_FILE, "w") as f:
            _json.dump({str(k): v for k, v in store.items()}, f)
    except Exception as e:
        logger.warning("Не удалось сохранить uid_store: %s", e)

_uid_store: dict[int, str] = _load_uid_store()


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _get_uid(telegram_id: int) -> str | None:
    return _uid_store.get(telegram_id)

def _set_uid(telegram_id: int, uid: str) -> None:
    _uid_store[telegram_id] = uid
    _save_uid_store(_uid_store)


async def _api_get(path: str) -> dict | None:
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(f"{API_BASE}{path}")
            r.raise_for_status()
            return r.json()
    except Exception as e:
        logger.error("API error %s: %s", path, e)
        return None


def _progress_bar(pct: int, width: int = 10) -> str:
    filled = round(pct / 100 * width)
    filled = max(0, min(filled, width))
    return "█" * filled + "░" * (width - filled)


def _format_date(iso: str | None) -> str:
    if not iso:
        return "—"
    try:
        return datetime.strptime(iso, "%Y-%m-%d").strftime("%-d %b").lower()
    except ValueError:
        return iso


# ──────────────────────────────────────────────────────────────────────────────
# Handlers
# ──────────────────────────────────────────────────────────────────────────────

async def cmd_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    uid = _get_uid(update.effective_user.id)
    if uid:
        await update.message.reply_text(
            "👋 Привет! Аккаунт уже привязан.\n"
            "Используй /stats или /today чтобы посмотреть прогресс."
        )
    else:
        await update.message.reply_text(
            "💧 *AquaTrack Bot*\n\n"
            "Для начала привяжи аккаунт:\n"
            "`/link <твой Firebase UID>`\n\n"
            "Firebase UID можно найти в приложении:\n"
            "Профиль → раздел Аккаунт → Firebase UID",
            parse_mode="Markdown",
        )


async def cmd_link(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    if not ctx.args:
        await update.message.reply_text(
            "Укажи Firebase UID:\n`/link <uid>`",
            parse_mode="Markdown",
        )
        return

    uid = ctx.args[0].strip()

    # Проверяем что пользователь существует на сервере через аналитику
    # (достаточно чтобы пользователь прошёл /user — т.е. просто запустил приложение)
    data = await _api_get(f"/analytics/{uid}?days=7")
    if data is None:
        await update.message.reply_text(
            "❌ Пользователь с таким UID не найден.\n"
            "Убедись что приложение запущено и выполнена хотя бы одна синхронизация."
        )
        return

    _set_uid(update.effective_user.id, uid)
    await update.message.reply_text(
        f"✅ Аккаунт привязан!\n\n"
        f"Теперь используй:\n"
        f"/today — прогресс сегодня\n"
        f"/stats — статистика за 7 дней"
    )


async def cmd_today(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    uid = _get_uid(update.effective_user.id)
    if not uid:
        await update.message.reply_text("Сначала привяжи аккаунт: /link <uid>")
        return

    today = datetime.now().strftime("%Y-%m-%d")
    data = await _api_get(f"/water-logs/{uid}?date={today}")
    analytics = await _api_get(f"/analytics/{uid}?days=1")

    if data is None:
        await update.message.reply_text("❌ Не удалось получить данные. Попробуй позже.")
        return

    total_ml  = data.get("total_ml", 0)
    goal_ml   = 2000  # fallback
    if analytics and analytics.get("days"):
        goal_ml = analytics["days"][0].get("goal_ml", 2000)

    pct = min(100, round(total_ml / goal_ml * 100)) if goal_ml > 0 else 0
    bar = _progress_bar(pct)
    remaining = max(0, goal_ml - total_ml)

    logs = data.get("logs", [])
    logs_str = ""
    if logs:
        last5 = logs[-5:]
        for log in reversed(last5):
            t = datetime.fromisoformat(log["logged_at"]).strftime("%H:%M")
            logs_str += f"  {t} — {int(log['amount_ml'])} мл\n"

    msg = (
        f"💧 *Сегодня, {datetime.now().strftime('%-d %b')}*\n\n"
        f"{bar} {pct}%\n"
        f"{total_ml} мл из {goal_ml} мл\n\n"
    )
    if remaining > 0:
        msg += f"Осталось выпить: *{remaining} мл*\n"
    else:
        msg += "🎉 Норма выполнена!\n"

    if logs_str:
        msg += f"\nПоследние записи:\n{logs_str}"

    await update.message.reply_text(msg, parse_mode="Markdown")


async def cmd_stats(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    uid = _get_uid(update.effective_user.id)
    if not uid:
        await update.message.reply_text("Сначала привяжи аккаунт: /link <uid>")
        return

    data = await _api_get(f"/analytics/{uid}?days=7")
    if data is None:
        await update.message.reply_text("❌ Не удалось получить данные. Попробуй позже.")
        return

    avg_completion = data.get("avg_completion", 0)
    avg_steps      = data.get("avg_steps", 0)
    best_day       = _format_date(data.get("best_day"))
    worst_day      = _format_date(data.get("worst_day"))
    days           = data.get("days", [])

    bar = _progress_bar(avg_completion)

    # Таблица по дням
    days_str = ""
    for d in sorted(days, key=lambda x: x["date"]):
        date_label = _format_date(d["date"])
        pct = d.get("completion", 0)
        mini_bar = _progress_bar(pct, width=5)
        days_str += f"  {date_label}: {mini_bar} {pct}%\n"

    msg = (
        f"📊 *Статистика за 7 дней*\n\n"
        f"Среднее выполнение нормы:\n"
        f"{bar} {avg_completion}%\n\n"
        f"Среднее шагов в день: *{avg_steps:,}*\n"
        f"Лучший день: *{best_day}*\n"
        f"Худший день: *{worst_day}*\n\n"
        f"*По дням:*\n{days_str}"
    )

    await update.message.reply_text(msg, parse_mode="Markdown")


async def cmd_help(update: Update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "💧 *AquaTrack Bot — команды*\n\n"
        "/link `<uid>` — привязать Firebase аккаунт\n"
        "/today — прогресс воды сегодня\n"
        "/stats — статистика за 7 дней\n"
        "/help — эта справка",
        parse_mode="Markdown",
    )


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main() -> None:
    if not BOT_TOKEN:
        raise RuntimeError("TELEGRAM_BOT_TOKEN не задан в .env")

    app = Application.builder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("link",  cmd_link))
    app.add_handler(CommandHandler("today", cmd_today))
    app.add_handler(CommandHandler("stats", cmd_stats))
    app.add_handler(CommandHandler("help",  cmd_help))

    logger.info("Bot started. API: %s", API_BASE)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
