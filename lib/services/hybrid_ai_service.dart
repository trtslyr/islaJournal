import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'embedded_ollama_service.dart';

/// Hybrid AI service that uses embedded Ollama on Windows and fllama elsewhere
class HybridAiService {
  static final HybridAiService _instance = HybridAiService._internal();
  factory HybridAiService() => _instance;
  HybridAiService._internal();

  // Services
  final AIService _fllamaService = AIService();
  final EmbeddedOllamaService _ollamaService = EmbeddedOllamaService();
  
  bool _initialized = false;

  /// Check which service we should use based on platform
  bool get _shouldUseOllama => Platform.isWindows;

  /// Initialize the appropriate service based on platform
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔀 Initializing Hybrid AI Service...');
    debugPrint('   Platform: ${Platform.operatingSystem}');
    
    if (_shouldUseOllama) {
      debugPrint('   🪟 Using embedded Ollama for Windows');
      try {
        await _ollamaService.initialize();
        debugPrint('   ✅ Embedded Ollama initialized successfully');
      } catch (e) {
        debugPrint('   ❌ Embedded Ollama failed to initialize: $e');
        debugPrint('   🔄 Falling back to fllama...');
        await _fllamaService.initialize();
      }
    } else {
      debugPrint('   🍎 Using fllama for Mac/other platforms');
      await _fllamaService.initialize();
    }
    
