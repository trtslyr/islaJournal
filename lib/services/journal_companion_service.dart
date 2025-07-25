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
    print('🚨🚨🚨🚨🚨 GENERATEINSIGHTS CALLED WITH QUERY: "$userQuery" 🚨🚨🚨🚨🚨');
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
      final conversationContext = _getConversationHistory(conversation, 300);
      
      // 2. PINNED CONTEXT (User-selected important content)
      final pinnedContext = await _getPinnedContent(userTokens ~/ 3); // Use up to 1/3 of tokens for pinned content
      final pinnedTokensUsed = _estimateTokens(pinnedContext);
      
      // 3. CUSTOM CONTEXT (Use what's actually needed, not a fixed budget)
      final customContext = await _getCustomContext(settings, userTokens); 
      final customTokensUsed = _estimateTokens(customContext);
      
      // 4. EMBEDDINGS (Gets remaining tokens)
      final coreTokensUsed = 300 + pinnedTokensUsed; // conversation(300) + pinned(actual usage)
      final remainingTokensForEmbeddings = userTokens - coreTokensUsed - customTokensUsed;
      print('🚨🚨🚨 ABOUT TO SEARCH EMBEDDINGS 🚨🚨🚨');
      final relevantEntries = await _getRelevantEntriesFromEmbeddings(userQuery, remainingTokensForEmbeddings);
      
      return await _generateCleanResponse(
        userQuery: userQuery,
        relevantEntries: relevantEntries,
        conversationContext: conversationContext,
        customContext: customContext,
        pinnedContext: pinnedContext,
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
      print('   🎯 About to call findSimilarFiles with query: "$userQuery"');
      final similarFiles = await _embeddingService.findSimilarFiles(userQuery, topK: 10);
      print('   🎯 Found ${similarFiles.length} similar files from chunked embeddings');
      
      if (similarFiles.isEmpty) {
        print('   ⚠️ CRITICAL: Embedding search returned NO RESULTS');
        print('   🔍 This suggests an issue with the similarity calculation or thresholds');
        return 'No relevant entries found for your query.';
      }
      
      final relevantEntries = <String>[];
      int currentTokens = 0;
      int skippedDueToTokens = 0;
      int skippedDueToEmptyContent = 0;
      
      print('   📄 Processing ${similarFiles.length} files:');
      for (int i = 0; i < similarFiles.length && currentTokens < tokenBudget; i++) {
        final file = similarFiles[i];
        print('   📄 Processing file ${i + 1}/${similarFiles.length}: ${file.name}');
        print('       Content length: ${file.content.length} chars');
        
        // Get clean content
        final cleanContent = _extractUserContentOnly(file.content);
        final entryTokens = _estimateTokens(cleanContent);
        
        print('     📊 Clean content: ${cleanContent.length} chars, ~$entryTokens tokens');
        print('     📊 Current tokens: $currentTokens, Budget: $tokenBudget, Would use: ${currentTokens + entryTokens}');
        
        if (cleanContent.isEmpty) {
          print('     ❌ SKIPPED: Empty content after filtering');
          skippedDueToEmptyContent++;
          continue;
        }
        
        if (currentTokens + entryTokens > tokenBudget) {
          print('     ❌ SKIPPED: Would exceed token budget ($tokenBudget)');
          skippedDueToTokens++;
          break;
        }
        
        final entry = '**${file.name}** (${file.journalDate?.toString().split(' ')[0] ?? 'No date'}):\n$cleanContent';
        relevantEntries.add(entry);
        currentTokens += entryTokens;
        print('     ✅ Added to context (total tokens: $currentTokens)');
      }
      
      print('   📊 FINAL STATS:');
      print('     - Files processed: ${similarFiles.length}');
      print('     - Files added to context: ${relevantEntries.length}');
      print('     - Skipped due to empty content: $skippedDueToEmptyContent');
      print('     - Skipped due to token budget: $skippedDueToTokens');
      print('     - Total tokens used: $currentTokens');
      
      if (relevantEntries.isEmpty) {
        print('   ⚠️ CRITICAL: No entries had usable content after filtering');
        if (skippedDueToEmptyContent > 0) {
          print('   🔍 Problem: All $skippedDueToEmptyContent files had empty content after filtering');
        }
        if (skippedDueToTokens > 0) {
          print('   🔍 Problem: $skippedDueToTokens files skipped due to token budget');
        }
        return 'No relevant entries found for your query.';
      }
      
      final result = relevantEntries.join('\n\n');
      print('   🎯 SUCCESS: Returning ${relevantEntries.length} relevant entries (~$currentTokens tokens)');
      return result;
      
    } catch (e) {
      print('   🔴 Error in embedding search: $e');
      print('   🔴 Stack trace: ${StackTrace.current}');
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
      
      final selectedFiles = <String>[];
      int totalTokensNeeded = 0;
      final maxReasonableLimit = (maxTokenBudget * 0.6).toInt(); // Don't let custom files dominate
      
      for (final fileId in settings.selectedFileIds) {
        
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

  /// Get pinned content for AI context (includes both files and folders)
  Future<String> _getPinnedContent(int tokenBudget) async {
    try {
      print('   📌 Loading pinned content...');
      
      // Get both pinned files and folders
      final pinnedFiles = await _dbService.getPinnedFiles();
      final pinnedFolders = await _dbService.getPinnedFolders();
      
      if (pinnedFiles.isEmpty && pinnedFolders.isEmpty) {
        print('   ⚠️ No pinned files or folders found');
        return '';
      }
      
      print('   📌 Found ${pinnedFiles.length} pinned files and ${pinnedFolders.length} pinned folders');
      
      final pinnedEntries = <String>[];
      int usedTokens = 0;
      
      // Process pinned files first
      for (final file in pinnedFiles) {
        if (file.content.isNotEmpty) {
          // Clean the content
          final cleanContent = _extractUserContentOnly(file.content);
          if (cleanContent.trim().isEmpty) continue;
          
          final entry = '${file.name}:\n$cleanContent';
          final entryTokens = _estimateTokens(entry);
          
          if (usedTokens + entryTokens <= tokenBudget) {
            pinnedEntries.add(entry);
            usedTokens += entryTokens;
            print('   ✅ Added pinned file: ${file.name} (${entryTokens} tokens)');
          } else {
            print('   ⏹️ Pinned content budget reached, stopping at file ${file.name}');
            break;
          }
        }
      }
      
      // Process pinned folders (get all files within them)
      for (final folder in pinnedFolders) {
        if (usedTokens >= tokenBudget) {
          print('   ⏹️ Pinned content budget reached, skipping folder ${folder.name}');
          break;
        }
        
        try {
          final folderFiles = await _dbService.getFiles(folderId: folder.id);
          print('   📁 Processing pinned folder "${folder.name}" with ${folderFiles.length} files');
          
          for (final file in folderFiles) {
            final fileContent = await _dbService.getFile(file.id);
            if (fileContent?.content?.isNotEmpty == true) {
              final cleanContent = _extractUserContentOnly(fileContent!.content!);
              if (cleanContent.trim().isEmpty) continue;
              
              final entry = '${folder.name}/${file.name}:\n$cleanContent';
              final entryTokens = _estimateTokens(entry);
              
              if (usedTokens + entryTokens <= tokenBudget) {
                pinnedEntries.add(entry);
                usedTokens += entryTokens;
                print('   ✅ Added file from pinned folder: ${folder.name}/${file.name} (${entryTokens} tokens)');
              } else {
                print('   ⏹️ Pinned content budget reached, stopping at folder file ${folder.name}/${file.name}');
                break;
              }
            }
          }
        } catch (e) {
          print('   ❌ Error processing pinned folder ${folder.name}: $e');
        }
      }
      
      if (pinnedEntries.isNotEmpty) {
        final result = pinnedEntries.join('\n\n');
        print('   ✅ Pinned context: ${pinnedEntries.length} entries (${pinnedFiles.length} files + ${pinnedFolders.length} folders), ${usedTokens} tokens');
        return result;
      }
      
      return '';
      
    } catch (e) {
      print('Error loading pinned content: $e');
      return '';
    }
  }

  /// Generate a clean response using the AI service
  Future<String> _generateCleanResponse({
    required String userQuery,
    required String relevantEntries,
    required String conversationContext,
    required String customContext,
    required String pinnedContext,
  }) async {
      
    final systemPrompt = '''You are talking to a close friend. Respond directly to what they just told you, like any friend would in conversation. 

Don't mention reading their journal or analyzing anything - just respond naturally to what they're sharing right now.''';

    final prompt = '''$userQuery

${conversationContext.isNotEmpty ? '$conversationContext\n' : ''}
${pinnedContext.isNotEmpty ? '$pinnedContext\n' : ''}
${relevantEntries.isNotEmpty ? '$relevantEntries\n' : ''}
${customContext.isNotEmpty ? '$customContext\n' : ''}''';

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

  /// DEBUGGING: Test the embedding system with a simple query
  Future<void> debugEmbeddingSystem({String testQuery = "work"}) async {
    print('🧪 DEBUGGING EMBEDDING SYSTEM WITH QUERY: "$testQuery"');
    
    try {
      // 1. Check database state
      final embeddingCount = await _dbService.getEmbeddingCount();
      print('   📊 Database embeddings: $embeddingCount');
      
      if (embeddingCount == 0) {
        print('   ❌ No embeddings found - import files first!');
        return;
      }
      
      // 2. Test query embedding generation
      final queryEmbedding = await _embeddingService.generateEmbedding(testQuery);
      print('   🧠 Query embedding: length=${queryEmbedding.length}, sum=${queryEmbedding.fold(0.0, (a, b) => a + b).toStringAsFixed(4)}');
      
      // 3. Test direct database parsing (NEW)
      final db = await _dbService.database;
      final sampleRows = await db.rawQuery('SELECT embedding FROM file_embeddings LIMIT 1');
      if (sampleRows.isNotEmpty) {
        final rawEmbedding = sampleRows.first['embedding'];
        final parsedEmbedding = _embeddingService.parseChunkedEmbedding(rawEmbedding);
        print('   🔧 PARSING TEST: Raw embedding type=${rawEmbedding.runtimeType}, parsed length=${parsedEmbedding.length}');
      }
      
      // 4. Test similarity search
      final similarFiles = await _embeddingService.findSimilarFiles(testQuery, topK: 5);
      print('   🎯 Similar files found: ${similarFiles.length}');
      
      // 5. Test content processing
      int validContentCount = 0;
      for (final file in similarFiles) {
        final cleanContent = _extractUserContentOnly(file.content);
        if (cleanContent.isNotEmpty) {
          validContentCount++;
          print('   ✅ File "${file.name}": ${cleanContent.length} chars after filtering');
        } else {
          print('   ❌ File "${file.name}": Empty after filtering (original: ${file.content.length} chars)');
        }
      }
      
      print('   📊 Files with valid content: $validContentCount/${similarFiles.length}');
      
      // 6. Test token estimation
      final tokenBudget = 5000;
      print('   💰 Testing with token budget: $tokenBudget');
      
      if (validContentCount == 0) {
        print('   ❌ ISSUE: No files have valid content after filtering!');
      } else {
        print('   ✅ Embedding system appears functional');
      }
      
    } catch (e) {
      print('   ❌ ERROR during embedding debug: $e');
      print('   📍 Stack trace: ${StackTrace.current}');
    }
  }

  /// CLEANUP: Clear corrupted embeddings and regenerate them
  Future<void> fixCorruptedEmbeddings() async {
    print('🔧 FIXING CORRUPTED EMBEDDINGS...');
    
    try {
      // 1. Clear all existing embeddings
      final db = await _dbService.database;
      await db.delete('file_embeddings');
      print('   🗑️ Cleared all existing embeddings');
      
      // 2. Get all files that need embeddings
      final allFiles = await _dbService.getFiles();
      print('   📄 Found ${allFiles.length} files to re-embed');
      
      // 3. Regenerate embeddings for each file
      int processed = 0;
      for (final fileMetadata in allFiles) {
        try {
          processed++;
          print('   📄 Processing ${processed}/${allFiles.length}: ${fileMetadata.name}');
          
          // Load full file content
          final file = await _dbService.getFile(fileMetadata.id);
          if (file?.content?.isNotEmpty == true) {
            // Generate embeddings using the import service chunking logic
            final chunks = _chunkContent(file!.content!);
            print('     🧠 Generating ${chunks.length} chunks...');
            
            for (int i = 0; i < chunks.length; i++) {
              final embedding = await _embeddingService.generateEmbedding(chunks[i]);
              await _dbService.storeChunkedEmbedding(file.id, i, chunks[i], embedding);
            }
            
            print('     ✅ Generated ${chunks.length} embeddings');
          } else {
            print('     ⏭️ Skipped (no content)');
          }
        } catch (e) {
          print('     ❌ Error processing ${fileMetadata.name}: $e');
        }
      }
      
      final finalCount = await _dbService.getEmbeddingCount();
      print('   🎉 COMPLETE: Generated $finalCount fresh embeddings');
      
    } catch (e) {
      print('   ❌ ERROR during embedding regeneration: $e');
    }
  }

  /// Helper: Chunk content similar to import service
  List<String> _chunkContent(String content) {
    final paragraphs = content.split('\n\n');
    final chunks = <String>[];
    String currentChunk = '';
    
    for (final paragraph in paragraphs) {
      final testChunk = currentChunk.isEmpty ? paragraph : '$currentChunk\n\n$paragraph';
      final wordCount = testChunk.split(' ').length;
      
      if (wordCount > 500 && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
        currentChunk = paragraph;
      } else {
        currentChunk = testChunk;
      }
    }
    
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }
    
    return chunks.isEmpty ? [content] : chunks;
  }
}