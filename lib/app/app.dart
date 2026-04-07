import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/router/app_router.dart';
import '../features/shared_location/shared_location_handler.dart';

class YatraApp extends ConsumerStatefulWidget {
  const YatraApp({super.key});

  @override
  ConsumerState<YatraApp> createState() => _YatraAppState();
}

class _YatraAppState extends ConsumerState<YatraApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize shared location handler for WhatsApp/other app links and invite deep links
    SharedLocationHandler.init(ref, navigatorKey: _navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yatra Planner',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
