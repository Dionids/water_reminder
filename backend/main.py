from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional

app = FastAPI(title="Water Reminder AI Backend")

class ActivityData(BaseModel):
    user_id: str
    steps: int
    workout_minutes: int
    weight_kg: float = 70.0  # Default if not provided

@app.get("/")
def read_root():
    return {"status": "online", "message": "Water Reminder AI Backend is running"}

@app.post("/sync-activity")
async def sync_activity(data: ActivityData):
    # Dynamic Water Goal Formula
    # base_ml = weight * 30
    # bonus = (steps / 1000) * 100

    base_goal = data.weight_kg * 30
    step_bonus = (data.steps / 1000) * 100
    workout_bonus = (data.workout_minutes / 30) * 500

    total_goal = int(base_goal + step_bonus + workout_bonus)

    return {
        "user_id": data.user_id,
        "daily_goal_ml": total_goal,
        "advice": generate_advice(data.steps)
    }

def generate_advice(steps: int):
    if steps < 3000:
        return "You've been quite sedentary today. Try to take a short walk and drink a glass of water!"
    elif steps > 10000:
        return "Great job on the steps! You're very active today, make sure to stay hydrated."
    else:
        return "Keep it up! Regular hydration is key to your energy levels."

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
