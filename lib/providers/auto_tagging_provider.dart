import 'package:flutter/foundation.dart';
import '../services/auto_tagging_service.dart';
import '../models/journal_file.dart';

class AutoTaggingProvider with ChangeNotifier {
  final AutoTaggingService _taggingService = AutoTaggingService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';
  TagSuggestions? _currentSuggestions;
  TagAnalytics? _analytics;
  List<String> _allTags = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  TagSuggestions? get currentSuggestions => _currentSuggestions;
  TagAnalytics? get analytics => _analytics;
  List<String> get allTags => _allTags;

  /// Initialize auto-tagging service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      await _taggingService.initialize();
      _isInitialized = true;
      await _loadAnalytics();
      await _loadAllTags();
      debugPrint('Auto-tagging Provider initialized successfully');
    } catch (e) {
      _setError('Auto-tagging service initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate tags for a journal entry
  Future<TagSuggestions?> generateTags(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final suggestions = await _taggingService.generateTags(file);
      _currentSuggestions = suggestions;
      await _loadAnalytics();
      return suggestions;
    } catch (e) {
      _setError('Tag generation error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get tags for a file
  Future<List<AutoTag>> getFileTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      return await _taggingService.getFileTags(fileId);
    } catch (e) {
      _setError('Error getting file tags: $e');
      return [];
    }
  }

  /// Get approved tags for a file
  Future<List<AutoTag>> getApprovedTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      return await _taggingService.getApprovedTags(fileId);
    } catch (e) {
      _setError('Error getting approved tags: $e');
      return [];
    }
  }

  /// Get suggested tags for a file
  Future<List<AutoTag>> getSuggestedTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      return await _taggingService.getSuggestedTags(fileId);
    } catch (e) {
      _setError('Error getting suggested tags: $e');
      return [];
    }
  }

  /// Approve a tag
  Future<void> approveTag(String tagId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      await _taggingService.approveTag(tagId);
      await _loadAnalytics();
      await _loadAllTags();
      notifyListeners();
    } catch (e) {
      _setError('Error approving tag: $e');
    }
  }

  /// Reject a tag
  Future<void> rejectTag(String tagId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      await _taggingService.rejectTag(tagId);
      await _loadAnalytics();
      notifyListeners();
    } catch (e) {
      _setError('Error rejecting tag: $e');
    }
  }

  /// Load analytics
  Future<void> _loadAnalytics() async {
    try {
      _analytics = await _taggingService.getAnalytics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tag analytics: $e');
    }
  }

  /// Load all tags
  Future<void> _loadAllTags() async {
    try {
      _allTags = await _taggingService.getAllTags();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all tags: $e');
    }
  }

  /// Get tag suggestions based on content
  Future<List<String>> getSimilarTags(String content) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      return await _taggingService.getSimilarTags(content);
    } catch (e) {
      _setError('Error getting similar tags: $e');
      return [];
    }
  }

  /// Tag all journal entries
  Future<void> tagAllEntries() async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      await _taggingService.tagAllEntries();
      await _loadAnalytics();
      await _loadAllTags();
    } catch (e) {
      _setError('Error tagging all entries: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete tags for a file
  Future<void> deleteFileTags(String fileId) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    try {
      await _taggingService.deleteFileTags(fileId);
      await _loadAnalytics();
      await _loadAllTags();
      notifyListeners();
    } catch (e) {
      _setError('Error deleting file tags: $e');
    }
  }

  /// Update tags for a file
  Future<TagSuggestions?> updateFileTags(JournalFile file) async {
    if (!_isInitialized) {
      throw Exception('Auto-tagging service not initialized');
    }

    _setLoading(true);
    _clearError();

    try {
      final suggestions = await _taggingService.updateFileTags(file);
      _currentSuggestions = suggestions;
      await _loadAnalytics();
      return suggestions;
    } catch (e) {
      _setError('Error updating file tags: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get trending tags
  List<String> getTrendingTags() {
    if (_analytics == null) return [];
    return _analytics!.trendingTags;
  }

  /// Get tag frequency
  Map<String, int> getTagFrequency() {
    if (_analytics == null) return {};
    return _analytics!.tagFrequency;
  }

  /// Get tags by category
  Map<String, List<String>> getTagsByCategory() {
    if (_analytics == null) return {};
    return _analytics!.categoryTags;
  }

  /// Get tag confidence scores
  Map<String, double> getTagConfidence() {
    if (_analytics == null) return {};
    return _analytics!.tagConfidence;
  }

  /// Get popular tags (most frequently used)
  List<String> getPopularTags({int limit = 10}) {
    if (_analytics == null) return [];
    
    final frequency = _analytics!.tagFrequency;
    final sortedTags = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTags.take(limit).map((e) => e.key).toList();
  }

  /// Get tag suggestions for new entries
  List<String> getTagSuggestions({String? category}) {
    if (_analytics == null) return [];
    
    if (category != null) {
      return _analytics!.categoryTags[category] ?? [];
    }
    
    return getTrendingTags();
  }

  /// Get tag color based on category
  String getTagColor(String category) {
    const categoryColors = {
      'emotions': '#FF6B6B',
      'activities': '#4ECDC4',
      'relationships': '#45B7D1',
      'goals': '#96CEB4',
      'themes': '#FFEAA7',
      'locations': '#DDA0DD',
      'time': '#98D8C8',
    };
    
    return categoryColors[category.toLowerCase()] ?? '#B0BEC5';
  }

  /// Get tag statistics summary
  String getTagStatsSummary() {
    if (_analytics == null) return 'No tag data available';
    
    final totalTags = _analytics!.tagFrequency.values.fold(0, (sum, count) => sum + count);
    final uniqueTags = _analytics!.tagFrequency.keys.length;
    final mostUsed = _analytics!.tagFrequency.entries.isEmpty ? 'none' :
        _analytics!.tagFrequency.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    return 'You have $totalTags tags across $uniqueTags unique categories. Your most used tag is "$mostUsed".';
  }

  /// Filter tags by search term
  List<String> filterTags(String searchTerm) {
    if (searchTerm.isEmpty) return _allTags;
    
    return _allTags.where((tag) => 
      tag.toLowerCase().contains(searchTerm.toLowerCase())
    ).toList();
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('Auto-tagging Provider Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = '';
    notifyListeners();
  }

  /// Cleanup
  @override
  void dispose() {
    _taggingService.dispose();
    super.dispose();
  }
}