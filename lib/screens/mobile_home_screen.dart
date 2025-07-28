import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/ai_provider.dart';
import '../widgets/file_tree_widget.dart';
import '../widgets/editor_widget.dart';
import '../widgets/ai_chat_panel.dart';
import '../widgets/search_widget.dart';
import '../screens/settings_screen.dart';
import '../core/theme/app_theme.dart';
import '../models/journal_file.dart';
import '../services/validation_service.dart';

/// Mobile home screen with bottom tab navigation
/// Files | Editor | AI Chat as separate screens
class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  int _currentIndex = 1; // Start on Editor tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
        _isSearching = false; // Close search when switching tabs
      });
    });
    _initializeProviders();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  /// Toggle search mode (only on Files tab)
  void _toggleSearch() {
    if (_currentIndex == 0) { // Files tab
      setState(() {
        _isSearching = !_isSearching;
        if (!_isSearching) {
          _searchController.clear();
          final journalProvider = Provider.of<JournalProvider>(context, listen: false);
          journalProvider.clearSearch();
        }
      });
    }
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

  /// Show settings modal
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppTheme.creamBeige,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JournalProvider>(
      builder: (context, journalProvider, child) {
        if (journalProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Text(
                'loading...',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  color: AppTheme.mediumGray,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFilesScreen(),
              _buildEditorScreen(),
              _buildAIScreen(),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigation(),
        );
      },
    );
  }

  /// Build app bar with context-sensitive actions
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.creamBeige,
      elevation: 0,
      title: Text(
        _getAppBarTitle(),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkText,
        ),
      ),
      actions: _buildAppBarActions(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0: return _isSearching ? 'search files' : 'files';
      case 1: return 'editor';
      case 2: return 'ai chat';
      default: return 'isla journal';
    }
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    // Context-sensitive actions based on current tab
    switch (_currentIndex) {
      case 0: // Files tab
        if (_isSearching) {
          actions.add(
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.mediumGray),
              onPressed: _toggleSearch,
            ),
          );
        } else {
          actions.addAll([
            IconButton(
              icon: const Icon(Icons.search, color: AppTheme.mediumGray),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder, color: AppTheme.mediumGray),
              onPressed: _createNewFolder,
            ),
            IconButton(
              icon: const Icon(Icons.note_add, color: AppTheme.mediumGray),
              onPressed: _createNewFile,
            ),
          ]);
        }
        break;
      
      case 1: // Editor tab
        actions.add(
          IconButton(
            icon: const Icon(Icons.note_add, color: AppTheme.mediumGray),
            onPressed: _createNewFile,
          ),
        );
        break;
    }

    // Settings always available
    actions.add(
      IconButton(
        icon: const Icon(Icons.settings, color: AppTheme.mediumGray),
        onPressed: _showSettings,
      ),
    );

    return actions;
  }

  /// Build Files screen (was left panel)
  Widget _buildFilesScreen() {
    return Container(
      color: AppTheme.creamBeige,
      child: _isSearching ? _buildSearchContent() : _buildFileTreeContent(),
    );
  }

  /// Build Editor screen (was middle panel)
  Widget _buildEditorScreen() {
    return Container(
      color: AppTheme.lightCream,
      child: const EditorWidget(),
    );
  }

  /// Build AI Chat screen (was right panel)
  Widget _buildAIScreen() {
    return Container(
      color: AppTheme.lightCream,
      child: const AIChatPanel(),
    );
  }

  /// Build search content
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

  /// Build file tree content
  Widget _buildFileTreeContent() {
    return const FileTreeWidget(showHeader: false);
  }

  /// Build search results
  Widget _buildSearchResults() {
    return Consumer<JournalProvider>(
      builder: (context, journalProvider, child) {
        final searchResults = journalProvider.searchResults;
        
        if (searchResults.isEmpty) {
          return const Center(
            child: Text(
              'no results found',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: searchResults.length,
          itemBuilder: (context, index) {
            final file = searchResults[index];
            return _buildSearchResultItem(file);
          },
        );
      },
    );
  }

  /// Build search result item
  Widget _buildSearchResultItem(JournalFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppTheme.lightCream,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: AppTheme.warmBrown.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          file.name,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: AppTheme.darkBrown,
          ),
        ),
                 subtitle: Text(
           'Modified: ${file.updatedAt.toString().split(' ')[0]}',
           style: const TextStyle(
             fontFamily: 'JetBrainsMono',
             fontSize: 12.0,
             color: AppTheme.mediumGray,
           ),
         ),
         onTap: () {
           final journalProvider = Provider.of<JournalProvider>(context, listen: false);
           journalProvider.selectFile(file.id);
           _tabController.animateTo(1); // Switch to Editor tab
         },
      ),
    );
  }

  /// Build bottom navigation
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightCream,
        border: Border(
          top: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.darkBrown,
        unselectedLabelColor: AppTheme.mediumGray,
        labelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
        ),
        indicator: BoxDecoration(
          color: AppTheme.warmBrown.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.0),
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.folder),
            text: 'files',
          ),
          Tab(
            icon: Icon(Icons.edit),
            text: 'editor',
          ),
          Tab(
            icon: Icon(Icons.chat),
            text: 'ai chat',
          ),
        ],
      ),
    );
  }

  // Dialog helpers (same as desktop)
  void _showCreateFileDialog(JournalProvider journalProvider) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightCream,
        title: const Text(
          'create new file',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkBrown,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'enter file name',
            hintStyle: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: AppTheme.mediumGray,
            ),
          ),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            color: AppTheme.darkBrown,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'cancel',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                if (ValidationService.isValidFileName(name)) {
                  await journalProvider.createFile(name, '');
                  Navigator.of(context).pop();
                  _tabController.animateTo(1); // Switch to Editor
                }
              }
            },
            child: const Text(
              'create',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog(JournalProvider journalProvider) {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightCream,
        title: const Text(
          'create new folder',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkBrown,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'enter folder name',
            hintStyle: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: AppTheme.mediumGray,
            ),
          ),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            color: AppTheme.darkBrown,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'cancel',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await journalProvider.createFolder(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'create',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 