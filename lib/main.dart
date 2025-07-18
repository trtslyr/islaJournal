import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/journal_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/layout_provider.dart';
import 'providers/conversation_provider.dart';
import 'screens/home_screen.dart';

/// Entry point of the Isla Journal application
void main() {
  runApp(const IslaJournalApp());
}

/// Main application widget that sets up providers and theme
class IslaJournalApp extends StatelessWidget {
  const IslaJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Journal management provider
        ChangeNotifierProvider(create: (context) => JournalProvider()),
        // AI features provider
        ChangeNotifierProvider(create: (context) => AIProvider()),
        // Layout management provider
        ChangeNotifierProvider(create: (context) => LayoutProvider()),
        // Conversation management provider
        ChangeNotifierProvider(create: (context) => ConversationProvider()),
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
