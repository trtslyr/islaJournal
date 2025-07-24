import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../models/mood_entry.dart';
import 'database_service.dart';
import 'ai_service.dart';

class MoodAnalysisService {
  static final MoodAnalysisService _instance = MoodAnalysisService._internal();
  factory MoodAnalysisService() => _instance;
  MoodAnalysisService._internal();

  final DatabaseService _dbService = DatabaseService();
  final AIService _aiService = AIService();
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _aiService.initialize();
      _isInitialized = true;
      debugPrint('Mood Analysis Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing mood analysis service: $e');
      throw Exception('Failed to initialize mood analysis service: $e');
    }
  }

  // Analyze mood for a journal entry
  Future<MoodEntry?> analyzeMood(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      debugPrint('Analyzing mood for: ${journalFile.name}');
      
      final prompt = '''
Analyze the emotional content of this journal entry and provide a structured analysis:

Journal Entry:
"${journalFile.content}"

Please respond with ONLY a valid JSON object in this exact format:
{
  "valence": 0.5,
  "arousal": 0.3,
  "emotions": ["happy", "excited", "nervous"],
  "summary": "The writer expresses excitement about new opportunities while feeling slightly anxious about the challenges ahead.",
  "confidence": 0.8
}

Where:
- valence: -1.0 (very negative) to 1.0 (very positive)
- arousal: 0.0 (very calm) to 1.0 (very excited/intense)
- emotions: List of 2-4 primary emotions detected (use: happy, sad, angry, fearful, surprised, disgusted, calm, excited, anxious, content, frustrated, hopeful, lonely, grateful, confused, proud, ashamed, jealous, guilty, peaceful)
- summary: 1-2 sentence emotional summary
- confidence: 0.0 (uncertain) to 1.0 (very confident in analysis)
''';

      final response = await _aiService.generateText(
        prompt,
        maxTokens: 400,
        temperature: 0.3,
      );

      // Parse AI response
      final analysis = _parseAIResponse(response);
      if (analysis == null) {
        debugPrint('Failed to parse AI mood analysis response');
        return null;
      }

      // Create MoodEntry
      final moodEntry = MoodEntry(
        id: 'mood_${journalFile.id}_${DateTime.now().millisecondsSinceEpoch}',
        fileId: journalFile.id,
        date: journalFile.updatedAt,
        valence: analysis['valence'] as double,
        arousal: analysis['arousal'] as double,
        emotions: List<String>.from(analysis['emotions']),
        summary: analysis['summary'] as String,
        confidence: analysis['confidence'] as double,
      );

      // Save to database using existing mood_entries table
      await _saveMoodEntry(moodEntry);
      
      debugPrint('Mood analysis completed for: ${journalFile.name}');
      return moodEntry;
    } catch (e) {
      debugPrint('Error analyzing mood: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseAIResponse(String response) {
    try {
      // Extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        debugPrint('No valid JSON found in AI response');
        return null;
      }
      
      final jsonString = response.substring(jsonStart, jsonEnd);
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      if (!parsed.containsKey('valence') ||
          !parsed.containsKey('arousal') ||
          !parsed.containsKey('emotions') ||
          !parsed.containsKey('summary') ||
          !parsed.containsKey('confidence')) {
        debugPrint('Missing required fields in AI response');
        return null;
      }
      
      // Clamp values to valid ranges
      parsed['valence'] = (parsed['valence'] as num).toDouble().clamp(-1.0, 1.0);
      parsed['arousal'] = (parsed['arousal'] as num).toDouble().clamp(0.0, 1.0);
      parsed['confidence'] = (parsed['confidence'] as num).toDouble().clamp(0.0, 1.0);
      
      // Validate emotions list
      if (parsed['emotions'] is! List || (parsed['emotions'] as List).isEmpty) {
        parsed['emotions'] = ['neutral'];
      }
      
      return parsed;
    } catch (e) {
      debugPrint('Error parsing AI response: $e');
      return null;
    }
  }

  Future<void> _saveMoodEntry(MoodEntry entry) async {
    try {
      await _dbService.saveMoodEntry(
        entry.fileId,
        entry.valence,
        entry.arousal,
        entry.emotions,
        confidence: entry.confidence,
        metadata: {
          'summary': entry.summary,
          'date': entry.date.toIso8601String(),
          'analysis_version': 1,
        },
      );
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      rethrow;
    }
  }

  // Get mood entry for a specific file
  Future<MoodEntry?> getMoodEntry(String fileId) async {
    if (!_isInitialized) await initialize();
    
    try {
      final moodData = await _dbService.getMoodEntry(fileId);
      if (moodData == null) return null;
      
      return MoodEntry.fromMap(moodData);
    } catch (e) {
      debugPrint('Error getting mood entry: $e');
      return null;
    }
  }

  // Get mood entries within a date range
  Future<List<MoodEntry>> getMoodEntries({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final moodDataList = await _dbService.getMoodHistory(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      
      return moodDataList.map((data) => MoodEntry.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error getting mood entries: $e');
      return [];
    }
  }

  // Analyze mood patterns over time
  Future<MoodPattern> analyzeMoodPattern({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) await initialize();
    
    final entries = await getMoodEntries(
      startDate: startDate,
      endDate: endDate,
    );
    
    if (entries.isEmpty) {
      return MoodPattern.empty(
        startDate: startDate,
        endDate: endDate,
      );
    }
    
    // Calculate averages
    final avgValence = entries.fold<double>(0, (sum, entry) => sum + entry.valence) / entries.length;
    final avgArousal = entries.fold<double>(0, (sum, entry) => sum + entry.arousal) / entries.length;
    
    // Count emotion frequency
    final emotionFrequency = <String, int>{};
    for (final entry in entries) {
      for (final emotion in entry.emotions) {
        emotionFrequency[emotion] = (emotionFrequency[emotion] ?? 0) + 1;
      }
    }
    
    // Determine trend
    String trend = 'stable';
    if (entries.length >= 3) {
      final recentEntries = entries.take(3).toList();
      final olderEntries = entries.skip(entries.length - 3).toList();
      
      final recentAvg = recentEntries.fold<double>(0, (sum, entry) => sum + entry.valence) / recentEntries.length;
      final olderAvg = olderEntries.fold<double>(0, (sum, entry) => sum + entry.valence) / olderEntries.length;
      
      final trendThreshold = 0.15; // More sensitive threshold
      if (recentAvg > olderAvg + trendThreshold) {
        trend = 'improving';
      } else if (recentAvg < olderAvg - trendThreshold) {
        trend = 'declining';
      }
    }
    
    // Calculate additional metrics
    final metrics = <String, double>{
      'volatility': _calculateVolatility(entries),
      'positiveRatio': entries.where((e) => e.valence > 0).length / entries.length,
      'highArousalRatio': entries.where((e) => e.arousal > 0.6).length / entries.length,
      'averageConfidence': entries.fold<double>(0, (sum, e) => sum + e.confidence) / entries.length,
    };
    
    return MoodPattern(
      startDate: startDate ?? entries.last.date,
      endDate: endDate ?? entries.first.date,
      averageValence: avgValence,
      averageArousal: avgArousal,
      emotionFrequency: emotionFrequency,
      entries: entries,
      trend: trend,
      metrics: metrics,
    );
  }

  double _calculateVolatility(List<MoodEntry> entries) {
    if (entries.length < 2) return 0.0;
    
    final valences = entries.map((e) => e.valence).toList();
    final mean = valences.reduce((a, b) => a + b) / valences.length;
    final variance = valences.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / valences.length;
    return variance;
  }

  // Get mood statistics
  Future<Map<String, dynamic>> getMoodStats() async {
    if (!_isInitialized) await initialize();
    
    try {
      final allEntries = await getMoodEntries();
      
      if (allEntries.isEmpty) {
        return {
          'totalEntries': 0,
          'averageValence': 0.0,
          'averageArousal': 0.0,
          'hasRecentMood': false,
          'lastAnalyzed': null,
          'dominantEmotion': 'none',
          'trendDescription': 'No data available',
        };
      }
      
      // Calculate comprehensive stats
      final avgValence = allEntries.fold<double>(0, (sum, e) => sum + e.valence) / allEntries.length;
      final avgArousal = allEntries.fold<double>(0, (sum, e) => sum + e.arousal) / allEntries.length;
      final avgConfidence = allEntries.fold<double>(0, (sum, e) => sum + e.confidence) / allEntries.length;
      
      // Find dominant emotion
      final emotionCounts = <String, int>{};
      for (final entry in allEntries) {
        for (final emotion in entry.emotions) {
          emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
        }
      }
      
      final dominantEmotion = emotionCounts.isEmpty ? 'neutral' : 
          emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      
      // Calculate trend
      final recent30Days = allEntries.where((e) => 
          e.date.isAfter(DateTime.now().subtract(const Duration(days: 30)))
      ).toList();
      
      String trendDescription = 'stable';
      if (recent30Days.length >= 5) {
        final recentAvg = recent30Days.fold<double>(0, (sum, e) => sum + e.valence) / recent30Days.length;
        if (recentAvg > avgValence + 0.1) {
          trendDescription = 'improving recently';
        } else if (recentAvg < avgValence - 0.1) {
          trendDescription = 'declining recently';
        }
      }
      
      return {
        'totalEntries': allEntries.length,
        'averageValence': avgValence,
        'averageArousal': avgArousal,
        'averageConfidence': avgConfidence,
        'hasRecentMood': allEntries.isNotEmpty,
        'lastAnalyzed': allEntries.first.createdAt.toIso8601String(),
        'dominantEmotion': dominantEmotion,
        'trendDescription': trendDescription,
        'positiveEntries': allEntries.where((e) => e.valence > 0).length,
        'negativeEntries': allEntries.where((e) => e.valence < 0).length,
        'highConfidenceEntries': allEntries.where((e) => e.confidence > 0.8).length,
      };
    } catch (e) {
      debugPrint('Error getting mood stats: $e');
      return {
        'totalEntries': 0,
        'averageValence': 0.0,
        'averageArousal': 0.0,
        'hasRecentMood': false,
        'lastAnalyzed': null,
        'error': e.toString(),
      };
    }
  }

  // Batch analyze mood for multiple files
  Future<void> batchAnalyzeMood(List<JournalFile> files, {
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    
    for (int i = 0; i < files.length; i++) {
      try {
        // Skip files that are too short for meaningful analysis
        if (files[i].content.trim().length < 50) {
          debugPrint('Skipping short file: ${files[i].name}');
          continue;
        }
        
        // Check if already analyzed recently
        final existing = await getMoodEntry(files[i].id);
        if (existing != null && 
            existing.createdAt.isAfter(files[i].updatedAt.subtract(const Duration(hours: 1)))) {
          debugPrint('Skipping recently analyzed file: ${files[i].name}');
          continue;
        }
        
        await analyzeMood(files[i]);
        progressCallback?.call(i + 1, files.length);
        
        // Small delay to prevent overwhelming the AI service
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Error analyzing mood for file ${files[i].id}: $e');
      }
    }
  }

  void dispose() {
    _isInitialized = false;
  }
} 