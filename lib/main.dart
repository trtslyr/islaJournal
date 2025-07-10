import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/journal_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IslaJournalApp());
}

class IslaJournalApp extends StatelessWidget {
  const IslaJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => JournalProvider(),
      child: MaterialApp(
        title: 'Isla Journal',
        theme: AppTheme.theme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
