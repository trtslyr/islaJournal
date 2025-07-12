import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/rag_provider.dart';
import '../models/journal_file.dart';
import '../services/rag_service.dart';
import '../core/theme/app_theme.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _controller = TextEditingController();
  List<JournalFile> _results = [];
  List<RetrievalResult> _semanticResults = [];
  bool _isLoading = false;
  bool _useSemanticSearch = true;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _semanticResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_useSemanticSearch) {
        // Semantic search using RAG system
        final ragProvider = Provider.of<RAGProvider>(context, listen: false);
        final semanticResults = await ragProvider.searchAllContent(
          query,
          maxResults: 20,
          minSimilarity: 0.1,
        );
        
        setState(() {
          _semanticResults = semanticResults;
          _results = [];
        });
      } else {
        // Traditional keyword search
        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
        await journalProvider.searchFiles(query);
        
        setState(() {
          _results = journalProvider.searchResults;
          _semanticResults = [];
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search header with toggle
          Row(
            children: [
              const Icon(Icons.search, color: AppTheme.warmBrown),
              const SizedBox(width: 8),
              Text(
                'Search',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Semantic search toggle
              Row(
                children: [
                  const Text(
                    'Semantic',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useSemanticSearch,
                    onChanged: (value) {
                      setState(() {
                        _useSemanticSearch = value;
                      });
                      if (_controller.text.isNotEmpty) {
                        _performSearch(_controller.text);
                      }
                    },
                    activeColor: AppTheme.warmBrown,
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Search input
          TextField(
            controller: _controller,
            onChanged: _performSearch,
            decoration: InputDecoration(
              hintText: _useSemanticSearch 
                  ? 'Search by meaning: "entries about feelings", "work stress", "happy memories"...'
                  : 'Search by keywords...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.warmBrown.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.warmBrown),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Search type indicator
          if (_controller.text.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  _useSemanticSearch ? Icons.psychology : Icons.search,
                  size: 16,
                  color: AppTheme.mediumGray,
                ),
                const SizedBox(width: 4),
                Text(
                  _useSemanticSearch 
                      ? 'Semantic search by meaning'
                      : 'Keyword search',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          
          // Loading indicator
          if (_isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          
          // Results
          if (!_isLoading) ...[
            if (_useSemanticSearch && _semanticResults.isNotEmpty) ...[
              Text(
                '${_semanticResults.length} semantic matches',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _semanticResults.length,
                  itemBuilder: (context, index) {
                    final result = _semanticResults[index];
                    return _buildSemanticResultCard(result);
                  },
                ),
              ),
            ] else if (!_useSemanticSearch && _results.isNotEmpty) ...[
              Text(
                '${_results.length} keyword matches',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final file = _results[index];
                    return _buildKeywordResultCard(file);
                  },
                ),
              ),
            ] else if (_controller.text.isNotEmpty) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: AppTheme.mediumGray,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No results found',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: AppTheme.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 48,
                        color: AppTheme.mediumGray,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Start typing to search your journal',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: AppTheme.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSemanticResultCard(RetrievalResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openFile(result.sourceId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.sourceType == 'journal_entry' 
                        ? Icons.description 
                        : Icons.file_present,
                    size: 16,
                    color: AppTheme.warmBrown,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.metadata['filename'] as String,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warmBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(result.similarity * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warmBrown,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.content.length > 200 
                    ? '${result.content.substring(0, 200)}...'
                    : result.content,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeywordResultCard(JournalFile file) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openFile(file.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description,
                    size: 16,
                    color: AppTheme.warmBrown,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${file.wordCount} words',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                file.content.length > 200 
                    ? '${file.content.substring(0, 200)}...'
                    : file.content,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(String fileId) {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    journalProvider.selectFile(fileId);
  }
}