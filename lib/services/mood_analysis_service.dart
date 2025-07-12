import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/journal_file.dart';
import 'database_service.dart';
import 'ai_service.dart';

class MoodEntry {
  final String id;
  final String fileId;
  final DateTime date;
  final double valence; // -1 (negative) to 1 (positive)
  final double arousal; // 0 (calm) to 1 (excited)
  final List<String> emotions;
  final String summary;
  final double confidence;

  MoodEntry({
    required this.id,
    required this.fileId,
    required this.date,
    required this.valence,
    required this.arousal,
    required this.emotions,
    required this.summary,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'date': date.toIso8601String(),
      'valence': valence,
      'arousal': arousal,
      'emotions': jsonEncode(emotions),
      'summary': summary,
      'confidence': confidence,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as String,
      fileId: map['file_id'] as String,
      date: DateTime.parse(map['date'] as String),
      valence: map['valence'] as double,
      arousal: map['arousal'] as double,
      emotions: List<String>.from(jsonDecode(map['emotions'] as String)),
      summary: map['summary'] as String,
      confidence: map['confidence'] as double,
    );
  }
}

class MoodPattern {
  final DateTime startDate;
  final DateTime endDate;
  final double averageValence;
  final double averageArousal;
  final Map<String, int> emotionFrequency;
  final List<MoodEntry> entries;
  final String trend; // 'improving', 'declining', 'stable'

  MoodPattern({
    required this.startDate,
    required this.endDate,
    required this.averageValence,
    required this.averageArousal,
    required this.emotionFrequency,
    required this.entries,
    required this.trend,
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
      await _ensureMoodTables();
      _isInitialized = true;
      debugPrint('Mood Analysis Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing mood analysis service: $e');
      throw Exception('Failed to initialize mood analysis service: $e');
    }
  }

  Future<void> _ensureMoodTables() async {
    final db = await _dbService.database;
    
    // Create mood_entries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_entries (
        id TEXT PRIMARY KEY,
        file_id TEXT NOT NULL,
        date TEXT NOT NULL,
        valence REAL NOT NULL,
        arousal REAL NOT NULL,
        emotions TEXT NOT NULL,
        summary TEXT NOT NULL,
        confidence REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (file_id) REFERENCES files (id) ON DELETE CASCADE
      )
    ''');

    // Create index for better performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mood_entries_date ON mood_entries(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mood_entries_file_id ON mood_entries(file_id)');
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
- emotions: List of 2-4 primary emotions detected
- summary: 1-2 sentence emotional summary
- confidence: 0.0 (uncertain) to 1.0 (very confident in analysis)
''';

      final response = await _aiService.generateText(
        prompt,
        maxTokens: 300,
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
        id: '${journalFile.id}_mood',
        fileId: journalFile.id,
        date: journalFile.updatedAt,
        valence: analysis['valence'] as double,
        arousal: analysis['arousal'] as double,
        emotions: List<String>.from(analysis['emotions']),
        summary: analysis['summary'] as String,
        confidence: analysis['confidence'] as double,
      );

      // Save to database
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
      
      return parsed;
    } catch (e) {
      debugPrint('Error parsing AI response: $e');
      return null;
    }
  }

  Future<void> _saveMoodEntry(MoodEntry entry) async {
    final db = await _dbService.database;
    
    await db.insert(
      'mood_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get mood entry for a specific file
  Future<MoodEntry?> getMoodEntry(String fileId) async {
    if (!_isInitialized) await initialize();
    
    try {
      final db = await _dbService.database;
      final maps = await db.query(
        'mood_entries',
        where: 'file_id = ?',
        whereArgs: [fileId],
      );
      
      if (maps.isNotEmpty) {
        return MoodEntry.fromMap(maps.first);
      }
      return null;
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
      final db = await _dbService.database;
      
      String whereClause = '';
      List<dynamic> whereArgs = [];
      
      if (startDate != null) {
        whereClause += 'date >= ?';
        whereArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        if (whereClause.isNotEmpty) whereClause += ' AND ';
        whereClause += 'date <= ?';
        whereArgs.add(endDate.toIso8601String());
      }
      
      final maps = await db.query(
        'mood_entries',
        where: whereClause.isEmpty ? null : whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'date DESC',
        limit: limit,
      );
      
      return maps.map((map) => MoodEntry.fromMap(map)).toList();
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
      return MoodPattern(
        startDate: startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        endDate: endDate ?? DateTime.now(),
        averageValence: 0.0,
        averageArousal: 0.0,
        emotionFrequency: {},
        entries: [],
        trend: 'stable',
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
      
      if (recentAvg > olderAvg + 0.1) {
        trend = 'improving';
      } else if (recentAvg < olderAvg - 0.1) {
        trend = 'declining';
      }
    }
    
    return MoodPattern(
      startDate: startDate ?? entries.last.date,
      endDate: endDate ?? entries.first.date,
      averageValence: avgValence,
      averageArousal: avgArousal,
      emotionFrequency: emotionFrequency,
      entries: entries,
      trend: trend,
    );
  }

  // Get mood statistics
  Future<Map<String, dynamic>> getMoodStats() async {
    if (!_isInitialized) await initialize();
    
    try {
      final db = await _dbService.database;
      
      final totalCount = await db.rawQuery('SELECT COUNT(*) as count FROM mood_entries');
      final avgValence = await db.rawQuery('SELECT AVG(valence) as avg FROM mood_entries');
      final avgArousal = await db.rawQuery('SELECT AVG(arousal) as avg FROM mood_entries');
      
      // Get most recent mood
      final recentMood = await db.query(
        'mood_entries',
        orderBy: 'date DESC',
        limit: 1,
      );
      
      return {
        'totalEntries': totalCount.first['count'] as int,
        'averageValence': (avgValence.first['avg'] as double?) ?? 0.0,
        'averageArousal': (avgArousal.first['avg'] as double?) ?? 0.0,
        'hasRecentMood': recentMood.isNotEmpty,
        'lastAnalyzed': recentMood.isNotEmpty 
            ? recentMood.first['date'] as String
            : null,
      };
    } catch (e) {
      debugPrint('Error getting mood stats: $e');
      return {
        'totalEntries': 0,
        'averageValence': 0.0,
        'averageArousal': 0.0,
        'hasRecentMood': false,
        'lastAnalyzed': null,
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
        await analyzeMood(files[i]);
        progressCallback?.call(i + 1, files.length);
      } catch (e) {
        debugPrint('Error analyzing mood for file ${files[i].id}: $e');
      }
    }
  }

  void dispose() {
    _isInitialized = false;
  }
} 