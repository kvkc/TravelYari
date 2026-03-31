import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'app/app.dart';
import 'core/services/storage_service.dart';
import 'core/services/firebase/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await StorageService.init();

  // Initialize Firebase (non-blocking - app works offline without it)
  await FirebaseService.initialize();

  runApp(
    const ProviderScope(
      child: YatraApp(),
    ),
  );
}
