from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI(title="Water Reminder AI Backend")


# ──────────────────────────────────────────────
# Модели запросов
# ──────────────────────────────────────────────

class ActivityData(BaseModel):
    user_id: str
    steps: int
    weight_kg: float = 70.0
    workout_minutes: int = 0
    workout_intensity: str = "none"   # none | low | medium | high | extreme
    activity_names: List[str] = []


# ──────────────────────────────────────────────
# Формула расчёта нормы воды
#
# Источники:
#   • Базовая норма: ВОЗ — 30 мл/кг массы тела
#   • Шаги: ACSM — +50 мл на каждые 1 000 шагов
#   • Тренировка: NSCA — потери пота по зонам ЧСС/МЕТ:
#       low     → 200 мл/час (ходьба, йога)
#       medium  → 400 мл/час (походы, танцы)
#       high    → 600 мл/час (бег, велосипед, плавание)
#       extreme → 900 мл/час (HIIT, бокс, кроссфит)
# ──────────────────────────────────────────────

INTENSITY_ML_PER_HOUR = {
    "none":    0,
    "low":     200,
    "medium":  400,
    "high":    600,
    "extreme": 900,
}


def calculate_water_goal(
    weight_kg: float,
    steps: int,
    workout_minutes: int,
    workout_intensity: str,
) -> dict:
    base_goal     = weight_kg * 30
    steps_bonus   = (steps / 1000) * 50
    ml_per_hour   = INTENSITY_ML_PER_HOUR.get(workout_intensity, 0)
    workout_bonus = ml_per_hour * (workout_minutes / 60)

    total = int(base_goal + steps_bonus + workout_bonus)

    return {
        "base_goal_ml":     int(base_goal),
        "steps_bonus_ml":   int(steps_bonus),
        "workout_bonus_ml": int(workout_bonus),
        "total_goal_ml":    total,
    }


def generate_advice(steps: int, workout_intensity: str, workout_minutes: int) -> str:
    if workout_intensity in ("high", "extreme") and workout_minutes > 0:
        return (
            f"Интенсивная тренировка {workout_minutes} мин — "
            "пейте воду каждые 15–20 минут активности!"
        )
    if steps > 10_000:
        return "Отличный результат по шагам! Не забывайте восполнять жидкость."
    if steps < 3_000:
        return "Сегодня малоактивный день — старайтесь делать небольшие прогулки."
    return "Хороший темп! Равномерно пейте воду в течение дня."


# ──────────────────────────────────────────────
# Эндпоинты
# ──────────────────────────────────────────────

@app.get("/")
def read_root():
    return {"status": "online", "message": "Water Reminder Backend is running"}


@app.post("/sync-activity")
async def sync_activity(data: ActivityData):
    breakdown = calculate_water_goal(
        weight_kg=data.weight_kg,
        steps=data.steps,
        workout_minutes=data.workout_minutes,
        workout_intensity=data.workout_intensity,
    )

    activities_str = ", ".join(data.activity_names) if data.activity_names else "—"

    return {
        "user_id":          data.user_id,
        "daily_goal_ml":    breakdown["total_goal_ml"],
        "breakdown": {
            "base_ml":    breakdown["base_goal_ml"],
            "steps_ml":   breakdown["steps_bonus_ml"],
            "workout_ml": breakdown["workout_bonus_ml"],
        },
        "workout_intensity": data.workout_intensity,
        "workout_minutes":   data.workout_minutes,
        "activities":        activities_str,
        "advice":            generate_advice(
            data.steps, data.workout_intensity, data.workout_minutes
        ),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
