import 'dart:io';
import 'ai_service.dart';
import 'database_service.dart';
import 'embedding_service.dart';
import '../models/journal_file.dart';
import '../models/conversation_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/context_settings.dart';

class JournalCompanionService {
  static final JournalCompanionService _instance = JournalCompanionService._internal();
  factory JournalCompanionService() => _instance;
  JournalCompanionService._internal();

  final AIService _aiService = AIService();
  final DatabaseService _dbService = DatabaseService();
  final EmbeddingService _embeddingService = EmbeddingService();

  /// Generate AI insights based on user query using embeddings-based context
  Future<String> generateInsights({
    required String userQuery,
    ConversationSession? conversation,
    required ContextSettings settings,
  }) async {
    print('=== GENERATEINSIGHTS METHOD CALLED ===');
    print('USER QUERY: $userQuery');
    
    // Try multiple log approaches to see if any work
    stderr.writeln('STDERR: generateInsights called with query: $userQuery');
    
    // Force flush stdout
    stdout.writeln('STDOUT: generateInsights method entry');
    
    print('🚨🚨🚨 METHOD CALLED - START OF GENERATEINSIGHTS 🚨🚨🚨');
    print('🚨🚨🚨 USER QUERY: $userQuery 🚨🚨🚨');
    print('🚨🚨🚨 SETTINGS: ${settings.toString()} 🚨🚨🚨');
    try {
      print('🚨🚨🚨 EMBEDDINGS SEARCH STARTING 🚨🚨🚨');
      print('🧠 Generating insights with embeddings-based context...');
      
      // Get user token setting
      final userTokens = await _getUserTokenSetting();
      print('   User token setting: $userTokens');
      
      // 1. CORE CONTEXT (Always included, minimal tokens)
      final profileContent = await _getUserProfile(100); // REDUCED - profile should be very minimal
      final conversationContext = _getConversationHistory(conversation, 300); // REDUCED - less context to avoid confusion
      
      // 2. CUSTOM CONTEXT (Use what's actually needed, not a fixed budget)
      final customContext = await _getCustomContext(settings, userTokens); // Let it calculate its own needs
      final customTokensUsed = _estimateTokens(customContext);
      
      // 3. EMBEDDINGS (Gets remaining tokens - scales with user setting!)
      final remainingTokensForEmbeddings = userTokens - 400 - customTokensUsed; // 400 = profile(100) + conversation(300)
      print('🚨🚨🚨 ABOUT TO SEARCH EMBEDDINGS 🚨🚨🚨');
      final relevantEntries = await _getRelevantEntriesFromEmbeddings(userQuery, remainingTokensForEmbeddings);
      
      return await _generateCleanResponse(
        userQuery: userQuery,
        profileContent: profileContent,
        relevantEntries: relevantEntries,
        conversationContext: conversationContext,
        customContext: customContext,
      );
      
    } catch (e) {
      print('❌ Error generating insights: $e');
      return 'Sorry, I had trouble processing your question. Please try again.';
    }
  }