    _initialized = true;
    debugPrint('✅ Hybrid AI Service initialized');
  }

  /// Generate text using the appropriate service
  Future<String> generateText(String prompt, {int maxTokens = 100}) async {
    if (!_initialized) {
      await initialize();
    }

    if (_shouldUseOllama) {
      // Try embedded Ollama first on Windows
      try {
        if (await _ollamaService.isAvailable()) {
          debugPrint('🪟 Using embedded Ollama for generation');
          return await _ollamaService.generateText(prompt, maxTokens: maxTokens);
        } else {
          debugPrint('🔄 Embedded Ollama not available, trying to start...');
          await _ollamaService.initialize();
          return await _ollamaService.generateText(prompt, maxTokens: maxTokens);
        }
      } catch (e) {
        debugPrint('❌ Embedded Ollama failed: $e');
        debugPrint('🔄 Falling back to fllama on Windows...');
        
        // Fallback to fllama if Ollama fails
        try {
          return await _fllamaService.generateText(prompt, maxTokens: maxTokens);
        } catch (e2) {
          debugPrint('❌ fllama also failed: $e2');
          throw Exception('AI generation failed on both Ollama and fllama: $e');
        }
      }
    } else {
      // Use fllama on Mac/other platforms
      debugPrint('🍎 Using fllama for generation');
      return await _fllamaService.generateText(prompt, maxTokens: maxTokens);
    }
  }

  /// Get model statuses (delegates to appropriate service)
  Map<String, dynamic> get modelStatuses {
    if (_shouldUseOllama && _ollamaService.isRunning) {
      return {'embedded_ollama': 'running'};
    }
    return _fllamaService.modelStatuses;
  }

  /// Check if any model is loaded and ready
  bool get isModelLoaded {
    if (_shouldUseOllama) {
      return _ollamaService.isRunning;
    }
    return _fllamaService.isModelLoaded;
  }

  /// Get available models (delegates to appropriate service)
  Map<String, dynamic> get availableModels {
    if (_shouldUseOllama) {
      return {
        'embedded_phi3': {
          'name': 'Phi-3 Mini (Embedded)',
          'description': 'Embedded Ollama model for Windows',
          'platform': 'Windows only',
        }
      };
    }
    return _fllamaService.availableModels;
  }

  /// Download model (only for fllama)
  Future<void> downloadModel(String modelId) async {
    if (_shouldUseOllama) {
      throw Exception('Model downloading not needed with embedded Ollama');
    }
    return await _fllamaService.downloadModel(modelId);
  }

  /// Load model (only for fllama)
  Future<void> loadModel(String modelId) async {
    if (_shouldUseOllama) {
      // For Ollama, just ensure it's initialized
      await _ollamaService.initialize();
      return;
    }
    return await _fllamaService.loadModel(modelId);
  }

  /// Unload model
  Future<void> unloadModel() async {
    if (_shouldUseOllama) {
      // Don't actually stop Ollama, just acknowledge
      debugPrint('📝 Ollama model unload requested (keeping service running)');
      return;
    }
    return await _fllamaService.unloadModel();
  }

  /// Delete model (only for fllama)
  Future<void> deleteModel(String modelId) async {
    if (_shouldUseOllama) {
      throw Exception('Model deletion not available with embedded Ollama');
    }
    return await _fllamaService.deleteModel(modelId);
  }

  /// Get storage usage
  Future<String> getStorageUsage() async {
    if (_shouldUseOllama) {
      return 'Embedded Ollama models';
    }
    return await _fllamaService.getStorageUsage();
  }

  /// Get device info
  String? get deviceType => _fllamaService.deviceType;
  int get deviceRAMGB => _fllamaService.deviceRAMGB;

  /// Check if generation is in progress
  bool get isGenerating {
    if (_shouldUseOllama) {
      // For Ollama, we don't track this state the same way
      return false;
    }
    return _fllamaService.isGenerating;
  }

  /// Get current model ID
  String? get currentModelId {
    if (_shouldUseOllama) {
      return _ollamaService.isRunning ? 'embedded_phi3' : null;
    }
    return _fllamaService.currentModelId;
  }

  /// Get recommended models
  List<dynamic> getRecommendedModels() {
    if (_shouldUseOllama) {
      return [
        {
          'id': 'embedded_phi3',
          'name': 'Phi-3 Mini (Embedded)',
          'description': 'Pre-installed with your app - no download needed!',
          'platform': 'Windows',
          'ready': true,
        }
      ];
    }
    return _fllamaService.getRecommendedModels();
  }

  /// Get best model for device
  dynamic getBestModelForDevice() {
    if (_shouldUseOllama) {
      return {
        'id': 'embedded_phi3',
        'name': 'Phi-3 Mini (Embedded)',
        'description': 'Optimized embedded model for Windows',
      };
    }
    return _fllamaService.getBestModelForDevice();
  }

  /// Debug test the AI system
  Future<void> debugTestAISystem() async {
    debugPrint('🧪 HYBRID AI SYSTEM DEBUG TEST');
    debugPrint('   Platform: ${Platform.operatingSystem}');
    debugPrint('   Should use Ollama: $_shouldUseOllama');
    
    if (_shouldUseOllama) {
      debugPrint('🪟 Testing embedded Ollama...');
      try {
        final available = await _ollamaService.isAvailable();
        debugPrint('   Ollama available: $available');
        
        if (available) {
          final testResponse = await _ollamaService.generateText('Hello', maxTokens: 10);
          debugPrint('   ✅ Ollama test successful: "${testResponse.substring(0, math.min(30, testResponse.length))}..."');
        } else {
          debugPrint('   🔄 Trying to initialize Ollama...');
          await _ollamaService.initialize();
        }
      } catch (e) {
        debugPrint('   ❌ Ollama test failed: $e');
        
        // Test fallback to fllama
        debugPrint('   🔄 Testing fllama fallback...');
        try {
          await _fllamaService.debugTestAISystem();
        } catch (e2) {
          debugPrint('   ❌ fllama fallback also failed: $e2');
        }
      }
    } else {
      debugPrint('🍎 Testing fllama...');
      await _fllamaService.debugTestAISystem();
    }
    
    debugPrint('🏁 Hybrid AI system debug test completed');
  }

  /// Dispose of all services
  Future<void> dispose() async {
    await _ollamaService.dispose();
    _fllamaService.dispose();
  }
}