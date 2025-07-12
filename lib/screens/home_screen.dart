import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/rag_provider.dart';
import '../providers/auto_tagging_provider.dart';
import '../widgets/file_tree_widget.dart';
import '../widgets/editor_widget.dart';
import '../widgets/search_widget.dart';
import '../screens/settings_screen.dart';
import '../screens/insights_screen.dart';
import '../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  void _initializeProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      final ragProvider = Provider.of<RAGProvider>(context, listen: false);
      final autoTaggingProvider = Provider.of<AutoTaggingProvider>(context, listen: false);
      
      await journalProvider.initialize();
      await aiProvider.initialize();
      await ragProvider.initialize();
      await autoTaggingProvider.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Isla Journal'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<JournalProvider>().clearSearch();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _showImportDialog(context),
            tooltip: 'Import Documents',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showInsights(context),
            tooltip: 'Personal Insights',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppTheme.darkerCream,
              child: const SearchWidget(),
            ),
          Expanded(
            child: Row(
              children: [
                // Left sidebar - File tree
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: AppTheme.darkerCream,
                    border: Border(
                      right: BorderSide(
                        color: AppTheme.warmBrown.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: const FileTreeWidget(),
                ),
                // Right panel - Editor/Conversation
                Expanded(
                  child: Consumer<JournalProvider>(
                    builder: (context, provider, child) {
                      if (_isSearching && provider.searchQuery.isNotEmpty) {
                        return _buildSearchResults(provider);
                      }
                      
                      if (provider.selectedFileId != null) {
                        return const EditorWidget();
                      }
                      
                      return _buildWelcomeScreen(provider);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(JournalProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.mediumGray,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "${provider.searchQuery}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 19.2,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
                color: AppTheme.mediumGray,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Results (${provider.searchResults.length})',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 19.2,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: provider.searchResults.length,
              itemBuilder: (context, index) {
                final file = provider.searchResults[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(
                      file.name,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    subtitle: Text(
                      '${file.wordCount} words • ${file.updatedAt.toString().split(' ')[0]}',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.8,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    trailing: Text(
                      provider.getFolderPath(file.folderId),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.8,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                    onTap: () {
                      provider.selectFile(file.id);
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                      });
                      provider.clearSearch();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildWelcomeScreen(JournalProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories,
            size: 96,
            color: AppTheme.warmBrown,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Isla Journal',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 32.0,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your private, offline journaling companion',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 19.2,
              fontWeight: FontWeight.w600,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (provider.recentFiles.isNotEmpty) ...[
            Text(
              'Recent Files',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 19.2,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 16),
            ...provider.recentFiles.take(5).map((file) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(
                  file.name,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                subtitle: Text(
                  '${file.wordCount} words • ${file.lastOpened?.toString().split(' ')[0] ?? 'Never'}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.8,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.mediumGray,
                  ),
                ),
                onTap: () => provider.selectFile(file.id),
              ),
            )),
          ] else ...[
            Text(
              'Start by creating your first journal entry',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16.0,
                fontWeight: FontWeight.w400,
                color: AppTheme.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Create New Entry'),
            ),
          ],
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateFileDialog(),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _showInsights(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const InsightsScreen(),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ImportDocumentDialog(),
    );
  }
}

class CreateFileDialog extends StatefulWidget {
  const CreateFileDialog({super.key});

  @override
  State<CreateFileDialog> createState() => _CreateFileDialogState();
}

class _CreateFileDialogState extends State<CreateFileDialog> {
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedFolderId;

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Entry'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'File Name',
                hintText: 'My Journal Entry',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Consumer<JournalProvider>(
              builder: (context, provider, child) {
                return DropdownButtonFormField<String>(
                  value: _selectedFolderId,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Root'),
                    ),
                    ...provider.folders.map((folder) => DropdownMenuItem<String>(
                      value: folder.id,
                      child: Text(folder.name),
                    )).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFolderId = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Initial Content (optional)',
                hintText: 'Start writing...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              final fileId = await provider.createFile(
                name,
                _contentController.text,
                folderId: _selectedFolderId,
              );
              
              if (fileId != null) {
                provider.selectFile(fileId);
                Navigator.of(context).pop();
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class ImportDocumentDialog extends StatefulWidget {
  const ImportDocumentDialog({super.key});

  @override
  State<ImportDocumentDialog> createState() => _ImportDocumentDialogState();
}

class _ImportDocumentDialogState extends State<ImportDocumentDialog> {
  bool _isImporting = false;
  String _importStatus = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Documents'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Import PDF, Word, or text documents to enhance your AI assistant with additional context.',
              style: TextStyle(fontFamily: 'JetBrainsMono'),
            ),
            const SizedBox(height: 16),
            if (_isImporting) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _importStatus,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Consumer<RAGProvider>(
              builder: (context, ragProvider, child) {
                return Column(
                  children: [
                    if (ragProvider.importedDocuments.isNotEmpty) ...[
                      const Text(
                        'Imported Documents:',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                                             ...ragProvider.importedDocuments.take(3).map((doc) => 
                         Text(
                           '• ${doc.originalFilename}',
                           style: const TextStyle(
                             fontFamily: 'JetBrainsMono',
                             fontSize: 12,
                             color: AppTheme.mediumGray,
                           ),
                         ),
                       ),
                      if (ragProvider.importedDocuments.length > 3)
                        Text(
                          '... and ${ragProvider.importedDocuments.length - 3} more',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      ragProvider.indexingSummary,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _isImporting ? null : () => _importDocuments(),
          child: const Text('Import Documents'),
        ),
      ],
    );
  }

  Future<void> _importDocuments() async {
    if (_isImporting) return;
    
    setState(() {
      _isImporting = true;
      _importStatus = 'Selecting documents...';
    });

    try {
      final ragProvider = Provider.of<RAGProvider>(context, listen: false);
      
      setState(() {
        _importStatus = 'Importing documents...';
      });
      
      final importedDocs = await ragProvider.importDocuments(
        allowMultiple: true,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'md'],
      );
      
      if (importedDocs.isNotEmpty) {
        setState(() {
          _importStatus = 'Successfully imported ${importedDocs.length} document(s)';
        });
        
        // Close dialog after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _importStatus = 'No documents were imported';
        });
      }
    } catch (e) {
      setState(() {
        _importStatus = 'Error importing documents: $e';
      });
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
}