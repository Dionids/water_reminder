import os
from datetime import datetime, date
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import (
    create_engine, Column, String, Integer, Float,
    DateTime, Date, Boolean, ForeignKey, text
)
from sqlalchemy.orm import declarative_base, sessionmaker, Session

# ──────────────────────────────────────────────
# Database setup
# ──────────────────────────────────────────────

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./aquatrack.db")

# Railway PostgreSQL возвращает postgres://, SQLAlchemy требует postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()

# ──────────────────────────────────────────────
# Models
# ──────────────────────────────────────────────

class User(Base):
    """Пользователь. firebase_uid — основной ключ из Firebase Auth."""
    __tablename__ = "users"

    firebase_uid = Column(String, primary_key=True, index=True)
    device_id    = Column(String, nullable=True, index=True)
    display_name = Column(String, nullable=True)
    email        = Column(String, nullable=True)
    is_anonymous = Column(Boolean, default=True)
    weight_kg    = Column(Float, nullable=True)
    age          = Column(Integer, nullable=True)
    created_at   = Column(DateTime, default=datetime.utcnow)
    updated_at   = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ActivityLog(Base):
    """Ежедневная активность — шаги, тренировки, калории."""
    __tablename__ = "activity_logs"

    id                = Column(Integer, primary_key=True, autoincrement=True)
    firebase_uid      = Column(String, ForeignKey("users.firebase_uid"), index=True)
    log_date          = Column(Date, default=date.today, index=True)
    steps             = Column(Integer, default=0)
    calories          = Column(Float, default=0.0)
    distance_m        = Column(Float, default=0.0)
    workout_minutes   = Column(Integer, default=0)
    workout_intensity = Column(String, default="none")
    activity_names    = Column(String, default="")   # JSON-строка через запятую
    goal_ml           = Column(Integer, default=2000)
    synced_at         = Column(DateTime, default=datetime.utcnow)


class WaterLog(Base):
    """Запись о выпитой воде."""
    __tablename__ = "water_logs"

    id           = Column(Integer, primary_key=True, autoincrement=True)
    firebase_uid = Column(String, ForeignKey("users.firebase_uid"), index=True)
    amount_ml    = Column(Float, nullable=False)
    logged_at    = Column(DateTime, default=datetime.utcnow, index=True)


Base.metadata.create_all(bind=engine)

# ──────────────────────────────────────────────
# FastAPI
# ──────────────────────────────────────────────

app = FastAPI(title="AquaTrack Backend")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# ──────────────────────────────────────────────
# Pydantic schemas
# ──────────────────────────────────────────────

class UserUpsert(BaseModel):
    firebase_uid: str
    device_id:    Optional[str] = None
    display_name: Optional[str] = None
    email:        Optional[str] = None
    is_anonymous: bool = True
    weight_kg:    Optional[float] = None
    age:          Optional[int] = None


class ActivityData(BaseModel):
    firebase_uid:      str
    steps:             int
    weight_kg:         float = 70.0
    workout_minutes:   int = 0
    workout_intensity: str = "none"
    activity_names:    List[str] = []
    calories:          float = 0.0
    distance_m:        float = 0.0


class WaterLogCreate(BaseModel):
    firebase_uid: str
    amount_ml:    float
    logged_at:    Optional[datetime] = None


# ──────────────────────────────────────────────
# Water goal formula (ВОЗ + ACSM + NSCA)
# ──────────────────────────────────────────────

INTENSITY_ML_PER_HOUR = {
    "none":    0,
    "low":     200,
    "medium":  400,
    "high":    600,
    "extreme": 900,
}

def calculate_water_goal(weight_kg: float, steps: int,
                          workout_minutes: int, workout_intensity: str) -> dict:
    base        = weight_kg * 30
    steps_bonus = (steps / 1000) * 50
    workout_b   = INTENSITY_ML_PER_HOUR.get(workout_intensity, 0) * (workout_minutes / 60)
    total       = int(base + steps_bonus + workout_b)
    return {
        "base_ml":    int(base),
        "steps_ml":   int(steps_bonus),
        "workout_ml": int(workout_b),
        "total":      total,
    }

def generate_advice(steps: int, intensity: str, minutes: int) -> str:
    if intensity in ("high", "extreme") and minutes > 0:
        return f"Интенсивная тренировка {minutes} мин — пейте воду каждые 15–20 минут!"
    if steps > 10_000:
        return "Отличный результат по шагам! Не забывайте восполнять жидкость."
    if steps < 3_000:
        return "Сегодня малоактивный день — старайтесь делать небольшие прогулки."
    return "Хороший темп! Равномерно пейте воду в течение дня."

# ──────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "online", "service": "AquaTrack Backend"}