  /// Get user's saved token setting from SharedPreferences
  Future<int> _getUserTokenSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokens = prefs.getDouble('context_token_usage') ?? 30000.0;
      return tokens.toInt();
    } catch (e) {
      print('   Using default tokens (SharedPreferences error): $e');
      return 30000; // Fallback to default
    }
  }

  /// Get user profile content
  Future<String> _getUserProfile(int tokenBudget) async {
    try {
      final profileFile = await _dbService.getProfileFile();
      if (profileFile?.content?.isNotEmpty == true) {
        final cleanProfile = _extractUserContentFromProfile(profileFile!.content!);
        final profileTokens = _estimateTokens(cleanProfile);
        
        if (profileTokens <= tokenBudget) {
          print('   ✅ Profile: ${profileTokens} tokens');
          return cleanProfile;
        }
        
        // Truncate profile if too long
        final truncatedProfile = _truncateToTokenBudget(cleanProfile, tokenBudget);
        final finalTokens = _estimateTokens(truncatedProfile);
        print('   ✅ Profile (truncated): ${finalTokens} tokens');
        return truncatedProfile;
      }
      
      print('   ⚠️ No profile file found');
      return 'No profile information available.';
      
    } catch (e) {
      print('Error loading user profile: $e');
      return 'Profile information unavailable.';
    }
  }

  /// Get conversation history (last 10 exchanges)
  String _getConversationHistory(ConversationSession? conversation, int tokenBudget) {
    try {
      if (conversation?.history.isEmpty != false) {
        print('   ⚠️ No conversation history');
        return '';
      }
      
      print('   💬 Building conversation context...');
      
      // Get recent messages (last 3 exchanges = 6 messages max) - reduced to avoid confusion
      final recentHistory = conversation!.history.reversed.take(6).toList().reversed.toList();
      
      final conversationLines = <String>[];
      int usedTokens = 0;
      
      for (final message in recentHistory) {
        final line = '${message.role == 'user' ? 'User' : 'Assistant'}: ${message.content}';
        final lineTokens = _estimateTokens(line);
        
        if (usedTokens + lineTokens <= tokenBudget) {
          conversationLines.insert(0, line);
          usedTokens += lineTokens;
        } else {
          break;
        }
      }
      
      print('   ✅ Conversation truncated: ${usedTokens} tokens');
      return conversationLines.join('\n');
      
    } catch (e) {
      print('Error building conversation context: $e');
      return 'No conversation context available.';
    }
  }

  /// Get relevant entries using embeddings search
  Future<String> _getRelevantEntriesFromEmbeddings(String userQuery, int tokenBudget) async {
    try {
      print('   🔍 Searching embeddings for relevant entries...');
      print('   Query: "$userQuery"');
      print('   Token budget: $tokenBudget');
      
      // First, check if any embeddings exist in the database
      final embeddingCount = await _dbService.getEmbeddingCount();
      print('   📊 Total embeddings in database: $embeddingCount');
      
      if (embeddingCount == 0) {
        print('   ⚠️ No embeddings found in database - files need to be imported first');
        return 'No relevant entries found. Import some journal files to enable AI search.';
      }
      
      // Show sample of what embeddings exist
      final sampleEmbeddings = await _dbService.getEmbeddingSample(limit: 3);
      print('   📋 Sample embeddings:');
      for (final sample in sampleEmbeddings) {
        print('     - ${sample['name']}: chunk ${sample['chunk_index']}, ${sample['content_length']} chars, ${sample['embedding_size']} bytes');
      }
      
      // Find most similar files using embeddings
      final similarFiles = await _embeddingService.findSimilarFiles(userQuery, topK: 10);
      print('   🎯 Found ${similarFiles.length} similar files from chunked embeddings');
      
      if (similarFiles.isEmpty) {
        print('   ⚠️ Embedding search returned no results - similarity may be too low');
        return 'No relevant entries found for your query.';
      }
      
      final relevantEntries = <String>[];
      int currentTokens = 0;
      
      print('   📄 Processing files:');
      for (int i = 0; i < similarFiles.length && currentTokens < tokenBudget; i++) {
        final file = similarFiles[i];
        print('   📄 Processing file ${i + 1}/${similarFiles.length}: ${file.name}');
        
        // Get clean content
        final cleanContent = _extractUserContentOnly(file.content);
        final entryTokens = _estimateTokens(cleanContent);
        
        print('     📊 Content: ${cleanContent.length} chars, ~$entryTokens tokens');
        
        if (currentTokens + entryTokens <= tokenBudget && cleanContent.isNotEmpty) {
          final entry = '**${file.name}** (${file.journalDate?.toString().split(' ')[0] ?? 'No date'}):\n$cleanContent';
          relevantEntries.add(entry);
          currentTokens += entryTokens;
          print('     ✅ Added to context (total tokens: $currentTokens)');
        } else {
          print('     ⏭️ Skipped (would exceed token budget or empty content)');
        }
      }
      
      if (relevantEntries.isEmpty) {
        print('   ⚠️ No entries had usable content after filtering');
        return 'No relevant entries found for your query.';
      }
      
      final result = relevantEntries.join('\n\n');
      print('   🎯 Returning ${relevantEntries.length} relevant entries (~$currentTokens tokens)');
      return result;
      
    } catch (e) {
      print('   🔴 Error in embedding search: $e');
      return 'Error searching for relevant entries: $e';
    }
  }

  /// Get custom context for selected files (NEEDS-BASED SYSTEM)
  Future<String> _getCustomContext(ContextSettings settings, int maxTokenBudget) async {
    try {
      if (settings.selectedFileIds.isEmpty) {
        return '';
      }
      
      print('   📁 Loading ${settings.selectedFileIds.length} selected files (needs-based system)...');
      
      // Get profile file ID to avoid duplication
      final profileFile = await _dbService.getProfileFile();
      final profileFileId = profileFile?.id;
      
      final selectedFiles = <String>[];
      int totalTokensNeeded = 0;
      final maxReasonableLimit = (maxTokenBudget * 0.6).toInt(); // Don't let custom files dominate
      
      for (final fileId in settings.selectedFileIds) {
        // Skip profile file to avoid duplication
        if (fileId == profileFileId) {
          print('   ⏭️ Skipping profile file - already loaded in main context');
          continue;
        }
        
        try {
          final file = await _dbService.getFile(fileId);
          if (file?.content?.isNotEmpty == true) {
            // Clean the content
            final cleanContent = _extractUserContentOnly(file!.content!);
            if (cleanContent.trim().isEmpty) {
              print('   ⏭️ Skipping ${file.name} - no user content after cleaning');
              continue;
            }
            
            final fileTokens = _estimateTokens(cleanContent);
            
            // Check if adding this file would exceed reasonable limits
            if (totalTokensNeeded + fileTokens > maxReasonableLimit) {
              print('   ⏹️ Stopping at ${file.name} - would exceed reasonable limit (${maxReasonableLimit} tokens)');
              break;
            }
            
            selectedFiles.add('${file.name}:\n$cleanContent');
            totalTokensNeeded += fileTokens;
            print('   ✅ Added ${file.name} (${fileTokens} tokens)');
            
          } else {
            print('   ⏭️ Skipping ${file?.name ?? 'unknown'} - no content');
          }
        } catch (e) {
          print('   ❌ Error loading file $fileId: $e');
        }
      }
      
      if (selectedFiles.isNotEmpty) {
        final result = selectedFiles.join('\n\n');
        print('   ✅ Custom context: ${selectedFiles.length} files, ${totalTokensNeeded} tokens used');
        return result;
      }
      
      return '';
      
    } catch (e) {
      print('Error getting custom context: $e');
      return '';
    }
  }

  /// Generate a clean response using the AI service
  Future<String> _generateCleanResponse({
    required String userQuery,
    required String profileContent,
    required String relevantEntries,
    required String conversationContext,
    required String customContext,
  }) async {
      
    final systemPrompt = '''You are their thoughtful journal analyst - like a close friend who maintains conversations through insights and questions. 
    

CRITICAL: FOCUS ON THEIR CURRENT QUESTION FIRST
- Their current question is the PRIORITY - answer it directly and completely
- Use context only to SUPPORT your answer to their current question
- Don't get sidetracked by unrelated context information
- Stay laser-focused on what they're asking RIGHT NOW

RESPONSE APPROACH:
1. ANSWER THEIR CURRENT QUESTION FIRST (this is most important)
2. Use journal entries only when they directly relate to their question
3. Reference conversation history only if it helps answer their current question
4. Ask follow-up questions related to what they just asked

CONVERSATIONAL STYLE:
- Use "you/your" exclusively - warm and personal
- Be direct and focused - answer what they asked
- Ask thoughtful follow-up questions about their current topic
- Reference entries only when they're relevant to their question

Your goal: Answer their current prompt thoroughly while using context only when it helps.''';

    final prompt = '''CURRENT QUESTION: $userQuery

SUPPORTING CONTEXT (use only if relevant to their question):
${conversationContext.isNotEmpty ? 'Recent conversation:\n$conversationContext\n' : ''}
${profileContent.isNotEmpty ? 'About them:\n$profileContent\n' : ''}
${relevantEntries.isNotEmpty ? 'Relevant journal entries:\n$relevantEntries\n' : ''}
${customContext.isNotEmpty ? 'Selected files:\n$customContext\n' : ''}

Answer their current question above:''';

    return await _generateCompleteResponse(prompt, systemPrompt);
  }

  /// Generate a complete response with natural completion
  Future<String> _generateCompleteResponse(String prompt, String systemPrompt) async {
    // Let AI complete naturally with no character limits
    final response = await _aiService.generateTextNaturally(
      prompt,
      // No safetyLimit - allow unlimited response length
      temperature: 0.5, // LOWER - More focused and direct responses
      systemPrompt: systemPrompt,
    );
    
    return response.trim();
  }
  
  /// Extract user content only (filter out template/AI content)
  String _extractUserContentOnly(String content) {
    if (content.trim().isEmpty) return '';
    
    // Light filtering for journal content - only remove truly empty content
    String cleanContent = content;
    
    // Remove excessive whitespace but preserve structure
    cleanContent = cleanContent.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    cleanContent = cleanContent.trim();
    
    return cleanContent;
  }

  /// Extract user content from profile file (aggressive template filtering)
  String _extractUserContentFromProfile(String content) {
    if (content.trim().isEmpty) return '';
    
    // Remove template indicators (ONLY for profile file)
    final templatePatterns = [
      r'\[Your Name Here\]',
      r'\[your name here\]',
      r'\*This becomes your display name.*?\*',
      r'\*What is your core purpose.*?\*',
      r'\*What are the key roles.*?\*',
      r'\*What principles guide.*?\*',
      r'\*What energizes and motivates.*?\*',
      r'\*Where do you see yourself.*?\*',
      r'\*What are your main objectives.*?\*',
      r'\*What specific goals.*?\*',
      r'Write your personal mission statement here\.\.\.',
      r'This information helps the AI understand.*?\*',
      r'## Mission Statement',
      r'## My Roles',
      r'## Core Values', 
      r'## What Drives Me',
      r'## 5-Year Vision',
      r"## This Year's Focus",
      r'## This Month',
    ];
    
    String cleanContent = content;
    
    // Remove template patterns
    for (final pattern in templatePatterns) {
      cleanContent = cleanContent.replaceAll(RegExp(pattern, multiLine: true, caseSensitive: false), '');
    }
    
    // Remove empty bullet points and placeholder text
    cleanContent = cleanContent.replaceAll(RegExp(r'^•\s*$', multiLine: true), '');
    cleanContent = cleanContent.replaceAll(RegExp(r'^\s*-\s*$', multiLine: true), '');
    cleanContent = cleanContent.replaceAll(RegExp(r'---+', multiLine: true), '');
    
    // Clean up excessive whitespace
    cleanContent = cleanContent.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    cleanContent = cleanContent.trim();
    
    return cleanContent;
  }

  /// Truncate text to fit within token budget, stopping at sentence boundaries
  String _truncateToTokenBudget(String text, int tokenBudget) {
    if (_estimateTokens(text) <= tokenBudget) {
      return text;
    }

    final sentences = text.split(RegExp(r'[.!?]+\s+'));
    final result = <String>[];
    int currentTokens = 0;

    for (final sentence in sentences) {
      final sentenceTokens = _estimateTokens(sentence + '. ');
      if (currentTokens + sentenceTokens <= tokenBudget) {
        result.add(sentence);
        currentTokens += sentenceTokens;
      } else {
        break;
      }
    }

    return result.isNotEmpty ? result.join('. ') + '.' : '';
  }

  /// Estimate tokens in text (rough approximation)
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