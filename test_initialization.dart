import 'lib/services/rag_service.dart';
import 'lib/services/embedding_service.dart';
import 'lib/providers/rag_provider.dart';

Future<void> main() async {
  print('=== RAG System Initialization Test ===\n');
  
  // Test 1: EmbeddingService initialization
  print('1. Testing EmbeddingService initialization...');
  try {
    final embeddingService = EmbeddingService();
    await embeddingService.initialize();
    print('✅ EmbeddingService initialized successfully\n');
  } catch (e) {
    print('❌ EmbeddingService failed: $e\n');
    return;
  }
  
  // Test 2: RAGService initialization  
  print('2. Testing RAGService initialization...');
  try {
    final ragService = RAGService();
    await ragService.initialize();
    print('✅ RAGService initialized successfully\n');
  } catch (e) {
    print('❌ RAGService failed: $e\n');
    return;
  }
  
  // Test 3: RAGProvider initialization
  print('3. Testing RAGProvider initialization...');
  try {
    final ragProvider = RAGProvider();
    await ragProvider.initialize();
    print('✅ RAGProvider initialized successfully\n');
  } catch (e) {
    print('❌ RAGProvider failed: $e\n');
    return;
  }
  
  print('=== All Initialization Tests Passed! ===');
  print('The RAG embeddings system should now be working.');
}