@app.post("/user", summary="Создать или обновить пользователя")
def upsert_user(data: UserUpsert, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.firebase_uid == data.firebase_uid).first()
    if user:
        # Обновляем только непустые поля
        if data.device_id:    user.device_id    = data.device_id
        if data.display_name: user.display_name = data.display_name
        if data.email:        user.email        = data.email
        if data.weight_kg:    user.weight_kg    = data.weight_kg
        if data.age:          user.age          = data.age
        user.is_anonymous = data.is_anonymous
        user.updated_at = datetime.utcnow()
    else:
        user = User(**data.model_dump())
        db.add(user)
    db.commit()
    return {"status": "ok", "firebase_uid": data.firebase_uid}


@app.post("/sync-activity", summary="Синхронизация активности + пересчёт нормы")
def sync_activity(data: ActivityData, db: Session = Depends(get_db)):
    # Проверяем что пользователь существует
    user = db.query(User).filter(User.firebase_uid == data.firebase_uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден. Сначала вызови /user")

    # Обновляем вес если передан
    if data.weight_kg and data.weight_kg != user.weight_kg:
        user.weight_kg = data.weight_kg

    breakdown = calculate_water_goal(
        data.weight_kg, data.steps,
        data.workout_minutes, data.workout_intensity,
    )

    # Upsert в activity_logs (один раз в день)
    today = date.today()
    log = (db.query(ActivityLog)
           .filter(ActivityLog.firebase_uid == data.firebase_uid,
                   ActivityLog.log_date == today)
           .first())
    if log:
        log.steps             = data.steps
        log.calories          = data.calories
        log.distance_m        = data.distance_m
        log.workout_minutes   = data.workout_minutes
        log.workout_intensity = data.workout_intensity
        log.activity_names    = ",".join(data.activity_names)
        log.goal_ml           = breakdown["total"]
        log.synced_at         = datetime.utcnow()
    else:
        log = ActivityLog(
            firebase_uid      = data.firebase_uid,
            log_date          = today,
            steps             = data.steps,
            calories          = data.calories,
            distance_m        = data.distance_m,
            workout_minutes   = data.workout_minutes,
            workout_intensity = data.workout_intensity,
            activity_names    = ",".join(data.activity_names),
            goal_ml           = breakdown["total"],
        )
        db.add(log)

    db.commit()

    return {
        "firebase_uid":   data.firebase_uid,
        "daily_goal_ml":  breakdown["total"],
        "breakdown": {
            "base_ml":    breakdown["base_ml"],
            "steps_ml":   breakdown["steps_ml"],
            "workout_ml": breakdown["workout_ml"],
        },
        "advice": generate_advice(
            data.steps, data.workout_intensity, data.workout_minutes
        ),
    }


@app.post("/water-log", summary="Сохранить запись о выпитой воде")
def add_water_log(data: WaterLogCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.firebase_uid == data.firebase_uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    log = WaterLog(
        firebase_uid = data.firebase_uid,
        amount_ml    = data.amount_ml,
        logged_at    = data.logged_at or datetime.utcnow(),
    )
    db.add(log)
    db.commit()
    return {"status": "ok", "amount_ml": data.amount_ml}


@app.get("/analytics/{firebase_uid}", summary="Аналитика за N дней")
def get_analytics(firebase_uid: str, days: int = 7, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    # Активность за период
    activity = (db.query(ActivityLog)
                .filter(ActivityLog.firebase_uid == firebase_uid)
                .order_by(ActivityLog.log_date.desc())
                .limit(days).all())

    # Вода за период
    water = (db.query(WaterLog)
             .filter(WaterLog.firebase_uid == firebase_uid)
             .order_by(WaterLog.logged_at.desc())
             .all())

    # Группируем воду по дням
    water_by_day: dict[str, float] = {}
    for w in water:
        key = w.logged_at.strftime("%Y-%m-%d")
        water_by_day[key] = water_by_day.get(key, 0) + w.amount_ml

    # Считаем статистику
    days_data = []
    total_completion = 0
    days_with_data = 0

    for a in activity:
        day_key = a.log_date.strftime("%Y-%m-%d")
        consumed = water_by_day.get(day_key, 0)
        goal = a.goal_ml or 2000
        completion = round(consumed / goal * 100) if goal > 0 else 0

        days_data.append({
            "date":       day_key,
            "consumed_ml": round(consumed),
            "goal_ml":    goal,
            "completion": completion,
            "steps":      a.steps,
            "workout_minutes": a.workout_minutes,
        })
        total_completion += completion
        days_with_data += 1

    avg_completion = round(total_completion / days_with_data) if days_with_data > 0 else 0
    avg_steps = round(sum(d["steps"] for d in days_data) / len(days_data)) if days_data else 0

    best  = max(days_data, key=lambda d: d["completion"], default=None)
    worst = min(days_data, key=lambda d: d["completion"], default=None)

    return {
        "firebase_uid":    firebase_uid,
        "period_days":     days,
        "avg_completion":  avg_completion,
        "avg_steps":       avg_steps,
        "best_day":        best["date"] if best else None,
        "worst_day":       worst["date"] if worst else None,
        "days":            days_data,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
