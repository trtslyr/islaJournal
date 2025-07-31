import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../models/journal_folder.dart';
import '../models/file_sort_option.dart';
import '../services/database_service.dart';
import '../services/embedding_service.dart';

class JournalProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final EmbeddingService _embeddingService = EmbeddingService();
  
  List<JournalFolder> _folders = [];
  List<JournalFile> _files = [];
  List<JournalFile> _recentFiles = [];
  List<JournalFile> _searchResults = [];
  
  String? _selectedFolderId;
  String? _selectedFileId;
  Set<String> _selectedFileIds = {}; // Multi-selection support
  String? _lastSelectedFileId; // For range selection
  bool _isLoading = false;
  String _searchQuery = '';
  Set<String> _unsavedFileIds = {};
  FileSortOption _sortOption = const FileSortOption();

  // Getters
  List<JournalFolder> get folders => _folders;
  List<JournalFile> get files => _files;
  List<JournalFile> get recentFiles => _recentFiles;
  List<JournalFile> get searchResults => _searchResults;
  String? get selectedFolderId => _selectedFolderId;
  String? get selectedFileId => _selectedFileId;
  Set<String> get selectedFileIds => Set.from(_selectedFileIds);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  FileSortOption get sortOption => _sortOption;
  
  // Check if a file has unsaved changes
  bool hasUnsavedChanges(String fileId) => _unsavedFileIds.contains(fileId);

  // Get files in current folder
  List<JournalFile> get currentFolderFiles {
    return _files.where((file) => file.folderId == _selectedFolderId).toList();
  }

  // Get subfolders in current folder
  List<JournalFolder> get currentFolderSubfolders {
    return _folders.where((folder) => folder.parentId == _selectedFolderId).toList();
  }

  // Get root folders - sorted alphabetically
  List<JournalFolder> get rootFolders {
    final rootFolders = _folders.where((folder) => folder.parentId == null).toList();
    
    // Sort all folders alphabetically
    rootFolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return rootFolders;
  }

  // Initialize provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
  
      
      await _dbService.ensureProfileFileExists(); // Ensure profile file exists

      
      // Load all data in parallel for better performance
      await Future.wait([
        loadFolders(),
        loadFiles(),
        loadRecentFiles(),
      ]);
      
      
      
      // Generate embeddings for files that don't have them
      
      await _generateMissingEmbeddings();
      
      
    } catch (e) {
      
    } finally {
      _isLoading = false;
      notifyListeners();

    }
  }

  /// Generate embeddings for files that don't have them yet
  Future<void> _generateMissingEmbeddings() async {
    try {
      // Get all files (metadata only)
      final allFiles = await _dbService.getFiles();
      final filesWithEmbeddings = await _dbService.getFilesWithEmbeddings();
      
      // Find files that don't have embeddings
      final filesWithEmbeddingIds = filesWithEmbeddings.map((f) => f.id).toSet();
      final filesWithoutEmbeddings = allFiles.where((f) => !filesWithEmbeddingIds.contains(f.id)).toList();
      
      if (filesWithoutEmbeddings.isEmpty) {
  
        return;
      }
      
      
      
      for (int i = 0; i < filesWithoutEmbeddings.length; i++) {
        final fileMetadata = filesWithoutEmbeddings[i];
        
        
        try {
          // Load the actual file content from disk
          final file = await _dbService.getFile(fileMetadata.id);
          
          if (file?.content?.isNotEmpty == true) {
            final embedding = await _embeddingService.generateEmbedding(file!.content!);
            await _dbService.storeEmbedding(file.id, embedding);

          } else {
            
          }
        } catch (e) {
          
        }
      }
      
      
    } catch (e) {
      
    }
  }



  // Folder operations
  Future<void> loadFolders() async {
    try {
      _folders = await _dbService.getFolders();
      notifyListeners();
    } catch (e) {

    }
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    try {
      await _dbService.createFolder(name, parentId: parentId);
      await loadFolders();
    } catch (e) {

    }
  }

  Future<void> updateFolder(JournalFolder folder) async {
    try {
      await _dbService.updateFolder(folder);
      await loadFolders();
    } catch (e) {

    }
  }

  Future<void> deleteFolder(String id) async {
    try {
      await _dbService.deleteFolder(id);
      await loadFolders();
      await loadFiles();
    } catch (e) {

    }
  }

  // File operations
  Future<void> loadFiles() async {
    try {
      _files = await _dbService.getFiles();
      notifyListeners();
    } catch (e) {

    }
  }

  /// Refresh journal dates for all existing files and reload
  Future<void> refreshJournalDates() async {
    try {
      await _dbService.refreshJournalDatesForAllFiles();
      await loadFiles(); // Reload files to get updated dates
      notifyListeners(); // Explicitly notify UI to refresh
      
    } catch (e) {
      
    }
  }

  /// Delete all user data and reset to empty state
  Future<void> deleteAllData() async {
    try {
      await _dbService.deleteAllData();
      await loadFiles(); // Reload to show empty state
      await loadFolders(); // Reload folders to show default state
      
    } catch (e) {
      
      rethrow;
    }
  }

  Future<void> loadFilesInFolder(String? folderId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _files = await _dbService.getFiles(folderId: folderId);
      notifyListeners();
    } catch (e) {

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createFile(String name, String content, {String? folderId}) async {
    try {
  
      
      // Automatically assign today's date
      final today = DateTime.now();
      
      // Use the provided folderId or null for root level (profile file always goes to root)
      final targetFolderId = name == 'Profile' ? null : folderId;
      
      final fileId = await _dbService.createFile(
        name, 
        content, 
        folderId: targetFolderId,
        journalDate: today, // Automatically assign today's date
      );
      
      
      // Generate embedding for new file
      if (content.isNotEmpty) {
        try {
  
          final embedding = await _embeddingService.generateEmbedding(content);
          await _dbService.storeEmbedding(fileId, embedding);

        } catch (e) {
          
        }
      }
      
      await loadFiles();
      
      

      
      return fileId;
    } catch (e) {
      
      return null;
    }
  }



  Future<JournalFile?> getFile(String id) async {
    try {
      final file = await _dbService.getFile(id);
      if (file != null) {
        await _dbService.updateLastOpened(id);
        await loadRecentFiles();
      }
      return file;
    } catch (e) {
      
      return null;
    }
  }



  Future<void> updateFile(JournalFile file) async {
    try {
      await _dbService.updateFile(file);
      _unsavedFileIds.remove(file.id); // File is now saved
      
      // Regenerate embedding for updated file
      if (file.content?.isNotEmpty == true) {
        try {
  
          final embedding = await _embeddingService.generateEmbedding(file.content!);
          await _dbService.storeEmbedding(file.id, embedding);
          
        } catch (e) {
          
        }
      }
      
      await loadFiles();
    } catch (e) {
      
    }
  }

  // Mark a file as having unsaved changes
  void markFileAsUnsaved(String fileId) {
    _unsavedFileIds.add(fileId);
    notifyListeners();
  }

  // Mark a file as saved
  void markFileAsSaved(String fileId) {
    _unsavedFileIds.remove(fileId);
    notifyListeners();
  }

  Future<void> deleteFile(String id) async {
    try {
      await _dbService.deleteFile(id);
      await loadFiles();
      await loadRecentFiles();
    } catch (e) {
      
    }
  }

  // Navigation
  void selectFolder(String? folderId) {
    _selectedFolderId = folderId;
    _selectedFileId = null;
    notifyListeners();
  }

  void selectFile(String? fileId) {
    _selectedFileId = fileId;
    _selectedFileIds.clear();
    if (fileId != null) {
      _selectedFileIds.add(fileId);
      _lastSelectedFileId = fileId;
    } else {
      _lastSelectedFileId = null;
    }
    notifyListeners();
  }

  void toggleFileSelection(String fileId, {bool clearOthers = false}) {
    if (clearOthers) {
      _selectedFileIds.clear();
    }
    
    if (_selectedFileIds.contains(fileId)) {
      _selectedFileIds.remove(fileId);
      if (_selectedFileId == fileId) {
        _selectedFileId = _selectedFileIds.isEmpty ? null : _selectedFileIds.first;
      }
    } else {
      _selectedFileIds.add(fileId);
      _selectedFileId = fileId;
      _lastSelectedFileId = fileId;
    }
    
    notifyListeners();
  }

  void selectFileRange(String fromFileId, String toFileId) {
    // Clear current multi-selection
    _selectedFileIds.clear();
    
    // Get the sorted list of files in the current view
    final sortedFiles = getSortedFiles(_files.where((file) => file.folderId == _selectedFolderId).toList());
    final fileIds = sortedFiles.map((f) => f.id).toList();
    
    final fromIndex = fileIds.indexOf(fromFileId);
    final toIndex = fileIds.indexOf(toFileId);
    
    if (fromIndex != -1 && toIndex != -1) {
      final startIndex = fromIndex < toIndex ? fromIndex : toIndex;
      final endIndex = fromIndex < toIndex ? toIndex : fromIndex;
      
      for (int i = startIndex; i <= endIndex; i++) {
        _selectedFileIds.add(fileIds[i]);
      }
      
      _selectedFileId = toFileId;
      _lastSelectedFileId = toFileId;
    }
    
    notifyListeners();
  }

  void clearSelection() {
    _selectedFolderId = null;
    _selectedFileId = null;
    _selectedFileIds.clear();
    _lastSelectedFileId = null;
    notifyListeners();
  }

  void clearFileSelection() {
    _selectedFileIds.clear();
    _selectedFileId = null;
    _lastSelectedFileId = null;
    notifyListeners();
  }

  bool isFileSelected(String fileId) {
    return _selectedFileIds.contains(fileId);
  }

  // Search operations
  Future<void> searchFiles(String query) async {
    _searchQuery = query;
    
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _searchResults = await _dbService.searchFiles(query);
      notifyListeners();
    } catch (e) {
      
      _searchResults = [];
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // Sorting and filtering
  void setSortOption(FileSortOption option) {
    _sortOption = option;
    notifyListeners();
  }
  
  void setSortType(FileSortType sortType) {
    _sortOption = _sortOption.copyWith(sortType: sortType);
    notifyListeners();
  }
  
  void setFilterType(FileFilterType filterType) {
    _sortOption = _sortOption.copyWith(filterType: filterType);
    notifyListeners();
  }

  /// Get sorted and filtered files for a specific folder
  List<JournalFile> getSortedFiles(List<JournalFile> files) {
    if (files.isEmpty) return files;
    
    // Apply filtering first
    var filteredFiles = _applyFilter(files, _sortOption.filterType);
    
    // Apply sorting
    return _applySorting(filteredFiles, _sortOption.sortType);
  }
  
  List<JournalFile> _applyFilter(List<JournalFile> files, FileFilterType filterType) {
    final now = DateTime.now();
    
    switch (filterType) {
      case FileFilterType.all:
        return files;
        
      case FileFilterType.today:
        return files.where((file) {
          final journalDate = file.journalDate;
          if (journalDate == null) return false;
          return _isSameDay(journalDate, now);
        }).toList();
        
      case FileFilterType.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return files.where((file) {
          final journalDate = file.journalDate;
          if (journalDate == null) return false;
          return journalDate.isAfter(startOfWeek.subtract(const Duration(days: 1)));
        }).toList();
        
      case FileFilterType.thisMonth:
        return files.where((file) {
          final journalDate = file.journalDate;
          if (journalDate == null) return false;
          return journalDate.year == now.year && journalDate.month == now.month;
        }).toList();
        
      case FileFilterType.thisYear:
        return files.where((file) {
          final journalDate = file.journalDate;
          if (journalDate == null) return false;
          return journalDate.year == now.year;
        }).toList();
        
      case FileFilterType.hasJournalDate:
        return files.where((file) => file.journalDate != null).toList();
        
      case FileFilterType.noJournalDate:
        return files.where((file) => file.journalDate == null).toList();
    }
  }
  
  List<JournalFile> _applySorting(List<JournalFile> files, FileSortType sortType) {
    final sortedFiles = List<JournalFile>.from(files);
    
    sortedFiles.sort((a, b) {
      switch (sortType) {
        case FileSortType.journalDateNewest:
          return _compareByJournalDate(a, b, newest: true);
          
        case FileSortType.journalDateOldest:
          return _compareByJournalDate(a, b, newest: false);
          
        case FileSortType.lastOpened:
          final aDate = a.lastOpened ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastOpened ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate); // Most recent first
          
        case FileSortType.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
          
        case FileSortType.createdOldest:
          return a.createdAt.compareTo(b.createdAt);
          
        case FileSortType.modifiedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
          
        case FileSortType.modifiedOldest:
          return a.updatedAt.compareTo(b.updatedAt);
          
        case FileSortType.alphabetical:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          
        case FileSortType.alphabeticalReverse:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });
    
    return sortedFiles;
  }
  
  int _compareByJournalDate(JournalFile a, JournalFile b, {required bool newest}) {
    if (a.journalDate != null && b.journalDate != null) {
      // Both have journal dates
      final comparison = newest 
          ? b.journalDate!.compareTo(a.journalDate!)
          : a.journalDate!.compareTo(b.journalDate!);
      if (comparison != 0) return comparison;
      // Tie-breaker: use updated date
      return newest 
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt);
    } else if (a.journalDate != null && b.journalDate == null) {
      // A has journal date, B doesn't - A comes first
      return -1;
    } else if (a.journalDate == null && b.journalDate != null) {
      // B has journal date, A doesn't - B comes first
      return 1;
    } else {
      // Neither has journal date - sort by updated date
      return newest 
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt);
    }
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // Recent files
  Future<void> loadRecentFiles() async {
    try {
      _recentFiles = await _dbService.getRecentFiles();
      notifyListeners();
    } catch (e) {
      
    }
  }

  /// Get the special profile file for AI context
  Future<JournalFile?> getProfileFile() async {
    try {
      return await _dbService.getProfileFile();
    } catch (e) {
      
      return null;
    }
  }

  /// Check if a file is the special profile file
  bool isProfileFile(String fileId) {
    return fileId == 'profile_special_file';
  }

  // Utility methods
  JournalFolder? getFolderById(String id) {
    try {
      return _folders.firstWhere((folder) => folder.id == id);
    } catch (e) {
      return null;
    }
  }

  JournalFile? getFileById(String id) {
    try {
      return _files.firstWhere((file) => file.id == id);
    } catch (e) {
      return null;
    }
  }

  String getFolderPath(String? folderId) {
    if (folderId == null) return '/';
    
    final folder = getFolderById(folderId);
    if (folder == null) return '/';
    
    if (folder.parentId == null) {
      return '/${folder.name}';
    }
    
    return '${getFolderPath(folder.parentId)}/${folder.name}';
  }



  @override
  void dispose() {
    _dbService.close();
    super.dispose();
  }
}