import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';

class AIProvider with ChangeNotifier {
  final AIService _aiService = AIService();
  
  bool _isInitialized = false;
  bool _isLoading = false;
  String _error = '';
  String? _currentModel;
  bool _isModelLoaded = false;
  bool _isOllamaRunning = false;
  List<Map<String, dynamic>> _availableModels = [];
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String get error => _error;
  String? get currentModel => _currentModel;
  bool get isModelLoaded => _isModelLoaded;
  bool get isOllamaRunning => _isOllamaRunning;
  List<Map<String, dynamic>> get availableModels => _availableModels;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  /// Initialize AI service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _aiService.initialize();
      if (success) {
        _isInitialized = true;
        _isOllamaRunning = _aiService.isOllamaRunning;
        _isModelLoaded = _aiService.isModelLoaded;
        _currentModel = _aiService.currentModel;
        
        if (_isOllamaRunning) {
          await _loadAvailableModels();
        }
        
        debugPrint('AI Provider initialized successfully');
      } else {
        _setError('Failed to initialize AI service. Please ensure Ollama is running.');
      }
    } catch (e) {
      _setError('AI initialization error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate text using AI
  Future<String> generateText(
    String prompt, {
    Map<String, dynamic>? options,
    Function(String)? onStreamChunk,
  }) async {
    if (!_isInitialized || !_isModelLoaded) {
      throw Exception('AI service not ready. Please initialize first.');
    }

    _setLoading(true);
    _clearError();

    try {
      final response = await _aiService.generateText(
        prompt,
        options: options,
        onStreamChunk: onStreamChunk,
      );
      return response;
    } catch (e) {
      _setError('Text generation error: $e');
      throw e;
    } finally {
      _setLoading(false);
    }
  }

  /// Generate embeddings for text
  Future<List<double>> generateEmbeddings(String text) async {
    if (!_isInitialized || !_isModelLoaded) {
      throw Exception('AI service not ready. Please initialize first.');
    }

    _setLoading(true);
    _clearError();

    try {
      final embeddings = await _aiService.generateEmbeddings(text);
      return embeddings;
    } catch (e) {
      _setError('Embeddings generation error: $e');
      throw e;
    } finally {
      _setLoading(false);
    }
  }

  /// Download a model
  Future<void> downloadModel(String modelName) async {
    if (!_isOllamaRunning) {
      throw Exception('Ollama is not running');
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _clearError();
    notifyListeners();

    try {
      await _aiService.downloadModel(
        modelName,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );
      
      // Refresh available models and current model status
      await _loadAvailableModels();
      _isModelLoaded = _aiService.isModelLoaded;
      _currentModel = _aiService.currentModel;
      
    } catch (e) {
      _setError('Model download error: $e');
      throw e;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Load available models
  Future<void> _loadAvailableModels() async {
    try {
      _availableModels = await _aiService.getAvailableModels();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading available models: $e');
    }
  }

  /// Refresh AI status
  Future<void> refreshStatus() async {
    if (!_isInitialized) return;
    
    _setLoading(true);
    try {
      await initialize();
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a model is available
  Future<bool> isModelAvailable(String modelName) async {
    if (!_isOllamaRunning) return false;
    
    try {
      return await _aiService.isModelAvailable(modelName);
    } catch (e) {
      debugPrint('Error checking model availability: $e');
      return false;
    }
  }

  /// Get model information
  Future<Map<String, dynamic>?> getModelInfo(String modelName) async {
    if (!_isOllamaRunning) return null;
    
    try {
      return await _aiService.getModelInfo(modelName);
    } catch (e) {
      debugPrint('Error getting model info: $e');
      return null;
    }
  }

  /// Get recommended models for device
  List<String> getRecommendedModels() {
    // Based on tech stack plan
    return [
      'llama3.2:3b',     // Mobile-friendly
      'llama3.1:8b',     // Desktop
      'llama3.2:3b-q4_0', // Quantized
    ];
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    debugPrint('AI Provider Error: $error');
    notifyListeners();
  }

  void _clearError() {
    _error = '';
    notifyListeners();
  }

  /// Cleanup
  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}