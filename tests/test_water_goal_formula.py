"""
Тесты формулы расчёта нормы воды (backend/main.py → calculate_water_goal).

Запуск:
    cd backend
    pip install pytest
    pytest ../tests/test_water_goal_formula.py -v

Эти тесты зеркалят test/water_goal_formula_test.dart.
Если формула меняется — менять оба файла и backend/main.py одновременно.
"""

import sys
import os

# Добавляем backend/ в путь импорта
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from main import calculate_water_goal, INTENSITY_ML_PER_HOUR


# ─────────────────────────────────────────────────────────────────────────────
# Базовый расчёт (ВОЗ: weight_kg × 30)
# ─────────────────────────────────────────────────────────────────────────────

class TestBaseCalculation:
    def test_70kg_gives_2100_base(self):
        r = calculate_water_goal(70, 0, 0, "none")
        assert r["base_ml"] == 2100
        assert r["total"] == 2100

    def test_50kg_gives_1500_base(self):
        r = calculate_water_goal(50, 0, 0, "none")
        assert r["base_ml"] == 1500

    def test_100kg_gives_3000_base(self):
        r = calculate_water_goal(100, 0, 0, "none")
        assert r["base_ml"] == 3000


# ─────────────────────────────────────────────────────────────────────────────
# Бонус за шаги (ACSM: steps / 1000 × 50)
# ─────────────────────────────────────────────────────────────────────────────

class TestStepsBonus:
    def test_1000_steps_gives_50ml(self):
        r = calculate_water_goal(70, 1000, 0, "none")
        assert r["steps_ml"] == 50

    def test_10000_steps_gives_500ml(self):
        r = calculate_water_goal(70, 10000, 0, "none")
        assert r["steps_ml"] == 500

    def test_500_steps_gives_25ml(self):
        r = calculate_water_goal(70, 500, 0, "none")
        assert r["steps_ml"] == 25

    def test_0_steps_gives_0ml(self):
        r = calculate_water_goal(70, 0, 0, "none")
        assert r["steps_ml"] == 0


# ─────────────────────────────────────────────────────────────────────────────
# Бонус за тренировку (NSCA: intensity_ml_per_hour × minutes / 60)
# ─────────────────────────────────────────────────────────────────────────────

class TestWorkoutBonus:
    def test_none_60min_gives_0ml(self):
        r = calculate_water_goal(70, 0, 60, "none")
        assert r["workout_ml"] == 0

    def test_low_60min_gives_200ml(self):
        r = calculate_water_goal(70, 0, 60, "low")
        assert r["workout_ml"] == 200

    def test_medium_60min_gives_400ml(self):
        r = calculate_water_goal(70, 0, 60, "medium")
        assert r["workout_ml"] == 400

    def test_high_60min_gives_600ml(self):
        r = calculate_water_goal(70, 0, 60, "high")
        assert r["workout_ml"] == 600

    def test_extreme_60min_gives_900ml(self):
        r = calculate_water_goal(70, 0, 60, "extreme")
        assert r["workout_ml"] == 900

    def test_high_30min_gives_300ml(self):
        r = calculate_water_goal(70, 0, 30, "high")
        assert r["workout_ml"] == 300

    def test_extreme_45min_gives_675ml(self):
        r = calculate_water_goal(70, 0, 45, "extreme")
        assert r["workout_ml"] == 675

    def test_0_minutes_gives_0_for_all_intensities(self):
        for intensity in INTENSITY_ML_PER_HOUR:
            r = calculate_water_goal(70, 0, 0, intensity)
            assert r["workout_ml"] == 0, \
                f"intensity={intensity} с 0 минутами должна давать 0"

    def test_unknown_intensity_gives_0(self):
        r = calculate_water_goal(70, 0, 60, "ultra")  # несуществующая
        assert r["workout_ml"] == 0


# ─────────────────────────────────────────────────────────────────────────────
# Комплексные сценарии
# ─────────────────────────────────────────────────────────────────────────────

