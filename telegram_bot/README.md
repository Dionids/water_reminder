# AquaTrack Telegram Bot

Бот показывает статистику гидратации из AquaTrack через FastAPI бэкенд.

## Команды

| Команда | Описание |
|---|---|
| `/start` | Приветствие |
| `/link <firebase_uid>` | Привязать аккаунт AquaTrack |
| `/today` | Прогресс воды сегодня |
| `/stats` | Статистика за 7 дней |
| `/help` | Список команд |

## Быстрый запуск локально

### 1. Создать бота в Telegram

1. Открой [@BotFather](https://t.me/BotFather) в Telegram
2. Отправь `/newbot`
3. Введи имя бота (например `AquaTrack`)
4. Введи username (например `aquatrack_mybot`) — должен заканчиваться на `bot`
5. Скопируй полученный токен

### 2. Настроить окружение

```bash
cd telegram_bot
cp .env.example .env
# Открой .env и вставь токен бота
```

### 3. Установить зависимости и запустить

```bash
pip install -r requirements.txt
python bot.py
```

Бот запустится в режиме polling — будет работать пока открыт терминал.

## Деплой на Railway (рекомендуется)

### 1. Подготовка

Убедись что у тебя установлен [Railway CLI](https://docs.railway.app/develop/cli):
```bash
npm install -g @railway/cli
railway login
```

### 2. Создать новый сервис

```bash
cd telegram_bot
railway init        # выбери "Empty Project"
railway up
```

### 3. Задать переменные окружения

В Railway Dashboard → твой проект → новый сервис → Variables:

```
TELEGRAM_BOT_TOKEN = токен_от_botfather
AQUATRACK_API_URL  = https://lovely-trust-production-ad76.up.railway.app
```

### 4. Создать Procfile

Railway нужен `Procfile` чтобы знать что запускать:

```bash
echo "worker: python bot.py" > Procfile
railway up
```

После деплоя бот будет работать 24/7 без твоего компьютера.

## Как пользователь привязывает аккаунт

1. Пользователь открывает бота → `/start`
2. В приложении AquaTrack: Профиль → Аккаунт → копирует Firebase UID
3. Отправляет боту: `/link <uid>`
4. Бот проверяет UID через API и сохраняет привязку
5. Готово — `/today` и `/stats` работают

> **Примечание:** Сейчас привязка хранится в памяти процесса.
> При перезапуске бота пользователям нужно снова сделать `/link`.
> Для продакшена добавь таблицу `telegram_links` в PostgreSQL бэкенда.

## Добавить Firebase UID в UI приложения

Сейчас UID не показывается в ProfileScreen. Добавь в карточку аккаунта:

```dart
// В _buildAccountCard(), после отображения email:
if (profile?.firebaseUid != null)
  SelectableText(
    'UID: ${profile!.firebaseUid}',
    style: TextStyle(fontSize: 11, color: Colors.grey),
  ),
```
