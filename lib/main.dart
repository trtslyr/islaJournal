import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Providers
import 'providers/journal_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/layout_provider.dart';
import 'providers/license_provider.dart';

// Services  
import 'services/license_service.dart';
import 'services/windows_stability_service.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/license_screen.dart';

// Theme
import 'core/theme/app_theme.dart';

/// Entry point of the Isla Journal application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Windows stability service first for crash prevention
  if (Platform.isWindows) {
    await WindowsStabilityService.initialize();
  }
  
  // Initialize database factory for Windows/Linux (macOS/iOS/Android work with regular sqflite)
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI for desktop platforms that need it
    sqfliteFfiInit();
    // Set the database factory for Windows/Linux
    databaseFactory = databaseFactoryFfi;
    print('🚀 Starting Isla Journal on ${Platform.operatingSystem} with FFI database support');
  } else {
    print('🚀 Starting Isla Journal on ${Platform.operatingSystem} with native database support');
  }
  
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
        debugPrint('🔍 Main app checking license: ${license.isValid} (${license.licenseStatus?.type})');
        
        // BULLETPROOF: Show main app ONLY if license is valid AND has a valid status
        // This ensures that ANY invalid license state shows the license screen
        if (license.isValid && 
            license.licenseStatus != null && 
            license.licenseStatus!.isValid &&
            (license.licenseStatus!.type == LicenseType.lifetime || 
             license.licenseStatus!.type == LicenseType.subscription)) {
          debugPrint('✅ Showing HomeScreen for valid license');
          return const HomeScreen();
        }
        
        // ALWAYS show license screen for ANY invalid/missing license
        debugPrint('🔒 Showing LicenseScreen - no valid license (isValid: ${license.isValid}, status: ${license.licenseStatus?.type})');
        return LicenseScreen();
      },
    );
  }
}
