# AquaTrack — Контекст проекта

> Этот файл — главный источник истины для любого AI-ассистента работающего с проектом.
> Читай его первым перед любым изменением кода.

---

## Суть проекта

Flutter-приложение для умного контроля гидратации. Норма воды рассчитывается динамически
на основе веса пользователя, шагов и типа тренировки из Health Connect (Samsung Health).
Данные синхронизируются с FastAPI бэкендом. Аутентификация через Firebase.

---

## Технологический стек

| Слой | Технология |
|---|---|
| Мобильное приложение | Flutter 3.41.6, Dart 3.11.4 |
| Локальная БД | Hive 2.2.3 |
| Health данные | health ^13.0.0 (Health Connect, Android 9+) |
| Аутентификация | Firebase Auth (Anonymous + Google Sign-In) |
| Уведомления | flutter_local_notifications + WorkManager |
| Фоновая синхронизация | workmanager ^0.6.0 |
| Графики | fl_chart ^0.70.0 |
| Бэкенд | FastAPI + SQLAlchemy |
| БД сервера | PostgreSQL (прод) / SQLite (локально) |
| Деплой бэкенда | Railway (рекомендуется) / Docker Compose |
| Device ID | device_info_plus ^10.1.0 |

---

## Структура проекта

```
lib/
  main.dart                    — точка входа, роутинг, главный экран
  firebase_options.dart        — конфиг Firebase (из google-services.json)
  models/
    user_profile.dart          — профиль пользователя (Hive typeId: 1)
    user_profile.g.dart        — сгенерированный адаптер (9 полей, 0–8)
    water_log.dart             — запись о воде (Hive typeId: 0, поле synced)
    water_log.g.dart           — сгенерированный адаптер (4 поля, 0–3)
    activity_cache.dart        — не используется (мёртвый код, к удалению)
  screens/
    login_screen.dart          — экран входа (Anonymous + Google)
    onboarding_screen.dart     — ввод веса и возраста (после входа)
    history_screen.dart        — история + BarChart за 7 дней (fl_chart)
    profile_screen.dart        — редактирование профиля, аккаунт, выход
  services/
    auth_service.dart          — Firebase Auth, Google Sign-In, Device ID
    health_service.dart        — Health Connect: шаги, вес, калории, тренировки
    hive_service.dart          — локальное хранилище (Hive)
    api_service.dart           — HTTP клиент для FastAPI бэкенда
    sync_service.dart          — WorkManager фоновая синхронизация + SyncState
    notification_service.dart  — уведомления о гидратации

android/
  app/
    google-services.json       — Firebase конфиг (project: aquatrack-7dbfb)
    src/main/AndroidManifest.xml
    src/main/res/xml/health_permissions.xml

backend/
  main.py                      — FastAPI приложение
  requirements.txt
  Dockerfile
  docker-compose.yml           — FastAPI + PostgreSQL
```

---

## Модели данных

### UserProfile (Hive typeId: 1)

| Field | HiveField | Тип | Описание |
|---|---|---|---|
| weight | 0 | double? | Вес в кг |
| age | 1 | int? | Возраст |
| dailyBaseGoal | 2 | int? | Норма воды в мл (пересчитывается сервером) |
| lastSync | 3 | DateTime? | Время последней синхронизации |
| firebaseUid | 4 | String? | Firebase UID — основной ID |
| deviceId | 5 | String? | Android Device ID — резервный ID |
| displayName | 6 | String? | Имя (из Google или null) |
| email | 7 | String? | Email (из Google или null) |
| isAnonymous | 8 | bool | Тип входа (default: true) |

Геттер `id` → возвращает firebaseUid ?? deviceId ?? 'user_local'

### WaterLog (Hive typeId: 0)

| Field | HiveField | Тип | Описание |
|---|---|---|---|
| id | 0 | int? | Локальный ID |
| amount | 1 | double | Объём в мл |
| date | 2 | DateTime | Время записи |
| synced | 3 | bool | Отправлен ли на сервер (офлайн-очередь) |

**ВАЖНО:** при добавлении воды лог сохраняется с synced=false.
При успешной отправке на сервер — markLogSynced(log). При синхронизации
вызывается _flushWaterLogs() который отправляет все unsynced логи.

---

## Формула расчёта нормы воды

Единая во всей цепочке (онбординг, бэкенд, офлайн-fallback):

```
base_ml      = weight_kg × 30           # ВОЗ
steps_bonus  = (steps / 1000) × 50      # ACSM
workout_bonus = intensity_ml_per_hour × (workout_minutes / 60)  # NSCA
total = base_ml + steps_bonus + workout_bonus
```

Интенсивность тренировки (WorkoutIntensity enum):
- none    → 0 мл/час
- low     → 200 мл/час (ходьба, йога, пилатес)
- medium  → 400 мл/час (походы, танцы, теннис)
- high    → 600 мл/час (бег, велосипед, плавание, баскетбол)
- extreme → 900 мл/час (HIIT, бокс, кроссфит, прыжки со скакалкой)

---

## Аутентификация

Схема:
1. Новый пользователь → /login
2. Нажал "Анонимно" → Firebase anonymous sign-in → /onboarding
3. Нажал "Google" → GoogleSignIn → linkWithCredential (если был анонимным) → /onboarding или /home
4. При переустановке → Firebase восстанавливает сессию → /home сразу

