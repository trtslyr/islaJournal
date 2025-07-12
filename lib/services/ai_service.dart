import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _baseUrl = 'http://localhost:11434';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  // Model configurations based on tech stack plan
  static const Map<String, String> _modelConfigs = {
    'desktop': 'llama3.1:8b',
    'mobile': 'llama3.2:3b',
    'quantized': 'llama3.2:3b-q4_0',
  };

  String? _currentModel;
  bool _isModelLoaded = false;
  bool _isOllamaRunning = false;

  // Getters
  bool get isModelLoaded => _isModelLoaded;
  bool get isOllamaRunning => _isOllamaRunning;
  String? get currentModel => _currentModel;

  /// Initialize the AI service and check if Ollama is running
  Future<bool> initialize() async {
    try {
      await _checkOllamaStatus();
      if (_isOllamaRunning) {
        await _selectOptimalModel();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AI Service initialization failed: $e');
      return false;
    }
  }

  /// Check if Ollama is running
  Future<void> _checkOllamaStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      _isOllamaRunning = response.statusCode == 200;
    } catch (e) {
      _isOllamaRunning = false;
      debugPrint('Ollama not running: $e');
    }
  }

  /// Select the optimal model based on device capabilities
  Future<void> _selectOptimalModel() async {
    try {
      // Check available models
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List;
        
        // Select model based on device type and available models
        String preferredModel = _getPreferredModel();
        
        for (var model in models) {
          if (model['name'].toString().contains(preferredModel)) {
            _currentModel = model['name'];
            _isModelLoaded = true;
            await _secureStorage.write(key: 'current_model', value: _currentModel);
            break;
          }
        }
        
        // If preferred model not found, use the first available Llama model
        if (!_isModelLoaded && models.isNotEmpty) {
          for (var model in models) {
            if (model['name'].toString().toLowerCase().contains('llama')) {
              _currentModel = model['name'];
              _isModelLoaded = true;
              await _secureStorage.write(key: 'current_model', value: _currentModel);
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error selecting model: $e');
    }
  }

  /// Get preferred model based on device capabilities
  String _getPreferredModel() {
    // Simple heuristic: mobile devices use smaller models
    if (Platform.isAndroid || Platform.isIOS) {
      return _modelConfigs['mobile']!;
    }
    return _modelConfigs['desktop']!;
  }

  /// Generate text using the loaded model
  Future<String> generateText(String prompt, {
    Map<String, dynamic>? options,
    Function(String)? onStreamChunk,
  }) async {
    if (!_isModelLoaded || _currentModel == null) {
      throw Exception('No model loaded. Please initialize the AI service first.');
    }

    try {
      final requestBody = {
        'model': _currentModel,
        'prompt': prompt,
        'stream': onStreamChunk != null,
        'options': options ?? {
          'temperature': 0.7,
          'max_tokens': 2000,
          'top_p': 0.9,
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (onStreamChunk != null) {
          // Handle streaming response
          final lines = response.body.split('\n');
          String fullResponse = '';
          
          for (String line in lines) {
            if (line.isNotEmpty) {
              try {
                final chunk = jsonDecode(line);
                if (chunk['response'] != null) {
                  final text = chunk['response'] as String;
                  fullResponse += text;
                  onStreamChunk(text);
                }
              } catch (e) {
                debugPrint('Error parsing chunk: $e');
              }
            }
          }
          return fullResponse;
        } else {
          // Handle non-streaming response
          final data = jsonDecode(response.body);
          return data['response'] as String? ?? '';
        }
      } else {
        throw Exception('AI generation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error generating text: $e');
      throw Exception('Failed to generate text: $e');
    }
  }

  /// Generate embeddings for text (for RAG system)
  Future<List<double>> generateEmbeddings(String text) async {
    if (!_isModelLoaded || _currentModel == null) {
      throw Exception('No model loaded for embeddings.');
    }

    try {
      final requestBody = {
        'model': _currentModel,
        'prompt': text,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding'] ?? []);
      } else {
        throw Exception('Embedding generation failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error generating embeddings: $e');
      throw Exception('Failed to generate embeddings: $e');
    }
  }

  /// Download a model
  Future<void> downloadModel(String modelName, {
    Function(double)? onProgress,
  }) async {
    if (!_isOllamaRunning) {
      throw Exception('Ollama is not running');
    }

    try {
      final requestBody = {'name': modelName};
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        // Handle streaming download progress
        final lines = response.body.split('\n');
        
        for (String line in lines) {
          if (line.isNotEmpty) {
            try {
              final chunk = jsonDecode(line);
              if (chunk['status'] == 'downloading' && onProgress != null) {
                final completed = chunk['completed'] as int? ?? 0;
                final total = chunk['total'] as int? ?? 1;
                onProgress(completed / total);
              }
            } catch (e) {
              debugPrint('Error parsing download progress: $e');
            }
          }
        }
        
        // Refresh model list after download
        await _selectOptimalModel();
      } else {
        throw Exception('Model download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading model: $e');
      throw Exception('Failed to download model: $e');
    }
  }

  /// Get available models
  Future<List<Map<String, dynamic>>> getAvailableModels() async {
    if (!_isOllamaRunning) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['models'] ?? []);
      }
    } catch (e) {
      debugPrint('Error getting available models: $e');
    }
    return [];
  }

  /// Check if a specific model is available
  Future<bool> isModelAvailable(String modelName) async {
    final models = await getAvailableModels();
    return models.any((model) => model['name'] == modelName);
  }

  /// Get model information
  Future<Map<String, dynamic>?> getModelInfo(String modelName) async {
    if (!_isOllamaRunning) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/show'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting model info: $e');
    }
    return null;
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _isModelLoaded = false;
    _isOllamaRunning = false;
    _currentModel = null;
  }
}