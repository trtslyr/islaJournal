import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'windows_stability_service.dart';
import 'ollama_service.dart';

enum ModelStatus { notDownloaded, downloading, downloaded, loaded, error }

class DownloadProgress {
  final int downloaded;
  final int total;
  final double speed; // MB/s
  final int remainingTime; // seconds

  DownloadProgress({
    required this.downloaded,
    required this.total,
    this.speed = 0.0,
    this.remainingTime = 0,
  });
  
  double get percentage => total > 0 ? (downloaded / total) * 100 : 0;
}

class DeviceOptimizedModel {
  final String id;
  final String name;
  final String description;
  final String quantization;
  final String downloadUrl;
  final int sizeGB;
  final int minRAMGB;
  final List<String> optimizedFor;
  final bool isRecommended;
  final double qualityScore; // 1-10 scale
  
  const DeviceOptimizedModel({
    required this.id,
    required this.name,
    required this.description,
    required this.quantization,
    required this.downloadUrl,
    required this.sizeGB,
    required this.minRAMGB,
    required this.optimizedFor,
    this.isRecommended = false,
    required this.qualityScore,
  });
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Model state
  final Map<String, ModelStatus> _modelStatuses = {};
  String? _currentModelId;
  bool _isGenerating = false;
  
  // Ollama service for Windows
  final OllamaService _ollamaService = OllamaService();

  // Download state
  final StreamController<DownloadProgress> _downloadProgressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress => _downloadProgressController.stream;
  
  // Device info
  String? _deviceType;
  int _deviceRAMGB = 8; // Default conservative estimate
  
  // Ollama model catalog - no downloads needed, managed by Ollama
  static const Map<String, DeviceOptimizedModel> _availableModels = {
    // Basic models for low RAM
    'llama3.2:1b': DeviceOptimizedModel(
      id: 'llama3.2:1b',
      name: 'Llama 3.2 1B',
      description: 'Very fast, basic intelligence. For 4GB RAM or less.',
      quantization: 'Q4_0',
      downloadUrl: '', // Managed by Ollama
      sizeGB: 1,
      minRAMGB: 2,
      optimizedFor: ['4GB RAM or less', 'Basic tasks'],
      isRecommended: true,
      qualityScore: 6.5,
    ),
    
    // Universal compatibility for 8GB systems
    'llama3.2:3b': DeviceOptimizedModel(
      id: 'llama3.2:3b',
      name: 'Llama 3.2 3B',
      description: 'Works on any system. Best for most users.',
      quantization: 'Q4_0',
      downloadUrl: '', // Managed by Ollama
      sizeGB: 2,
      minRAMGB: 4,
      optimizedFor: ['8GB RAM', 'General use'],
      isRecommended: true,
      qualityScore: 7.5,
    ),
    
    // High-end systems
    'llama3:8b': DeviceOptimizedModel(
      id: 'llama3:8b',
      name: 'Llama 3 8B',
      description: 'Highest intelligence. For 16GB+ RAM systems.',
      quantization: 'Q4_K_M',
      downloadUrl: '', // Managed by Ollama
      sizeGB: 5,
      minRAMGB: 12,
      optimizedFor: ['16GB+ RAM', 'Complex tasks'],
      qualityScore: 9.0,
    ),
  };

  // Getters
  Map<String, ModelStatus> get modelStatuses => Map.from(_modelStatuses);
  Map<String, DeviceOptimizedModel> get availableModels => _availableModels;
  bool get isGenerating => _isGenerating;
  bool get hasDownloadedModel => _modelStatuses.values.any((status) => status == ModelStatus.downloaded || status == ModelStatus.loaded);
  bool get isModelLoaded => _currentModelId != null && _modelStatuses[_currentModelId] == ModelStatus.loaded;
  String? get currentModelId => _currentModelId;
  String? get deviceType => _deviceType;
  int get deviceRAMGB => _deviceRAMGB;

  Future<void> initialize() async {
    // Initialize Windows stability service first
    await WindowsStabilityService.initialize();
    
    // Initialize ollama service on Windows
    if (Platform.isWindows) {
      try {
        await _ollamaService.initialize();
        debugPrint('✅ Ollama service initialized for Windows');
      } catch (e) {
        debugPrint('⚠️ Ollama not available, falling back to fllama: $e');
      }
    }
    
    await _detectDeviceCapabilities();
    await _checkExistingModels();
    await _loadPreviouslyLoadedModel();
  }

