import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';

class AIProvider with ChangeNotifier {
  final AIService _aiService = AIService();
  
  // State variables
  bool _isInitialized = false;
  String? _currentModelId;
  Map<String, ModelStatus> _modelStatuses = {};
  DownloadProgress? _currentDownload;
  String _aiResponse = '';
  bool _isGenerating = false;
  String? _error;
  
  // AI Features state
  String? _currentMoodAnalysis;
  String? _currentWritingAnalysis;
  List<String> _writingPrompts = [];
  bool _showAISuggestions = true;
  
  // Getters
  bool get isInitialized => _isInitialized;
  String? get currentModelId => _currentModelId;
  Map<String, ModelStatus> get modelStatuses => _modelStatuses;
  Map<String, AIModelInfo> get availableModels => _aiService.availableModels;
  DownloadProgress? get currentDownload => _currentDownload;
  String get aiResponse => _aiResponse;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  
  // AI Features getters
  String? get currentMoodAnalysis => _currentMoodAnalysis;
  String? get currentWritingAnalysis => _currentWritingAnalysis;
  List<String> get writingPrompts => _writingPrompts;
  bool get showAISuggestions => _showAISuggestions;
  
  // Computed getters
  bool get hasDownloadedModel => _modelStatuses.values.any(
    (status) => status == ModelStatus.downloaded || status == ModelStatus.loaded
  );
  
  bool get isModelLoaded => _currentModelId != null && 
    _modelStatuses[_currentModelId] == ModelStatus.loaded;
  
  int get downloadedModelsCount => _modelStatuses.values
    .where((status) => status == ModelStatus.downloaded || status == ModelStatus.loaded)
    .length;

  Future<void> initialize() async {
    try {
      _error = null;
      await _aiService.initialize();
      
      // Set up listeners
      _aiService.downloadProgress.listen((progress) {
        _currentDownload = progress;
        notifyListeners();
      });
      
      _aiService.aiResponse.listen((response) {
        _aiResponse = response;
        notifyListeners();
      });
      
      _currentModelId = _aiService.currentModelId;
      _modelStatuses = Map.from(_aiService.modelStatuses);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize AI: $e';
      notifyListeners();
    }
  }

  Future<void> downloadModel(String modelId) async {
    try {
      _error = null;
      notifyListeners();
      
      await _aiService.downloadModel(modelId);
      _modelStatuses = Map.from(_aiService.modelStatuses);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to download model: $e';
      notifyListeners();
    }
  }

  void cancelDownload() {
    _aiService.cancelDownload();
    _currentDownload = null;
    notifyListeners();
  }

  Future<void> loadModel(String modelId) async {
    try {
      _error = null;
      notifyListeners();
      
      await _aiService.loadModel(modelId);
      _currentModelId = _aiService.currentModelId;
      _modelStatuses = Map.from(_aiService.modelStatuses);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load model: $e';
      notifyListeners();
    }
  }

  Future<void> unloadModel() async {
    try {
      _error = null;
      await _aiService.unloadModel();
      _currentModelId = null;
      _modelStatuses = Map.from(_aiService.modelStatuses);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to unload model: $e';
      notifyListeners();
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      _error = null;
      await _aiService.deleteModel(modelId);
      _modelStatuses = Map.from(_aiService.modelStatuses);
      
      if (_currentModelId == modelId) {
        _currentModelId = null;
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete model: $e';
      notifyListeners();
    }
  }

  Future<String> generateText(String prompt, {
    int maxTokens = 256,
    double temperature = 0.7,
    String? systemPrompt,
  }) async {
    if (!isModelLoaded) {
      throw Exception('No model loaded');
    }

    try {
      _error = null;
      _isGenerating = true;
      notifyListeners();

      final response = await _aiService.generateText(
        prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        systemPrompt: systemPrompt,
      );

      return response;
    } catch (e) {
      _error = 'Failed to generate text: $e';
      rethrow;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  // AI Feature Methods
  Future<void> analyzeCurrentText(String text) async {
    if (!isModelLoaded || text.trim().isEmpty) return;

    try {
      _error = null;
      
      // Run mood and writing analysis in parallel
      final futures = await Future.wait([
        _aiService.analyzeMood(text),
        _aiService.analyzeWritingStyle(text),
      ]);
      
      _currentMoodAnalysis = futures[0];
      _currentWritingAnalysis = futures[1];
      notifyListeners();
    } catch (e) {
      _error = 'Failed to analyze text: $e';
      notifyListeners();
    }
  }

  Future<void> generateWritingPrompts(String context) async {
    if (!isModelLoaded) return;

    try {
      _error = null;
      _writingPrompts = await _aiService.generateWritingPrompts(context);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate prompts: $e';
      notifyListeners();
    }
  }

  Future<String> suggestContinuation(String text) async {
    if (!isModelLoaded) {
      throw Exception('No model loaded');
    }

    return await _aiService.suggestContinuation(text);
  }

  Future<String> generateResponse(String prompt) async {
    if (!isModelLoaded) {
      throw Exception('No model loaded');
    }

    try {
      _error = null;
      _isGenerating = true;
      notifyListeners();

      final response = await _aiService.generateText(
        prompt,
        maxTokens: 200,
        temperature: 0.7,
        systemPrompt: 'You are a helpful AI assistant. Provide concise, helpful responses to user questions and requests.',
      );

      return response;
    } catch (e) {
      _error = 'Failed to generate response: $e';
      rethrow;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void toggleAISuggestions() {
    _showAISuggestions = !_showAISuggestions;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearAIAnalysis() {
    _currentMoodAnalysis = null;
    _currentWritingAnalysis = null;
    _writingPrompts = [];
    notifyListeners();
  }

  Future<String> getStorageUsageFormatted() async {
    final bytes = await _aiService.getStorageUsage();
    return _formatBytes(bytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
} 