Ключевые детали:
- GoogleSignIn использует `clientId:` (НЕ serverClientId — это баг Android)
- web_client_id (type 3): 624904190292-rufut8a3q3r5guea0v3dgkmo0l68sh5n.apps.googleusercontent.com
- После входа ВСЕГДА вызывается apiService.upsertUser() на бэкенде
- signOut() очищает и Firebase сессию и Hive профиль

---

## Синхронизация с Health Connect

### Разрешения (AndroidManifest + health_permissions.xml)
READ_STEPS, READ_SLEEP, READ_WEIGHT, READ_HEART_RATE,
READ_TOTAL_CALORIES_BURNED, READ_DISTANCE, READ_EXERCISE

### fetchAllTodayData() — главный метод
Читает параллельно через Future.wait: шаги, вес, калории, пульс, дистанцию.
Потом последовательно: тренировки (нужен пульс для fallback).

### Известные особенности Samsung Health
- WORKOUT type часто возвращает OTHER → fallback на пульс (зоны ЧСС)
- Калории могут дублироваться → дедупликация через _sumWithoutOverlap()
- hasPermissions() возвращает null → используется кэш + step read fallback

### Авто-синхронизация
- В приложении: Timer.periodic каждые 30 мин (пока приложение открыто)
- В фоне: WorkManager каждые 15 мин (даже когда приложение закрыто)
- Дедупликация: минимум 5 мин между синхронизациями
- checkPermissions() для авто-sync (без диалога)
- requestPermissions() только при ручном нажатии Sync

### Индикатор свежести (SyncState)
- fresh (<30 мин): зелёная точка
- aging (30–60 мин): жёлтая точка
- stale (>1 ч): красная точка + предупреждение на Hero карточке

---

## Бэкенд (FastAPI)

### Эндпоинты

| Метод | Путь | Описание |
|---|---|---|
| POST | /user | Создать/обновить пользователя |
| POST | /sync-activity | Синхронизация активности + расчёт нормы |
| POST | /water-log | Сохранить запись о воде |
| GET | /analytics/{uid}?days=7 | Статистика за N дней |

### Таблицы PostgreSQL
- users: firebase_uid (PK), device_id, display_name, email, is_anonymous, weight_kg, age
- activity_logs: firebase_uid, log_date (один раз в день, upsert), steps, calories, workout_minutes, workout_intensity, goal_ml
- water_logs: firebase_uid, amount_ml, logged_at

### Запуск локально
```bash
cd backend
pip install -r requirements.txt
python main.py          # SQLite fallback, порт 8000
# или
docker-compose up       # PostgreSQL + FastAPI
```

### URL в ApiService
- Эмулятор: http://10.0.2.2:8000
- Физическое устройство: IP компьютера в локальной сети
- Прод: https://lovely-trust-production-ad76.up.railway.app ✅ задеплоен

---

## Firebase

- Project ID: aquatrack-7dbfb
- Project Number: 624904190292
- Package: com.example.untitled1 (нужно переименовать!)
- SHA-1: 42:54:B0:65:DA:6E:7E:ED:EC:F1:A2:0A:10:06:66:EE:4C:8E:EE:01
- google-services.json: android/app/google-services.json
- firebase_options.dart: lib/firebase_options.dart

---

## Роутинг

```
/login      — LoginScreen (нет Firebase сессии)
/onboarding — OnboardingScreen (вошёл, но нет веса/возраста)
/home       — MyHomePage (главный экран)
/history    — HistoryScreen (история + график)
/profile    — ProfileScreen (редактирование + аккаунт)
```

Логика выбора initialRoute в MyApp:
- firebaseUid == null → /login
- weight == null → /onboarding
- иначе → /home

---

## Известные проблемы и технический долг

1. **applicationId = "com.example.untitled1"** — нужно переименовать перед релизом
2. **activity_cache.dart** — мёртвый код, не используется, нужно удалить
3. **baseUrl захардкожен** — нужен env-конфиг для прод URL бэкенда
4. **Бэкенд задеплоен** — https://lovely-trust-production-ad76.up.railway.app ✅
5. **ProfileScreen** — не передаёт обновлённый вес на сервер при сохранении
6. **Аналитика** — GET /analytics реализована на бэкенде, но не показывается в приложении
7. **fl_chart** — подключён, используется только в HistoryScreen (7 дней). Можно добавить на главный экран

---

## Что ещё не сделано (приоритеты)

**Высокий приоритет:**
- ~~Задеплоить бэкенд на Railway~~ ✅ https://lovely-trust-production-ad76.up.railway.app
- Заменить applicationId на com.dionids.aquatrack
- Показать аналитику в приложении (экран статистики)

**Средний приоритет:**
- Телеграм-бот с /stats командой (читает из PostgreSQL через FastAPI)
- AI-советы через Claude API (персонализированные, не if/else)
- ProfileScreen → при сохранении веса отправлять на сервер

**Низкий приоритет:**
- Удалить activity_cache.dart
- Виджет рабочего стола (home_widget)
- Unit-тесты на формулу расчёта нормы
