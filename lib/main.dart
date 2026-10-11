import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'db/database_helper.dart';

void main() async {
  // Ensure Flutter bindings are initialized before any async work
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the SQLite database (creates tables + seeds data on first run)
  await DatabaseHelper.instance.database;

  runApp(
    // ProviderScope is required for Riverpod state management
    const ProviderScope(
      child: FinanceApp(),
    ),
  );
}
