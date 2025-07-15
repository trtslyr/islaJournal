import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_file.dart';
import 'database_service.dart';
import 'ai_service.dart';

class MoodEntry {
  final String id;
  final String fileId;
  final double valence; // -1 to 1 (negative to positive)
  final double arousal; // 0 to 1 (calm to excited)
  final List<String> emotions;
  final double confidence;
  final int analysisVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  MoodEntry({
    String? id,
    required this.fileId,
    required this.valence,
    required this.arousal,
    required this.emotions,
    required this.confidence,
    this.analysisVersion = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'valence': valence,
      'arousal': arousal,
      'emotions': jsonEncode(emotions),
      'confidence': confidence,
      'analysis_version': analysisVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      valence: map['valence'] as double,
      arousal: map['arousal'] as double,
      emotions: List<String>.from(jsonDecode(map['emotions'] as String)),
      confidence: map['confidence'] as double,
      analysisVersion: map['analysis_version'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata'] as String))
          : null,
    );
  }
}

class MoodPattern {
  final double averageValence;
  final double averageArousal;
  final Map<String, int> emotionFrequency;
  final String trend; // 'improving', 'declining', 'stable'
  final DateTime startDate;
  final DateTime endDate;
  final int entryCount;

  MoodPattern({
    required this.averageValence,
    required this.averageArousal,
    required this.emotionFrequency,
    required this.trend,
    required this.startDate,
    required this.endDate,
    required this.entryCount,
  });
}

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
    } catch (e) {
      print('Error initializing mood analysis service: $e');
      throw Exception('Failed to initialize mood analysis service: $e');
    }
  }

  // Analyze mood for a single journal entry
  Future<MoodEntry?> analyzeMood(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Check if analysis already exists
      final existing = await getMoodEntry(journalFile.id);
      if (existing != null) {
        return existing;
      }

      // Use AI to analyze mood
      final moodText = await _aiService.generateText(
        journalFile.content,
        systemPrompt: _getMoodAnalysisPrompt(),
        maxTokens: 150,
        temperature: 0.3,
      );

      // Parse AI response
      final moodData = _parseMoodResponse(moodText);
      
      // Create mood entry
      final moodEntry = MoodEntry(
        fileId: journalFile.id,
        valence: moodData['valence'] as double,
        arousal: moodData['arousal'] as double,
        emotions: List<String>.from(moodData['emotions']),
        confidence: moodData['confidence'] as double,
        metadata: {
          'analysis_method': 'ai_llama',
          'original_text_length': journalFile.content.length,
          'word_count': journalFile.wordCount,
        },
      );

      // Store in database
      await _storeMoodEntry(moodEntry);
      
      return moodEntry;
    } catch (e) {
      print('Error analyzing mood: $e');
      return null;
    }
  }

  // Batch analyze mood for multiple files
  Future<void> batchAnalyzeMood(
    List<JournalFile> files, {
    Function(int current, int total)? progressCallback,
  }) async {
    if (!_isInitialized) await initialize();
    
    for (int i = 0; i < files.length; i++) {
      await analyzeMood(files[i]);
      progressCallback?.call(i + 1, files.length);
    }
  }

  // Get mood entry for a specific file
  Future<MoodEntry?> getMoodEntry(String fileId) async {
    final db = await _dbService.database;
    
    final maps = await db.query(
      'mood_entries',
      where: 'file_id = ?',
      whereArgs: [fileId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MoodEntry.fromMap(maps.first);
    }
    return null;
  }

  // Get mood entries for a date range
  Future<List<MoodEntry>> getMoodEntries({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await _dbService.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (startDate != null) {
      whereClause = 'created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    
    if (endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    
    final maps = await db.query(
      'mood_entries',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => MoodEntry.fromMap(map)).toList();
  }

  // Analyze mood pattern over time
  Future<MoodPattern?> analyzeMoodPattern({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getMoodEntries(
      startDate: startDate,
      endDate: endDate,
    );

    if (entries.isEmpty) return null;

    // Calculate averages
    final avgValence = entries.fold<double>(0, (sum, entry) => sum + entry.valence) / entries.length;
    final avgArousal = entries.fold<double>(0, (sum, entry) => sum + entry.arousal) / entries.length;

    // Calculate emotion frequency
    final emotionFreq = <String, int>{};
    for (final entry in entries) {
      for (final emotion in entry.emotions) {
        emotionFreq[emotion] = (emotionFreq[emotion] ?? 0) + 1;
      }
    }

    // Calculate trend
    String trend = 'stable';
    if (entries.length >= 3) {
      final recent = entries.take(entries.length ~/ 3).toList();
      final older = entries.skip(entries.length * 2 ~/ 3).toList();
      
      final recentAvg = recent.fold<double>(0, (sum, entry) => sum + entry.valence) / recent.length;
      final olderAvg = older.fold<double>(0, (sum, entry) => sum + entry.valence) / older.length;
      
      if (recentAvg > olderAvg + 0.2) {
        trend = 'improving';
      } else if (recentAvg < olderAvg - 0.2) {
        trend = 'declining';
      }
    }

    return MoodPattern(
      averageValence: avgValence,
      averageArousal: avgArousal,
      emotionFrequency: emotionFreq,
      trend: trend,
      startDate: startDate ?? entries.last.createdAt,
      endDate: endDate ?? entries.first.createdAt,
      entryCount: entries.length,
    );
  }

  // Get mood statistics
  Future<Map<String, dynamic>> getMoodStats() async {
    final db = await _dbService.database;
    
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM mood_entries');
    final avgResult = await db.rawQuery('''
      SELECT AVG(valence) as avg_valence, AVG(arousal) as avg_arousal, AVG(confidence) as avg_confidence
      FROM mood_entries
    ''');
    
    return {
      'totalEntries': countResult.first['count'] as int,
      'averageValence': avgResult.first['avg_valence'] as double? ?? 0.0,
      'averageArousal': avgResult.first['avg_arousal'] as double? ?? 0.0,
      'averageConfidence': avgResult.first['avg_confidence'] as double? ?? 0.0,
    };
  }

  // Store mood entry in database
  Future<void> _storeMoodEntry(MoodEntry entry) async {
    final db = await _dbService.database;
    await db.insert('mood_entries', entry.toMap());
  }

  // Get system prompt for mood analysis
  String _getMoodAnalysisPrompt() {
    return '''
You are a mood analyzer. Analyze the emotional content of the given text and respond with ONLY a JSON object in this exact format:

{
  "valence": -0.5,
  "arousal": 0.7,
  "emotions": ["sad", "anxious", "hopeful"],
  "confidence": 0.8
}

Where:
- valence: -1 to 1 (very negative to very positive)
- arousal: 0 to 1 (very calm to very excited/energetic)
- emotions: array of 1-3 primary emotions (happy, sad, angry, anxious, excited, calm, hopeful, frustrated, content, etc.)
- confidence: 0 to 1 (how confident you are in this analysis)

Respond with ONLY the JSON object, no other text.
''';
  }

  // Parse AI response for mood data
  Map<String, dynamic> _parseMoodResponse(String response) {
    try {
      // Clean up the response
      final cleanResponse = response.trim();
      
      // Try to parse as JSON
      final json = jsonDecode(cleanResponse);
      
      return {
        'valence': (json['valence'] as num?)?.toDouble() ?? 0.0,
        'arousal': (json['arousal'] as num?)?.toDouble() ?? 0.5,
        'emotions': (json['emotions'] as List?)?.cast<String>() ?? ['neutral'],
        'confidence': (json['confidence'] as num?)?.toDouble() ?? 0.5,
      };
    } catch (e) {
      // Fallback if JSON parsing fails
      return {
        'valence': 0.0,
        'arousal': 0.5,
        'emotions': ['neutral'],
        'confidence': 0.3,
      };
    }
  }

  void dispose() {
    _isInitialized = false;
  }
} 