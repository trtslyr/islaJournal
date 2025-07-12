import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'ai_service.dart';
import 'database_service.dart';
import '../models/journal_file.dart';

/// Mood analysis result
@HiveType(typeId: 1)
class MoodAnalysis {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String fileId;
  
  @HiveField(2)
  final String primaryEmotion;
  
  @HiveField(3)
  final double confidence;
  
  @HiveField(4)
  final Map<String, double> emotionScores;
  
  @HiveField(5)
  final int sentiment; // -1 negative, 0 neutral, 1 positive
  
  @HiveField(6)
  final List<String> keywords;
  
  @HiveField(7)
  final DateTime analyzedAt;
  
  @HiveField(8)
  final String summary;

  MoodAnalysis({
    required this.id,
    required this.fileId,
    required this.primaryEmotion,
    required this.confidence,
    required this.emotionScores,
    required this.sentiment,
    required this.keywords,
    required this.analyzedAt,
    required this.summary,
  });
}

/// Mood trend over time
class MoodTrend {
  final DateTime date;
  final String primaryEmotion;
  final double positivity;
  final int entryCount;

  MoodTrend({
    required this.date,
    required this.primaryEmotion,
    required this.positivity,
    required this.entryCount,
  });
}

/// Mood pattern insights
class MoodInsights {
  final String mostCommonEmotion;
  final double averagePositivity;
  final List<String> trendingEmotions;
  final List<MoodTrend> weeklyTrends;
  final Map<String, int> emotionFrequency;

  MoodInsights({
    required this.mostCommonEmotion,
    required this.averagePositivity,
    required this.trendingEmotions,
    required this.weeklyTrends,
    required this.emotionFrequency,
  });
}

/// Service for analyzing mood and emotional patterns in journal entries
class MoodAnalysisService {
  static final MoodAnalysisService _instance = MoodAnalysisService._internal();
  factory MoodAnalysisService() => _instance;
  MoodAnalysisService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  Box<MoodAnalysis>? _moodBox;
  
  bool _isInitialized = false;

  // Predefined emotions for analysis
  static const List<String> _baseEmotions = [
    'joy', 'sadness', 'anger', 'fear', 'surprise', 'disgust',
    'love', 'gratitude', 'excitement', 'anxiety', 'contentment',
    'frustration', 'hope', 'loneliness', 'pride', 'shame'
  ];

