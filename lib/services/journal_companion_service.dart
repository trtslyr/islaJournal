import 'ai_service.dart';
import 'database_service.dart';
import 'embedding_service.dart';
import '../models/journal_file.dart';
import '../models/conversation_session.dart';
import '../models/context_settings.dart';

class JournalCompanionService {
  static final JournalCompanionService _instance = JournalCompanionService._internal();
  factory JournalCompanionService() => _instance;
  JournalCompanionService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  final EmbeddingService _embeddingService = EmbeddingService();

  /// Main method: Generate insights using context based on conversation settings
  Future<String> generateInsights(String query, {ConversationSession? conversation}) async {
    try {
      // Get context based on conversation settings
      final contextSettings = conversation?.contextSettings ?? ContextSettings.general;
      final contextFiles = await _getContextForSettings(query, contextSettings);
      
      // Generate thoughtful response with conversation awareness
      return await _generateResponse(query, contextFiles, conversation);
      
    } catch (e) {
      print('❌ Error generating insights: $e');
      return 'Sorry, I had trouble processing your question. Please try again.';
    }
  }

  /// Get context based on conversation settings with token limits
  Future<List<JournalFile>> _getContextForSettings(String query, ContextSettings settings) async {
    switch (settings.mode) {
      case ContextMode.general:
        return await _getGeneralContext(query, settings.maxTokens);
      case ContextMode.timeframe:
        return await _getTimeframeContext(settings, settings.maxTokens);
      case ContextMode.custom:
        return await _getCustomContext(settings, settings.maxTokens);
    }
  }

  /// Get general context (current hybrid approach)
  Future<List<JournalFile>> _getGeneralContext(String query, int maxTokens) async {
    final contexts = await Future.wait([
      _getRecentContext(maxTokens: maxTokens ~/ 3),           // 1/3 of tokens for recent
      _getRelevantContext(query, maxTokens: maxTokens ~/ 3),  // 1/3 for relevant
      _getLongTermContext(query, maxTokens: maxTokens ~/ 3),  // 1/3 for long-term
    ]);
    
    return _mergeContexts(contexts[0], contexts[1], contexts[2]);
  }

  /// Get timeframe-based context
  Future<List<JournalFile>> _getTimeframeContext(ContextSettings settings, int maxTokens) async {
    final timeframeDays = settings.timeframeDays;
    
    DateTime? sinceDate;
    if (timeframeDays != null) {
      sinceDate = DateTime.now().subtract(Duration(days: timeframeDays));
    }
    
    return await _dbService.getRecentFilesOrdered(
      maxTokens: maxTokens,
      sinceDate: sinceDate,
    );
  }

  /// Get custom context from selected files
  Future<List<JournalFile>> _getCustomContext(ContextSettings settings, int maxTokens) async {
    if (settings.customFileIds.isEmpty) {
      return [];
    }
    
    final files = <JournalFile>[];
    int totalTokens = 0;
    
    // Load files in order and respect token limit
    for (final fileId in settings.customFileIds) {
      final file = await _dbService.getFile(fileId);
      if (file != null) {
        final fileTokens = _estimateTokens(file.content ?? '');
        if (totalTokens + fileTokens <= maxTokens) {
          files.add(file);
          totalTokens += fileTokens;
        } else {
          break; // Stop if we would exceed token limit
        }
      }
    }
    
    // Sort chronologically by date
    files.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    
    return files;
  }

  /// Get intelligent context across time periods (kept for backwards compatibility)
  Future<List<JournalFile>> _getHybridContext(String query) async {
    final contexts = await Future.wait([
      _getRecentContext(),           // Last 30 days
      _getRelevantContext(query),    // Semantic similarity
      _getLongTermContext(query),    // Historical patterns
    ]);
    
    return _mergeContexts(contexts[0], contexts[1], contexts[2]);
  }

  /// Recent context: Last 30 days for continuity
  Future<List<JournalFile>> _getRecentContext({int? maxTokens}) async {
    final cutoff = DateTime.now().subtract(Duration(days: 30));
    return await _dbService.getRecentFilesOrdered(
      maxTokens: maxTokens ?? 8000,  // Use provided maxTokens or default to 8K
      sinceDate: cutoff,
    );
  }

