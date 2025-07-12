import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'providers/journal_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/rag_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/auto_tagging_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
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
        home: const AppInitializer(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _isLoading = true;
  String _error = '';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize all providers in sequence
      await _initializeProviders();
      
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize app: $e';
        _isLoading = false;
      });
      debugPrint('App initialization error: $e');
    }
  }

  Future<void> _initializeProviders() async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final aiProvider = Provider.of<AIProvider>(context, listen: false);
    final ragProvider = Provider.of<RAGProvider>(context, listen: false);
    final moodProvider = Provider.of<MoodProvider>(context, listen: false);
    final autoTaggingProvider = Provider.of<AutoTaggingProvider>(context, listen: false);

    // Step 1: Initialize journal provider (core functionality)
    setState(() {
      _progress = 0.1;
    });
    await journalProvider.initialize();
    debugPrint('Journal provider initialized');

    // Step 2: Initialize AI provider (optional, may fail if Ollama not running)
    setState(() {
      _progress = 0.3;
    });
    try {
      await aiProvider.initialize();
      debugPrint('AI provider initialized');
    } catch (e) {
      debugPrint('AI provider initialization failed (optional): $e');
    }

    // Step 3: Initialize mood provider
    setState(() {
      _progress = 0.5;
    });
    try {
      await moodProvider.initialize();
      debugPrint('Mood provider initialized');
    } catch (e) {
      debugPrint('Mood provider initialization failed: $e');
    }

    // Step 4: Initialize auto-tagging provider
    setState(() {
      _progress = 0.7;
    });
    try {
      await autoTaggingProvider.initialize();
      debugPrint('Auto-tagging provider initialized');
    } catch (e) {
      debugPrint('Auto-tagging provider initialization failed: $e');
    }

    // Step 5: Initialize RAG provider (requires AI provider)
    setState(() {
      _progress = 0.9;
    });
    try {
      await ragProvider.initialize();
      debugPrint('RAG provider initialized');
    } catch (e) {
      debugPrint('RAG provider initialization failed: $e');
    }

    setState(() {
      _progress = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.creamBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo/Icon placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.warmBrown,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.book,
                  size: 50,
                  color: AppTheme.white,
                ),
              ),
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'Isla Journal',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppTheme.warmBrown,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                'AI-Powered Private Journaling',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(height: 48),
              
              // Progress indicator
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.darkerCream,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                ),
              ),
              const SizedBox(height: 16),
              
              // Progress text
              Text(
                'Initializing... ${(_progress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mediumGray,
                ),
              ),
              
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.warningRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warningRed.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning,
                        color: AppTheme.warningRed,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.warningRed,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = '';
                            _isLoading = true;
                            _progress = 0.0;
                          });
                          _initializeApp();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppTheme.creamBeige,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.warningRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Initialization Failed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.mediumGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = '';
                    _isLoading = true;
                    _progress = 0.0;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