  /// Initialize the mood analysis service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register Hive adapter
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(MoodAnalysisAdapter());
      }
      
      // Open the mood analysis box
      _moodBox = await Hive.openBox<MoodAnalysis>('mood_analysis');
      
      _isInitialized = true;
      debugPrint('MoodAnalysisService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize MoodAnalysisService: $e');
      throw Exception('Failed to initialize mood analysis service: $e');
    }
  }

  /// Analyze mood for a journal entry
  Future<MoodAnalysis> analyzeEntry(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    try {
      // Check if analysis already exists
      final existingAnalysis = await getAnalysis(file.id);
      if (existingAnalysis != null) {
        return existingAnalysis;
      }

      // Generate mood analysis using AI
      final analysisResult = await _aiService.generateText(
        _buildMoodAnalysisPrompt(file),
        options: {
          'temperature': 0.3,
          'max_tokens': 400,
        },
      );

      // Parse the AI response
      final moodAnalysis = _parseAnalysisResult(file.id, analysisResult);
      
      // Store the analysis
      await _moodBox!.put(moodAnalysis.id, moodAnalysis);
      
      return moodAnalysis;
    } catch (e) {
      debugPrint('Error analyzing mood: $e');
      throw Exception('Failed to analyze mood: $e');
    }
  }

  /// Get mood analysis for a file
  Future<MoodAnalysis?> getAnalysis(String fileId) async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    return _moodBox!.values
        .cast<MoodAnalysis?>()
        .firstWhere((analysis) => analysis?.fileId == fileId, orElse: () => null);
  }

  /// Get mood trends over time
  Future<List<MoodTrend>> getTrends({
    DateTime? startDate,
    DateTime? endDate,
    String? emotion,
  }) async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    final allAnalyses = _moodBox!.values.toList();
    
    // Filter by date range
    var filteredAnalyses = allAnalyses;
    if (startDate != null) {
      filteredAnalyses = filteredAnalyses
          .where((a) => a.analyzedAt.isAfter(startDate))
          .toList();
    }
    if (endDate != null) {
      filteredAnalyses = filteredAnalyses
          .where((a) => a.analyzedAt.isBefore(endDate))
          .toList();
    }
    if (emotion != null) {
      filteredAnalyses = filteredAnalyses
          .where((a) => a.primaryEmotion == emotion)
          .toList();
    }

    // Group by week and calculate trends
    final trendMap = <String, List<MoodAnalysis>>{};
    
    for (final analysis in filteredAnalyses) {
      final weekKey = _getWeekKey(analysis.analyzedAt);
      trendMap[weekKey] ??= [];
      trendMap[weekKey]!.add(analysis);
    }

    // Convert to trend objects
    final trends = <MoodTrend>[];
    for (final entry in trendMap.entries) {
      final analyses = entry.value;
      final positivity = _calculatePositivity(analyses);
      final mostCommon = _getMostCommonEmotion(analyses);
      final weekDate = _parseWeekKey(entry.key);
      
      trends.add(MoodTrend(
        date: weekDate,
        primaryEmotion: mostCommon,
        positivity: positivity,
        entryCount: analyses.length,
      ));
    }

    trends.sort((a, b) => a.date.compareTo(b.date));
    return trends;
  }

  /// Get comprehensive mood insights
  Future<MoodInsights> getInsights({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    final allAnalyses = _moodBox!.values.toList();
    
    // Filter by date range
    var filteredAnalyses = allAnalyses;
    if (startDate != null) {
      filteredAnalyses = filteredAnalyses
          .where((a) => a.analyzedAt.isAfter(startDate))
          .toList();
    }
    if (endDate != null) {
      filteredAnalyses = filteredAnalyses
          .where((a) => a.analyzedAt.isBefore(endDate))
          .toList();
    }

    // Calculate insights
    final emotionFrequency = <String, int>{};
    double totalPositivity = 0;
    
    for (final analysis in filteredAnalyses) {
      emotionFrequency[analysis.primaryEmotion] = 
          (emotionFrequency[analysis.primaryEmotion] ?? 0) + 1;
      totalPositivity += analysis.sentiment.toDouble();
    }

    final mostCommon = emotionFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    
    final averagePositivity = filteredAnalyses.isEmpty 
        ? 0.0 
        : totalPositivity / filteredAnalyses.length;

    final trendingEmotions = emotionFrequency.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        .take(3)
        .map((e) => e.key)
        .toList();

    final weeklyTrends = await getTrends(
      startDate: startDate,
      endDate: endDate,
    );

    return MoodInsights(
      mostCommonEmotion: mostCommon,
      averagePositivity: averagePositivity,
      trendingEmotions: trendingEmotions,
      weeklyTrends: weeklyTrends,
      emotionFrequency: emotionFrequency,
    );
  }

  /// Analyze mood for all journal entries
  Future<void> analyzeAllEntries() async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    try {
      final files = await _dbService.getFiles();
      
      for (final file in files) {
        final existingAnalysis = await getAnalysis(file.id);
        if (existingAnalysis == null) {
          await analyzeEntry(file);
        }
      }
    } catch (e) {
      debugPrint('Error analyzing all entries: $e');
      throw Exception('Failed to analyze all entries: $e');
    }
  }

  /// Build prompt for mood analysis
  String _buildMoodAnalysisPrompt(JournalFile file) {
    return '''Analyze the emotional content of this journal entry and provide a structured analysis.

Journal Entry: "${file.name}"
Content:
---
${file.content}
---

Please provide a JSON response with the following structure:
{
  "primaryEmotion": "the main emotion detected",
  "confidence": 0.85,
  "emotionScores": {
    "joy": 0.2,
    "sadness": 0.1,
    "anger": 0.0,
    "fear": 0.1,
    "love": 0.6
  },
  "sentiment": 1,
  "keywords": ["love", "happiness", "gratitude"],
  "summary": "Brief summary of the emotional tone"
}

Available emotions: ${_baseEmotions.join(', ')}
Sentiment: -1 (negative), 0 (neutral), 1 (positive)
Confidence: 0.0 to 1.0

Analysis:''';
  }

  /// Parse AI analysis result
  MoodAnalysis _parseAnalysisResult(String fileId, String response) {
    try {
      // Try to extract JSON from response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('No JSON found in response');
      }
      
      final jsonStr = response.substring(jsonStart, jsonEnd + 1);
      final data = Map<String, dynamic>.from(
        // Simple JSON parsing - in production, use a proper JSON parser
        _parseSimpleJson(jsonStr),
      );

      return MoodAnalysis(
        id: 'mood_${DateTime.now().millisecondsSinceEpoch}',
        fileId: fileId,
        primaryEmotion: data['primaryEmotion'] ?? 'neutral',
        confidence: (data['confidence'] ?? 0.5).toDouble(),
        emotionScores: Map<String, double>.from(
          data['emotionScores'] ?? {},
        ),
        sentiment: data['sentiment'] ?? 0,
        keywords: List<String>.from(data['keywords'] ?? []),
        analyzedAt: DateTime.now(),
        summary: data['summary'] ?? 'No summary available',
      );
    } catch (e) {
      debugPrint('Error parsing analysis result: $e');
      
      // Fallback analysis
      return MoodAnalysis(
        id: 'mood_${DateTime.now().millisecondsSinceEpoch}',
        fileId: fileId,
        primaryEmotion: 'neutral',
        confidence: 0.5,
        emotionScores: {'neutral': 1.0},
        sentiment: 0,
        keywords: [],
        analyzedAt: DateTime.now(),
        summary: 'Analysis failed, using neutral mood',
      );
    }
  }

  /// Simple JSON parser (replace with proper JSON parser in production)
  Map<String, dynamic> _parseSimpleJson(String jsonStr) {
    // This is a very basic JSON parser - use dart:convert in production
    final Map<String, dynamic> result = {};
    
    // Remove braces and split by commas
    final content = jsonStr.replaceAll(RegExp(r'[{}]'), '');
    final pairs = content.split(',');
    
    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim().replaceAll('"', '');
        final value = keyValue[1].trim().replaceAll('"', '');
        
        // Try to parse as number
        if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          result[key] = value;
        }
      }
    }
    
    return result;
  }

  /// Get week key for grouping
  String _getWeekKey(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return '${weekStart.year}-W${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  /// Parse week key back to date
  DateTime _parseWeekKey(String weekKey) {
    final parts = weekKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1].substring(1));
    final day = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  /// Calculate positivity score
  double _calculatePositivity(List<MoodAnalysis> analyses) {
    if (analyses.isEmpty) return 0.0;
    
    double total = 0;
    for (final analysis in analyses) {
      total += analysis.sentiment.toDouble();
    }
    return total / analyses.length;
  }

  /// Get most common emotion
  String _getMostCommonEmotion(List<MoodAnalysis> analyses) {
    if (analyses.isEmpty) return 'neutral';
    
    final frequency = <String, int>{};
    for (final analysis in analyses) {
      frequency[analysis.primaryEmotion] = 
          (frequency[analysis.primaryEmotion] ?? 0) + 1;
    }
    
    return frequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Delete mood analysis for a file
  Future<void> deleteAnalysis(String fileId) async {
    if (!_isInitialized) {
      throw Exception('MoodAnalysisService not initialized');
    }

    final analysis = await getAnalysis(fileId);
    if (analysis != null) {
      await _moodBox!.delete(analysis.id);
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_moodBox != null) {
      await _moodBox!.close();
    }
    _isInitialized = false;
  }
}

/// Hive adapter for MoodAnalysis
class MoodAnalysisAdapter extends TypeAdapter<MoodAnalysis> {
  @override
  final int typeId = 1;

  @override
  MoodAnalysis read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MoodAnalysis(
      id: fields[0] as String,
      fileId: fields[1] as String,
      primaryEmotion: fields[2] as String,
      confidence: fields[3] as double,
      emotionScores: Map<String, double>.from(fields[4]),
      sentiment: fields[5] as int,
      keywords: List<String>.from(fields[6]),
      analyzedAt: fields[7] as DateTime,
      summary: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MoodAnalysis obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileId)
      ..writeByte(2)
      ..write(obj.primaryEmotion)
      ..writeByte(3)
      ..write(obj.confidence)
      ..writeByte(4)
      ..write(obj.emotionScores)
      ..writeByte(5)
      ..write(obj.sentiment)
      ..writeByte(6)
      ..write(obj.keywords)
      ..writeByte(7)
      ..write(obj.analyzedAt)
      ..writeByte(8)
      ..write(obj.summary);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodAnalysisAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}