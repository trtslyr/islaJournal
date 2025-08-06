import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'windows_stability_service.dart';

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
  String? _currentModelPath;
  bool _isGenerating = false;

  // Download state
  final StreamController<DownloadProgress> _downloadProgressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get downloadProgress => _downloadProgressController.stream;
  
  // Device info
  String? _deviceType;
  int _deviceRAMGB = 8; // Default conservative estimate
  
  // Simplified model catalog - better distribution for all RAM levels
  static const Map<String, DeviceOptimizedModel> _availableModels = {
    // Basic models for low RAM
    'llama3.2-1b-q4_0': DeviceOptimizedModel(
      id: 'llama3.2-1b-q4_0',
      name: 'Basic 1B',
      description: 'Very fast, basic intelligence. For 4GB RAM or less.',
      quantization: 'Q4_0',
      downloadUrl: 'https://huggingface.co/unsloth/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_0.gguf',
      sizeGB: 1,
      minRAMGB: 2,
      optimizedFor: ['4GB RAM or less', 'Very old systems', 'Testing'],
      isRecommended: true,
      qualityScore: 6.5,
    ),
    
    // Universal compatibility for 8GB systems
    'llama3.2-3b-q4_0': DeviceOptimizedModel(
      id: 'llama3.2-3b-q4_0',
      name: 'Compatible 3B',
      description: 'Works on any system. Best for old Apple/PC with 8GB RAM.',
      quantization: 'Q4_0',
      downloadUrl: 'https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_0.gguf',
      sizeGB: 2,
      minRAMGB: 4,
      optimizedFor: ['8GB RAM', 'Old Apple (Intel)', 'Old Windows/PC'],
      isRecommended: true,
      qualityScore: 7.5,
    ),
    
    // Modern systems with 16GB
    'llama3.2-3b-q4_k_m': DeviceOptimizedModel(
      id: 'llama3.2-3b-q4_k_m',
      name: 'Modern 3B',
      description: 'Best quality for 16GB RAM. New Apple Silicon and modern PCs.',
      quantization: 'Q4_K_M',
      downloadUrl: 'https://huggingface.co/unsloth/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      sizeGB: 2,
      minRAMGB: 6,
      optimizedFor: ['16GB RAM', 'New Apple (M1/M2/M3/M4)', 'Modern PC'],
      isRecommended: true,
      qualityScore: 8.5,
    ),
    
    // High-end systems with 32GB+
    'llama3-8b-q4_k_m': DeviceOptimizedModel(
      id: 'llama3-8b-q4_k_m',
      name: 'Premium 8B',
      description: 'Highest intelligence. For 32GB+ RAM systems only.',
      quantization: 'Q4_K_M',
      downloadUrl: 'https://huggingface.co/QuantFactory/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct.Q4_K_M.gguf',
      sizeGB: 5,
      minRAMGB: 12,
      optimizedFor: ['32GB+ RAM', 'Apple Pro/Max/Ultra', 'High-end PC'],
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
      final modelsDir = await _getModelsDirectory();
      // Use proper path joining for Windows compatibility
      final modelPath = Platform.isWindows 
          ? path.join(modelsDir.path, '$modelId.gguf').replaceAll('/', '\\')
          : '${modelsDir.path}/$modelId.gguf';
      final modelFile = File(modelPath);
      
      debugPrint('📥 Downloading ${model.name} (${model.sizeGB}GB, ${model.quantization})...');
      
      final request = http.Request('GET', Uri.parse(model.downloadUrl));
      final response = await request.send();
      
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      
      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final startTime = DateTime.now();
      
      final sink = modelFile.openWrite();
      
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          
          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          final speed = elapsed > 0 ? (downloadedBytes / 1024 / 1024) / (elapsed / 1000) : 0.0;
          final remaining = speed > 0 ? ((totalBytes - downloadedBytes) / 1024 / 1024 / speed).round() : 0;
          
          _downloadProgressController.add(DownloadProgress(
            downloaded: downloadedBytes,
            total: totalBytes,
            speed: speed,
            remainingTime: remaining,
          ));
        },
        onDone: () async {
          await sink.close();
          _modelStatuses[modelId] = ModelStatus.downloaded;
          debugPrint('✅ Downloaded ${model.name} successfully');
          
          // Ensure status is updated before method returns
          await Future.delayed(Duration(milliseconds: 100));
        },
        onError: (error) async {
          await sink.close();
          if (await modelFile.exists()) {
            await modelFile.delete();
          }
          _modelStatuses[modelId] = ModelStatus.error;
          throw error;
        },
      ).asFuture();

    } catch (e) {
      _modelStatuses[modelId] = ModelStatus.error;
      debugPrint('❌ Failed to download ${model.name}: $e');
      rethrow;
    }
  }

  Future<void> loadModel(String modelId) async {
    debugPrint('🔄 Starting model loading for: $modelId');
    
    if (_modelStatuses[modelId] != ModelStatus.downloaded) {
      debugPrint('❌ Model not downloaded: $modelId');
      throw Exception('Model not downloaded: $modelId');
    }

    try {
      // Unload current model if any
      if (_currentModelPath != null) {
        debugPrint('🔄 Unloading current model...');
        await unloadModel();
      }

      final modelsDir = await _getModelsDirectory();
      // Use proper path joining for Windows compatibility
      final modelPath = Platform.isWindows 
          ? path.join(modelsDir.path, '$modelId.gguf').replaceAll('/', '\\')
          : '${modelsDir.path}/$modelId.gguf';
      
      debugPrint('🔄 Loading model: $modelId');
      debugPrint('📂 Model path: $modelPath');

      // ENHANCED MODEL VALIDATION - especially critical for Windows
      final modelFile = File(modelPath);
      
      // 1. Check if file exists
      if (!await modelFile.exists()) {
        debugPrint('❌ Model file not found: $modelPath');
        throw Exception('Model file not found: $modelPath');
      }
      
      // 2. Verify file size and integrity
      final fileSize = await modelFile.length();
      debugPrint('📊 Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
      
      if (fileSize < 1024 * 1024) { // Less than 1MB is definitely not a valid model
        debugPrint('❌ Model file too small (${fileSize} bytes) - likely corrupted');
        throw Exception('Model file appears corrupted (too small): ${fileSize} bytes');
      }
      
      // 3. Windows-specific validation
      if (Platform.isWindows) {
        debugPrint('🔒 Windows-specific model validation...');
        
        // Check if file is accessible and not locked
        try {
          final randomAccess = await modelFile.open(mode: FileMode.read);
          await randomAccess.close();
          debugPrint('✅ Model file is accessible');
        } catch (e) {
          debugPrint('❌ Model file access failed: $e');
          throw Exception('Model file cannot be accessed - it may be locked or corrupted');
        }
        
        // Read and validate file header (basic GGUF validation)
        try {
          final randomAccess = await modelFile.open(mode: FileMode.read);
          final headerBytes = await randomAccess.read(4);
          await randomAccess.close();
          
          // GGUF files should start with "GGUF" magic bytes
          final header = String.fromCharCodes(headerBytes);
          debugPrint('📋 Model file header: $header');
          
          if (!header.startsWith('GGUF') && !header.startsWith('GGML')) {
            debugPrint('❌ Invalid model format - header: $header');
            throw Exception('Invalid model file format - not a valid GGUF/GGML model');
          }
          
          debugPrint('✅ Model file format validation passed');
          
        } catch (e) {
          debugPrint('❌ Model header validation failed: $e');
          throw Exception('Model file validation failed: $e');
        }
        
        debugPrint('✅ Windows model validation completed');
      }

      // 4. Set model as loaded (but don't actually load into memory yet)
      _currentModelPath = modelPath;
      _currentModelId = modelId;
      _modelStatuses[modelId] = ModelStatus.loaded;
      
      // Persist the loaded model ID
      await _saveLoadedModelId(modelId);
      
      final model = _availableModels[modelId]!;
      debugPrint('✅ Successfully loaded ${model.name} (${model.quantization}) - ${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB');
      debugPrint('✅ Model ready for AI generation');
      
    } catch (e) {
      debugPrint('❌ Failed to load model $modelId: $e');
      
      _modelStatuses[modelId] = ModelStatus.error;
      _currentModelPath = null;
      _currentModelId = null;
      
      // Add more context to the error message
      String errorMessage = 'Failed to load model $modelId: ${e.toString()}';
      
      if (Platform.isWindows) {
        errorMessage += '\n\nWindows troubleshooting:';
        errorMessage += '\n- Ensure no antivirus is blocking the model file';
        errorMessage += '\n- Try running as administrator';
        errorMessage += '\n- Check if model file is corrupted (redownload if needed)';
      }
      
      throw Exception(errorMessage);
    }
  }

  int _getContextSize() {
    // Reasonable context sizes for Windows (slightly more conservative than other platforms)
    if (Platform.isWindows) {
      if (_deviceRAMGB >= 32) return 3072; // Was 1536, now reasonable for high-end Windows
      if (_deviceRAMGB >= 16) return 2048; // Was 1024, now decent for mid-range Windows  
      if (_deviceRAMGB >= 8) return 1536;  // Was 768, now usable for 8GB Windows
      return 1024;  // Was 512, now minimum viable for low-end Windows
    }
    
    // Normal sizes for other platforms
    if (_deviceRAMGB >= 32) return 4096;
    if (_deviceRAMGB >= 16) return 3072;
    if (_deviceRAMGB >= 8) return 2048;
    return 1536;  // Minimum viable context size
  }

  int _getOptimalGpuLayers() {
    // Conservative GPU layer configuration to ensure stability
    if (Platform.isIOS) {
      // iPhone/iPad - be more conservative initially
      if (_deviceRAMGB >= 16) return 25;  // Moderate GPU layers for high-end
      if (_deviceRAMGB >= 8) return 15;   // Some GPU layers for mid-range
      return 5;  // Minimal GPU for lower-end
    } else if (Platform.isAndroid) {
      // Android devices - similar conservative approach
      if (_deviceRAMGB >= 16) return 20;  // Moderate GPU layers
      if (_deviceRAMGB >= 8) return 10;   // Some GPU layers
      return 3;  // Minimal GPU
    } else if (Platform.isMacOS) {
      // Mac - can handle more GPU layers
      return _deviceRAMGB >= 16 ? 35 : 25;
    } else if (Platform.isWindows) {
      // Windows - more conservative but not completely disabled
      if (_deviceRAMGB >= 32) return 15;  // Some GPU for high-end Windows
      if (_deviceRAMGB >= 16) return 10;  // Moderate GPU for mid-range Windows
      if (_deviceRAMGB >= 8) return 5;    // Light GPU for 8GB Windows
      return 0;  // CPU-only for low-end Windows (4GB or less)
    } else if (Platform.isLinux) {
      // Linux - moderate approach
      return _deviceRAMGB >= 16 ? 15 : 10;
    }
    return 5;  // Safe fallback
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
    if (_currentModelPath != null) {
      debugPrint('🔄 Model unloaded');
    }
    
    if (_currentModelId != null && _modelStatuses[_currentModelId] == ModelStatus.loaded) {
      _modelStatuses[_currentModelId!] = ModelStatus.downloaded;
      _currentModelId = null;
      _currentModelPath = null;
      
      // Clear the persisted loaded model ID
      await _clearLoadedModelId();
    }
  }

  Future<String> generateText(String prompt, {int maxTokens = 100}) async {
    debugPrint('🚀 Starting AI generation - Windows: ${Platform.isWindows}');
    
    // WINDOWS ENHANCED SAFETY: Pre-operation checks
    if (Platform.isWindows) {
      final safetyCheck = await WindowsStabilityService.preOperationSafetyCheck(
        operation: 'generateText',
        modelPath: _currentModelPath,
        parameters: {
          'maxTokens': maxTokens,
          'promptLength': prompt.length,
          'currentModelId': _currentModelId,
          'deviceRAMGB': _deviceRAMGB,
        },
      );
      
      if (!safetyCheck) {
        debugPrint('❌ Windows safety check failed - aborting AI generation');
        throw Exception('Windows safety check failed. System may be unstable or in safe mode.');
      }
    }
    
    // Check Windows system health before proceeding
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
    
    // CRITICAL: Validate state before proceeding
    if (_currentModelPath == null) {
      debugPrint('❌ No model loaded - aborting');
      throw Exception('No model loaded');
    }
    if (_isGenerating) {
      debugPrint('❌ Generation already in progress - aborting');
      throw Exception('Generation already in progress');
    }

    // WINDOWS SAFETY: Comprehensive pre-flight validation
    if (Platform.isWindows) {
      debugPrint('🔒 Windows safety checks...');
      
      // 1. Validate model file exists and is readable
      try {
        final modelFile = File(_currentModelPath!);
        if (!await modelFile.exists()) {
          debugPrint('❌ Model file does not exist: $_currentModelPath');
          throw Exception('Model file not found - please reload the model');
        }
        
        final fileSize = await modelFile.length();
        debugPrint('📁 Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
        
        if (fileSize < 1024 * 1024) { // Less than 1MB
          debugPrint('❌ Model file too small - possibly corrupted');
          throw Exception('Model file appears corrupted - please redownload');
        }
      } catch (e) {
        debugPrint('❌ Model file validation failed: $e');
        throw Exception('Model file validation failed: $e');
      }
      
      // 2. Validate parameters are within safe ranges
      if (maxTokens > 1000) {
        debugPrint('⚠️ Reducing maxTokens from $maxTokens to 1000 for Windows safety');
        maxTokens = 1000;
      }
      
      // 3. Validate prompt length
      if (prompt.length > 10000) {
        debugPrint('⚠️ Truncating long prompt for Windows safety');
        prompt = prompt.substring(0, 10000);
      }
      
      debugPrint('✅ Windows safety checks passed');
    }

    _isGenerating = true;
    debugPrint('🔄 Setting generation flag to true');

    try {
      final messages = <Message>[];
      messages.add(Message(Role.system, 'You are a helpful AI assistant. Answer questions directly and concisely.'));
      messages.add(Message(Role.user, prompt));

      final gpuLayers = _getOptimalGpuLayers();
      final contextSize = _getContextSize();
      
      debugPrint('🖥️ GPU Layers: $gpuLayers, Context: $contextSize, RAM: ${_deviceRAMGB}GB');
      debugPrint('🎯 MaxTokens: $maxTokens, Prompt length: ${prompt.length}');
      
      // Reasonable parameters for Windows (not overly conservative)
      final temperature = Platform.isWindows ? 0.4 : 0.5; // Was 0.3, now less restrictive
      final topP = Platform.isWindows ? 0.8 : 0.8;
      
      debugPrint('⚙️ Temperature: $temperature, TopP: $topP');
      debugPrint('📂 Model path: $_currentModelPath');
      
      final request = OpenAiRequest(
        maxTokens: maxTokens,
        messages: messages,
        numGpuLayers: gpuLayers,
        modelPath: _currentModelPath!,
        temperature: temperature,        // More conservative for Windows
        topP: topP,                     
        contextSize: contextSize,
        frequencyPenalty: 0.1,         
        presencePenalty: 0.6,          
      );

      debugPrint('📝 OpenAiRequest created successfully');
      
      String fullResponse = '';
      final completer = Completer<String>();

      // ENHANCED WINDOWS PROTECTION: Multiple safety layers
      if (Platform.isWindows) {
        debugPrint('🛡️ Starting Windows-protected fllama call...');
        
        try {
          // Pre-call validation
          debugPrint('🔍 Final pre-call validation...');
          if (_currentModelPath == null || _currentModelPath!.isEmpty) {
            throw Exception('Model path became null before fllama call');
          }
          
          // CRITICAL: Wrap fllama call in additional safety with crash detection
          debugPrint('🚀 Calling fllamaChat with timeout protection...');
          
          final callStart = DateTime.now();
          
          await fllamaChat(request, (response, openaiResponseJsonString, done) {
            try {
              debugPrint('📨 fllama callback - Response length: ${response.length}, Done: $done');
              fullResponse = response;
              if (done && !completer.isCompleted) {
                debugPrint('✅ fllama generation completed successfully');
                completer.complete(fullResponse);
              }
            } catch (e) {
              debugPrint('❌ Error in fllama callback: $e');
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
          }).timeout(
            Duration(seconds: 45), // Increased from 30 for better reliability
            onTimeout: () {
              final duration = DateTime.now().difference(callStart);
              debugPrint('⏰ fllama call timed out after ${duration.inSeconds} seconds');
              
              // Record native crash with timeout details
              WindowsStabilityService.recordNativeCrash(
                operation: 'fllamaChat_timeout',
                modelPath: _currentModelPath,
                errorDetails: 'Timeout after ${duration.inSeconds} seconds',
                parameters: {
                  'maxTokens': maxTokens,
                  'promptLength': prompt.length,
                  'gpuLayers': gpuLayers,
                  'contextSize': contextSize,
                },
              );
              
              if (!completer.isCompleted) {
                completer.completeError(Exception('AI generation timeout - took longer than expected'));
              }
              throw TimeoutException('Windows AI timeout', Duration(seconds: 45));
            },
          );
          
          debugPrint('🏁 fllamaChat call completed, waiting for result...');
          
          // Wait for the completer if not already completed
          if (!completer.isCompleted) {
            debugPrint('⏳ Waiting for completer...');
            await completer.future;
          }
          
        } catch (e) {
          debugPrint('💥 Exception during fllama call: $e');
          debugPrint('🔍 Exception type: ${e.runtimeType}');
          
          // Record detailed native crash information
          await WindowsStabilityService.recordNativeCrash(
            operation: 'fllamaChat_exception',
            modelPath: _currentModelPath,
            errorDetails: e.toString(),
            parameters: {
              'maxTokens': maxTokens,
              'promptLength': prompt.length,
              'gpuLayers': gpuLayers,
              'contextSize': contextSize,
              'temperature': temperature,
              'topP': topP,
            },
          );
          
          // Handle timeout and other errors gracefully
          if (e is TimeoutException) {
            throw Exception('AI generation timed out. Try again with a shorter prompt or restart the app.');
          } else {
            throw Exception('Windows AI native call failed: ${e.toString()}. Check model compatibility.');
          }
        }
        
        if (completer.isCompleted) {
          fullResponse = await completer.future;
          debugPrint('✅ Got final response: ${fullResponse.length} characters');
        }
        
      } else {
        debugPrint('🖥️ Using standard non-Windows fllama call...');
        // Non-Windows platforms use the original simple approach
        await fllamaChat(request, (response, openaiResponseJsonString, done) {
          fullResponse = response;
          if (done && !completer.isCompleted) {
            completer.complete(fullResponse);
          }
        });
        
        if (!completer.isCompleted) {
          await completer.future;
        }
        fullResponse = completer.isCompleted ? await completer.future : fullResponse;
      }

      // Mark successful operation for Windows stability tracking
      if (Platform.isWindows) {
        await WindowsStabilityService.markSuccessfulOperation();
        debugPrint('✅ Marked successful Windows operation');
      }
      
      // Ensure we have a valid response
      if (fullResponse.trim().isEmpty) {
        debugPrint('❌ AI returned empty response');
        throw Exception('AI returned empty response. Try rephrasing your question.');
      }
      
      debugPrint('🎉 AI generation completed successfully: ${fullResponse.length} characters');
      return fullResponse;
      
    } catch (e) {
      debugPrint('💥 Generation failed with exception: $e');
      debugPrint('🔍 Exception type: ${e.runtimeType}');
      debugPrint('📍 Stack trace: ${StackTrace.current}');
      
      // Record crash for Windows stability tracking
      if (Platform.isWindows) {
        await WindowsStabilityService.recordCrash();
        debugPrint('📊 Recorded Windows crash in stability service');
        
        // Also record as native crash if it seems to be from fllama
        if (e.toString().contains('fllama') || e.toString().contains('model') || 
            e.toString().contains('generation') || e.toString().contains('native')) {
          await WindowsStabilityService.recordNativeCrash(
            operation: 'generateText_general_failure',
            modelPath: _currentModelPath,
            errorDetails: e.toString(),
            parameters: {
              'maxTokens': maxTokens,
              'promptLength': prompt.length,
              'currentModelId': _currentModelId,
            },
          );
        }
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
      debugPrint('🔄 Cleared generation flag');
    }
  }

  Future<void> deleteModel(String modelId) async {
    try {
      if (_currentModelId == modelId && _currentModelPath != null) {
      await unloadModel();
    }

    final modelsDir = await _getModelsDirectory();
      // Use proper path joining for Windows compatibility
      final modelPath = Platform.isWindows 
          ? path.join(modelsDir.path, '$modelId.gguf').replaceAll('/', '\\')
          : '${modelsDir.path}/$modelId.gguf';
      final modelFile = File(modelPath);

    if (await modelFile.exists()) {
      await modelFile.delete();
        debugPrint('🗑️ Deleted model: $modelId');
    }

    _modelStatuses[modelId] = ModelStatus.notDownloaded;
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

  /// DEBUGGING: Test AI system safely with minimal risk
  Future<void> debugTestAISystem() async {
    debugPrint('🧪 DEBUGGING AI SYSTEM TEST');
    
    try {
      // 1. Print system status
      await WindowsStabilityService.printDiagnostics();
      
      // 2. Check model status
      debugPrint('📊 Model Status:');
      debugPrint('   Current model: $_currentModelId');
      debugPrint('   Model path: $_currentModelPath');
      debugPrint('   Is generating: $_isGenerating');
      debugPrint('   Is model loaded: $isModelLoaded');
      
      // 3. Check model file if available
      if (_currentModelPath != null) {
        final modelFile = File(_currentModelPath!);
        if (await modelFile.exists()) {
          final fileSize = await modelFile.length();
          debugPrint('   Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB');
        } else {
          debugPrint('   ❌ Model file not found!');
        }
      }
      
      // 4. System capabilities
      debugPrint('🖥️ System Info:');
      debugPrint('   Platform: ${Platform.operatingSystem}');
      debugPrint('   Device RAM: ${_deviceRAMGB}GB');
      debugPrint('   GPU Layers: ${_getOptimalGpuLayers()}');
      debugPrint('   Context Size: ${_getContextSize()}');
      
      // 5. Windows-specific checks
      if (Platform.isWindows) {
        debugPrint('🪟 Windows Checks:');
        final healthy = await WindowsStabilityService.isSystemHealthy();
        debugPrint('   System healthy: $healthy');
        
        final safeMode = await WindowsStabilityService.shouldRunInSafeMode();
        debugPrint('   Safe mode: $safeMode');
        
        if (_currentModelPath != null) {
          final safetyCheck = await WindowsStabilityService.preOperationSafetyCheck(
            operation: 'debug_test',
            modelPath: _currentModelPath,
          );
          debugPrint('   Safety check: $safetyCheck');
        }
      }
      
      // 6. Test with minimal parameters if model is loaded
      if (isModelLoaded && Platform.isWindows) {
        debugPrint('🧪 Attempting safe test generation...');
        try {
          final testResponse = await generateText(
            'Hi', 
            maxTokens: 10,  // Very small test
          );
          debugPrint('✅ Test generation successful: "${testResponse.substring(0, min(50, testResponse.length))}..."');
        } catch (e) {
          debugPrint('❌ Test generation failed: $e');
        }
      }
      
      debugPrint('🏁 AI system debug test completed');
      
    } catch (e) {
      debugPrint('💥 Debug test failed: $e');
    }
  }
} 