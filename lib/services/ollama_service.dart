import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Ollama service for Windows - HTTP API integration
/// This replaces fllama on Windows to prevent crashes
class OllamaService {
  static const String _baseUrl = 'http://localhost:11434';
  static const String _defaultModel = 'llama3.2-3b';
  
  // Model state
  String? _currentModel;
  bool _isGenerating = false;
  
  // Getters
  bool get isGenerating => _isGenerating;
  String? get currentModel => _currentModel;
  
  /// Initialize ollama service
  Future<void> initialize() async {
    try {
      // Check if ollama is running
      final isRunning = await _checkOllamaStatus();
      if (!isRunning) {
        debugPrint('⚠️ Ollama is not running. Please start ollama first.');
        throw Exception('Ollama is not running. Please install and start ollama.');
      }
      
      // Load previously used model
      await _loadPreviouslyUsedModel();
      
      debugPrint('✅ Ollama service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Ollama service: $e');
      rethrow;
    }
  }
  
  /// Check if ollama is running
  Future<bool> _checkOllamaStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ Ollama not responding: $e');
      return false;
    }
  }
  
  /// Get available models from ollama
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = <String>[];
        
        if (data['models'] != null) {
          for (final model in data['models']) {
            models.add(model['name']);
          }
        }
        
        return models;
      } else {
        throw Exception('Failed to get models: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Failed to get available models: $e');
      return [];
    }
  }
  
  /// Pull/download a model
  Future<void> pullModel(String modelName) async {
    try {
      debugPrint('📥 Pulling model: $modelName');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(Duration(minutes: 10));
      
      if (response.statusCode == 200) {
        debugPrint('✅ Model $modelName pulled successfully');
        _currentModel = modelName;
        await _saveCurrentModel(modelName);
      } else {
        throw Exception('Failed to pull model: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Failed to pull model $modelName: $e');
      rethrow;
    }
  }
  
  /// Generate text using ollama
  Future<String> generateText(String prompt, {int maxTokens = 100}) async {
    if (_isGenerating) {
      throw Exception('Generation already in progress');
    }
    
    if (_currentModel == null) {
      // Try to use default model
      _currentModel = _defaultModel;
      debugPrint('⚠️ No model selected, using default: $_currentModel');
    }
    
    _isGenerating = true;
    
    try {
      debugPrint('🤖 Generating with ollama model: $_currentModel');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _currentModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'num_predict': maxTokens,
            'temperature': 0.4,
            'top_p': 0.8,
            'top_k': 40,
            'repeat_penalty': 1.1,
            'seed': -1,
          }
        }),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedText = data['response'] ?? '';
        
        debugPrint('✅ Ollama generation completed: ${generatedText.length} characters');
        return generatedText;
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error'] ?? 'Unknown error';
        throw Exception('Ollama error: $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ Ollama generation failed: $e');
      rethrow;
    } finally {
      _isGenerating = false;
    }
  }
  
  /// Set current model
  Future<void> setModel(String modelName) async {
    try {
      // Check if model exists
      final models = await getAvailableModels();
      if (!models.contains(modelName)) {
        throw Exception('Model $modelName not found. Available: ${models.join(', ')}');
      }
      
      _currentModel = modelName;
      await _saveCurrentModel(modelName);
      debugPrint('✅ Set current model to: $modelName');
    } catch (e) {
      debugPrint('❌ Failed to set model: $e');
      rethrow;
    }
  }
  
  /// Delete a model
  Future<void> deleteModel(String modelName) async {
    try {
      debugPrint('🗑️ Deleting model: $modelName');
      
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        debugPrint('✅ Model $modelName deleted successfully');
        
        // If we deleted the current model, clear it
        if (_currentModel == modelName) {
          _currentModel = null;
          await _clearCurrentModel();
        }
      } else {
        throw Exception('Failed to delete model: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Failed to delete model $modelName: $e');
      rethrow;
    }
  }
  
  /// Get model info
  Future<Map<String, dynamic>?> getModelInfo(String modelName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/show'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('❌ Failed to get model info: $e');
      return null;
    }
  }
  
  /// Save current model to preferences
  Future<void> _saveCurrentModel(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ollama_current_model', modelName);
    } catch (e) {
      debugPrint('⚠️ Failed to save current model: $e');
    }
  }
  
  /// Load previously used model
  Future<void> _loadPreviouslyUsedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString('ollama_current_model');
      
      if (savedModel != null) {
        final models = await getAvailableModels();
        if (models.contains(savedModel)) {
          _currentModel = savedModel;
          debugPrint('✅ Loaded previously used model: $savedModel');
        } else {
          debugPrint('⚠️ Previously used model $savedModel not found');
          await _clearCurrentModel();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load previously used model: $e');
    }
  }
  
  /// Clear current model from preferences
  Future<void> _clearCurrentModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ollama_current_model');
    } catch (e) {
      debugPrint('⚠️ Failed to clear current model: $e');
    }
  }
  
  /// Get installation instructions for Windows
  static String getInstallationInstructions() {
    return '''
To use Ollama on Windows:

1. Download Ollama from: https://ollama.ai/download
2. Install and run Ollama
3. Open Command Prompt and run:
   ollama pull llama3.2-3b
4. Restart Isla Journal

Ollama will run as a background service and provide stable AI generation.
''';
  }
} 