  /// Relevant context: Semantic similarity with strong recency bias
  Future<List<JournalFile>> _getRelevantContext(String query, {int? maxTokens}) async {
    final candidates = await _embeddingService.findSimilarFiles(query, topK: 10);
    
    // Apply STRONG recency bias to avoid getting stuck on old topics
    final now = DateTime.now();
    final scoredCandidates = candidates.map((file) {
      final daysSinceUpdate = now.difference(file.updatedAt).inDays;
      
      // Heavily favor recent entries
      double recencyBoost = 1.0;
      if (daysSinceUpdate <= 3) {
        recencyBoost = 5.0;  // Very recent gets huge boost
      } else if (daysSinceUpdate <= 7) {
        recencyBoost = 3.0;  // Recent gets big boost
      } else if (daysSinceUpdate <= 30) {
        recencyBoost = 1.5;  // Somewhat recent gets small boost
      }
      
      return _ScoredFile(file, recencyBoost);
    }).toList();
    
    // Sort by adjusted score
    scoredCandidates.sort((a, b) => b.score.compareTo(a.score));
    
    // Apply token limit if provided
    if (maxTokens != null) {
      final filteredFiles = <JournalFile>[];
      int totalTokens = 0;
      
      for (final candidate in scoredCandidates) {
        final fileTokens = _estimateTokens(candidate.file.content ?? '');
        if (totalTokens + fileTokens <= maxTokens) {
          filteredFiles.add(candidate.file);
          totalTokens += fileTokens;
        } else {
          break;
        }
      }
      
      return filteredFiles;
    }
    
    return scoredCandidates.take(3).map((sf) => sf.file).toList();
  }

  /// Long-term context: Historical patterns and growth
  Future<List<JournalFile>> _getLongTermContext(String query, {int? maxTokens}) async {
    // Get older entries (3+ months ago) that are semantically similar
    final threeMonthsAgo = DateTime.now().subtract(Duration(days: 90));
    
    // Find semantic matches from the older time period
    final allSimilar = await _embeddingService.findSimilarFiles(query, topK: 20);
    
    // Filter for entries older than 3 months
    final longTermCandidates = allSimilar.where((file) => 
      file.updatedAt.isBefore(threeMonthsAgo)
    ).toList();
    
    // Apply token limit if provided
    if (maxTokens != null) {
      final filteredFiles = <JournalFile>[];
      int totalTokens = 0;
      
      for (final candidate in longTermCandidates) {
        final fileTokens = _estimateTokens(candidate.content ?? '');
        if (totalTokens + fileTokens <= maxTokens) {
          filteredFiles.add(candidate);
          totalTokens += fileTokens;
        } else {
          break;
        }
      }
      
      return filteredFiles;
    }
    
    return longTermCandidates.take(2).toList();
  }

  /// Smart merge: balance all three contexts with recent priority
  List<JournalFile> _mergeContexts(
    List<JournalFile> recent, 
    List<JournalFile> relevant, 
    List<JournalFile> longTerm
  ) {
    final seen = <String>{};
    final merged = <JournalFile>[];
    
    // Add recent context FIRST (up to 3) - this breaks feedback loops
    for (final file in recent.take(3)) {
      if (!seen.contains(file.id)) {
        merged.add(file);
        seen.add(file.id);
      }
    }
    
    // Add relevant entries only if they're not already included
    for (final file in relevant.take(2)) {
      if (!seen.contains(file.id) && merged.length < 5) {
        merged.add(file);
        seen.add(file.id);
      }
    }
    
    // Add long-term perspective (up to 1)
    for (final file in longTerm.take(1)) {
      if (!seen.contains(file.id) && merged.length < 5) {
        merged.add(file);
        seen.add(file.id);
      }
    }
    
    return merged;
  }