class TestComplexScenarios:
    def test_active_day_75kg_8000steps_high_45min(self):
        # base = 75*30 = 2250
        # steps = (8000/1000)*50 = 400
        # workout = 600*(45/60) = 450
        # total = 3100
        r = calculate_water_goal(75, 8000, 45, "high")
        assert r["base_ml"]    == 2250
        assert r["steps_ml"]   == 400
        assert r["workout_ml"] == 450
        assert r["total"]      == 3100

    def test_athlete_90kg_15000steps_extreme_90min(self):
        # base = 90*30 = 2700
        # steps = (15000/1000)*50 = 750
        # workout = 900*(90/60) = 1350
        # total = 4800
        r = calculate_water_goal(90, 15000, 90, "extreme")
        assert r["base_ml"]    == 2700
        assert r["steps_ml"]   == 750
        assert r["workout_ml"] == 1350
        assert r["total"]      == 4800

    def test_office_day_60kg_2000steps_no_workout(self):
        # base = 60*30 = 1800
        # steps = (2000/1000)*50 = 100
        # total = 1900
        r = calculate_water_goal(60, 2000, 0, "none")
        assert r["base_ml"]    == 1800
        assert r["steps_ml"]   == 100
        assert r["workout_ml"] == 0
        assert r["total"]      == 1900

    def test_total_always_equals_sum_of_components(self):
        cases = [
            (70.0, 5000, 30, "medium"),
            (85.0, 12000, 60, "high"),
            (55.0, 0, 0, "none"),
            (95.0, 20000, 120, "extreme"),
        ]
        for weight, steps, minutes, intensity in cases:
            r = calculate_water_goal(weight, steps, minutes, intensity)
            expected = r["base_ml"] + r["steps_ml"] + r["workout_ml"]
            assert r["total"] == expected, \
                f"total должен быть {expected}, получили {r['total']}"


# ─────────────────────────────────────────────────────────────────────────────
# Синхронность Dart ↔ Python (целочисленное усечение)
# ─────────────────────────────────────────────────────────────────────────────

class TestDartPythonParity:
    """
    Оба языка используют int() — усечение, не округление.
    Тесты документируют ожидаемое поведение чтобы не разъехаться.
    """

    def test_1500_steps_gives_75ml(self):
        r = calculate_water_goal(70, 1500, 0, "none")
        assert r["steps_ml"] == 75  # 1500/1000*50 = 75.0 → 75

    def test_high_20min_gives_200ml(self):
        r = calculate_water_goal(70, 0, 20, "high")
        assert r["workout_ml"] == 200  # 600*(20/60) = 200.0

    def test_extreme_10min_gives_150ml(self):
        r = calculate_water_goal(70, 0, 10, "extreme")
        assert r["workout_ml"] == 150  # 900*(10/60) = 150.0

    def test_medium_40min_truncates_to_266(self):
        r = calculate_water_goal(70, 0, 40, "medium")
        assert r["workout_ml"] == 266  # 400*(40/60) = 266.66 → int() = 266

    def test_low_40min_truncates_to_133(self):
        r = calculate_water_goal(70, 0, 40, "low")
        assert r["workout_ml"] == 133  # 200*(40/60) = 133.33 → int() = 133


# ─────────────────────────────────────────────────────────────────────────────
# Константы интенсивности
# ─────────────────────────────────────────────────────────────────────────────

class TestIntensityConstants:
    """Проверяем что INTENSITY_ML_PER_HOUR содержит все ожидаемые значения."""

    def test_all_intensities_present(self):
        expected = {"none", "low", "medium", "high", "extreme"}
        assert set(INTENSITY_ML_PER_HOUR.keys()) == expected

    def test_intensity_values(self):
        assert INTENSITY_ML_PER_HOUR["none"]    == 0
        assert INTENSITY_ML_PER_HOUR["low"]     == 200
        assert INTENSITY_ML_PER_HOUR["medium"]  == 400
        assert INTENSITY_ML_PER_HOUR["high"]    == 600
        assert INTENSITY_ML_PER_HOUR["extreme"] == 900
