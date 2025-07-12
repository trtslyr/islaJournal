import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'ai_service.dart';
import 'database_service.dart';
import 'mood_analysis_service.dart';
import 'auto_tagging_service.dart';
import '../models/journal_file.dart';

/// Writing prompt data
@HiveType(typeId: 3)
class WritingPrompt {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String prompt;
  
  @HiveField(2)
  final String category;
  
  @HiveField(3)
  final List<String> tags;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final bool isUsed;
  
  @HiveField(6)
  final String? inspiration; // What inspired this prompt
  
  @HiveField(7)
  final double personalityScore; // How personal/relevant this prompt is

  WritingPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.isUsed,
    this.inspiration,
    this.personalityScore = 0.5,
  });

  WritingPrompt copyWith({
    bool? isUsed,
  }) {
    return WritingPrompt(
      id: id,
      prompt: prompt,
      category: category,
      tags: tags,
      createdAt: createdAt,
      isUsed: isUsed ?? this.isUsed,
      inspiration: inspiration,
      personalityScore: personalityScore,
    );
  }
}

/// Writing prompt suggestions
class PromptSuggestions {
  final List<WritingPrompt> dailyPrompts;
  final List<WritingPrompt> moodBasedPrompts;
  final List<WritingPrompt> themeBasedPrompts;
  final List<WritingPrompt> reflectionPrompts;

  PromptSuggestions({
    required this.dailyPrompts,
    required this.moodBasedPrompts,
    required this.themeBasedPrompts,
    required this.reflectionPrompts,
  });
}

/// Service for generating personalized writing prompts
class WritingPromptsService {
  static final WritingPromptsService _instance = WritingPromptsService._internal();
  factory WritingPromptsService() => _instance;
  WritingPromptsService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  final MoodAnalysisService _moodService = MoodAnalysisService();
  final AutoTaggingService _tagService = AutoTaggingService();
  Box<WritingPrompt>? _promptBox;
  
  bool _isInitialized = false;

  // Prompt categories
  static const Map<String, List<String>> _promptCategories = {
    'reflection': [
      'personal growth',
      'lessons learned',
      'gratitude',
      'memories',
      'achievements',
    ],
    'creativity': [
      'imagination',
      'dreams',
      'future planning',
      'what if scenarios',
      'storytelling',
    ],
    'relationships': [
      'family',
      'friends',
      'love',
      'communication',
      'connections',
    ],
    'goals': [
      'career',
      'health',
      'personal development',
      'habits',
      'aspirations',
    ],
    'mindfulness': [
      'present moment',
      'awareness',
      'emotions',
      'self-care',
      'inner peace',
    ],
  };

