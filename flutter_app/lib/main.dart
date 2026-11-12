import 'package:flutter/material.dart';

import 'core/navigation/app_router.dart';
import 'core/services/pb_client.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initPb();
  initPbRealtime();
  runApp(const TodoinApp());
}

class TodoinApp extends StatelessWidget {
  const TodoinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'todoin.id',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
