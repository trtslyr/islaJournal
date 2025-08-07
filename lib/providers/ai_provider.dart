import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';

class AIProvider with ChangeNotifier {
  final AIService _aiService = AIService();
  
  // State
  String _aiResponse = '';
  String _moodAnalysis = '';
  String _writingAnalysis = '';
  List<String> _writingPrompts = [];
  
  // Download progress
  DownloadProgress? _downloadProgress;
  
  // Getters
  String get aiResponse => _aiResponse;
  String get moodAnalysis => _moodAnalysis;
  String get writingAnalysis => _writingAnalysis;
  List<String> get writingPrompts => _writingPrompts;
  DownloadProgress? get downloadProgress => _downloadProgress;
  
  // AI Service getters
  Map<String, ModelStatus> get modelStatuses => _aiService.modelStatuses;
  Map<String, DeviceOptimizedModel> get availableModels => _aiService.availableModels;
  bool get isGenerating => _aiService.isGenerating;
  bool get hasDownloadedModel => _aiService.hasDownloadedModel;
  bool get isModelLoaded => _aiService.isModelLoaded;
  String? get currentModelId => _aiService.currentModelId;
  String? get deviceType => _aiService.deviceType;
  int get deviceRAMGB => _aiService.deviceRAMGB;
  bool get autoDownloadEnabled => _aiService.autoDownloadEnabled;
  
  set autoDownloadEnabled(bool enabled) {
    _aiService.autoDownloadEnabled = enabled;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _aiService.initialize();
    _listenToDownloadProgress();
    notifyListeners();
  }

  void _listenToDownloadProgress() {
    _aiService.downloadProgress.listen((progress) {
      _downloadProgress = progress;
      
      // Clear progress when download completes (indicated by 0 total)
      if (progress.total == 0 && progress.downloaded == 0) {
        _downloadProgress = null;
      }
      
      notifyListeners();
    });
  }

  List<DeviceOptimizedModel> getRecommendedModels() {
    return _aiService.getRecommendedModels();
  }
  
  DeviceOptimizedModel? getBestModelForDevice() {
    return _aiService.getBestModelForDevice();
  }

  Future<void> downloadModel(String modelId) async {
    try {
      await _aiService.downloadModel(modelId);
      notifyListeners();
      debugPrint('✅ Model $modelId downloaded successfully! Click "Load" to activate it.');
    } catch (e) {
      debugPrint('❌ Failed to download model: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadModel(String modelId) async {
    try {
      await _aiService.loadModel(modelId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load model: $e');
      rethrow;
    }
  }

  Future<void> unloadModel() async {
    try {
      await _aiService.unloadModel();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to unload model: $e');
      rethrow;
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      await _aiService.deleteModel(modelId);
      notifyListeners();
      debugPrint('✅ Model $modelId deleted successfully. Storage freed.');
    } catch (e) {
      debugPrint('❌ Failed to delete model: $e');
      rethrow;
    }
  }

  /// Force sync with Ollama and refresh model statuses
  Future<Map<String, dynamic>> syncWithOllama() async {
    try {
      final result = await _aiService.syncWithOllama();
      notifyListeners(); // Refresh UI after sync
      return result;
    } catch (e) {
      debugPrint('❌ Failed to sync with Ollama: $e');
      return {
        'success': false,
        'error': 'Failed to sync with Ollama: $e',
        'models': <String>[]
      };
    }
  }

  Future<void> generateText(String prompt, {int maxTokens = 100}) async {
    try {
      _aiResponse = await _aiService.generateText(prompt, maxTokens: maxTokens);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Text generation failed: $e');
      _aiResponse = 'Error generating response: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Placeholder methods - these would need re-implementation with the new AI service
  Future<void> analyzeMood(String text) async {
    try {
      _moodAnalysis = await _aiService.generateText(
        'Analyze the mood of this text briefly: $text',
        maxTokens: 30,  // Reduced from 50 for faster analysis
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Mood analysis failed: $e');
      _moodAnalysis = 'Error analyzing mood: $e';
      notifyListeners();
    }
  }

  Future<void> analyzeWritingStyle(String text) async {
    try {
      _writingAnalysis = await _aiService.generateText(
        'Analyze the writing style of this text briefly: $text',
        maxTokens: 50,  // Reduced from 80 for faster analysis
      );
      notifyListeners();
    } catch (e) {
      print('❌ Writing analysis failed: $e');
      _writingAnalysis = 'Error analyzing writing style: $e';
      notifyListeners();
    }
  }

  Future<void> generateWritingPrompts(String context) async {
    try {
      final response = await _aiService.generateText(
        'Generate 3 creative writing prompts based on: $context',
        maxTokens: 100,
      );
      _writingPrompts = response.split('\n').where((line) => line.trim().isNotEmpty).toList();
      notifyListeners();
    } catch (e) {
      print('❌ Writing prompts generation failed: $e');
      _writingPrompts = ['Error generating writing prompts: $e'];
      notifyListeners();
    }
  }

  // Clear methods
  void clearAIResponse() {
    _aiResponse = '';
    notifyListeners();
  }

  void clearMoodAnalysis() {
    _moodAnalysis = '';
    notifyListeners();
  }

  void clearWritingAnalysis() {
    _writingAnalysis = '';
    notifyListeners();
  }

  void clearWritingPrompts() {
    _writingPrompts = [];
    notifyListeners();
  }

  Future<String> getStorageUsage() async {
    return await _aiService.getStorageUsage();
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
} 