  /// Generate thoughtful response with conversation awareness
  Future<String> _generateResponse(String query, List<JournalFile> files, ConversationSession? conversation) async {
    if (files.isEmpty) {
      return "I don't see any journal entries that relate to your question.";
    }
    
    final prompt = await _buildPrompt(query, files, conversation);
    
    return await _aiService.generateText(
      prompt,
      maxTokens: 275, // Sweet spot: complete thoughts without rambling
      temperature: 0.6, // Balanced: natural but focused
      systemPrompt: '''You are a supportive friend who has read their journal over time.
      
      Respond naturally and directly to their CURRENT question. Follow their lead on topic changes.
      Use the most recent journal entries as your primary source of truth.
      Keep responses thoughtful but concise - 2-3 sentences typically.
      Be warm and understanding, like a friend who really knows them.
      
      IMPORTANT: You have been provided background context about this person for personalization, but DO NOT reference or mention this background context unless they specifically ask about it.''',
    );
  }

  /// Clean prompt with user question as primary focus - ONLY user journal data
  Future<String> _buildPrompt(String query, List<JournalFile> files, ConversationSession? conversation) async {
    final parts = <String>[];
    
    // GET USER PROFILE FROM PROFILE FILE (but don't mention it)
    final profileFile = await _dbService.getProfileFile();
    if (profileFile != null && profileFile.content!.isNotEmpty) {
      final cleanProfileContent = _extractUserContentOnly(profileFile.content!);
      if (cleanProfileContent.trim().isNotEmpty) {
        parts.add('[BACKGROUND CONTEXT - DO NOT MENTION OR REFERENCE]');
        parts.add(cleanProfileContent);
        parts.add('[END BACKGROUND CONTEXT]');
        parts.add('');
      }
    }
    
    // START WITH CLEAR INSTRUCTION AND USER'S QUESTION
    parts.add('ANSWER THIS QUESTION: $query');
    parts.add('');
    parts.add('Use the journal entries below as context to provide a thoughtful, personal answer based on the user\'s actual experiences and patterns.');
    parts.add('');
    
    // NO CONVERSATION HISTORY - Only pure user journal data
    parts.add('SUPPORTING CONTEXT FROM JOURNAL:');
    
    for (final file in files) {
      parts.add('${file.name} (${_formatDate(file.updatedAt)}):');
      // Only include pure user journal content - filter out any AI interactions
      final cleanContent = _extractUserContentOnly(file.content!);
      parts.add(cleanContent);
      parts.add('');
    }
    
    parts.add('---');
    parts.add('Remember: Answer the question "$query" using insights from the journal entries above.');
    
    return parts.join('\n');
  }
  
  /// Extract only user-written content, removing AI interactions
  String _extractUserContentOnly(String content) {
    final lines = content.split('\n');
    final userLines = <String>[];
    
    for (final line in lines) {
      // Skip AI prompts and responses (including inline Q&A format)
      if (line.startsWith('/') || 
          line.startsWith('< ') ||          // User questions
          line.startsWith('> ') ||          // AI responses
          line.startsWith('🤖') || 
          line.startsWith('⏳ thinking...') ||
          line.contains('Processing:') ||
          line.contains('Error:')) {
        continue;
      }
      userLines.add(line);
    }
    
    return userLines.join('\n').trim();
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Generate embedding for a file (for backward compatibility)
  Future<void> generateEmbeddingForFile(String fileId, String content) async {
    try {
      await _embeddingService.storeEmbedding(fileId, content);
    } catch (e) {
      print('Error generating embedding for file $fileId: $e');
    }
  }

  /// Estimate token count for content
  int _estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    
    // More accurate token estimation:
    // - Count words and punctuation separately
    // - Average English word is ~1.3 tokens
    // - Punctuation and spaces add overhead
    final words = text.trim().split(RegExp(r'\s+'));
    final wordTokens = (words.length * 1.3).ceil();
    
    // Add overhead for formatting, punctuation, etc.
    final overhead = (text.length * 0.1).ceil();
    
    return wordTokens + overhead;
  }
}

/// Helper class for scoring files with recency bias
class _ScoredFile {
  final JournalFile file;
  final double score;
  
  _ScoredFile(this.file, this.score);
}