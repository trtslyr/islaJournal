import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/mood_analysis_service.dart';
import '../models/journal_file.dart';

class WritingStats {
  final int totalEntries;
  final int totalWords;
  final double averageWordsPerEntry;
  final int writingDays;
  final double entriesPerWeek;
  final Map<String, int> writingByDayOfWeek;
  final Map<String, int> writingByMonth;
  final List<Map<String, dynamic>> longestEntries;
  final List<Map<String, dynamic>> recentActivity;

  WritingStats({
    required this.totalEntries,
    required this.totalWords,
    required this.averageWordsPerEntry,
    required this.writingDays,
    required this.entriesPerWeek,
    required this.writingByDayOfWeek,
    required this.writingByMonth,
    required this.longestEntries,
    required this.recentActivity,
  });
}

class MoodTrends {
  final double averageValence;
  final double averageArousal;
  final Map<String, int> emotionFrequency;
  final List<Map<String, dynamic>> moodOverTime;
  final String predominantMood;
  final double moodStability;
  final List<String> insights;

  MoodTrends({
    required this.averageValence,
    required this.averageArousal,
    required this.emotionFrequency,
    required this.moodOverTime,
    required this.predominantMood,
    required this.moodStability,
    required this.insights,
  });
}

class ThemeAnalysis {
  final List<Map<String, dynamic>> topThemes;
  final List<Map<String, dynamic>> topTags;
  final Map<String, double> themeEvolution;
  final List<String> emergingTopics;
  final Map<String, List<String>> themeConnections;

  ThemeAnalysis({
    required this.topThemes,
    required this.topTags,
    required this.themeEvolution,
    required this.emergingTopics,
    required this.themeConnections,
  });
}

class GrowthInsights {
  final double writingConsistency;
  final double emotionalGrowth;
  final double thematicDiversity;
  final List<String> personalityTraits;
  final List<String> growthAreas;
  final List<Map<String, dynamic>> milestones;
  final String overallTrend;

  GrowthInsights({
    required this.writingConsistency,
    required this.emotionalGrowth,
    required this.thematicDiversity,
    required this.personalityTraits,
    required this.growthAreas,
    required this.milestones,
    required this.overallTrend,
  });
}

class PersonalInsightsDashboard {
  final WritingStats writingStats;
  final MoodTrends moodTrends;
  final ThemeAnalysis themeAnalysis;
  final GrowthInsights growthInsights;
  final DateTime generatedAt;
  final String timeRange;

  PersonalInsightsDashboard({
    required this.writingStats,
    required this.moodTrends,
    required this.themeAnalysis,
    required this.growthInsights,
    required this.generatedAt,
    required this.timeRange,
  });
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final DatabaseService _dbService = DatabaseService();
  final MoodAnalysisService _moodService = MoodAnalysisService();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _moodService.initialize();
      