  /// Initialize the writing prompts service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Register Hive adapter
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(WritingPromptAdapter());
      }
      
      // Open the prompts box
      _promptBox = await Hive.openBox<WritingPrompt>('writing_prompts');
      
      _isInitialized = true;
      debugPrint('WritingPromptsService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize WritingPromptsService: $e');
      throw Exception('Failed to initialize writing prompts service: $e');
    }
  }

  /// Generate personalized writing prompts
  Future<PromptSuggestions> generatePrompts({
    int dailyCount = 3,
    int moodCount = 2,
    int themeCount = 2,
    int reflectionCount = 2,
  }) async {
    if (!_isInitialized) {
      throw Exception('WritingPromptsService not initialized');
    }

    try {
      // Generate different types of prompts
      final dailyPrompts = await _generateDailyPrompts(dailyCount);
      final moodBasedPrompts = await _generateMoodBasedPrompts(moodCount);
      final themeBasedPrompts = await _generateThemeBasedPrompts(themeCount);
      final reflectionPrompts = await _generateReflectionPrompts(reflectionCount);

      return PromptSuggestions(
        dailyPrompts: dailyPrompts,
        moodBasedPrompts: moodBasedPrompts,
        themeBasedPrompts: themeBasedPrompts,
        reflectionPrompts: reflectionPrompts,
      );
    } catch (e) {
      debugPrint('Error generating prompts: $e');
      throw Exception('Failed to generate prompts: $e');
    }
  }

  /// Generate daily writing prompts
  Future<List<WritingPrompt>> _generateDailyPrompts(int count) async {
    // Get recent journal entries for context
    final recentFiles = await _dbService.getRecentFiles(limit: 5);
    
    final prompt = _buildDailyPromptsPrompt(recentFiles, count);
    
    final response = await _aiService.generateText(
      prompt,
      options: {
        'temperature': 0.8,
        'max_tokens': 400,
      },
    );

    return _parsePromptsResponse(response, 'daily');
  }

  /// Generate mood-based writing prompts
  Future<List<WritingPrompt>> _generateMoodBasedPrompts(int count) async {
    try {
      // Get recent mood analysis
      final recentInsights = await _moodService.getInsights(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
      );
      
      final prompt = _buildMoodBasedPromptsPrompt(recentInsights, count);
      
      final response = await _aiService.generateText(
        prompt,
        options: {
          'temperature': 0.7,
          'max_tokens': 300,
        },
      );

      return _parsePromptsResponse(response, 'mood', 
          inspiration: 'Based on recent mood: ${recentInsights.mostCommonEmotion}');
    } catch (e) {
      debugPrint('Error generating mood-based prompts: $e');
      return [];
    }
  }

  /// Generate theme-based writing prompts
  Future<List<WritingPrompt>> _generateThemeBasedPrompts(int count) async {
    try {
      // Get trending tags
      final tagAnalytics = await _tagService.getAnalytics();
      
      final prompt = _buildThemeBasedPromptsPrompt(tagAnalytics, count);
      
      final response = await _aiService.generateText(
        prompt,
        options: {
          'temperature': 0.7,
          'max_tokens': 300,
        },
      );

      return _parsePromptsResponse(response, 'theme',
          inspiration: 'Based on trending themes: ${tagAnalytics.trendingTags.join(', ')}');
    } catch (e) {
      debugPrint('Error generating theme-based prompts: $e');
      return [];
    }
  }

  /// Generate reflection prompts
  Future<List<WritingPrompt>> _generateReflectionPrompts(int count) async {
    final prompt = _buildReflectionPromptsPrompt(count);
    
    final response = await _aiService.generateText(
      prompt,
      options: {
        'temperature': 0.6,
        'max_tokens': 300,
      },
    );

    return _parsePromptsResponse(response, 'reflection');
  }

  /// Build daily prompts prompt
  String _buildDailyPromptsPrompt(List<JournalFile> recentFiles, int count) {
    final contextText = recentFiles.isEmpty
        ? "No recent journal entries available."
        : recentFiles.take(3).map((f) => 
            "Recent entry: ${f.name}\n${f.content.substring(0, 100)}..."
          ).join('\n\n');

    return '''You are an AI assistant for Isla Journal. Generate $count thoughtful daily writing prompts based on the user's recent journal entries.

Recent journal context:
---
$contextText
---

Generate $count daily writing prompts that:
1. Are personally relevant and engaging
2. Encourage self-reflection and mindfulness
3. Are specific but not too prescriptive
4. Build on recent themes or experiences
5. Are appropriate for daily journaling

Format each prompt as a numbered list item (1., 2., 3., etc.).

Daily Writing Prompts:''';
  }

  /// Build mood-based prompts prompt
  String _buildMoodBasedPromptsPrompt(MoodInsights insights, int count) {
    return '''You are an AI assistant for Isla Journal. Generate $count writing prompts based on the user's recent mood patterns.

Recent mood insights:
- Most common emotion: ${insights.mostCommonEmotion}
- Average positivity: ${insights.averagePositivity.toStringAsFixed(2)}
- Trending emotions: ${insights.trendingEmotions.join(', ')}

Generate $count writing prompts that:
1. Help process and understand these emotions
2. Encourage emotional growth and awareness
3. Are supportive and constructive
4. Address the dominant emotional patterns

Format each prompt as a numbered list item (1., 2., 3., etc.).

Mood-Based Writing Prompts:''';
  }

  /// Build theme-based prompts prompt
  String _buildThemeBasedPromptsPrompt(TagAnalytics analytics, int count) {
    return '''You are an AI assistant for Isla Journal. Generate $count writing prompts based on the user's trending journal themes.

Trending themes and tags:
- Most frequent tags: ${analytics.tagFrequency.entries.take(5).map((e) => e.key).join(', ')}
- Tag categories: ${analytics.categoryTags.keys.join(', ')}
- Recent trending: ${analytics.trendingTags.join(', ')}

Generate $count writing prompts that:
1. Explore these themes more deeply
2. Connect different themes together
3. Encourage new perspectives on familiar topics
4. Are thought-provoking and creative

Format each prompt as a numbered list item (1., 2., 3., etc.).

Theme-Based Writing Prompts:''';
  }

  /// Build reflection prompts prompt
  String _buildReflectionPromptsPrompt(int count) {
    return '''You are an AI assistant for Isla Journal. Generate $count universal reflection writing prompts that encourage personal growth and self-awareness.

Generate $count reflection prompts that:
1. Are universally applicable and timeless
2. Encourage deep self-reflection
3. Help with personal growth and insight
4. Are open-ended and thought-provoking
5. Focus on gratitude, lessons learned, or future aspirations

Format each prompt as a numbered list item (1., 2., 3., etc.).

Reflection Writing Prompts:''';
  }

  /// Parse prompts response from AI
  List<WritingPrompt> _parsePromptsResponse(
    String response, 
    String category, {
    String? inspiration,
  }) {
    final lines = response.split('\n');
    final prompts = <WritingPrompt>[];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && 
          (trimmed.startsWith(RegExp(r'\d+\.')) || 
           trimmed.startsWith('•') || 
           trimmed.startsWith('-'))) {
        // Remove numbering and bullet points
        final promptText = trimmed.replaceFirst(RegExp(r'^\d+\.\s*'), '')
                             .replaceFirst(RegExp(r'^[•-]\s*'), '')
                             .trim();
        
        if (promptText.isNotEmpty) {
          final prompt = WritingPrompt(
            id: 'prompt_${DateTime.now().millisecondsSinceEpoch}_${prompts.length}',
            prompt: promptText,
            category: category,
            tags: _extractTags(promptText),
            createdAt: DateTime.now(),
            isUsed: false,
            inspiration: inspiration,
            personalityScore: _calculatePersonalityScore(promptText, category),
          );
          
          prompts.add(prompt);
        }
      }
    }
    
    return prompts;
  }

  /// Extract tags from prompt text
  List<String> _extractTags(String promptText) {
    final tags = <String>[];
    
    // Look for common theme words
    final themeWords = [
      'gratitude', 'growth', 'family', 'work', 'health', 'goals',
      'love', 'friendship', 'creativity', 'challenge', 'success',
      'learning', 'reflection', 'future', 'past', 'present'
    ];
    
    for (final word in themeWords) {
      if (promptText.toLowerCase().contains(word)) {
        tags.add(word);
      }
    }
    
    return tags;
  }

  /// Calculate personality score for a prompt
  double _calculatePersonalityScore(String promptText, String category) {
    double score = 0.5; // Base score
    
    // Boost score for personal words
    final personalWords = [
      'you', 'your', 'yourself', 'personal', 'life', 'experience',
      'feel', 'think', 'believe', 'value', 'important', 'meaningful'
    ];
    
    for (final word in personalWords) {
      if (promptText.toLowerCase().contains(word)) {
        score += 0.1;
      }
    }
    
    // Category-based adjustments
    switch (category) {
      case 'reflection':
        score += 0.2;
        break;
      case 'mood':
        score += 0.15;
        break;
      case 'theme':
        score += 0.1;
        break;
    }
    
    return score.clamp(0.0, 1.0);
  }

  /// Get all stored prompts
  Future<List<WritingPrompt>> getAllPrompts() async {
    if (!_isInitialized) {
      throw Exception('WritingPromptsService not initialized');
    }

    return _promptBox!.values.toList();
  }

  /// Get unused prompts
  Future<List<WritingPrompt>> getUnusedPrompts() async {
    final allPrompts = await getAllPrompts();
    return allPrompts.where((prompt) => !prompt.isUsed).toList();
  }

  /// Mark prompt as used
  Future<void> markPromptAsUsed(String promptId) async {
    if (!_isInitialized) {
      throw Exception('WritingPromptsService not initialized');
    }

    final prompt = _promptBox!.get(promptId);
    if (prompt != null) {
      await _promptBox!.put(promptId, prompt.copyWith(isUsed: true));
    }
  }

  /// Get prompts by category
  Future<List<WritingPrompt>> getPromptsByCategory(String category) async {
    final allPrompts = await getAllPrompts();
    return allPrompts.where((prompt) => prompt.category == category).toList();
  }

  /// Get prompt statistics
  Future<Map<String, dynamic>> getPromptStats() async {
    final allPrompts = await getAllPrompts();
    
    final categoryStats = <String, int>{};
    final usedCount = allPrompts.where((p) => p.isUsed).length;
    
    for (final prompt in allPrompts) {
      categoryStats[prompt.category] = (categoryStats[prompt.category] ?? 0) + 1;
    }
    
    return {
      'total': allPrompts.length,
      'used': usedCount,
      'unused': allPrompts.length - usedCount,
      'categories': categoryStats,
      'averagePersonality': allPrompts.isEmpty ? 0.0 : 
          allPrompts.map((p) => p.personalityScore).reduce((a, b) => a + b) / allPrompts.length,
    };
  }

  /// Store prompts
  Future<void> storePrompts(List<WritingPrompt> prompts) async {
    if (!_isInitialized) {
      throw Exception('WritingPromptsService not initialized');
    }

    for (final prompt in prompts) {
      await _promptBox!.put(prompt.id, prompt);
    }
  }

  /// Clear old prompts
  Future<void> clearOldPrompts({int daysToKeep = 30}) async {
    if (!_isInitialized) {
      throw Exception('WritingPromptsService not initialized');
    }

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final allPrompts = await getAllPrompts();
    
    for (final prompt in allPrompts) {
      if (prompt.createdAt.isBefore(cutoffDate) && !prompt.isUsed) {
        await _promptBox!.delete(prompt.id);
      }
    }
  }

  /// Get daily prompt suggestion
  Future<WritingPrompt?> getDailyPrompt() async {
    try {
      final today = DateTime.now();
      final todayPrompts = await _promptBox!.values
          .where((p) => p.createdAt.day == today.day && 
                       p.createdAt.month == today.month && 
                       p.createdAt.year == today.year)
          .toList();

      if (todayPrompts.isNotEmpty) {
        return todayPrompts.first;
      }

      // Generate new daily prompts
      final dailyPrompts = await _generateDailyPrompts(1);
      if (dailyPrompts.isNotEmpty) {
        await storePrompts(dailyPrompts);
        return dailyPrompts.first;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting daily prompt: $e');
      return null;
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    if (_promptBox != null) {
      await _promptBox!.close();
    }
    _isInitialized = false;
  }
}

/// Hive adapter for WritingPrompt
class WritingPromptAdapter extends TypeAdapter<WritingPrompt> {
  @override
  final int typeId = 3;

  @override
  WritingPrompt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WritingPrompt(
      id: fields[0] as String,
      prompt: fields[1] as String,
      category: fields[2] as String,
      tags: List<String>.from(fields[3]),
      createdAt: fields[4] as DateTime,
      isUsed: fields[5] as bool,
      inspiration: fields[6] as String?,
      personalityScore: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, WritingPrompt obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.prompt)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.isUsed)
      ..writeByte(6)
      ..write(obj.inspiration)
      ..writeByte(7)
      ..write(obj.personalityScore);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WritingPromptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}