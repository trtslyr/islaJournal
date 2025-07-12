import 'package:flutter/foundation.dart';
import '../services/mood_analysis_service.dart';
import '../models/journal_file.dart';

class MoodProvider with ChangeNotifier {
  final MoodAnalysisService _moodService = MoodAnalysisService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';
  MoodAnalysis? _currentAnalysis;
  List<MoodTrend> _trends = [];
  MoodInsights? _insights;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  MoodAnalysis? get currentAnalysis => _currentAnalysis;
  List<MoodTrend> get trends => _trends;
  MoodInsights? get insights => _insights;

  /// Initialize mood service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      await _moodService.initialize();
      _isInitialized = true;
      await _loadRecentInsights();
      debugPrint('Mood Provider initialized successfully');
    } catch (e) {
      _setError('Mood service initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Analyze mood for a journal entry
  Future<MoodAnalysis?> analyzeEntry(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final analysis = await _moodService.analyzeEntry(file);
      _currentAnalysis = analysis;
      await _loadRecentInsights(); // Refresh insights
      return analysis;
    } catch (e) {
      _setError('Mood analysis error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get mood analysis for a file
  Future<MoodAnalysis?> getAnalysis(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    try {
      final analysis = await _moodService.getAnalysis(fileId);
      if (analysis != null) {
        _currentAnalysis = analysis;
        notifyListeners();
      }
      return analysis;
    } catch (e) {
      _setError('Error getting mood analysis: $e');
      return null;
    }
  }

  /// Get mood trends
  Future<void> loadTrends({
    DateTime? startDate,
    DateTime? endDate,
    String? emotion,
  }) async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      _trends = await _moodService.getTrends(
        startDate: startDate,
        endDate: endDate,
        emotion: emotion,
      );
    } catch (e) {
      _setError('Error loading mood trends: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load recent insights
  Future<void> _loadRecentInsights() async {
    try {
      _insights = await _moodService.getInsights(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent insights: $e');
    }
  }

  /// Get insights for a specific period
  Future<MoodInsights?> getInsights({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final insights = await _moodService.getInsights(
        startDate: startDate,
        endDate: endDate,
      );
      _insights = insights;
      return insights;
    } catch (e) {
      _setError('Error getting mood insights: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Analyze all entries
  Future<void> analyzeAllEntries() async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      await _moodService.analyzeAllEntries();
      await _loadRecentInsights();
    } catch (e) {
      _setError('Error analyzing all entries: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete mood analysis
  Future<void> deleteAnalysis(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Mood service not initialized');
    }

    try {
      await _moodService.deleteAnalysis(fileId);
      if (_currentAnalysis?.fileId == fileId) {
        _currentAnalysis = null;
        notifyListeners();
      }
    } catch (e) {
      _setError('Error deleting mood analysis: $e');
    }
  }

  /// Get mood summary text
  String getMoodSummary() {
    if (_insights == null) return 'No mood data available';

    final insights = _insights!;
    final emotion = insights.mostCommonEmotion;
    final positivity = insights.averagePositivity;
    final positivityText = positivity > 0.5 ? 'positive' : 
                          positivity < -0.5 ? 'negative' : 'neutral';

    return 'Your most common emotion is $emotion with an overall $positivityText mood trend.';
  }

  /// Get mood color based on emotion
  String getMoodColor(String emotion) {
    const moodColors = {
      'joy': '#FFD700',
      'love': '#FF69B4',
      'gratitude': '#32CD32',
      'excitement': '#FF4500',
      'contentment': '#87CEEB',
      'pride': '#9370DB',
      'hope': '#98FB98',
      'sadness': '#4682B4',
      'anger': '#DC143C',
      'fear': '#696969',
      'anxiety': '#FF6347',
      'frustration': '#B22222',
      'loneliness': '#778899',
      'shame': '#DDA0DD',
      'surprise': '#FFB6C1',
      'disgust': '#8FBC8F',
    };

    return moodColors[emotion.toLowerCase()] ?? '#87CEEB';
  }

  /// Get trending emotions for the past week
  List<String> getTrendingEmotions() {
    if (_insights == null) return [];
    return _insights!.trendingEmotions;
  }

  /// Get weekly mood pattern
  List<MoodTrend> getWeeklyPattern() {
    if (_trends.isEmpty) return [];
    
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return _trends.where((trend) => 
      trend.date.isAfter(weekStart) && 
      trend.date.isBefore(now.add(const Duration(days: 1)))
    ).toList();
  }

  /// Get emotion frequency chart data
  Map<String, int> getEmotionFrequency() {
    if (_insights == null) return {};
    return _insights!.emotionFrequency;
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('Mood Provider Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = '';
    notifyListeners();
  }

  /// Cleanup
  @override
  void dispose() {
    _moodService.dispose();
    super.dispose();
  }
}