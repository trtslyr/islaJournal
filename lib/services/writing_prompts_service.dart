import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../services/rag_service.dart';
import '../services/mood_analysis_service.dart';
import '../services/ai_service.dart';

class WritingPrompt {
  final String id;
  final String prompt;
  final String category;
  final String inspiration;
  final DateTime createdAt;
  final double relevanceScore;
  final Map<String, dynamic> context;

  WritingPrompt({
    required this.id,
    required this.prompt,
    required this.category,
    required this.inspiration,
    required this.createdAt,
    required this.relevanceScore,
    required this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prompt': prompt,
      'category': category,
      'inspiration': inspiration,
      'createdAt': createdAt.toIso8601String(),
      'relevanceScore': relevanceScore,
      'context': jsonEncode(context),
    };
  }

  factory WritingPrompt.fromMap(Map<String, dynamic> map) {
    return WritingPrompt(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      category: map['category'] as String,
      inspiration: map['inspiration'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      relevanceScore: map['relevanceScore'] as double,
      context: Map<String, dynamic>.from(jsonDecode(map['context'] as String)),
    );
  }
}

enum PromptCategory {
  reflection('Reflection'),
  growth('Personal Growth'),
  creativity('Creative'),
  emotions('Emotional'),
  goals('Goals & Dreams'),
  relationships('Relationships'),
  memories('Memories'),
  future('Future Planning'),
  gratitude('Gratitude'),
  challenges('Challenges');

  const PromptCategory(this.displayName);
  final String displayName;
}

class WritingPromptsService {
  static final WritingPromptsService _instance = WritingPromptsService._internal();
  factory WritingPromptsService() => _instance;
  WritingPromptsService._internal();

  final RAGService _ragService = RAGService();
  final MoodAnalysisService _moodService = MoodAnalysisService();
  final AIService _aiService = AIService();
  
  bool _isInitialized = false;
  final Random _random = Random();

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _ragService.initialize();
      await _moodService.initialize();
      await _aiService.initialize();
      
