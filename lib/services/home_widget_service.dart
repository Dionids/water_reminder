import 'dart:io';
import 'package:home_widget/home_widget.dart';

/// Сервис обновления виджета на домашнем экране.
/// Вызывай [update] после каждого добавления воды или пересчёта нормы.
class HomeWidgetService {
  static const _androidName = 'AquaWidgetReceiver';

  static final HomeWidgetService _instance = HomeWidgetService._();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._();

  /// Сохранить данные и обновить виджет.
  Future<void> update({required double currentMl, required double goalMl}) async {
    if (!Platform.isAndroid) return;

    await HomeWidget.saveWidgetData<double>('widget_current_ml', currentMl);
    await HomeWidget.saveWidgetData<double>('widget_goal_ml', goalMl);

    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.example.untitled1.widget.$_androidName',
    );
  }

  /// Запросить у системы добавление виджета на домашний экран.
  /// Показывает системный диалог выбора места для виджета.
  Future<void> requestPin() async {
    if (!Platform.isAndroid) return;
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }
}

/// Фоновый callback для обработки нажатия + в виджете.
/// Должен быть top-level функцией.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'add_water') {
    // Виджет уже обновил SharedPreferences напрямую через AddWaterAction.kt
    // Здесь можно дополнительно синхронизировать с Hive если нужно
  }
}
