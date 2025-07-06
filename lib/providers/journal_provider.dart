import 'package:flutter/foundation.dart';
import '../models/journal_file.dart';
import '../models/journal_folder.dart';
import '../services/database_service.dart';

class JournalProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  
  List<JournalFolder> _folders = [];
  List<JournalFile> _files = [];
  List<JournalFile> _recentFiles = [];
  List<JournalFile> _searchResults = [];
  
  String? _selectedFolderId;
  String? _selectedFileId;
  bool _isLoading = false;
  String _searchQuery = '';

  // Getters
  List<JournalFolder> get folders => _folders;
  List<JournalFile> get files => _files;
  List<JournalFile> get recentFiles => _recentFiles;
  List<JournalFile> get searchResults => _searchResults;
  String? get selectedFolderId => _selectedFolderId;
  String? get selectedFileId => _selectedFileId;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  // Get files in current folder
  List<JournalFile> get currentFolderFiles {
    return _files.where((file) => file.folderId == _selectedFolderId).toList();
  }

  // Get subfolders in current folder
  List<JournalFolder> get currentFolderSubfolders {
    return _folders.where((folder) => folder.parentId == _selectedFolderId).toList();
  }

  // Get root folders
  List<JournalFolder> get rootFolders {
    return _folders.where((folder) => folder.parentId == null).toList();
  }

  // Initialize provider
  Future<void> initialize() async {
    await loadFolders();
    await loadFiles();
    await loadRecentFiles();
  }

  // Folder operations
  Future<void> loadFolders() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _folders = await _dbService.getFolders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading folders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createFolder(String name, {String? parentId}) async {
    try {
      await _dbService.createFolder(name, parentId: parentId);
      await loadFolders();
    } catch (e) {
      debugPrint('Error creating folder: $e');
    }
  }

  Future<void> updateFolder(JournalFolder folder) async {
    try {
      await _dbService.updateFolder(folder);
      await loadFolders();
    } catch (e) {
      debugPrint('Error updating folder: $e');
    }
  }

  Future<void> deleteFolder(String id) async {
    try {
      await _dbService.deleteFolder(id);
      await loadFolders();
      await loadFiles();
    } catch (e) {
      debugPrint('Error deleting folder: $e');
    }
  }

  // File operations
  Future<void> loadFiles() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _files = await _dbService.getFiles();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFilesInFolder(String? folderId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _files = await _dbService.getFiles(folderId: folderId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading files in folder: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createFile(String name, String content, {String? folderId}) async {
    try {
      final fileId = await _dbService.createFile(name, content, folderId: folderId);
      await loadFiles();
      return fileId;
    } catch (e) {
      debugPrint('Error creating file: $e');
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
      debugPrint('Error getting file: $e');
      return null;
    }
  }

  Future<void> updateFile(JournalFile file) async {
    try {
      await _dbService.updateFile(file);
      await loadFiles();
    } catch (e) {
      debugPrint('Error updating file: $e');
    }
  }

  Future<void> deleteFile(String id) async {
    try {
      await _dbService.deleteFile(id);
      await loadFiles();
      await loadRecentFiles();
    } catch (e) {
      debugPrint('Error deleting file: $e');
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
    notifyListeners();
  }

  void clearSelection() {
    _selectedFolderId = null;
    _selectedFileId = null;
    notifyListeners();
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
      debugPrint('Error searching files: $e');
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

  // Recent files
  Future<void> loadRecentFiles() async {
    try {
      _recentFiles = await _dbService.getRecentFiles();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent files: $e');
    }
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