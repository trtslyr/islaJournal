import 'package:flutter/foundation.dart';
import '../services/auto_tagging_service.dart';
import '../models/journal_file.dart';
import '../models/auto_tagging_models.dart';

class AutoTaggingProvider with ChangeNotifier {
  final AutoTaggingService _autoTaggingService = AutoTaggingService();
  
  bool _isInitialized = false;
  bool _isAnalyzing = false;
  bool _isBatchProcessing = false;
  int _batchProgress = 0;
  int _batchTotal = 0;
  String? _error;
  
  AutoTaggingResult? _lastResult;
  Map<String, dynamic> _stats = {};
  
  // Settings
  AutoTaggingSettings _settings = const AutoTaggingSettings();
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAnalyzing => _isAnalyzing;
  bool get isBatchProcessing => _isBatchProcessing;
  int get batchProgress => _batchProgress;
  int get batchTotal => _batchTotal;
  double get batchPercentage => _batchTotal > 0 ? (_batchProgress / _batchTotal) * 100 : 0;
  String? get error => _error;
  
  AutoTaggingResult? get lastResult => _lastResult;
  Map<String, dynamic> get stats => _stats;
  
  AutoTaggingSettings get settings => _settings;
  bool get autoTagOnSave => _settings.autoTagOnSave;
  double get autoApprovalThreshold => _settings.autoApprovalThreshold;
  bool get enableNewTagCreation => _settings.enableNewTagCreation;
  bool get enableNewThemeCreation => _settings.enableNewThemeCreation;

  // Initialize the auto-tagging system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _error = null;
      await _autoTaggingService.initialize();
      await refreshStats();
      _loadSettings();
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('Auto-tagging provider initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize auto-tagging: $e';
      debugPrint('Error initializing auto-tagging provider: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Analyze and suggest tags for a single entry
  Future<AutoTaggingResult?> analyzeEntry(JournalFile journalFile) async {
    if (!_isInitialized) await initialize();
    
    if (_isAnalyzing) return null;
    
    try {
      _error = null;
      _isAnalyzing = true;
      notifyListeners();
      
      final result = await _autoTaggingService.analyzeAndTagEntry(journalFile);
      _lastResult = result;
      
      return result;
    } catch (e) {
      _error = 'Failed to analyze entry: $e';
      debugPrint('Error analyzing entry for auto-tagging: $e');
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // Apply auto-tagging to a journal file
  Future<void> applyAutoTagging(String fileId, AutoTaggingResult result, {bool? autoApprove}) async {
    try {
      _error = null;
      await _autoTaggingService.applyAutoTagging(
        fileId, 
        result, 
        autoApprove: autoApprove ?? (result.overallConfidence >= _settings.autoApprovalThreshold),
      );
      
      await refreshStats();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to apply auto-tagging: $e';
      debugPrint('Error applying auto-tagging: $e');
    }
  }

  // Auto-tag entry when saving (if enabled)
  Future<void> autoTagOnSaveIfEnabled(JournalFile journalFile) async {
    if (!_settings.autoTagOnSave || !_isInitialized) return;
    
    try {
      final result = await analyzeEntry(journalFile);
      if (result != null && result.overallConfidence >= _settings.autoApprovalThreshold) {
        await applyAutoTagging(journalFile.id, result, autoApprove: true);
      }
    } catch (e) {
      debugPrint('Error in auto-tag on save: $e');
    }
  }

  // Batch process multiple files
  Future<void> batchAutoTag(List<JournalFile> files, {bool autoApprove = false}) async {
    if (!_isInitialized) await initialize();
    
    if (_isBatchProcessing) return;
    
    try {
      _error = null;
      _isBatchProcessing = true;
      _batchProgress = 0;
      _batchTotal = files.length;
      notifyListeners();
      
      await _autoTaggingService.batchAutoTag(
        files,
        autoApprove: autoApprove,
        progressCallback: (current, total) {
          _batchProgress = current;
          _batchTotal = total;
          notifyListeners();
        },
      );
      
      await refreshStats();
    } catch (e) {
      _error = 'Batch auto-tagging failed: $e';
      debugPrint('Error in batch auto-tagging: $e');
    } finally {
      _isBatchProcessing = false;
      _batchProgress = 0;
      _batchTotal = 0;
      notifyListeners();
    }
  }

  // Refresh statistics
  Future<void> refreshStats() async {
    try {
      _stats = await _autoTaggingService.getAutoTaggingStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing auto-tagging stats: $e');
    }
  }

  // Settings management
  void updateSettings(AutoTaggingSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
    _saveSettings();
  }

  void setAutoTagOnSave(bool enabled) {
    _settings = _settings.copyWith(autoTagOnSave: enabled);
    notifyListeners();
    _saveSettings();
  }

  void setAutoApprovalThreshold(double threshold) {
    _settings = _settings.copyWith(
      autoApprovalThreshold: threshold.clamp(0.0, 1.0)
    );
    notifyListeners();
    _saveSettings();
  }

  void setEnableNewTagCreation(bool enabled) {
    _settings = _settings.copyWith(enableNewTagCreation: enabled);
    notifyListeners();
    _saveSettings();
  }

  void setEnableNewThemeCreation(bool enabled) {
    _settings = _settings.copyWith(enableNewThemeCreation: enabled);
    notifyListeners();
    _saveSettings();
  }

  void _saveSettings() {
    // TODO: Save settings to local storage (SharedPreferences)
    debugPrint('Auto-tagging settings saved: ${_settings.toString()}');
  }

  void _loadSettings() {
    // TODO: Load settings from local storage
    debugPrint('Auto-tagging settings loaded');
  }

  // Get human-readable confidence description
  String getConfidenceDescription(double confidence) {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.6) return 'Medium';
    if (confidence >= 0.5) return 'Low';
    return 'Very Low';
  }

  // Get color for confidence level
  String getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return '#4CAF50'; // Green
    if (confidence >= 0.7) return '#8BC34A'; // Light Green
    if (confidence >= 0.6) return '#FFC107'; // Amber
    if (confidence >= 0.5) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  // Get stats summary
  String get statsSummary {
    final aiTaggedFiles = _stats['ai_tagged_files'] as int? ?? 0;
    final aiThemedFiles = _stats['ai_themed_files'] as int? ?? 0;
    final totalTags = _stats['total_tags'] as int? ?? 0;
    final totalThemes = _stats['total_themes'] as int? ?? 0;
    
    if (aiTaggedFiles == 0 && aiThemedFiles == 0) {
      return 'No auto-tagging performed yet';
    }
    
    return '$aiTaggedFiles files tagged, $aiThemedFiles files themed (${totalTags} tags, ${totalThemes} themes available)';
  }

  // Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Check if service is working
  bool get isServiceHealthy {
    return _isInitialized && (_stats['service_initialized'] as bool? ?? false);
  }

  @override
  void dispose() {
    _autoTaggingService.dispose();
    super.dispose();
  }
} 