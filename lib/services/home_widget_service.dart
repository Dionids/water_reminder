import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис обновления виджета на домашнем экране.
/// Вызывай [update] после каждого добавления воды или пересчёта нормы.
class HomeWidgetService {
  static const _androidName = 'AquaWidgetReceiver';

  static final HomeWidgetService _instance = HomeWidgetService._();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._();

  /// Сохранить данные и обновить виджет.
  ///
  /// Используем Flutter SharedPreferences напрямую — так данные гарантированно
  /// попадают в FlutterSharedPreferences под ключами "flutter.widget_*"
  /// в виде Int, которые нативный AquaWidget.kt читает через getInt().
  Future<void> update({required double currentMl, required double goalMl}) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('widget_current_ml', currentMl.toInt());
      await prefs.setInt('widget_goal_ml', goalMl.toInt());

      // Триггер обновления виджета через home_widget
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.untitled1.widget.$_androidName',
      );
    } catch (e) {
      // Не критично если виджет не обновился
    }
  }

  /// Запросить у системы добавление виджета на домашний экран.
  Future<void> requestPin() async {
    if (!Platform.isAndroid) return;
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  }
}

/// Фоновый callback для обработки нажатия + в виджете.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // Виджет обновляет SharedPreferences напрямую через AddWaterAction.kt
}
