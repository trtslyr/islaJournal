import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:path/path.dart' as path;

enum AIModelSize {
  small, // 1B model (~800MB)
  medium, // 3B model (~2GB)
  large, // 8B model (~4.5GB)
}

enum ModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  loaded,
  error,
}

class AIModelInfo {
  final String id;
  final String name;
  final AIModelSize size;
  final String downloadUrl;
  final int fileSizeBytes;
  final String expectedHash;
  final String fileName;

  AIModelInfo({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadUrl,
    required this.fileSizeBytes,
    required this.expectedHash,
    required this.fileName,
  });
}

class DownloadProgress {
  final int downloaded;
  final int total;
  final double percentage;
  final String status;
  final double speedBytesPerSecond;
  final Duration? estimatedTimeRemaining;
  final DateTime timestamp;

  DownloadProgress({
    required this.downloaded,
    required this.total,
    required this.percentage,
    required this.status,
    this.speedBytesPerSecond = 0.0,
    this.estimatedTimeRemaining,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedSpeed {
    if (speedBytesPerSecond < 1024) {
      return '${speedBytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get formattedETA {
    if (estimatedTimeRemaining == null) return 'calculating...';
    
    final totalSeconds = estimatedTimeRemaining!.inSeconds;
    if (totalSeconds < 60) {
      return '${totalSeconds}s left';
    } else if (totalSeconds < 3600) {
      final minutes = (totalSeconds / 60).floor();
      return '${minutes}m left';
    } else {
      final hours = (totalSeconds / 3600).floor();
      final minutes = ((totalSeconds % 3600) / 60).floor();
      return '${hours}h ${minutes}m left';
    }
  }
}

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // Available models
  static final Map<String, AIModelInfo> _availableModels = {
    'test-model': AIModelInfo(
      id: 'test-model',
      name: 'Test Model (Small)',
      size: AIModelSize.small,
      downloadUrl: 'https://huggingface.co/microsoft/DialoGPT-medium/resolve/main/pytorch_model.bin',
      fileSizeBytes: 50 * 1024 * 1024, // ~50MB for testing
      expectedHash: '', // Will be set when we verify
      fileName: 'test-model.bin',
    ),
    'llama-3.2-1b': AIModelInfo(
      id: 'llama-3.2-1b',
      name: 'Llama 3.2 1B',
      size: AIModelSize.small,
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      fileSizeBytes: 800 * 1024 * 1024, // ~800MB
      expectedHash: '', // Will be set when we verify
      fileName: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    ),
    'llama-3.2-3b': AIModelInfo(
      id: 'llama-3.2-3b',
      name: 'Llama 3.2 3B',
      size: AIModelSize.medium,
      downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      fileSizeBytes: 2 * 1024 * 1024 * 1024, // ~2GB
      expectedHash: '', // Will be set when we verify
      fileName: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    ),
  };

  // State management
  final Map<String, ModelStatus> _modelStatuses = {};
  final StreamController<DownloadProgress> _downloadProgressController = StreamController.broadcast();
  final StreamController<String> _aiResponseController = StreamController.broadcast();
  
  String? _currentModelId;
  String? _currentModelPath;
  bool _isInitialized = false;
  CancelToken? _downloadCancelToken;

  // Getters
  Stream<DownloadProgress> get downloadProgress => _downloadProgressController.stream;
  Stream<String> get aiResponse => _aiResponseController.stream;
  Map<String, AIModelInfo> get availableModels => _availableModels;
  Map<String, ModelStatus> get modelStatuses => _modelStatuses;
  String? get currentModelId => _currentModelId;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check which models are already downloaded
      await _checkExistingModels();
      _isInitialized = true;
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing AI service: $e');
      throw Exception('Failed to initialize AI service: $e');
    }
  }

  Future<void> _checkExistingModels() async {
    final modelsDir = await _getModelsDirectory();
    
    for (final modelInfo in _availableModels.values) {
      final modelFile = File('${modelsDir.path}/${modelInfo.fileName}');
      
      if (await modelFile.exists()) {
        // Verify file integrity if hash is available
        if (modelInfo.expectedHash.isNotEmpty) {
          final isValid = await _verifyFileHash(modelFile, modelInfo.expectedHash);
          _modelStatuses[modelInfo.id] = isValid ? ModelStatus.downloaded : ModelStatus.error;
        } else {
          _modelStatuses[modelInfo.id] = ModelStatus.downloaded;
        }
      } else {
        _modelStatuses[modelInfo.id] = ModelStatus.notDownloaded;
      }
    }
  }

