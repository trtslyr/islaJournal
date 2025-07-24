import 'dart:io';
import 'lib/services/rag_service.dart';
import 'lib/services/embedding_service.dart';
import 'lib/services/database_service.dart';
import 'lib/models/journal_file.dart';

Future<void> main() async {
  print('=== Context System Test ===');
  
  try {
    // Initialize core services
    final dbService = DatabaseService();
    final embeddingService = EmbeddingService();
    final ragService = RAGService();
    
    print('Initializing services...');
    await embeddingService.initialize();
    await ragService.initialize();
    print('✅ Services initialized');
    
    // Get or create some test content
    final files = await dbService.getFiles();
    
    if (files.isEmpty) {
      print('No journal files found. Creating test content...');
      
      // Create test journal entries
      final testEntries = [
        {
          'name': 'Morning Thoughts',
          'content': 'Today I woke up feeling grateful for the beautiful sunrise. The warm colors reminded me of my childhood memories playing in the garden. I want to focus on being more mindful and present in each moment.',
        },
        {
          'name': 'Work Reflection',
          'content': 'Had an interesting meeting today about the new project. The team is really collaborative and I feel excited about the challenges ahead. Need to remember to balance work and personal time better.',
        },
        {
          'name': 'Evening Journal',
          'content': 'Spent time with family today. We talked about our dreams and aspirations. I realize how important relationships are for my happiness and personal growth. Feeling inspired to pursue creative writing.',
        },
      ];
      
      for (final entry in testEntries) {
        final fileId = await dbService.createFile(
          entry['name']!, 
          entry['content']!, 
          folderId: 'personal'
        );
        print('Created test file: ${entry['name']}');
      }
      
      // Refresh files list
      final newFiles = await dbService.getFiles();
      print('✅ Created ${newFiles.length} test files');
    }
    
    // Test the embedding system
    print('\n=== Testing Embedding System ===');
    
    final testText = 'I am feeling happy and grateful today. The weather is beautiful and I spent time in nature.';
    final embedding = await embeddingService.generateEmbedding(testText, 'test_embedding');
    print('✅ Generated embedding: ${embedding.length} dimensions');
    
    final vocabStats = embeddingService.getVocabularyStats();
    print('✅ Vocabulary stats: $vocabStats');
    
    // Test indexing journal entries
    print('\n=== Testing Journal Indexing ===');
    
    final journalFiles = await dbService.getFiles();
    print('Found ${journalFiles.length} journal files to index');
    
    for (final file in journalFiles) {
      final fullFile = await dbService.getFile(file.id);
      if (fullFile != null && fullFile.content.trim().isNotEmpty) {
        print('Indexing: ${fullFile.name}');
        await ragService.indexJournalEntry(fullFile);
        print('✅ Indexed: ${fullFile.name}');
      }
    }
    
    // Test context retrieval
    print('\n=== Testing Context Retrieval ===');
    
    final testQueries = [
      'happiness and gratitude',
      'work and projects',
      'family and relationships',
      'creative writing inspiration',
      'mindfulness and being present',
    ];
    
    for (final query in testQueries) {
      print('\nQuery: "$query"');
      final results = await ragService.retrieveRelevantContent(query);
      print('Found ${results.length} relevant chunks:');
      
      for (int i = 0; i < results.length && i < 3; i++) {
        final result = results[i];
        print('  ${i+1}. [${(result.similarity * 100).toStringAsFixed(1)}%] ${result.content.substring(0, 100)}...');
      }
    }
    
    // Test RAG response generation
    print('\n=== Testing RAG Response Generation ===');
    
    final testPrompts = [
      'What are the main themes in my journal entries?',
      'How do I feel about work and personal life balance?',
      'What makes me happy according to my writing?',
    ];
    
    for (final prompt in testPrompts) {
      print('\nPrompt: "$prompt"');
      try {
        final response = await ragService.generateContextualResponse(prompt);
        print('Response: ${response.substring(0, 200)}...\n');
      } catch (e) {
        print('⚠️ Could not generate response (likely no AI model loaded): $e');
      }
    }
    
    // Show final stats
    print('\n=== Final System Status ===');
    final ragStats = await ragService.getRAGStats();
    print('RAG Stats: $ragStats');
    
    final debugStatus = await ragService.debugDatabaseStatus();
    print('Database Status: $debugStatus');
    
    print('\n=== Context System Test Completed ===');
    
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}