      _isInitialized = true;
      debugPrint('Analytics Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing analytics service: $e');
      throw Exception('Failed to initialize analytics service: $e');
    }
  }

  // Generate comprehensive personal insights dashboard
  Future<PersonalInsightsDashboard> generateInsightsDashboard({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final timeRange = _getTimeRangeDescription(startDate, endDate);
      debugPrint('Generating insights dashboard for: $timeRange');
      
      // Generate all analytics in parallel for better performance
      final results = await Future.wait([
        generateWritingStats(startDate: startDate, endDate: endDate),
        generateMoodTrends(startDate: startDate, endDate: endDate),
        generateThemeAnalysis(startDate: startDate, endDate: endDate),
        generateGrowthInsights(startDate: startDate, endDate: endDate),
      ]);

      return PersonalInsightsDashboard(
        writingStats: results[0] as WritingStats,
        moodTrends: results[1] as MoodTrends,
        themeAnalysis: results[2] as ThemeAnalysis,
        growthInsights: results[3] as GrowthInsights,
        generatedAt: DateTime.now(),
        timeRange: timeRange,
      );
    } catch (e) {
      debugPrint('Error generating insights dashboard: $e');
      rethrow;
    }
  }

  // Generate writing statistics
  Future<WritingStats> generateWritingStats({DateTime? startDate, DateTime? endDate}) async {
    try {
      final files = await _getFilesInDateRange(startDate, endDate);
      
      if (files.isEmpty) {
        return WritingStats(
          totalEntries: 0,
          totalWords: 0,
          averageWordsPerEntry: 0,
          writingDays: 0,
          entriesPerWeek: 0,
          writingByDayOfWeek: {},
          writingByMonth: {},
          longestEntries: [],
          recentActivity: [],
        );
      }

      // Calculate basic stats
      final totalEntries = files.length;
      final totalWords = files.fold<int>(0, (sum, file) => sum + file.wordCount);
      final averageWordsPerEntry = totalWords / totalEntries;

      // Calculate writing days and frequency
      final writingDates = files.map((f) => _dateOnly(f.createdAt)).toSet();
      final writingDays = writingDates.length;
      
      final daysBetween = endDate != null && startDate != null 
          ? endDate.difference(startDate).inDays + 1
          : writingDays;
      
      final entriesPerWeek = (totalEntries / daysBetween) * 7;

      // Writing patterns by day of week
      final writingByDayOfWeek = <String, int>{};
      for (final file in files) {
        final dayName = _getDayName(file.createdAt.weekday);
        writingByDayOfWeek[dayName] = (writingByDayOfWeek[dayName] ?? 0) + 1;
      }

      // Writing patterns by month
      final writingByMonth = <String, int>{};
      for (final file in files) {
        final monthKey = '${file.createdAt.year}-${file.createdAt.month.toString().padLeft(2, '0')}';
        writingByMonth[monthKey] = (writingByMonth[monthKey] ?? 0) + 1;
      }

      // Longest entries
      final sortedByLength = List<JournalFile>.from(files)
        ..sort((a, b) => b.wordCount.compareTo(a.wordCount));
      
      final longestEntries = sortedByLength.take(5).map((file) => {
        'name': file.name,
        'wordCount': file.wordCount,
        'date': file.createdAt.toIso8601String(),
      }).toList();

      // Recent activity (last 7 days)
      final recentFiles = files.where((f) => 
        DateTime.now().difference(f.updatedAt).inDays <= 7
      ).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final recentActivity = recentFiles.take(10).map((file) => {
        'name': file.name,
        'date': file.updatedAt.toIso8601String(),
        'wordCount': file.wordCount,
        'action': 'updated',
      }).toList();

      return WritingStats(
        totalEntries: totalEntries,
        totalWords: totalWords,
        averageWordsPerEntry: averageWordsPerEntry,
        writingDays: writingDays,
        entriesPerWeek: entriesPerWeek,
        writingByDayOfWeek: writingByDayOfWeek,
        writingByMonth: writingByMonth,
        longestEntries: longestEntries,
        recentActivity: recentActivity,
      );
    } catch (e) {
      debugPrint('Error generating writing stats: $e');
      rethrow;
    }
  }

  // Generate mood trends analysis
  Future<MoodTrends> generateMoodTrends({DateTime? startDate, DateTime? endDate}) async {
    try {
      final moodEntries = await _dbService.getMoodHistory(
        startDate: startDate,
        endDate: endDate,
      );

      if (moodEntries.isEmpty) {
        return MoodTrends(
          averageValence: 0.0,
          averageArousal: 0.0,
          emotionFrequency: {},
          moodOverTime: [],
          predominantMood: 'Unknown',
          moodStability: 0.0,
          insights: ['No mood data available for this period'],
        );
      }

      // Calculate averages
      final averageValence = moodEntries
          .map((e) => e['valence'] as double)
          .reduce((a, b) => a + b) / moodEntries.length;
      
      final averageArousal = moodEntries
          .map((e) => e['arousal'] as double)
          .reduce((a, b) => a + b) / moodEntries.length;

      // Emotion frequency analysis
      final emotionFrequency = <String, int>{};
      for (final entry in moodEntries) {
        final emotions = (entry['emotions'] as String).split(',');
        for (final emotion in emotions) {
          final cleanEmotion = emotion.trim();
          if (cleanEmotion.isNotEmpty) {
            emotionFrequency[cleanEmotion] = (emotionFrequency[cleanEmotion] ?? 0) + 1;
          }
        }
      }

      // Mood over time
      final moodOverTime = moodEntries.map((entry) => {
        'date': entry['created_at'] as String,
        'valence': entry['valence'] as double,
        'arousal': entry['arousal'] as double,
        'emotions': entry['emotions'] as String,
      }).toList();

      // Determine predominant mood
      String predominantMood = 'Unknown';
      if (emotionFrequency.isNotEmpty) {
        final topEmotion = emotionFrequency.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        predominantMood = topEmotion.key;
      }

      // Calculate mood stability (lower variance = more stable)
      final valenceVariance = _calculateVariance(
        moodEntries.map((e) => e['valence'] as double).toList()
      );
      final arousalVariance = _calculateVariance(
        moodEntries.map((e) => e['arousal'] as double).toList()
      );
      final moodStability = 1.0 - ((valenceVariance + arousalVariance) / 2).clamp(0.0, 1.0);

      // Generate insights
      final insights = _generateMoodInsights(
        averageValence, averageArousal, emotionFrequency, moodStability
      );

      return MoodTrends(
        averageValence: averageValence,
        averageArousal: averageArousal,
        emotionFrequency: emotionFrequency,
        moodOverTime: moodOverTime,
        predominantMood: predominantMood,
        moodStability: moodStability,
        insights: insights,
      );
    } catch (e) {
      debugPrint('Error generating mood trends: $e');
      // Return empty trends on error
      return MoodTrends(
        averageValence: 0.0,
        averageArousal: 0.0,
        emotionFrequency: {},
        moodOverTime: [],
        predominantMood: 'Unknown',
        moodStability: 0.0,
        insights: ['Error analyzing mood data'],
      );
    }
  }

  // Generate theme analysis
  Future<ThemeAnalysis> generateThemeAnalysis({DateTime? startDate, DateTime? endDate}) async {
    try {
      // Get themes and tags data
      final themes = await _dbService.getThemes();
      final tags = await _dbService.getTags();

      // Get file themes and tags in date range
      final files = await _getFilesInDateRange(startDate, endDate);
      final fileIds = files.map((f) => f.id).toList();

      // Calculate theme usage
      final themeUsage = <String, int>{};
      final tagUsage = <String, int>{};

      for (final fileId in fileIds) {
        final fileThemes = await _dbService.getFileThemes(fileId);
        final fileTags = await _dbService.getFileTags(fileId);

        for (final theme in fileThemes) {
          final themeName = theme['name'] as String;
          themeUsage[themeName] = (themeUsage[themeName] ?? 0) + 1;
        }

        for (final tag in fileTags) {
          final tagName = tag['name'] as String;
          tagUsage[tagName] = (tagUsage[tagName] ?? 0) + 1;
        }
      }

      // Sort and format top themes and tags
      final topThemes = themeUsage.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final topTags = tagUsage.entries
          .map((e) => {'name': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      // Theme evolution (simplified - would need time-based analysis)
      final themeEvolution = <String, double>{};
      for (final theme in topThemes.take(5)) {
        themeEvolution[theme['name'] as String] = (theme['count'] as int).toDouble();
      }

      // Emerging topics (new themes/tags with growing usage)
      final emergingTopics = topThemes
          .take(3)
          .map((t) => t['name'] as String)
          .toList();

      // Theme connections (simplified)
      final themeConnections = <String, List<String>>{};
      for (final theme in topThemes.take(3)) {
        themeConnections[theme['name'] as String] = topTags
            .take(3)
            .map((t) => t['name'] as String)
            .toList();
      }

      return ThemeAnalysis(
        topThemes: topThemes,
        topTags: topTags,
        themeEvolution: themeEvolution,
        emergingTopics: emergingTopics,
        themeConnections: themeConnections,
      );
    } catch (e) {
      debugPrint('Error generating theme analysis: $e');
      return ThemeAnalysis(
        topThemes: [],
        topTags: [],
        themeEvolution: {},
        emergingTopics: [],
        themeConnections: {},
      );
    }
  }

  // Generate personal growth insights
  Future<GrowthInsights> generateGrowthInsights({DateTime? startDate, DateTime? endDate}) async {
    try {
      final writingStats = await generateWritingStats(startDate: startDate, endDate: endDate);
      final moodTrends = await generateMoodTrends(startDate: startDate, endDate: endDate);
      final themeAnalysis = await generateThemeAnalysis(startDate: startDate, endDate: endDate);

      // Calculate writing consistency (0-1 score)
      final writingConsistency = min(1.0, writingStats.entriesPerWeek / 3.0); // Target 3 entries per week

      // Calculate emotional growth (improvement in valence over time)
      final emotionalGrowth = max(0.0, (moodTrends.averageValence + 1) / 2); // Convert -1,1 to 0,1

      // Calculate thematic diversity
      final thematicDiversity = min(1.0, themeAnalysis.topThemes.length / 10.0); // Target 10 different themes

      // Identify personality traits based on writing patterns
      final personalityTraits = _inferPersonalityTraits(writingStats, moodTrends, themeAnalysis);

      // Suggest growth areas
      final growthAreas = _suggestGrowthAreas(writingStats, moodTrends, themeAnalysis);

      // Identify milestones
      final milestones = _identifyMilestones(writingStats, moodTrends);

      // Determine overall trend
      final overallTrend = _determineOverallTrend(writingConsistency, emotionalGrowth, thematicDiversity);

      return GrowthInsights(
        writingConsistency: writingConsistency,
        emotionalGrowth: emotionalGrowth,
        thematicDiversity: thematicDiversity,
        personalityTraits: personalityTraits,
        growthAreas: growthAreas,
        milestones: milestones,
        overallTrend: overallTrend,
      );
    } catch (e) {
      debugPrint('Error generating growth insights: $e');
      return GrowthInsights(
        writingConsistency: 0.0,
        emotionalGrowth: 0.0,
        thematicDiversity: 0.0,
        personalityTraits: [],
        growthAreas: [],
        milestones: [],
        overallTrend: 'Insufficient data',
      );
    }
  }

  // Helper methods
  Future<List<JournalFile>> _getFilesInDateRange(DateTime? startDate, DateTime? endDate) async {
    final allFiles = await _dbService.getFiles();
    
    if (startDate == null && endDate == null) {
      return allFiles;
    }
    
    return allFiles.where((file) {
      if (startDate != null && file.createdAt.isBefore(startDate)) return false;
      if (endDate != null && file.createdAt.isAfter(endDate)) return false;
      return true;
    }).toList();
  }

  String _getTimeRangeDescription(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) return 'All time';
    if (startDate == null) return 'Until ${_formatDate(endDate!)}';
    if (endDate == null) return 'Since ${_formatDate(startDate)}';
    return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  List<String> _generateMoodInsights(
    double averageValence, 
    double averageArousal, 
    Map<String, int> emotions, 
    double stability
  ) {
    final insights = <String>[];
    
    if (averageValence > 0.3) {
      insights.add('You tend to write with a positive emotional tone');
    } else if (averageValence < -0.3) {
      insights.add('Your writing often reflects challenging emotions');
    } else {
      insights.add('Your emotional tone in writing is balanced');
    }
    
    if (averageArousal > 0.7) {
      insights.add('Your entries often reflect high energy and intensity');
    } else if (averageArousal < 0.3) {
      insights.add('Your writing style tends to be calm and reflective');
    }
    
    if (stability > 0.8) {
      insights.add('You show remarkable emotional consistency in your writing');
    } else if (stability < 0.4) {
      insights.add('Your emotional expression varies significantly between entries');
    }
    
    return insights;
  }

  List<String> _inferPersonalityTraits(WritingStats writing, MoodTrends mood, ThemeAnalysis themes) {
    final traits = <String>[];
    
    if (writing.entriesPerWeek > 2) traits.add('Consistent');
    if (writing.averageWordsPerEntry > 200) traits.add('Expressive');
    if (mood.moodStability > 0.7) traits.add('Emotionally stable');
    if (mood.averageValence > 0.2) traits.add('Optimistic');
    if (themes.topThemes.length > 5) traits.add('Diverse thinker');
    
    return traits;
  }

  List<String> _suggestGrowthAreas(WritingStats writing, MoodTrends mood, ThemeAnalysis themes) {
    final areas = <String>[];
    
    if (writing.entriesPerWeek < 1) areas.add('Increase writing frequency');
    if (mood.moodStability < 0.5) areas.add('Explore emotional regulation');
    if (themes.topThemes.length < 3) areas.add('Diversify writing topics');
    if (writing.averageWordsPerEntry < 100) areas.add('Develop ideas more deeply');
    
    return areas;
  }

  List<Map<String, dynamic>> _identifyMilestones(WritingStats writing, MoodTrends mood) {
    final milestones = <Map<String, dynamic>>[];
    
    if (writing.totalEntries >= 10) {
      milestones.add({
        'title': 'Dedicated Writer',
        'description': 'Reached ${writing.totalEntries} journal entries',
        'date': DateTime.now().toIso8601String(),
      });
    }
    
    if (writing.totalWords >= 1000) {
      milestones.add({
        'title': 'Word Master',
        'description': 'Written over ${writing.totalWords} words',
        'date': DateTime.now().toIso8601String(),
      });
    }
    
    return milestones;
  }

  String _determineOverallTrend(double consistency, double emotional, double diversity) {
    final average = (consistency + emotional + diversity) / 3;
    
    if (average > 0.8) return 'Excellent progress';
    if (average > 0.6) return 'Good development';
    if (average > 0.4) return 'Steady growth';
    if (average > 0.2) return 'Building foundation';
    return 'Starting journey';
  }

  void dispose() {
    // Cleanup if needed
  }
} 