      _isInitialized = true;
      debugPrint('Writing Prompts Service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing writing prompts service: $e');
      throw Exception('Failed to initialize writing prompts service: $e');
    }
  }

  // Generate contextual writing prompts
  Future<List<WritingPrompt>> generateContextualPrompts({
    String? currentContent,
    int count = 5,
    List<PromptCategory>? preferredCategories,
  }) async {
    if (!_isInitialized) await initialize();
    
    try {
      // Gather context from user's writing history
      final context = await _gatherWritingContext(currentContent);
      
      // Generate prompts using AI with context
      final prompts = await _generateAIPrompts(context, count, preferredCategories);
      
      // If not enough AI prompts, supplement with fallback prompts
      if (prompts.length < count) {
        final fallbackPrompts = _generateFallbackPrompts(
          context, 
          count - prompts.length,
          preferredCategories,
        );
        prompts.addAll(fallbackPrompts);
      }
      
      // Sort by relevance score
      prompts.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      
      return prompts.take(count).toList();
    } catch (e) {
      debugPrint('Error generating contextual prompts: $e');
      return _generateFallbackPrompts({}, count, preferredCategories);
    }
  }

  // Gather context from user's writing history
  Future<Map<String, dynamic>> _gatherWritingContext(String? currentContent) async {
    try {
      // Get recent journal themes using RAG
      final recentThemes = await _getRecentThemes();
      
      // Get mood patterns
      final moodPattern = await _moodService.analyzeMoodPattern(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      // Analyze current content if provided
      String? currentTheme;
      if (currentContent != null && currentContent.trim().isNotEmpty) {
        currentTheme = await _analyzeCurrentTheme(currentContent);
      }
      
      return {
        'recentThemes': recentThemes,
        'moodPattern': {
          'averageValence': moodPattern.averageValence,
          'averageArousal': moodPattern.averageArousal,
          'topEmotions': moodPattern.emotionFrequency.entries
              .toList()
              ..sort((a, b) => b.value.compareTo(a.value)),
          'trend': moodPattern.trend,
        },
        'currentTheme': currentTheme,
        'hasCurrentContent': currentContent?.trim().isNotEmpty ?? false,
      };
    } catch (e) {
      debugPrint('Error gathering writing context: $e');
      return {};
    }
  }

  // Get recent themes from journal entries
  Future<List<String>> _getRecentThemes() async {
    try {
      const query = 'What are the main themes and topics in my recent writing?';
      final relevantContent = await _ragService.retrieveRelevantContent(
        query,
        maxResults: 10,
        minSimilarity: 0.1,
      );
      
      if (relevantContent.isEmpty) return [];
      
      // Extract themes using AI
      final prompt = '''
Based on these recent journal entries, identify the 3-5 main themes or topics:

${relevantContent.map((r) => '- ${r.content.substring(0, 200)}...').join('\n')}

Please respond with ONLY a JSON array of theme strings:
["theme1", "theme2", "theme3"]
''';
      
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 150,
        temperature: 0.3,
      );
      
      return _parseThemesResponse(response);
    } catch (e) {
      debugPrint('Error getting recent themes: $e');
      return [];
    }
  }

  List<String> _parseThemesResponse(String response) {
    try {
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd <= jsonStart) return [];
      
      final jsonString = response.substring(jsonStart, jsonEnd);
      final parsed = jsonDecode(jsonString) as List;
      
      return parsed.map((theme) => theme.toString()).toList();
    } catch (e) {
      debugPrint('Error parsing themes response: $e');
      return [];
    }
  }

  // Analyze current content theme
  Future<String?> _analyzeCurrentTheme(String content) async {
    try {
      final prompt = '''
What is the main theme or topic of this text in 2-3 words?

Text: "${content.substring(0, content.length.clamp(0, 500))}"

Theme:''';
      
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 20,
        temperature: 0.3,
      );
      
      return response.trim();
    } catch (e) {
      debugPrint('Error analyzing current theme: $e');
      return null;
    }
  }

  // Generate AI-powered prompts
  Future<List<WritingPrompt>> _generateAIPrompts(
    Map<String, dynamic> context,
    int count,
    List<PromptCategory>? preferredCategories,
  ) async {
    try {
      final prompts = <WritingPrompt>[];
      
      // Generate different types of prompts based on context
      if (context['hasCurrentContent'] == true) {
        final continuationPrompts = await _generateContinuationPrompts(context, 2);
        prompts.addAll(continuationPrompts);
      }
      
      final reflectionPrompts = await _generateReflectionPrompts(context, 2);
      prompts.addAll(reflectionPrompts);
      
      final creativityPrompts = await _generateCreativityPrompts(context, 1);
      prompts.addAll(creativityPrompts);
      
      return prompts;
    } catch (e) {
      debugPrint('Error generating AI prompts: $e');
      return [];
    }
  }

  // Generate continuation prompts for current content
  Future<List<WritingPrompt>> _generateContinuationPrompts(
    Map<String, dynamic> context,
    int count,
  ) async {
    try {
      final currentTheme = context['currentTheme'] as String?;
      if (currentTheme == null) return [];
      
      final prompt = '''
The user is writing about: "$currentTheme"

Generate $count thoughtful writing prompts that help them continue or explore this topic deeper. Make the prompts:
- Personal and introspective
- Open-ended to encourage exploration
- Connected to their current thoughts
- Encouraging rather than prescriptive

Format as JSON:
[
  {"prompt": "What aspect of [theme] surprises you most when you think about it?", "inspiration": "Explores unexpected angles"},
  {"prompt": "How has your relationship with [theme] changed over time?", "inspiration": "Encourages temporal reflection"}
]
''';
      
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 300,
        temperature: 0.7,
      );
      
      return _parsePromptResponse(response, PromptCategory.reflection, context);
    } catch (e) {
      debugPrint('Error generating continuation prompts: $e');
      return [];
    }
  }

  // Generate reflection prompts based on mood and themes
  Future<List<WritingPrompt>> _generateReflectionPrompts(
    Map<String, dynamic> context,
    int count,
  ) async {
    try {
      final recentThemes = context['recentThemes'] as List? ?? [];
      final moodPattern = context['moodPattern'] as Map? ?? {};
      final trend = moodPattern['trend'] as String? ?? 'stable';
      
      final prompt = '''
Generate $count reflective writing prompts for someone who:
- Recently wrote about: ${recentThemes.join(', ')}
- Has a $trend mood trend
- Wants to explore their thoughts and feelings deeper

Make the prompts:
- Thought-provoking but not overwhelming
- Personally relevant based on their themes
- Encouraging self-discovery
- Suitable for journaling

Format as JSON:
[
  {"prompt": "What patterns do you notice in your recent thoughts?", "inspiration": "Pattern recognition"},
  {"prompt": "What would you tell your past self about handling challenges?", "inspiration": "Wisdom sharing"}
]
''';
      
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 300,
        temperature: 0.7,
      );
      
      return _parsePromptResponse(response, PromptCategory.reflection, context);
    } catch (e) {
      debugPrint('Error generating reflection prompts: $e');
      return [];
    }
  }

  // Generate creativity prompts
  Future<List<WritingPrompt>> _generateCreativityPrompts(
    Map<String, dynamic> context,
    int count,
  ) async {
    try {
      final prompt = '''
Generate $count creative writing prompts that:
- Spark imagination and creativity
- Are open-ended and inspiring
- Encourage storytelling or creative thinking
- Could lead to interesting journal entries

Format as JSON:
[
  {"prompt": "If you could have dinner with any version of yourself, which would you choose and why?", "inspiration": "Self-exploration through imagination"},
  {"prompt": "Describe a perfect day 10 years from now in vivid detail", "inspiration": "Future visioning"}
]
''';
      
      final response = await _aiService.generateText(
        prompt,
        maxTokens: 200,
        temperature: 0.8,
      );
      
      return _parsePromptResponse(response, PromptCategory.creativity, context);
    } catch (e) {
      debugPrint('Error generating creativity prompts: $e');
      return [];
    }
  }

  List<WritingPrompt> _parsePromptResponse(
    String response, 
    PromptCategory category,
    Map<String, dynamic> context,
  ) {
    try {
      final jsonStart = response.indexOf('[');
      final jsonEnd = response.lastIndexOf(']') + 1;
      
      if (jsonStart == -1 || jsonEnd <= jsonStart) return [];
      
      final jsonString = response.substring(jsonStart, jsonEnd);
      final parsed = jsonDecode(jsonString) as List;
      
      return parsed.map((item) {
        final promptData = item as Map<String, dynamic>;
        return WritingPrompt(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}',
          prompt: promptData['prompt'] as String,
          category: category.displayName,
          inspiration: promptData['inspiration'] as String? ?? 'AI-generated prompt',
          createdAt: DateTime.now(),
          relevanceScore: 0.8 + (_random.nextDouble() * 0.2), // 0.8-1.0
          context: context,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error parsing prompt response: $e');
      return [];
    }
  }

  // Generate fallback prompts when AI generation fails
  List<WritingPrompt> _generateFallbackPrompts(
    Map<String, dynamic> context,
    int count,
    List<PromptCategory>? preferredCategories,
  ) {
    final fallbackPrompts = [
      // Reflection prompts
      WritingPrompt(
        id: 'fallback_reflection_1',
        prompt: 'What three things are you most grateful for today?',
        category: PromptCategory.gratitude.displayName,
        inspiration: 'Daily gratitude practice',
        createdAt: DateTime.now(),
        relevanceScore: 0.6,
        context: context,
      ),
      WritingPrompt(
        id: 'fallback_growth_1',
        prompt: 'What skill or habit would you like to develop, and what\'s your first step?',
        category: PromptCategory.growth.displayName,
        inspiration: 'Personal development',
        createdAt: DateTime.now(),
        relevanceScore: 0.6,
        context: context,
      ),
      WritingPrompt(
        id: 'fallback_emotions_1',
        prompt: 'How would you describe your current emotional state to a close friend?',
        category: PromptCategory.emotions.displayName,
        inspiration: 'Emotional awareness',
        createdAt: DateTime.now(),
        relevanceScore: 0.6,
        context: context,
      ),
      WritingPrompt(
        id: 'fallback_memories_1',
        prompt: 'What\'s a small moment from this week that brought you joy?',
        category: PromptCategory.memories.displayName,
        inspiration: 'Mindful appreciation',
        createdAt: DateTime.now(),
        relevanceScore: 0.6,
        context: context,
      ),
      WritingPrompt(
        id: 'fallback_future_1',
        prompt: 'If you could send a message to yourself one year from now, what would it say?',
        category: PromptCategory.future.displayName,
        inspiration: 'Future self communication',
        createdAt: DateTime.now(),
        relevanceScore: 0.6,
        context: context,
      ),
    ];
    
    // Shuffle and return requested count
    fallbackPrompts.shuffle(_random);
    return fallbackPrompts.take(count).toList();
  }

  // Get prompts by category
  Future<List<WritingPrompt>> getPromptsByCategory(
    PromptCategory category, {
    int count = 5,
    String? currentContent,
  }) async {
    return generateContextualPrompts(
      currentContent: currentContent,
      count: count,
      preferredCategories: [category],
    );
  }

  void dispose() {
    _isInitialized = false;
  }
} 