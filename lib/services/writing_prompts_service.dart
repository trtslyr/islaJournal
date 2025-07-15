import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/journal_file.dart';
import 'database_service.dart';
import 'ai_service.dart';

class WritingPrompt {
  final String id;
  final String prompt;
  final String category;
  final double relevance;
  final String? context;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  WritingPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.relevance,
    this.context,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'category': category,
      'relevance': relevance,
      'context': context,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata != null ? jsonEncode(metadata) : null,
    };
  }

  factory WritingPrompt.fromMap(Map<String, dynamic> map) {
    return WritingPrompt(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      category: map['category'] as String,
      relevance: map['relevance'] as double,
      context: map['context'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(jsonDecode(map['metadata'] as String))
          : null,
    );
  }
}

class WritingPromptsService {
  static final WritingPromptsService _instance = WritingPromptsService._internal();
  factory WritingPromptsService() => _instance;
  WritingPromptsService._internal();

  final DatabaseService _dbService = DatabaseService();
  final AIService _aiService = AIService();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _aiService.initialize();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing writing prompts service: $e');
      throw Exception('Failed to initialize writing prompts service: $e');
    }
  }

  // Generate contextual writing prompts based on current content
  Future<List<WritingPrompt>> generateContextualPrompts(
    String currentContent, {
    int maxPrompts = 5,
    bool includeJournalHistory = true,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Get context from journal history if requested
      String historyContext = '';
      if (includeJournalHistory) {
        historyContext = await _getJournalHistoryContext();
      }

      // Generate prompts using AI
      final aiResponse = await _aiService.generateText(
        currentContent,
        systemPrompt: _getPromptsSystemPrompt(historyContext),
        maxTokens: 400,
        temperature: 0.8,
      );

      // Parse AI response
      final promptsData = _parsePromptsResponse(aiResponse);
      
      // Create WritingPrompt objects
      final prompts = <WritingPrompt>[];
      int index = 0;
      
      for (final promptData in promptsData) {
        if (index >= maxPrompts) break;
        
        prompts.add(WritingPrompt(
          id: 'prompt_${DateTime.now().millisecondsSinceEpoch}_$index',
          prompt: promptData['prompt'] as String,
          category: promptData['category'] as String,
          relevance: promptData['relevance'] as double,
          context: promptData['context'] as String?,
          metadata: {
            'generated_from': 'ai_contextual',
            'content_length': currentContent.length,
            'has_history_context': includeJournalHistory,
          },
        ));
        
        index++;
      }

      return prompts;
    } catch (e) {
      print('Error generating contextual prompts: $e');
      return _getFallbackPrompts();
    }
  }

  // Generate prompts based on specific themes or moods
  Future<List<WritingPrompt>> generateThematicPrompts(
    String theme, {
    int maxPrompts = 3,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final aiResponse = await _aiService.generateText(
        'Generate writing prompts for the theme: $theme',
        systemPrompt: _getThematicPromptsSystemPrompt(),
        maxTokens: 250,
        temperature: 0.9,
      );

      final promptsData = _parsePromptsResponse(aiResponse);
      
      final prompts = <WritingPrompt>[];
      int index = 0;
      
      for (final promptData in promptsData) {
        if (index >= maxPrompts) break;
        
        prompts.add(WritingPrompt(
          id: 'theme_prompt_${DateTime.now().millisecondsSinceEpoch}_$index',
          prompt: promptData['prompt'] as String,
          category: theme,
          relevance: promptData['relevance'] as double,
          context: promptData['context'] as String?,
          metadata: {
            'generated_from': 'ai_thematic',
            'theme': theme,
          },
        ));
        
        index++;
      }

      return prompts;
    } catch (e) {
      print('Error generating thematic prompts: $e');
      return _getFallbackPrompts();
    }
  }

  // Get writing prompts based on recent journal patterns
  Future<List<WritingPrompt>> getPatternBasedPrompts({
    int maxPrompts = 5,
    int daysPast = 7,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Get recent journal entries
      final recentEntries = await _getRecentEntries(daysPast);
      
      if (recentEntries.isEmpty) {
        return _getFallbackPrompts();
      }

      // Analyze patterns in recent entries
      final patternAnalysis = await _analyzeWritingPatterns(recentEntries);
      
      // Generate prompts based on patterns
      final aiResponse = await _aiService.generateText(
        'Recent writing patterns: $patternAnalysis',
        systemPrompt: _getPatternBasedPromptsSystemPrompt(),
        maxTokens: 300,
        temperature: 0.7,
      );

      final promptsData = _parsePromptsResponse(aiResponse);
      
      final prompts = <WritingPrompt>[];
      int index = 0;
      
      for (final promptData in promptsData) {
        if (index >= maxPrompts) break;
        
        prompts.add(WritingPrompt(
          id: 'pattern_prompt_${DateTime.now().millisecondsSinceEpoch}_$index',
          prompt: promptData['prompt'] as String,
          category: promptData['category'] as String,
          relevance: promptData['relevance'] as double,
          context: promptData['context'] as String?,
          metadata: {
            'generated_from': 'ai_pattern_based',
            'entries_analyzed': recentEntries.length,
            'days_past': daysPast,
          },
        ));
        
        index++;
      }

      return prompts;
    } catch (e) {
      print('Error generating pattern-based prompts: $e');
      return _getFallbackPrompts();
    }
  }

  // Get daily writing prompts (general inspiration)
  Future<List<WritingPrompt>> getDailyPrompts({
    int maxPrompts = 3,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      final aiResponse = await _aiService.generateText(
        'Generate daily writing prompts for journaling',
        systemPrompt: _getDailyPromptsSystemPrompt(),
        maxTokens: 200,
        temperature: 0.8,
      );

      final promptsData = _parsePromptsResponse(aiResponse);
      
      final prompts = <WritingPrompt>[];
      int index = 0;
      
      for (final promptData in promptsData) {
        if (index >= maxPrompts) break;
        
        prompts.add(WritingPrompt(
          id: 'daily_prompt_${DateTime.now().millisecondsSinceEpoch}_$index',
          prompt: promptData['prompt'] as String,
          category: 'Daily Inspiration',
          relevance: promptData['relevance'] as double,
          context: promptData['context'] as String?,
          metadata: {
            'generated_from': 'ai_daily',
            'date': DateTime.now().toIso8601String(),
          },
        ));
        
        index++;
      }

      return prompts;
    } catch (e) {
      print('Error generating daily prompts: $e');
      return _getFallbackPrompts();
    }
  }

  // Get journal history context for prompts
  Future<String> _getJournalHistoryContext() async {
    try {
      final db = await _dbService.database;
      
      // Get recent entries
      final recentEntries = await db.rawQuery('''
        SELECT f.name, f.content, f.created_at, f.word_count
        FROM files f
        WHERE f.content IS NOT NULL AND f.content != ''
        ORDER BY f.updated_at DESC
        LIMIT 5
      ''');

      if (recentEntries.isEmpty) return '';

      // Build context string
      final contextParts = <String>[];
      
      for (final entry in recentEntries) {
        final content = entry['content'] as String;
        final preview = content.length > 100 ? content.substring(0, 100) + '...' : content;
        contextParts.add('Entry: ${entry['name']} - $preview');
      }
      
      return 'Recent journal entries context:\n${contextParts.join('\n')}';
    } catch (e) {
      print('Error getting journal history context: $e');
      return '';
    }
  }

  // Get recent journal entries
  Future<List<Map<String, dynamic>>> _getRecentEntries(int daysPast) async {
    final db = await _dbService.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysPast));
    
    return await db.rawQuery('''
      SELECT f.id, f.name, f.content, f.created_at, f.updated_at, f.word_count
      FROM files f
      WHERE f.updated_at >= ? AND f.content IS NOT NULL AND f.content != ''
      ORDER BY f.updated_at DESC
      LIMIT 10
    ''', [cutoffDate.toIso8601String()]);
  }

  // Analyze writing patterns in recent entries
  Future<String> _analyzeWritingPatterns(List<Map<String, dynamic>> entries) async {
    try {
      final patterns = <String>[];
      
      // Analyze word count patterns
      final wordCounts = entries.map((e) => e['word_count'] as int).toList();
      final avgWordCount = wordCounts.isNotEmpty 
          ? wordCounts.reduce((a, b) => a + b) / wordCounts.length
          : 0;
      patterns.add('Average word count: ${avgWordCount.toStringAsFixed(0)}');
      
      // Analyze writing frequency
      patterns.add('Entries in period: ${entries.length}');
      
      // Analyze content themes (simplified)
      final allContent = entries.map((e) => e['content'] as String).join(' ');
      final commonWords = _extractCommonWords(allContent);
      patterns.add('Common themes: ${commonWords.join(', ')}');
      
      return patterns.join('\n');
    } catch (e) {
      return 'Unable to analyze patterns';
    }
  }

  // Extract common words from content
  List<String> _extractCommonWords(String content) {
    final words = content.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((word) => word.length > 4)
        .toList();
    
    final wordCount = <String, int>{};
    for (final word in words) {
      wordCount[word] = (wordCount[word] ?? 0) + 1;
    }
    
    final sortedWords = wordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedWords.take(5).map((e) => e.key).toList();
  }

  // System prompts for different types of prompt generation
  String _getPromptsSystemPrompt(String historyContext) {
    return '''
You are a creative writing coach. Generate personalized writing prompts based on the user's current content and journal history.

Current content context: The user is currently writing/thinking about this topic.
$historyContext

Generate 3-5 writing prompts that:
1. Build on their current thoughts
2. Encourage deeper reflection
3. Connect to their past entries when relevant
4. Are specific and engaging

Respond with ONLY a JSON array in this format:
[
  {
    "prompt": "What emotions are you avoiding confronting about this situation?",
    "category": "Self-Reflection",
    "relevance": 0.9,
    "context": "Based on your recent entries about work stress"
  },
  {
    "prompt": "Describe this moment as if you were telling a story to a friend.",
    "category": "Narrative",
    "relevance": 0.8,
    "context": "To help you process current experiences"
  }
]

Guidelines:
- Make prompts specific and actionable
- Categories: Self-Reflection, Narrative, Gratitude, Goals, Memories, Future, Emotions, Relationships
- Relevance: 0.0 to 1.0 (how relevant to current content)
- Context: Brief explanation of why this prompt is suggested

Respond with ONLY the JSON array, no other text.
''';
  }

  String _getThematicPromptsSystemPrompt() {
    return '''
You are a writing prompt generator. Create thoughtful prompts for the given theme.

Respond with ONLY a JSON array in this format:
[
  {
    "prompt": "What does this theme mean to you personally?",
    "category": "Theme Exploration",
    "relevance": 0.9,
    "context": "Personal connection to the theme"
  }
]

Make prompts thought-provoking and specific to the theme.
Respond with ONLY the JSON array, no other text.
''';
  }

  String _getPatternBasedPromptsSystemPrompt() {
    return '''
You are a writing coach analyzing journal patterns. Based on the user's recent writing patterns, suggest prompts that:
1. Build on their current interests
2. Address gaps in their reflection
3. Encourage growth and new perspectives

Respond with ONLY a JSON array in this format:
[
  {
    "prompt": "What patterns do you notice in your recent thoughts?",
    "category": "Pattern Analysis",
    "relevance": 0.9,
    "context": "Based on your recent writing patterns"
  }
]

Focus on helping them grow and reflect more deeply.
Respond with ONLY the JSON array, no other text.
''';
  }

  String _getDailyPromptsSystemPrompt() {
    return '''
You are a daily inspiration generator. Create general but engaging daily writing prompts for journaling.

Respond with ONLY a JSON array in this format:
[
  {
    "prompt": "What made you smile today, even if just for a moment?",
    "category": "Daily Inspiration",
    "relevance": 0.8,
    "context": "Finding joy in everyday moments"
  }
]

Make prompts universal yet meaningful.
Respond with ONLY the JSON array, no other text.
''';
  }

  // Parse AI response for prompts
  List<Map<String, dynamic>> _parsePromptsResponse(String response) {
    try {
      final cleanResponse = response.trim();
      
      // Remove any markdown formatting
      final jsonStart = cleanResponse.indexOf('[');
      final jsonEnd = cleanResponse.lastIndexOf(']');
      
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception('No JSON array found in response');
      }
      
      final jsonString = cleanResponse.substring(jsonStart, jsonEnd + 1);
      final parsed = jsonDecode(jsonString) as List;
      
      return parsed.map((item) => {
        'prompt': item['prompt'] as String? ?? 'What are you thinking about right now?',
        'category': item['category'] as String? ?? 'General',
        'relevance': (item['relevance'] as num?)?.toDouble() ?? 0.7,
        'context': item['context'] as String?,
      }).toList();
    } catch (e) {
      print('Error parsing prompts response: $e');
      return [];
    }
  }

  // Fallback prompts when AI generation fails
  List<WritingPrompt> _getFallbackPrompts() {
    return [
      WritingPrompt(
        id: 'fallback_1',
        prompt: 'What are you feeling right now, and why?',
        category: 'Self-Reflection',
        relevance: 0.8,
        context: 'A simple prompt to start reflection',
      ),
      WritingPrompt(
        id: 'fallback_2',
        prompt: 'Describe your ideal day from start to finish.',
        category: 'Future Vision',
        relevance: 0.7,
        context: 'Explore your aspirations and desires',
      ),
      WritingPrompt(
        id: 'fallback_3',
        prompt: 'What challenge are you facing, and what would you tell a friend in the same situation?',
        category: 'Problem Solving',
        relevance: 0.9,
        context: 'Gain perspective on current challenges',
      ),
    ];
  }

  void dispose() {
    _isInitialized = false;
  }
} 