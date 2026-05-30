import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/alert_service.dart';
import 'services/app_navigator.dart';
import 'services/app_theme_controller.dart';
import 'services/usb_camera_coordinator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.instance.init();
  await AppThemeController.instance.load();
  UsbCameraCoordinator.instance.startListening();
  runApp(const EfpicLiveApp());
}

class EfpicLiveApp extends StatelessWidget {
  const EfpicLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        final theme = AppThemeController.instance;
        return MaterialApp(
          title: 'EFPIC LIVE',
          debugShowCheckedModeBanner: false,
          navigatorKey: AppNavigator.rootKey,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
