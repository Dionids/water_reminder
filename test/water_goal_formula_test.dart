import 'package:flutter_test/flutter_test.dart';
import 'package:untitled1/services/health_service.dart';

// Вспомогательная функция — зеркало _recalculateGoal из main.dart.
// Если формула изменится в main.dart — меняй и здесь, и в backend/main.py.
Map<String, int> calculateWaterGoal({
  required double weightKg,
  required int steps,
  required int workoutMinutes,
  required WorkoutIntensity intensity,
}) {
  const mlPerHour = {
    WorkoutIntensity.none:    0,
    WorkoutIntensity.low:     200,
    WorkoutIntensity.medium:  400,
    WorkoutIntensity.high:    600,
    WorkoutIntensity.extreme: 900,
  };
  final base    = (weightKg * 30).toInt();
  final stepsB  = ((steps / 1000) * 50).toInt();
  final workout = ((mlPerHour[intensity]! * workoutMinutes) / 60).toInt();
  return {
    'base':    base,
    'steps':   stepsB,
    'workout': workout,
    'total':   base + stepsB + workout,
  };
}

void main() {
  group('Формула нормы воды — базовый расчёт (ВОЗ)', () {
    test('70 кг → 2100 мл базы', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['base'], 2100);
      expect(r['total'], 2100);
    });

    test('50 кг → 1500 мл базы', () {
      final r = calculateWaterGoal(
        weightKg: 50, steps: 0,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['base'], 1500);
    });

    test('100 кг → 3000 мл базы', () {
      final r = calculateWaterGoal(
        weightKg: 100, steps: 0,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['base'], 3000);
    });
  });

  group('Формула нормы воды — бонус за шаги (ACSM)', () {
    test('1000 шагов → +50 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 1000,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['steps'], 50);
    });

    test('10 000 шагов → +500 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 10000,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['steps'], 500);
    });

    test('500 шагов → +25 мл (целочисленное усечение)', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 500,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['steps'], 25);
    });

    test('0 шагов → 0 бонуса', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['steps'], 0);
    });
  });

  group('Формула нормы воды — бонус за тренировку (NSCA)', () {
    test('none: 60 мин → 0 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 60, intensity: WorkoutIntensity.none,
      );
      expect(r['workout'], 0);
    });

    test('low: 60 мин → 200 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 60, intensity: WorkoutIntensity.low,
      );
      expect(r['workout'], 200);
    });

    test('medium: 60 мин → 400 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 60, intensity: WorkoutIntensity.medium,
      );
      expect(r['workout'], 400);
    });

    test('high: 60 мин → 600 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 60, intensity: WorkoutIntensity.high,
      );
      expect(r['workout'], 600);
    });

    test('extreme: 60 мин → 900 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 60, intensity: WorkoutIntensity.extreme,
      );
      expect(r['workout'], 900);
    });

    test('high: 30 мин → 300 мл (половина часа)', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 30, intensity: WorkoutIntensity.high,
      );
      expect(r['workout'], 300);
    });

    test('extreme: 45 мин → 675 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 45, intensity: WorkoutIntensity.extreme,
      );
      expect(r['workout'], 675);
    });

    test('0 минут тренировки → 0 мл независимо от интенсивности', () {
      for (final intensity in WorkoutIntensity.values) {
        final r = calculateWaterGoal(
          weightKg: 70, steps: 0,
          workoutMinutes: 0, intensity: intensity,
        );
        expect(r['workout'], 0,
            reason: 'intensity=$intensity должна давать 0 при 0 минутах');
      }
    });
  });

  group('Формула нормы воды — комплексные сценарии', () {
    test('Типичный активный день: 75 кг, 8000 шагов, high 45 мин', () {
      // base = 75*30 = 2250
      // steps = (8000/1000)*50 = 400
      // workout = 600*(45/60) = 450
      // total = 3100
      final r = calculateWaterGoal(
        weightKg: 75, steps: 8000,
        workoutMinutes: 45, intensity: WorkoutIntensity.high,
      );
      expect(r['base'],    2250);
      expect(r['steps'],   400);
      expect(r['workout'], 450);
      expect(r['total'],   3100);
    });

    test('Спортсмен: 90 кг, 15000 шагов, extreme 90 мин', () {
      // base = 90*30 = 2700
      // steps = (15000/1000)*50 = 750
      // workout = 900*(90/60) = 1350
      // total = 4800
      final r = calculateWaterGoal(
        weightKg: 90, steps: 15000,
        workoutMinutes: 90, intensity: WorkoutIntensity.extreme,
      );
      expect(r['base'],    2700);
      expect(r['steps'],   750);
      expect(r['workout'], 1350);
      expect(r['total'],   4800);
    });

    test('Офисный день: 60 кг, 2000 шагов, нет тренировки', () {
      // base = 60*30 = 1800
      // steps = (2000/1000)*50 = 100
      // workout = 0
      // total = 1900
      final r = calculateWaterGoal(
        weightKg: 60, steps: 2000,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['base'],    1800);
      expect(r['steps'],   100);
      expect(r['workout'], 0);
      expect(r['total'],   1900);
    });

    test('Итог всегда равен сумме компонентов', () {
      final cases = [
        (70.0, 5000, 30, WorkoutIntensity.medium),
        (85.0, 12000, 60, WorkoutIntensity.high),
        (55.0, 0, 0, WorkoutIntensity.none),
      ];
      for (final c in cases) {
        final r = calculateWaterGoal(
          weightKg: c.$1, steps: c.$2,
          workoutMinutes: c.$3, intensity: c.$4,
        );
        expect(r['total'], r['base']! + r['steps']! + r['workout']!,
            reason: 'total должен равняться base+steps+workout');
      }
    });
  });

  group('Синхронность Dart ↔ Python (граничные значения)', () {
    // Эти тесты документируют поведение целочисленного усечения,
    // чтобы Dart и Python давали одинаковые результаты.

    test('Дробные шаги усекаются, не округляются: 1500 шагов → 75 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 1500,
        workoutMinutes: 0, intensity: WorkoutIntensity.none,
      );
      expect(r['steps'], 75); // 1500/1000*50 = 75.0 → 75
    });

    test('Дробные минуты тренировки усекаются: high 20 мин → 200 мл', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 20, intensity: WorkoutIntensity.high,
      );
      // 600 * (20/60) = 200.0 → 200
      expect(r['workout'], 200);
    });

    test('extreme 10 мин → 150 мл (900 * 10/60 = 150.0)', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 10, intensity: WorkoutIntensity.extreme,
      );
      expect(r['workout'], 150);
    });

    test('medium 40 мин → 266 мл (400 * 40/60 = 266.6 → truncate)', () {
      final r = calculateWaterGoal(
        weightKg: 70, steps: 0,
        workoutMinutes: 40, intensity: WorkoutIntensity.medium,
      );
      expect(r['workout'], 266); // toInt() усекает, не округляет
    });
  });
}
