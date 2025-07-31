import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/layout_provider.dart';
import '../widgets/file_tree_widget.dart';
import '../widgets/editor_widget.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/resize_handle.dart';
import '../widgets/search_widget.dart';

import '../screens/settings_screen.dart';
import '../core/theme/app_theme.dart';
import '../models/journal_file.dart';
import '../services/validation_service.dart';

/// Main home screen with 3-panel IDE-like layout
/// Left: File tree | Middle: Editor | Right: AI Chat
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
    _initializeProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Initialize the journal and AI providers
  void _initializeProviders() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      
      await journalProvider.initialize();
      await aiProvider.initialize();
    });
  }

  /// Toggle search mode
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
        journalProvider.clearSearch();
      }
    });
  }

  /// Create new file
  void _createNewFile() {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    _showCreateFileDialog(journalProvider);
  }

  /// Create new folder
  void _createNewFolder() {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    _showCreateFolderDialog(journalProvider);
  }

  /// Navigate to settings
  void _showSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }



  /// Build the main body with 3-panel layout
  Widget _buildBody() {
    return Consumer<JournalProvider>(
      builder: (context, journalProvider, child) {
        if (journalProvider.isLoading) {
          return const Center(
            child: Text(
              'loading...',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }

        return Consumer<LayoutProvider>(
          builder: (context, layoutProvider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                
                return Row(
                  children: [
                    // Left Panel - File Tree
                    if (layoutProvider.isFileTreeVisible) ...[
                      SizedBox(
                        width: layoutProvider.fileTreeWidth,
                        child: _buildFileTreePanel(),
                      ),
                      // Resize handle for file tree
                      ResizeHandle(
                        onResize: (delta) {
                          final newWidth = layoutProvider.fileTreeWidth + delta;
                          layoutProvider.setFileTreeWidth(newWidth, screenWidth);
                        },
                      ),
                    ],
                    
                    // Middle Panel - Editor (always visible)
                    Expanded(
                      child: _buildEditorPanel(),
                    ),
                    
                    // Right Panel - AI Chat
                    if (layoutProvider.isAIChatVisible) ...[
                      // Resize handle for AI chat
                      ResizeHandle(
                        onResize: (delta) {
                          final newWidth = layoutProvider.aiChatWidth - delta;
                          layoutProvider.setAIChatWidth(newWidth, screenWidth);
                        },
                      ),
                      SizedBox(
                        width: layoutProvider.aiChatWidth,
                        child: const AIChatPanel(),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Build the file tree panel
  Widget _buildFileTreePanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.creamBeige,
        border: Border(
          right: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
                     // Panel toolbar
           Container(
             height: 40,
             padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
             decoration: BoxDecoration(
               color: AppTheme.darkerCream,
               border: Border(
                 bottom: BorderSide(
                   color: AppTheme.warmBrown.withOpacity(0.2),
                   width: 1,
                 ),
               ),
             ),
                         child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Add folder
                Flexible(
                  child: TextButton(
                    onPressed: _createNewFolder,
                    style: TextButton.styleFrom(
                      overlayColor: Colors.transparent,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '+',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.warmBrown,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'folder',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.warmBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add file
                Flexible(
                  child: TextButton(
                    onPressed: _createNewFile,
                    style: TextButton.styleFrom(
                      overlayColor: Colors.transparent,
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '✎',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.warmBrown,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'file',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.warmBrown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
           ),
          
                  // Content area
        Expanded(
          child: _isSearching ? _buildSearchContent() : _buildFileTreeContent(),
        ),

        
        // Settings at the bottom
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: AppTheme.darkerCream,
            border: Border(
              top: BorderSide(
                color: AppTheme.warmBrown.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: _showSettings,
            child: const Text(
              'settings',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// Build the search content
  Widget _buildSearchContent() {
    return Column(
      children: [
        // Search input
        Container(
          padding: const EdgeInsets.all(16.0),
          child: SearchWidget(
            controller: _searchController,
            onSearch: (query) {
              final journalProvider = Provider.of<JournalProvider>(context, listen: false);
              journalProvider.searchFiles(query);
            },
            autofocus: true,
          ),
        ),
        // Search results
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  /// Build the file tree content
  Widget _buildFileTreeContent() {
    return Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return FileTreeWidget(
          showHeader: false,
        );
      },
    );
  }

  /// Build the editor panel
  Widget _buildEditorPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.creamBeige,
        border: Border(
          left: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
          right: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
                 children: [
           // Panel toolbar
           Container(
             height: 40,
             padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
             decoration: BoxDecoration(
               color: AppTheme.darkerCream,
               border: Border(
                 bottom: BorderSide(
                   color: AppTheme.warmBrown.withOpacity(0.2),
                   width: 1,
                 ),
               ),
             ),
             child: Consumer<JournalProvider>(
               builder: (context, provider, child) {
                 final selectedFile = provider.selectedFileId != null 
                     ? provider.files.where((f) => f.id == provider.selectedFileId).firstOrNull 
                     : null;
                 
                 if (selectedFile == null) {
                   return Row(
                     children: [
                       // File tree toggle (far left)
                       Consumer<LayoutProvider>(
                         builder: (context, layoutProvider, child) {
                           return TextButton(
                             onPressed: layoutProvider.toggleFileTree,
                             style: TextButton.styleFrom(
                               overlayColor: Colors.transparent,
                             ),
                             child: Text(
                               '≡',
                               style: const TextStyle(
                                 fontFamily: 'JetBrainsMono',
                                 fontSize: 16.0,
                                 fontWeight: FontWeight.w600,
                                 color: AppTheme.warmBrown,
                               ),
                             ),
                           );
                         },
                       ),
                       const Expanded(
                         child: Center(
                           child: Text(
                             'no file selected',
                             style: TextStyle(
                               fontFamily: 'JetBrainsMono',
                               fontSize: 14.0,
                               color: AppTheme.mediumGray,
                             ),
                           ),
                         ),
                       ),
                       // AI chat toggle (far right)
                       Consumer<LayoutProvider>(
                         builder: (context, layoutProvider, child) {
                           return TextButton(
                             onPressed: layoutProvider.toggleAIChat,
                             style: TextButton.styleFrom(
                               overlayColor: Colors.transparent,
                             ),
                             child: Text(
                               '✦',
                               style: const TextStyle(
                                 fontFamily: 'JetBrainsMono',
                                 fontSize: 16.0,
                                 fontWeight: FontWeight.w600,
                                 color: AppTheme.warmBrown,
                               ),
                             ),
                           );
                         },
                       ),
                     ],
                   );
                 }
                 
                 return Row(
                   children: [
                     // File tree toggle (far left)
                     Consumer<LayoutProvider>(
                       builder: (context, layoutProvider, child) {
                         return TextButton(
                           onPressed: layoutProvider.toggleFileTree,
                           style: TextButton.styleFrom(
                             overlayColor: Colors.transparent,
                           ),
                           child: Text(
                             '≡',
                             style: const TextStyle(
                               fontFamily: 'JetBrainsMono',
                               fontSize: 16.0,
                               fontWeight: FontWeight.w600,
                               color: AppTheme.warmBrown,
                             ),
                           ),
                         );
                       },
                     ),
                                         Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: GestureDetector(
                          onDoubleTap: () => _showEditFileDialog(context, selectedFile, provider),
                          child: Text(
                            selectedFile.name,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                     const SizedBox(width: 4),
                                            // AI chat toggle (far right)
                       Consumer<LayoutProvider>(
                         builder: (context, layoutProvider, child) {
                           return TextButton(
                             onPressed: layoutProvider.toggleAIChat,
                             style: TextButton.styleFrom(
                               overlayColor: Colors.transparent,
                             ),
                             child: Text(
                               '✦',
                               style: const TextStyle(
                                 fontFamily: 'JetBrainsMono',
                                 fontSize: 16.0,
                                 fontWeight: FontWeight.w600,
                                 color: AppTheme.warmBrown,
                               ),
                             ),
                           );
                         },
                       ),
                   ],
                 );
               },
             ),
           ),
          
          // Editor content
          const Expanded(
            child: EditorWidget(),
          ),
        ],
      ),
    );
  }

  /// Build search results list
  Widget _buildSearchResults() {
    return Consumer<JournalProvider>(
      builder: (context, journalProvider, child) {
        if (journalProvider.searchQuery.isEmpty) {
          return const Center(
            child: Text(
              'type to search entries',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }

        if (journalProvider.searchResults.isEmpty) {
          return const Center(
            child: Text(
              'no results',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: journalProvider.searchResults.length,
          itemBuilder: (context, index) {
            final file = journalProvider.searchResults[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 1.0),
              color: AppTheme.darkerCream,
              child: ListTile(
                leading: const Text(
                  '•',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: AppTheme.mediumGray,
                  ),
                ),
                title: Text(
                  file.name,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${file.wordCount}w',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.mediumGray,
                  ),
                ),
                onTap: () {
                  journalProvider.selectFile(file.id);
                  _toggleSearch(); // Close search after selecting
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Show create file dialog
  void _showCreateFileDialog(JournalProvider provider) {
    final nameController = TextEditingController();
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('create file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  hintText: 'my journal entry',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: false);
                    if (errorMessage == null) {
                      // Check for duplicates in root level (where new files are created)
                      final existingNames = provider.files
                          .where((f) => f.folderId == null)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFileNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A file with this name already exists';
                      }
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && nameController.text.trim().isNotEmpty
                  ? () async {
                      final name = nameController.text.trim();
                      final fileId = await provider.createFile(name, '');
                      if (fileId != null) {
                        provider.selectFile(fileId);
                      }
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('create'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show create folder dialog
  void _showCreateFolderDialog(JournalProvider provider) {
    final nameController = TextEditingController();
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('create folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  hintText: 'my folder',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: true);
                    if (errorMessage == null) {
                      // Check for duplicates
                      final existingNames = provider.folders
                          .where((f) => f.parentId == provider.selectedFolderId)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFolderNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A folder with this name already exists';
                      }
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && nameController.text.trim().isNotEmpty
                  ? () async {
                      final name = nameController.text.trim();
                      await provider.createFolder(name);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFileDialog(BuildContext context, JournalFile file, JournalProvider provider) {
    final nameController = TextEditingController(text: file.name);
    final isProfileFile = file.id == 'profile_special_file';
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: Text(
          isProfileFile ? 'Edit Name' : 'Rename File',
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isProfileFile ? 'Your name' : 'File name',
            hintText: isProfileFile ? 'Enter your name' : 'Enter file name',
          ),
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != file.name) {
                await provider.updateFile(file.copyWith(name: name));
                Navigator.of(context).pop();
              } else if (name.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}