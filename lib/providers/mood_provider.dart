import 'package:flutter/foundation.dart';
import '../services/mood_analysis_service.dart';
import '../models/journal_file.dart';
import '../models/mood_entry.dart';

class MoodProvider with ChangeNotifier {
  final MoodAnalysisService _moodService = MoodAnalysisService();
  
  bool _isInitialized = false;
  bool _isAnalyzing = false;
  int _analysisProgress = 0;
  int _totalToAnalyze = 0;
  String _analysisStatus = '';
  
  MoodEntry? _currentMoodEntry;
  MoodPattern? _currentPattern;
  Map<String, dynamic> _moodStats = {};
  List<MoodEntry> _recentEntries = [];
  String? _error;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAnalyzing => _isAnalyzing;
  int get analysisProgress => _analysisProgress;
  int get totalToAnalyze => _totalToAnalyze;
  String get analysisStatus => _analysisStatus;
  double get analysisPercentage => _totalToAnalyze > 0 ? (_analysisProgress / _totalToAnalyze) * 100 : 0;
  String? get error => _error;
  
  MoodEntry? get currentMoodEntry => _currentMoodEntry;
  MoodPattern? get currentPattern => _currentPattern;
  Map<String, dynamic> get moodStats => _moodStats;
  List<MoodEntry> get recentEntries => _recentEntries;

  // Initialize the mood analysis system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _error = null;
      await _moodService.initialize();
      await _refreshMoodStats();
      await _loadRecentEntries();
      
      _isInitialized = true;
      notifyListeners();
      debugPrint('Mood provider initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize mood analysis: $e';
      debugPrint('Error initializing mood provider: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Analyze mood for a specific journal file
  Future<MoodEntry?> analyzeMood(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      _error = null;
      _isAnalyzing = true;
      _analysisStatus = 'Analyzing mood for ${journalFile.name}...';
      notifyListeners();
      
      final moodEntry = await _moodService.analyzeMood(journalFile);
      
      if (moodEntry != null) {
        _currentMoodEntry = moodEntry;
        await _refreshMoodStats();
        await _loadRecentEntries();
      }
      
      return moodEntry;
    } catch (e) {
      _error = 'Failed to analyze mood: $e';
      debugPrint('Error analyzing mood: $e');
      return null;
    } finally {
      _isAnalyzing = false;
      _analysisStatus = '';
      notifyListeners();
    }
  }

  // Batch analyze mood for multiple files
  Future<void> batchAnalyzeMood(List<JournalFile> files) async {
    if (!_isInitialized) await initialize();
    if (_isAnalyzing) return;
    
    try {
      _error = null;
      _isAnalyzing = true;
      _analysisProgress = 0;
      _totalToAnalyze = files.length;
      _analysisStatus = 'Starting mood analysis...';
      notifyListeners();
      
      await _moodService.batchAnalyzeMood(
        files,
        progressCallback: (current, total) {
          _analysisProgress = current;
          _totalToAnalyze = total;
          _analysisStatus = 'Analyzing mood... ($current/$total)';
          notifyListeners();
        },
      );
      
      _analysisStatus = 'Analysis completed successfully';
      await _refreshMoodStats();
      await _loadRecentEntries();
    } catch (e) {
      _error = 'Mood analysis failed: $e';
      _analysisStatus = 'Analysis failed';
      debugPrint('Error during batch mood analysis: $e');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // Get mood entry for a specific file
  Future<MoodEntry?> getMoodEntry(String fileId) async {
    if (!_isInitialized) await initialize();
    
    try {
      return await _moodService.getMoodEntry(fileId);
    } catch (e) {
      debugPrint('Error getting mood entry: $e');
      return null;
    }
  }

  // Analyze mood pattern for a date range
  Future<MoodPattern?> analyzeMoodPattern({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      _isAnalyzing = true;
      _analysisStatus = 'Analyzing mood patterns...';
      notifyListeners();
      
      final pattern = await _moodService.analyzeMoodPattern(
        startDate: startDate,
        endDate: endDate,
      );
      
      _currentPattern = pattern;
      return pattern;
    } catch (e) {
      _error = 'Failed to analyze mood patterns: $e';
      debugPrint('Error analyzing mood pattern: $e');
      return null;
    } finally {
      _isAnalyzing = false;
      _analysisStatus = '';
      notifyListeners();
    }
  }

  // Get mood entries for a date range
  Future<List<MoodEntry>> getMoodEntries({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      return await _moodService.getMoodEntries(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    } catch (e) {
      debugPrint('Error getting mood entries: $e');
      return [];
    }
  }

  // Refresh mood statistics
  Future<void> _refreshMoodStats() async {
    try {
      _moodStats = await _moodService.getMoodStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing mood stats: $e');
    }
  }

  // Load recent mood entries
  Future<void> _loadRecentEntries() async {
    try {
      _recentEntries = await _moodService.getMoodEntries(limit: 10);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent entries: $e');
    }
  }

  // Get mood trend summary
  String get moodTrendSummary {
    if (_currentPattern == null) return 'No mood data available';
    
    final pattern = _currentPattern!;
    final valenceStr = pattern.averageValence > 0.2 ? 'positive' : 
                     pattern.averageValence < -0.2 ? 'negative' : 'neutral';
    final arousalStr = pattern.averageArousal > 0.6 ? 'high energy' : 
                     pattern.averageArousal > 0.3 ? 'moderate energy' : 'calm';
    
    return 'Recent mood: $valenceStr and $arousalStr (${pattern.trend})';
  }

  // Get emotion summary
  String get topEmotions {
    if (_currentPattern?.emotionFrequency.isEmpty ?? true) {
      return 'No emotions analyzed yet';
    }
    
    final emotions = _currentPattern!.emotionFrequency.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    return emotions.take(3).map((e) => e.key).join(', ');
  }

  // Check if mood analysis is available
  bool get hasMoodData {
    return (_moodStats['totalEntries'] as int? ?? 0) > 0;
  }

  // Get mood summary for display
  String get moodSummary {
    final totalEntries = _moodStats['totalEntries'] as int? ?? 0;
    if (totalEntries == 0) return 'No mood analysis available';
    
    final avgValence = _moodStats['averageValence'] as double? ?? 0.0;
    final avgArousal = _moodStats['averageArousal'] as double? ?? 0.0;
    final dominantEmotion = _moodStats['dominantEmotion'] as String? ?? 'neutral';
    
    final valenceStr = avgValence > 0.1 ? 'generally positive' :
                      avgValence < -0.1 ? 'generally negative' : 'balanced';
    final arousalStr = avgArousal > 0.5 ? 'energetic' : 'calm';
    
    return '$totalEntries entries • $valenceStr • $arousalStr • $dominantEmotion';
  }

  // Get recent mood description
  String get recentMoodDescription {
    if (_recentEntries.isEmpty) return 'No recent mood data';
    
    final recent = _recentEntries.first;
    return '${recent.valenceMood} mood, ${recent.arousalLevel} energy (${recent.primaryEmotion})';
  }

  // Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Manually refresh all data
  Future<void> refresh() async {
    if (!_isInitialized) return;
    
    try {
      await _refreshMoodStats();
      await _loadRecentEntries();
    } catch (e) {
      _error = 'Failed to refresh mood data: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _moodService.dispose();
    super.dispose();
  }
} 