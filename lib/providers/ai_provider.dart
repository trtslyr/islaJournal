import 'package:flutter/foundation.dart';
import '../services/hybrid_ai_service.dart';

class AIProvider with ChangeNotifier {
  final HybridAiService _aiService = HybridAiService();
  
  String _aiResponse = '';
  String _moodAnalysis = '';
  String _writingStyleAnalysis = '';
  bool _isInitialized = false;

  String get aiResponse => _aiResponse;
  String get moodAnalysis => _moodAnalysis;
  String get writingStyleAnalysis => _writingStyleAnalysis;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _aiService.initialize();
      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ AI Provider initialized with hybrid service');
    } catch (e) {
      debugPrint('❌ Failed to initialize AI Provider: $e');
      rethrow;
    }
  }

  // Delegate properties to hybrid service
  Map<String, dynamic> get modelStatuses => _aiService.modelStatuses;
  Map<String, dynamic> get availableModels => _aiService.availableModels;
  bool get hasDownloadedModel => _aiService.isModelLoaded;
  bool get isModelLoaded => _aiService.isModelLoaded;
  String? get currentModelId => _aiService.currentModelId;
  String? get deviceType => _aiService.deviceType;
  int get deviceRAMGB => _aiService.deviceRAMGB;
  bool get isGenerating => _aiService.isGenerating;

  List<dynamic> getRecommendedModels() {
    return _aiService.getRecommendedModels();
  }

  dynamic getBestModelForDevice() {
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
      _writingStyleAnalysis = await _aiService.generateText(
        'Analyze the writing style of this text briefly: $text',
        maxTokens: 40,  // Quick style analysis
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Writing style analysis failed: $e');
      _writingStyleAnalysis = 'Error analyzing writing style: $e';
      notifyListeners();
    }
  }

  Future<String> getStorageUsage() async {
    return await _aiService.getStorageUsage();
  }

  /// Debug test the AI system
  Future<void> debugTestAISystem() async {
    await _aiService.debugTestAISystem();
  }

  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
} 