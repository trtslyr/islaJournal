import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers
import 'providers/journal_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/layout_provider.dart';
import 'providers/license_provider.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/license_screen.dart';

// Theme
import 'core/theme/app_theme.dart';

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
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => AIProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => LayoutProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider()),
      ],
              child: MaterialApp(
          title: 'Isla Journal',
          theme: AppTheme.theme,
          home: LicenseCheckWrapper(),
        routes: {
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/license': (context) => LicenseScreen(),
        },
      ),
    );
  }
}

class LicenseCheckWrapper extends StatefulWidget {
  @override
  State<LicenseCheckWrapper> createState() => _LicenseCheckWrapperState();
}

class _LicenseCheckWrapperState extends State<LicenseCheckWrapper> {
  bool _isChecking = true;
  
  @override
  void initState() {
    super.initState();
    _checkLicenseStatus();
  }
  
  Future<void> _checkLicenseStatus() async {
    final licenseProvider = Provider.of<LicenseProvider>(context, listen: false);
    await licenseProvider.initialize();
    
    setState(() {
      _isChecking = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: AppTheme.creamBeige,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'isla journal',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.warmBrown),
              ),
              SizedBox(height: 16),
              Text(
                'Starting up...',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Consumer<LicenseProvider>(
      builder: (context, license, child) {
        // Show main app for licensed users (lifetime, subscription, or active trial)
        if (license.isValid || license.isTrial) {
          return const HomeScreen();
        }
        
        // Only show license screen if trial has actually expired or unlicensed
        if (license.needsLicense) {
          return LicenseScreen();
        }
        
        // Default: show main app (be generous to users during trial)
        return const HomeScreen();
      },
    );
  }
}