  Future<Directory> _getModelsDirectory() async {
    late Directory baseDir;
    
    // Use platform-appropriate directory
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms - use application documents directory
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop platforms - use application support directory for better organization
      try {
        baseDir = await getApplicationSupportDirectory();
      } catch (e) {
        // Fallback to documents directory if application support is not available
        baseDir = await getApplicationDocumentsDirectory();
      }
    } else {
      // Fallback for any other platforms
      baseDir = await getApplicationDocumentsDirectory();
    }
    
    // Create platform-appropriate models directory path
    final modelsDir = Directory(path.join(baseDir.path, 'isla_journal_models'));
    
    if (!await modelsDir.exists()) {
      try {
        await modelsDir.create(recursive: true);
      } catch (e) {
        // ignore: avoid_print
        print('Error creating models directory: $e');
        throw Exception('Failed to create models directory: $e');
      }
    }
    
    return modelsDir;
  }

  Future<bool> _verifyFileHash(File file, String expectedHash) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString() == expectedHash;
    } catch (e) {
      // ignore: avoid_print
      print('Error verifying file hash: $e');
      return false;
    }
  }

  Future<void> downloadModel(String modelId, {bool resumeIfPossible = true}) async {
    final modelInfo = _availableModels[modelId];
    if (modelInfo == null) {
      throw Exception('Model not found: $modelId');
    }

    if (_modelStatuses[modelId] == ModelStatus.downloading) {
      throw Exception('Model is already being downloaded');
    }

    _modelStatuses[modelId] = ModelStatus.downloading;
    _downloadCancelToken = CancelToken();

    // Immediately notify UI that download is starting
    _downloadProgressController.add(DownloadProgress(
      downloaded: 0,
      total: modelInfo.fileSizeBytes,
      percentage: 0.0,
      status: 'Preparing download...',
      speedBytesPerSecond: 0.0,
    ));

    // Download speed tracking
    DateTime? lastProgressTime;
    DateTime? lastUpdateTime; // For throttling UI updates
    int lastProgressBytes = 0;
    final List<double> speedSamples = [];
    const maxSpeedSamples = 10; // Keep last 10 speed samples for smoothing
    const updateInterval = Duration(milliseconds: 500); // Update UI every 500ms max

    try {
      final modelsDir = await _getModelsDirectory();
      final modelFile = File('${modelsDir.path}/${modelInfo.fileName}');
      final tempFile = File('${modelFile.path}.tmp');

      int downloadedBytes = 0;
      
      // Check if we can resume
      if (resumeIfPossible && await tempFile.exists()) {
        downloadedBytes = await tempFile.length();
        lastProgressBytes = downloadedBytes;
      }

      final dio = Dio();
      
      // Configure Dio with better timeout and retry settings
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);
      dio.options.sendTimeout = const Duration(seconds: 30);
      
      // Add debug logging
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) {
          // ignore: avoid_print
          print('[DIO] $obj');
        },
      ));
      
      _downloadProgressController.add(DownloadProgress(
        downloaded: downloadedBytes,
        total: modelInfo.fileSizeBytes,
        percentage: (downloadedBytes / modelInfo.fileSizeBytes) * 100,
        status: 'Testing connection...',
      ));
      
      // Test connectivity first
      try {
        final response = await dio.head(modelInfo.downloadUrl);
        // ignore: avoid_print
        print('Connection test successful: ${response.statusCode}');
      } catch (e) {
        // ignore: avoid_print
        print('Connection test failed: $e');
        throw Exception('Cannot connect to download server. Please check your internet connection.');
      }
      
      _downloadProgressController.add(DownloadProgress(
        downloaded: downloadedBytes,
        total: modelInfo.fileSizeBytes,
        percentage: (downloadedBytes / modelInfo.fileSizeBytes) * 100,
        status: 'Starting download...',
      ));
      
      await dio.download(
        modelInfo.downloadUrl,
        tempFile.path,
        cancelToken: _downloadCancelToken,
        options: Options(
          headers: downloadedBytes > 0 ? {'Range': 'bytes=$downloadedBytes-'} : null,
          followRedirects: true,
          maxRedirects: 5,
        ),
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final totalBytes = total != -1 ? total : modelInfo.fileSizeBytes;
          final currentReceived = downloadedBytes + received;
          final percentage = (currentReceived / totalBytes) * 100;
          
          // Throttle UI updates to prevent flashing
          if (lastUpdateTime != null && 
              now.difference(lastUpdateTime!).inMilliseconds < updateInterval.inMilliseconds &&
              percentage < 100) {
            return; // Skip this update to prevent spamming the UI
          }
          
          double currentSpeed = 0.0;
          Duration? eta;
          
          // Calculate speed if we have previous timing data
          if (lastProgressTime != null) {
            final timeDiff = now.difference(lastProgressTime!);
            final bytesDiff = currentReceived - lastProgressBytes;
            
            if (timeDiff.inMilliseconds > 0) {
              // Calculate current speed in bytes per second
              currentSpeed = bytesDiff / (timeDiff.inMilliseconds / 1000.0);
              
              // Add to speed samples for smoothing
              speedSamples.add(currentSpeed);
              if (speedSamples.length > maxSpeedSamples) {
                speedSamples.removeAt(0);
              }
              
              // Use average speed for more stable calculations
              final avgSpeed = speedSamples.reduce((a, b) => a + b) / speedSamples.length;
              
              // Calculate ETA based on average speed
              if (avgSpeed > 0) {
                final remainingBytes = totalBytes - currentReceived;
                final etaSeconds = remainingBytes / avgSpeed;
                eta = Duration(seconds: etaSeconds.round());
              }
              
              currentSpeed = avgSpeed; // Use smoothed speed
            }
          }
          
          lastProgressTime = now;
          lastUpdateTime = now;
          lastProgressBytes = currentReceived;
          
          _downloadProgressController.add(DownloadProgress(
            downloaded: currentReceived,
            total: totalBytes,
            percentage: percentage,
            status: 'Downloading ${modelInfo.name}... ${percentage.toStringAsFixed(1)}%',
            speedBytesPerSecond: currentSpeed,
            estimatedTimeRemaining: eta,
          ));
        },
      );

      // Move temp file to final location
      await tempFile.rename(modelFile.path);
      
      _modelStatuses[modelId] = ModelStatus.downloaded;
      _downloadProgressController.add(DownloadProgress(
        downloaded: modelInfo.fileSizeBytes,
        total: modelInfo.fileSizeBytes,
        percentage: 100.0,
        status: 'Download completed successfully!',
        speedBytesPerSecond: 0.0,
      ));

    } catch (e) {
      _modelStatuses[modelId] = ModelStatus.error;
      
      String errorMessage = 'Download failed';
      
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.cancel:
            errorMessage = 'Download cancelled';
            break;
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.receiveTimeout:
          case DioExceptionType.sendTimeout:
            errorMessage = 'Connection timeout. Please check your internet connection and try again.';
            break;
          case DioExceptionType.connectionError:
            errorMessage = 'Connection failed. Please check your internet connection and firewall settings.';
            break;
          case DioExceptionType.badResponse:
            errorMessage = 'Server error (${e.response?.statusCode}). The download server may be temporarily unavailable.';
            break;
          default:
            errorMessage = 'Network error: ${e.message}';
        }
      } else {
        errorMessage = 'Unexpected error: $e';
      }
      
      _downloadProgressController.add(DownloadProgress(
        downloaded: 0,
        total: modelInfo.fileSizeBytes,
        percentage: 0.0,
        status: errorMessage,
        speedBytesPerSecond: 0.0,
      ));
      
      throw Exception(errorMessage);
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel();
  }

  Future<void> loadModel(String modelId) async {
    final modelInfo = _availableModels[modelId];
    if (modelInfo == null) {
      throw Exception('Model not found: $modelId');
    }

    if (_modelStatuses[modelId] != ModelStatus.downloaded) {
      throw Exception('Model must be downloaded first');
    }

    try {
      final modelsDir = await _getModelsDirectory();
      final modelPath = '${modelsDir.path}/${modelInfo.fileName}';
      
      // Unload current model if any
      if (_currentModelId != null) {
        await unloadModel();
      }

      _currentModelPath = modelPath;
      _currentModelId = modelId;
      _modelStatuses[modelId] = ModelStatus.loaded;
      
    } catch (e) {
      _modelStatuses[modelId] = ModelStatus.error;
      throw Exception('Failed to load model: $e');
    }
  }

  Future<void> unloadModel() async {
    if (_currentModelId != null) {
      _modelStatuses[_currentModelId!] = ModelStatus.downloaded;
      _currentModelId = null;
      _currentModelPath = null;
    }
  }

  Future<String> generateText(String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    String? systemPrompt,
  }) async {
    if (_currentModelPath == null) {
      throw Exception('No model loaded');
    }

    try {
      final messages = <Message>[];
      
      // Add a default system prompt if none provided
      final defaultSystemPrompt = systemPrompt ?? '''You are a close friend who knows this person well. Respond naturally and directly, like you would in any normal conversation. Be warm, authentic, and helpful.''';
      
      messages.add(Message(Role.system, defaultSystemPrompt));
      messages.add(Message(Role.user, prompt));

      final request = OpenAiRequest(
        maxTokens: maxTokens,
        messages: messages,
        numGpuLayers: 99, // Auto-detect GPU support
        modelPath: _currentModelPath!,
        temperature: temperature,
        topP: topP,
        contextSize: _getContextSize(_currentModelId),
        frequencyPenalty: 0.0,
        presencePenalty: 1.1,
        logger: (log) {
          // ignore: avoid_print
          print('[AI] $log');
        },
      );

      String fullResponse = '';
      final completer = Completer<String>();

      await fllamaChat(request, (response, openaiResponseJsonString, done) {
        // Handle case where fllama doesn't extract response text properly
        if (response.isEmpty && openaiResponseJsonString != null && openaiResponseJsonString.isNotEmpty) {
          // Extract content from JSON response as fallback
          try {
            final jsonMatch = RegExp(r'"content":"([^"]*)"').firstMatch(openaiResponseJsonString);
            if (jsonMatch != null) {
              String extractedContent = jsonMatch.group(1) ?? '';
              // Decode common escape sequences
              extractedContent = extractedContent
                  .replaceAll('\\n', '\n')
                  .replaceAll('\\t', '\t')
                  .replaceAll('\\"', '"')
                  .replaceAll('\\\\', '\\');
              
              fullResponse = extractedContent;
              _aiResponseController.add(extractedContent);
            } else {
              fullResponse = response; // Use empty response as fallback
              _aiResponseController.add(response);
            }
          } catch (e) {
            fullResponse = response;
            _aiResponseController.add(response);
          }
        } else {
        fullResponse = response;
        _aiResponseController.add(response);
        }
        
        if (done) {
          completer.complete(fullResponse);
        }
      });

      return await completer.future;
    } catch (e) {
      throw Exception('Failed to generate text: $e');
    }
  }

  /// Generate text response with natural completion (no artificial limits)
  Future<String> generateTextNaturally(
    String prompt, {
    int? safetyLimit, // Made optional - null means no limit
    double temperature = 0.7,
    double topP = 0.9,
    String? systemPrompt,
  }) async {
    if (_currentModelPath == null) {
      throw Exception('No model loaded');
    }

    try {
      final messages = <Message>[];
      
      // Add system prompt emphasizing natural completion
      final defaultSystemPrompt = systemPrompt ?? '''You are a helpful friend who has read someone's journal. 
Respond naturally and directly to their questions. 
Answer completely but concisely - say what needs to be said, then stop naturally.
Never mention that you are an AI or language model.''';
      
      messages.add(Message(Role.system, defaultSystemPrompt));
      messages.add(Message(Role.user, prompt));

      final request = OpenAiRequest(
        maxTokens: 512, // REDUCED - Concise but complete responses
        messages: messages,
        numGpuLayers: 99, // Auto-detect GPU support
        modelPath: _currentModelPath!,
        temperature: temperature,
        topP: topP,
        contextSize: _getContextSize(_currentModelId),
        frequencyPenalty: 0.0,
        presencePenalty: 1.1,
        logger: (log) {
          // ignore: avoid_print
          print('[AI] $log');
        },
      );

      String fullResponse = '';
      final completer = Completer<String>();
      bool shouldStop = false;

      await fllamaChat(request, (response, openaiResponseJsonString, done) {
        if (shouldStop) return; // Don't process more if we've decided to stop
        
        String currentResponse = response;
        
        // Handle case where fllama doesn't extract response text properly
        if (response.isEmpty && openaiResponseJsonString != null && openaiResponseJsonString.isNotEmpty) {
          // Extract content from JSON response as fallback
          try {
            print('[AI] DEBUG: Attempting to parse JSON response of length ${openaiResponseJsonString.length}');
            
            // Try parsing as proper JSON first
            final jsonData = jsonDecode(openaiResponseJsonString);
            if (jsonData is Map<String, dynamic>) {
              // Handle OpenAI format: {"choices": [{"message": {"content": "..."}}]}
              if (jsonData['choices'] != null && jsonData['choices'] is List && jsonData['choices'].isNotEmpty) {
                final choice = jsonData['choices'][0];
                if (choice['message'] != null && choice['message']['content'] != null) {
                  currentResponse = choice['message']['content'].toString();
                  print('[AI] DEBUG: Extracted response from choices.message.content: ${currentResponse.length} chars');
                }
              }
              // Handle direct content format: {"content": "..."}
              else if (jsonData['content'] != null) {
                currentResponse = jsonData['content'].toString();
                print('[AI] DEBUG: Extracted response from direct content: ${currentResponse.length} chars');
              }
            }
            
            // Fallback to regex if JSON parsing didn't work
            if (currentResponse.isEmpty) {
              print('[AI] DEBUG: JSON parsing failed, trying regex fallback');
              // Try multiple regex patterns
              var patterns = [
                r'"content":"([^"]*)"',
                r'"content":\s*"([^"]*)"',
                r'content["\s]*:["\s]*([^"]*)',
              ];
              
              for (var pattern in patterns) {
                final jsonMatch = RegExp(pattern, multiLine: true, dotAll: true).firstMatch(openaiResponseJsonString);
                if (jsonMatch != null && jsonMatch.group(1) != null) {
                  currentResponse = jsonMatch.group(1)!;
                  print('[AI] DEBUG: Regex pattern "$pattern" extracted: ${currentResponse.length} chars');
                  break;
                }
              }
            }
            
            // Decode common escape sequences
            if (currentResponse.isNotEmpty) {
              currentResponse = currentResponse
                  .replaceAll('\\n', '\n')
                  .replaceAll('\\t', '\t')
                  .replaceAll('\\"', '"')
                  .replaceAll('\\\\', '\\');
              print('[AI] DEBUG: Final response after decoding: ${currentResponse.length} chars');
            } else {
              print('[AI] DEBUG: Failed to extract any content from JSON response');
              print('[AI] DEBUG: JSON sample: ${openaiResponseJsonString.length > 200 ? openaiResponseJsonString.substring(0, 200) + "..." : openaiResponseJsonString}');
            }
          } catch (e) {
            print('[AI] DEBUG: JSON parsing error: $e');
            // Use empty response as fallback
          }
        }
        
        fullResponse = currentResponse;
        _aiResponseController.add(currentResponse);
        
        // Only check safety limit if one is provided
        if (safetyLimit != null && currentResponse.length >= safetyLimit) {
          // Safety stop - prevent runaway generation
          shouldStop = true;
          completer.complete(_stopAtSentenceBoundary(currentResponse, safetyLimit));
          return;
        }
        
        // Let AI complete naturally - no artificial early stopping
        if (done && !shouldStop) {
          completer.complete(fullResponse);
        }
      });

      return await completer.future;
    } catch (e) {
      throw Exception('Failed to generate text: $e');
    }
  }

  /// Generate text response with character-based smart stopping
  Future<String> generateTextWithCharLimit(
    String prompt, {
    required int targetCharLimit,
    required int maxCharLimit,
    double temperature = 0.7,
    double topP = 0.9,
    String? systemPrompt,
  }) async {
    if (_currentModelPath == null) {
      throw Exception('No model loaded');
    }

    try {
      final messages = <Message>[];
      
      // Add a default system prompt if none provided
      final defaultSystemPrompt = systemPrompt ?? '''You are a close friend who knows this person well. Respond naturally and directly, like you would in any normal conversation. Be warm, authentic, and helpful.''';
      
      messages.add(Message(Role.system, defaultSystemPrompt));
      messages.add(Message(Role.user, prompt));

      final request = OpenAiRequest(
        maxTokens: 512, // REDUCED - Consistent with other methods
        messages: messages,
        numGpuLayers: 99, // Auto-detect GPU support
        modelPath: _currentModelPath!,
        temperature: temperature,
        topP: topP,
        contextSize: _getContextSize(_currentModelId),
        frequencyPenalty: 0.0,
        presencePenalty: 1.1,
        logger: (log) {
          // ignore: avoid_print
          print('[AI] $log');
        },
      );

      String fullResponse = '';
      final completer = Completer<String>();
      bool shouldStop = false;

      await fllamaChat(request, (response, openaiResponseJsonString, done) {
        if (shouldStop) return; // Don't process more if we've decided to stop
        
        String currentResponse = response;
        
        // Handle case where fllama doesn't extract response text properly
        if (response.isEmpty && openaiResponseJsonString != null && openaiResponseJsonString.isNotEmpty) {
          // Extract content from JSON response as fallback
          try {
            final jsonMatch = RegExp(r'"content":"([^"]*)"').firstMatch(openaiResponseJsonString);
            if (jsonMatch != null) {
              currentResponse = jsonMatch.group(1) ?? '';
              // Decode common escape sequences
              currentResponse = currentResponse
                  .replaceAll('\\n', '\n')
                  .replaceAll('\\t', '\t')
                  .replaceAll('\\"', '"')
                  .replaceAll('\\\\', '\\');
            }
          } catch (e) {
            // Use empty response as fallback
          }
        }
        
        fullResponse = currentResponse;
        _aiResponseController.add(currentResponse);
        
        // Check if we should stop based on character count
        if (currentResponse.length >= maxCharLimit) {
          // Hard stop - exceeded max limit
          shouldStop = true;
          completer.complete(_stopAtSentenceBoundary(currentResponse, maxCharLimit));
          return;
        } else if (currentResponse.length >= targetCharLimit && _endsWithCompleteSentence(currentResponse)) {
          // Soft stop - reached target and found good stopping point
          shouldStop = true;
          completer.complete(currentResponse);
          return;
        }
        
        if (done && !shouldStop) {
          completer.complete(fullResponse);
        }
      });

      return await completer.future;
    } catch (e) {
      throw Exception('Failed to generate text: $e');
    }
  }

  /// Check if text ends with a complete sentence
  bool _endsWithCompleteSentence(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    
    // Check for sentence-ending punctuation
    return trimmed.endsWith('.') || 
           trimmed.endsWith('!') || 
           trimmed.endsWith('?') ||
           trimmed.endsWith('."') ||
           trimmed.endsWith('!"') ||
           trimmed.endsWith('?"');
  }

  /// Stop response at the last complete sentence within the character limit
  String _stopAtSentenceBoundary(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    
    // Find the last sentence boundary before the limit
    final truncated = text.substring(0, maxChars);
    final sentences = truncated.split(RegExp(r'[.!?](?=\s|$)'));
    
    if (sentences.length > 1) {
      // Remove the last incomplete sentence and reconstruct
      sentences.removeLast();
      final result = sentences.join('.') + '.';
      return result;
    }
    
    // Fallback: just truncate at word boundary
    final words = truncated.split(' ');
    words.removeLast();
    return words.join(' ') + '...';
  }

  // Get appropriate context size based on model
  int _getContextSize(String? modelId) {
    // Model-specific context limits (conservative to leave room for response)
    switch (modelId) {
      case 'llama-3.2-1b':
        return 100000; // 100K tokens
      case 'llama-3.2-3b':
        return 120000; // 120K tokens
      case 'llama-3.1-8b':
        return 120000; // 120K tokens
      default:
        return 100000; // Default safe limit
    }
  }

  // AI Feature Methods
  Future<String> analyzeWritingStyle(String text) async {
    const systemPrompt = '''
You are a writing style analyzer. Analyze the given text and provide brief insights about:
1. Writing tone (formal, casual, emotional, etc.)
2. Complexity level
3. Main themes or topics
4. Suggestions for improvement

Keep your response concise and helpful.
''';

    return await generateText(
      text,
      systemPrompt: systemPrompt,
      maxTokens: 200,
      temperature: 0.3,
    );
  }

  Future<String> analyzeMood(String text) async {
    const systemPrompt = '''
You are a mood analyzer. Analyze the emotional tone of the given text and respond with:
1. Primary mood (happy, sad, anxious, calm, excited, etc.)
2. Emotional intensity (low, medium, high)
3. Brief explanation

Keep your response very brief and focused.
''';

    return await generateText(
      text,
      systemPrompt: systemPrompt,
      maxTokens: 100,
      temperature: 0.2,
    );
  }

  Future<String> suggestContinuation(String text) async {
    const systemPrompt = '''
You are a writing assistant. Given the text, suggest a natural continuation or completion.
Focus on maintaining the same tone and style. Keep suggestions brief and relevant.
''';

    return await generateText(
      text,
      systemPrompt: systemPrompt,
      maxTokens: 150,
      temperature: 0.8,
    );
  }

  Future<List<String>> generateWritingPrompts(String context) async {
    const systemPrompt = '''
You are a creative writing prompt generator. Based on the context provided, generate 3-5 short, engaging writing prompts.
Each prompt should be on a new line and be thought-provoking.
''';

    final response = await generateText(
      context,
      systemPrompt: systemPrompt,
      maxTokens: 200,
      temperature: 0.9,
    );

    return response.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  /// Generate a concise summary of journal content for token-efficient context
  Future<String> generateSummary(String content) async {
    if (content.trim().isEmpty) return '';
    
    const systemPrompt = '''You are a journal summarizer. Create a 2-3 sentence summary of this journal entry.
Focus on:
- Key events and activities
- Important emotions or insights
- Main themes or topics

Keep it concise but capture the essence. Do not mention that this is a journal or diary.''';

    return await generateText(
      content,
      systemPrompt: systemPrompt,
      maxTokens: 80,  // Keep summaries very concise
      temperature: 0.3,
    );
  }

  /// Extract keywords from journal content for efficient semantic retrieval
  Future<String> generateKeywords(String content) async {
    if (content.trim().isEmpty) return '';
    
    const systemPrompt = '''You are a keyword extractor. Extract 5-10 important keywords or short phrases from this text.
Focus on:
- People, places, activities
- Emotions and themes
- Important concepts or topics

Return as a comma-separated list. No explanations, just the keywords.''';

    return await generateText(
      content,
      systemPrompt: systemPrompt,
      maxTokens: 50,  // Very short for keywords
      temperature: 0.2,
    );
  }

  Future<int> getStorageUsage() async {
    final modelsDir = await _getModelsDirectory();
    int totalSize = 0;
    
    if (await modelsDir.exists()) {
      await for (final entity in modelsDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }

  Future<void> deleteModel(String modelId) async {
    final modelInfo = _availableModels[modelId];
    if (modelInfo == null) return;

    // Unload if currently loaded
    if (_currentModelId == modelId) {
      await unloadModel();
    }

    final modelsDir = await _getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${modelInfo.fileName}');
    final tempFile = File('${modelFile.path}.tmp');

    if (await modelFile.exists()) {
      await modelFile.delete();
    }
    
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    _modelStatuses[modelId] = ModelStatus.notDownloaded;
  }

  // Helper method to get manual download instructions
  String getManualDownloadInstructions(String modelId) {
    final modelInfo = _availableModels[modelId];
    if (modelInfo == null) return 'Model not found';
    
    return '''
Manual Download Instructions for ${modelInfo.name}:

1. Download the model file from: ${modelInfo.downloadUrl}
2. Save it as: ${modelInfo.fileName}
3. Place it in your models directory

The app will automatically detect the model once it's in the correct location.

Model Details:
- Size: ${_formatBytes(modelInfo.fileSizeBytes)}
- File: ${modelInfo.fileName}
- Type: ${modelInfo.size == AIModelSize.small ? 'Fast, good for basic features' : 'Balanced performance and quality'}
''';
  }

  // Helper method to import a manually downloaded model
  Future<bool> importManualModel(String modelId, String filePath) async {
    final modelInfo = _availableModels[modelId];
    if (modelInfo == null) return false;
    
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) return false;
      
      final modelsDir = await _getModelsDirectory();
      final targetFile = File('${modelsDir.path}/${modelInfo.fileName}');
      
      // Copy the file to the models directory
      await sourceFile.copy(targetFile.path);
      
      // Update status
      _modelStatuses[modelId] = ModelStatus.downloaded;
      
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error importing model: $e');
      return false;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void dispose() {
    _downloadProgressController.close();
    _aiResponseController.close();
    _downloadCancelToken?.cancel();
  }
} 