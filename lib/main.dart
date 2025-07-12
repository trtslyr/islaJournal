import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/journal_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/rag_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/auto_tagging_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const IslaJournalApp());
}

class IslaJournalApp extends StatelessWidget {
  const IslaJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => JournalProvider()),
        ChangeNotifierProvider(create: (context) => AIProvider()),
        ChangeNotifierProvider(create: (context) => RAGProvider()),
        ChangeNotifierProvider(create: (context) => MoodProvider()),
        ChangeNotifierProvider(create: (context) => AutoTaggingProvider()),
      ],
      child: MaterialApp(
        title: 'Isla Journal',
        theme: AppTheme.theme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
