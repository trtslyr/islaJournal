import 'lib/services/rag_service.dart';
import 'lib/services/embedding_service.dart';
import 'lib/services/database_service.dart';
import 'lib/services/ai_service.dart';
import 'lib/models/journal_file.dart';

void main() async {
  print('=== RAG System Debug Test ===');
  
  try {
    print('\n1. Testing DatabaseService initialization...');
    final dbService = DatabaseService();
    final db = await dbService.database;
    print('✅ Database initialized successfully');
    
    // Test basic database operations
    final folders = await dbService.getFolders();
    print('✅ Found ${folders.length} folders');
    
    final files = await dbService.getFiles();
    print('✅ Found ${files.length} files');
    
    print('\n2. Testing EmbeddingService initialization...');
    final embeddingService = EmbeddingService();
    await embeddingService.initialize();
    print('✅ Embedding service initialized');
    
    // Test embedding generation
    final testEmbedding = await embeddingService.generateEmbedding('This is a test document', 'test_doc_1');
    print('✅ Generated embedding with ${testEmbedding.length} dimensions');
    
    final vocabStats = embeddingService.getVocabularyStats();
    print('✅ Vocabulary stats: $vocabStats');
    
    print('\n3. Testing AIService initialization...');
    final aiService = AIService();
    await aiService.initialize();
    print('✅ AI service initialized');
    print('Available models: ${aiService.availableModels.keys.toList()}');
    print('Model statuses: ${aiService.modelStatuses}');
    
    print('\n4. Testing RAGService initialization...');
    final ragService = RAGService();
    await ragService.initialize();
    print('✅ RAG service initialized');
    
    // Test RAG stats
    final ragStats = await ragService.getRAGStats();
    print('✅ RAG stats: $ragStats');
    
    // Test debug database status
    final debugStatus = await ragService.debugDatabaseStatus();
    print('✅ Debug status: $debugStatus');
    
    print('\n5. Testing basic RAG functionality...');
    
    // Create a test journal file
    if (files.isNotEmpty) {
      final testFile = files.first;
      print('Testing with file: ${testFile.name}');
      
      // Try to index it
      await ragService.indexJournalEntry(testFile);
      print('✅ Indexed journal entry');
      
      // Try to retrieve content
      final results = await ragService.retrieveRelevantContent('test query');
      print('✅ Retrieved ${results.length} results');
      
      // Try to generate a response (if AI model is available)
      try {
        final response = await ragService.generateContextualResponse('What are the main themes in my writing?');
        print('✅ Generated contextual response: ${response.substring(0, 100)}...');
      } catch (e) {
        print('⚠️ Could not generate AI response (no model loaded): $e');
      }
    } else {
      print('⚠️ No files found to test with');
    }
    
    print('\n=== All Tests Completed Successfully! ===');
    
  } catch (e, stackTrace) {
    print('\n❌ Error occurred: $e');
    print('Stack trace: $stackTrace');
  }
}