  Future<void> _detectDeviceCapabilities() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceType = '${androidInfo.manufacturer} ${androidInfo.model}';
        // Estimate RAM based on Android version and year
        _deviceRAMGB = _estimateAndroidRAM(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceType = iosInfo.model;
        _deviceRAMGB = _estimateIOSRAM(iosInfo.model);
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _deviceType = macInfo.model;
        _deviceRAMGB = _estimateMacRAM(macInfo.model);
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceType = windowsInfo.computerName;
        _deviceRAMGB = 16; // Conservative estimate for Windows PCs
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceType = linuxInfo.name;
        _deviceRAMGB = 16; // Conservative estimate for Linux PCs
      }
      
      debugPrint('🔍 Device detected: $_deviceType with estimated ${_deviceRAMGB}GB RAM');
    } catch (e) {
      debugPrint('⚠️ Could not detect device capabilities: $e');
      _deviceType = 'Unknown Device';
      _deviceRAMGB = 8; // Safe default
    }
  }
  
  int _estimateAndroidRAM(AndroidDeviceInfo info) {
    // Enhanced heuristics based on Android version and device characteristics
    final sdkInt = info.version.sdkInt;
    final model = info.model.toLowerCase();
    
    // High-end devices
    if (model.contains('galaxy s') || model.contains('pixel') || model.contains('oneplus')) {
      if (sdkInt >= 33) return 16; // Android 13+ flagship
      if (sdkInt >= 30) return 12; // Android 11+ flagship
      return 8;
    }
    
    // Standard progression based on Android version
    if (sdkInt >= 34) return 12; // Android 14+ usually has 8-16GB
    if (sdkInt >= 33) return 10; // Android 13+ usually has 6-12GB
    if (sdkInt >= 30) return 8;  // Android 11+ usually has 4-8GB
    if (sdkInt >= 28) return 6;  // Android 9+ usually has 3-6GB
    return 4; // Older Android devices
  }
  
  int _estimateIOSRAM(String model) {
    // iPhone models typically have known RAM amounts
    if (model.contains('iPhone15') || model.contains('iPhone 15')) return 8;
    if (model.contains('iPhone14') || model.contains('iPhone 14')) return 6;
    if (model.contains('iPhone13') || model.contains('iPhone 13')) return 6;
    if (model.contains('iPad Pro')) return 16;
    if (model.contains('iPad Air')) return 8;
    return 4; // Conservative for older devices
  }
  
  int _estimateMacRAM(String model) {
    // Enhanced Mac RAM estimation based on specific models
    final modelLower = model.toLowerCase();
    
    // Mac Studio and Mac Pro (high-end)
    if (modelLower.contains('mac pro')) {
      if (modelLower.contains('m2') || modelLower.contains('m3')) return 128; // M2/M3 Ultra Mac Pro
      return 64; // Intel or M1 Mac Pro
    }
    if (modelLower.contains('mac studio')) {
      if (modelLower.contains('ultra')) return 64; // M1/M2 Ultra Studio
      return 32; // M1/M2 Max Studio
    }
    
    // MacBook Pro (varies by chip and size)
    if (modelLower.contains('macbook pro')) {
      if (modelLower.contains('16') && (modelLower.contains('m3') || modelLower.contains('m2'))) {
        return 36; // 16" MBP with M2/M3 Pro/Max
      }
      if (modelLower.contains('14') && (modelLower.contains('m3') || modelLower.contains('m2'))) {
        return 32; // 14" MBP with M2/M3 Pro/Max
      }
      if (modelLower.contains('m3') || modelLower.contains('m2') || modelLower.contains('m1')) {
        return 16; // 13" MBP or base models
      }
      return 16; // Intel MacBook Pro
    }
    
    // iMac
    if (modelLower.contains('imac')) {
      if (modelLower.contains('27')) return 32; // 27" Intel iMac
      if (modelLower.contains('m3')) return 24; // 24" M3 iMac
      return 16; // 24" M1 iMac or older
    }
    
    // MacBook Air
    if (modelLower.contains('macbook air')) {
      if (modelLower.contains('m3')) return 24; // M3 MacBook Air
      if (modelLower.contains('m2')) return 16; // M2 MacBook Air
      if (modelLower.contains('m1')) return 16; // M1 MacBook Air (but often 8GB)
      return 8; // Intel MacBook Air
    }
    
    // Mac mini
    if (modelLower.contains('mac mini')) {
      if (modelLower.contains('m2')) return 24; // M2 Mac mini
      if (modelLower.contains('m1')) return 16; // M1 Mac mini
      return 16; // Intel Mac mini
    }
    
    return 16; // Safe default for any Mac
  }

  List<DeviceOptimizedModel> getRecommendedModels() {
    final recommended = <DeviceOptimizedModel>[];
    
    for (final model in _availableModels.values) {
      if (model.minRAMGB <= _deviceRAMGB) {
        recommended.add(model);
      }
    }
    
    // Sort by quality score descending, but prioritize recommended models
    recommended.sort((a, b) {
      if (a.isRecommended && !b.isRecommended) return -1;
      if (!a.isRecommended && b.isRecommended) return 1;
      return b.qualityScore.compareTo(a.qualityScore);
    });
    
    return recommended;
  }
  
  DeviceOptimizedModel? getBestModelForDevice() {
    final recommended = getRecommendedModels();
    if (recommended.isEmpty) return null;
    
    // Find the best model that fits in device RAM with some buffer
    final safeRAM = (_deviceRAMGB * 0.7).round(); // Use 70% of available RAM
    
    for (final model in recommended) {
      if (model.sizeGB <= safeRAM) {
        return model;
      }
    }
    
    // If nothing fits safely, return the smallest available
    return recommended.last;
  }

  Future<void> _checkExistingModels() async {
    // Initialize all models as not downloaded first
    for (final modelId in _availableModels.keys) {
      _modelStatuses[modelId] = ModelStatus.notDownloaded;
    }
    
    final modelsDir = await _getModelsDirectory();
    if (!await modelsDir.exists()) return;
    
    // Check which models actually exist
    for (final modelId in _availableModels.keys) {
      final modelFile = File('${modelsDir.path}/$modelId.gguf');
      if (await modelFile.exists()) {
        _modelStatuses[modelId] = ModelStatus.downloaded;
        debugPrint('✅ Found existing model: $modelId');
      }
    }
    
    debugPrint('📊 Model status initialized: ${_modelStatuses.length} models checked');
  }

  Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/ai_models');
    if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<void> downloadModel(String modelId) async {
    final model = _availableModels[modelId];
    if (model == null) {
      throw Exception('Model not found: $modelId');
    }

    _modelStatuses[modelId] = ModelStatus.downloading;

    try {
      debugPrint('📥 Downloading ${model.name} via Ollama...');
      
      // Use ollama to pull the model
      await _ollamaService.pullModel(modelId);
      
      _modelStatuses[modelId] = ModelStatus.downloaded;
      debugPrint('✅ Downloaded ${model.name} successfully via Ollama');

    } catch (e) {
      _modelStatuses[modelId] = ModelStatus.error;
      debugPrint('❌ Failed to download ${model.name}: $e');
      rethrow;
    }
  }

  Future<void> loadModel(String modelId) async {
    try {
      // Use ollama to set the current model
      await _ollamaService.setModel(modelId);
      
      _currentModelId = modelId;
      _modelStatuses[modelId] = ModelStatus.loaded;
      
      // Persist the loaded model ID
      await _saveLoadedModelId(modelId);
      
      final model = _availableModels[modelId]!;
      debugPrint('✅ Successfully loaded ${model.name} via Ollama');
      
    } catch (e) {
      _modelStatuses[modelId] = ModelStatus.error;
      _currentModelId = null;
      debugPrint('❌ Failed to load model $modelId: $e');
      rethrow;
    }
  }



  /// Save the currently loaded model ID to SharedPreferences
  Future<void> _saveLoadedModelId(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loaded_model_id', modelId);
      debugPrint('💾 Saved loaded model ID: $modelId');
    } catch (e) {
      debugPrint('⚠️ Failed to save loaded model ID: $e');
    }
  }

  /// Clear the loaded model ID from SharedPreferences
  Future<void> _clearLoadedModelId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loaded_model_id');
      debugPrint('🗑️ Cleared loaded model ID');
    } catch (e) {
      debugPrint('⚠️ Failed to clear loaded model ID: $e');
    }
  }

  /// Load the previously loaded model on app startup
  Future<void> _loadPreviouslyLoadedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModelId = prefs.getString('loaded_model_id');
      
      if (savedModelId != null && _availableModels.containsKey(savedModelId)) {
        // Check if the model is downloaded and ready to load
        if (_modelStatuses[savedModelId] == ModelStatus.downloaded) {
          debugPrint('🔄 Auto-loading previously loaded model: $savedModelId');
          await loadModel(savedModelId);
          debugPrint('✅ Successfully restored previously loaded model: $savedModelId');
        } else {
          debugPrint('⚠️ Previously loaded model $savedModelId is not downloaded, skipping auto-load');
          // Clear the saved model ID since it's no longer valid
          await _clearLoadedModelId();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load previously loaded model: $e');
      // Clear the saved model ID if there was an error
      await _clearLoadedModelId();
    }
  }

  Future<void> unloadModel() async {
    if (_currentModelId != null) {
      _modelStatuses[_currentModelId!] = ModelStatus.downloaded;
      _currentModelId = null;
      
      // Clear the persisted loaded model ID
      await _clearLoadedModelId();
      
      debugPrint('🔄 Model unloaded');
    }
  }

  Future<String> generateText(String prompt, {int maxTokens = 100}) async {
    if (_isGenerating) {
      throw Exception('Generation already in progress');
    }

    _isGenerating = true;

    try {
      // Use ollama on Windows if available
      if (Platform.isWindows) {
        try {
          final result = await _ollamaService.generateText(prompt, maxTokens: maxTokens);
          debugPrint('✅ Ollama generation successful on Windows');
          return result;
        } catch (e) {
          debugPrint('⚠️ Ollama failed, falling back to fllama: $e');
          // Fall back to fllama if ollama fails
        }
      }
      
      // Check Windows system health before proceeding with fllama
      if (Platform.isWindows) {
        final isHealthy = await WindowsStabilityService.isSystemHealthy();
        if (!isHealthy) {
          throw Exception('Windows system not ready for AI operation - insufficient memory');
        }
        
        final inSafeMode = await WindowsStabilityService.shouldRunInSafeMode();
        if (inSafeMode) {
          // Use safe configuration for Windows
          maxTokens = 50; // Was 25, now more reasonable for safe mode
          debugPrint('⚠️ Windows safe mode: using reduced parameters');
        }
      }
      
      // Adaptive token optimization based on prompt complexity
      if (maxTokens == 100) {  // Only optimize default calls
        if (prompt.length < 50) {
          maxTokens = 50;   // Short prompt = short response
        } else if (prompt.length < 200) {
          maxTokens = 80;   // Medium prompt = medium response
        }
        // Long prompts keep the passed maxTokens value
      }
      
      // Use ollama for all platforms (no more fllama crashes)
      final result = await _ollamaService.generateText(prompt, maxTokens: maxTokens);

      // Mark successful operation for Windows stability tracking
      if (Platform.isWindows) {
        await WindowsStabilityService.markSuccessfulOperation();
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Generation failed: $e');
      
      // Record crash for Windows stability tracking
      if (Platform.isWindows) {
        await WindowsStabilityService.recordCrash();
      }
      
      // If generation fails, the model might be corrupted or incompatible
      if (_currentModelId != null) {
        debugPrint('⚠️ Marking model $_currentModelId as error due to generation failure');
        _modelStatuses[_currentModelId!] = ModelStatus.error;
        _currentModelPath = null;
        _currentModelId = null;
        
        // Clear persisted model ID on error
        await _clearLoadedModelId();
      }
      
      String errorMessage = 'AI generation failed: ${e.toString()}.';
      if (Platform.isWindows) {
        errorMessage += ' ${WindowsStabilityService.getWindowsErrorGuidance(e.toString())}';
      } else {
        errorMessage += ' Model may be incompatible with this device.';
      }
      
      throw Exception(errorMessage);
    } finally {
      _isGenerating = false;
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      if (_currentModelId == modelId) {
        await unloadModel();
      }

      // Use ollama to delete the model
      await _ollamaService.deleteModel(modelId);

      _modelStatuses[modelId] = ModelStatus.notDownloaded;
      debugPrint('🗑️ Deleted model: $modelId');
    } catch (e) {
      debugPrint('❌ Failed to delete model $modelId: $e');
      rethrow;
    }
  }



  Future<String> getStorageUsage() async {
    try {
      final modelsDir = await _getModelsDirectory();
      if (!await modelsDir.exists()) return '0 MB';

      int totalBytes = 0;
      final modelFiles = modelsDir.listSync().whereType<File>();
      
      for (final file in modelFiles) {
        if (file.path.endsWith('.gguf')) {
          final stat = await file.stat();
          totalBytes += stat.size;
        }
      }

      final mb = totalBytes / (1024 * 1024);
      if (mb < 1024) {
        return '${mb.toStringAsFixed(1)} MB';
      } else {
        final gb = mb / 1024;
        return '${gb.toStringAsFixed(1)} GB';
      }
    } catch (e) {
      debugPrint('❌ Failed to calculate storage usage: $e');
      return 'Unknown';
    }
  }

  void dispose() {
    _downloadProgressController.close();
  }
} 