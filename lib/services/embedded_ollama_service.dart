import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

/// Service for managing embedded Ollama on Windows
class EmbeddedOllamaService {
  static final EmbeddedOllamaService _instance = EmbeddedOllamaService._internal();
  factory EmbeddedOllamaService() => _instance;
  EmbeddedOllamaService._internal();

  Process? _ollamaProcess;
  static const int _port = 11435; // Custom port to avoid conflicts
  static const String _defaultModel = 'phi3:mini'; // Small, fast model for Windows
  bool _isRunning = false;
  bool _isInitialized = false;

  /// Check if we're on Windows and should use embedded Ollama
  bool get shouldUseEmbedded => Platform.isWindows;

  /// Check if embedded Ollama is running
  bool get isRunning => _isRunning;

  /// Initialize and start embedded Ollama (Windows only)
  Future<void> initialize() async {
    if (!shouldUseEmbedded) {
      debugPrint('🍎 Not Windows - skipping embedded Ollama');
      return;
    }

    if (_isInitialized) {
      debugPrint('✅ Embedded Ollama already initialized');
      return;
    }

    debugPrint('🚀 Initializing embedded Ollama for Windows...');

    try {
      // 1. Extract Ollama binary
      final ollamaBinary = await _extractOllamaBinary();
      
      // 2. Setup models directory
      await _setupModelsDirectory();
      
      // 3. Start Ollama process
      await _startOllamaProcess(ollamaBinary);
      
      // 4. Wait for Ollama to be ready
      await _waitForOllamaReady();
      
      // 5. Pull/setup default model if needed
      await _ensureModelAvailable();
      
      _isInitialized = true;
      debugPrint('🎉 Embedded Ollama ready on Windows!');
      
    } catch (e) {
      debugPrint('💥 Failed to initialize embedded Ollama: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Extract Ollama binary from assets to temp directory
  Future<File> _extractOllamaBinary() async {
    debugPrint('📦 Extracting Ollama binary...');
    
    try {
      final tempDir = await getTemporaryDirectory();
      final ollamaDir = Directory(path.join(tempDir.path, 'ollama'));
      await ollamaDir.create(recursive: true);
      
      final binaryFile = File(path.join(ollamaDir.path, 'ollama.exe'));
      
      // Only extract if not already extracted
      if (!await binaryFile.exists()) {
        debugPrint('   Extracting ollama.exe from assets...');
        final binaryData = await rootBundle.load('assets/binaries/windows/ollama.exe');
        await binaryFile.writeAsBytes(binaryData.buffer.asUint8List());
        debugPrint('   ✅ Extracted ollama.exe (${binaryData.lengthInBytes} bytes)');
      } else {
        debugPrint('   ✅ Ollama binary already extracted');
      }
      
      return binaryFile;
      
    } catch (e) {
      debugPrint('❌ Failed to extract Ollama binary: $e');
      throw Exception('Could not extract Ollama binary: $e');
    }
  }

  /// Setup models directory for Ollama
  Future<void> _setupModelsDirectory() async {
    debugPrint('📁 Setting up models directory...');
    
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(path.join(appDocDir.path, 'ollama_models'));
    
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
      debugPrint('   ✅ Created models directory: ${modelsDir.path}');
    }
  }

  /// Start Ollama process
  Future<void> _startOllamaProcess(File ollamaBinary) async {
    debugPrint('🚀 Starting Ollama process...');
    
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final modelsDir = path.join(appDocDir.path, 'ollama_models');
      
      _ollamaProcess = await Process.start(
        ollamaBinary.path,
        ['serve'],
        environment: {
          'OLLAMA_HOST': '127.0.0.1:$_port',
          'OLLAMA_MODELS': modelsDir,
          'OLLAMA_KEEP_ALIVE': '5m', // Keep model in memory for 5 minutes
          'OLLAMA_NUM_PARALLEL': '1', // Conservative for Windows
        },
        workingDirectory: ollamaBinary.parent.path,
      );

      // Listen to output for debugging
      _ollamaProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('Ollama: $data');
      });
      
      _ollamaProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('Ollama Error: $data');
      });

      debugPrint('   ✅ Ollama process started (PID: ${_ollamaProcess!.pid})');
      
    } catch (e) {
      debugPrint('❌ Failed to start Ollama process: $e');
      throw Exception('Could not start Ollama process: $e');
    }
  }

  /// Wait for Ollama to be ready to accept requests
  Future<void> _waitForOllamaReady() async {
    debugPrint('⏳ Waiting for Ollama to be ready...');
    
    for (int i = 0; i < 60; i++) { // Wait up to 60 seconds
      try {
        final response = await http.get(
          Uri.parse('http://127.0.0.1:$_port/api/tags'),
        ).timeout(Duration(seconds: 2));
        
        if (response.statusCode == 200) {
          _isRunning = true;
          debugPrint('   ✅ Ollama is ready! (took ${i + 1} seconds)');
          return;
        }
      } catch (e) {
        // Still starting up
      }
      
      await Future.delayed(Duration(seconds: 1));
      debugPrint('   ⏳ Still waiting... (${i + 1}/60 seconds)');
    }
    
    throw Exception('Ollama failed to start within 60 seconds');
  }

  /// Ensure the default model is available
  Future<void> _ensureModelAvailable() async {
    debugPrint('🧠 Ensuring model $_defaultModel is available...');
    
    try {
      // Check if model exists
      final response = await http.get(
        Uri.parse('http://127.0.0.1:$_port/api/tags'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List?;
        
        if (models != null && models.any((model) => model['name'].toString().contains('phi3'))) {
          debugPrint('   ✅ Model $_defaultModel already available');
          return;
        }
      }
      
      // Model not found - need to pull it
      debugPrint('   📥 Pulling model $_defaultModel...');
      await _pullModel(_defaultModel);
      
    } catch (e) {
      debugPrint('⚠️ Could not ensure model availability: $e');
      // Continue anyway - we'll handle this in generateText
    }
  }

  /// Pull a model from Ollama registry
  Future<void> _pullModel(String modelName) async {
    debugPrint('📥 Pulling model: $modelName');
    
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$_port/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(Duration(minutes: 10)); // Long timeout for model download
      
      if (response.statusCode == 200) {
        debugPrint('   ✅ Successfully pulled model: $modelName');
      } else {
        debugPrint('   ⚠️ Model pull returned status: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('   ❌ Failed to pull model $modelName: $e');
      // Don't throw - we'll try to continue with other models
    }
  }

  /// Generate text using embedded Ollama
  Future<String> generateText(String prompt, {int maxTokens = 100}) async {
    if (!shouldUseEmbedded) {
      throw Exception('Embedded Ollama only supported on Windows');
    }
    
    if (!_isInitialized || !_isRunning) {
      await initialize();
    }
    
    debugPrint('🧠 Generating text with embedded Ollama...');
    debugPrint('   Prompt: "${prompt.substring(0, math.min(50, prompt.length))}..."');
    debugPrint('   Max tokens: $maxTokens');
    
    try {
      final requestBody = {
        'model': _defaultModel,
        'prompt': prompt,
        'stream': false,
        'options': {
          'num_predict': maxTokens,
          'temperature': 0.4,
          'top_p': 0.8,
        },
      };
      
      final response = await http.post(
        Uri.parse('http://127.0.0.1:$_port/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String? ?? 'No response generated';
        
        debugPrint('   ✅ Generated ${result.length} characters');
        return result;
      } else {
        final errorMsg = 'Ollama API error: ${response.statusCode} - ${response.body}';
        debugPrint('   ❌ $errorMsg');
        throw Exception(errorMsg);
      }
      
    } catch (e) {
      debugPrint('   💥 Generation failed: $e');
      
      // If Ollama seems to have died, try to restart
      if (e.toString().contains('Connection refused') || e.toString().contains('Connection closed')) {
        debugPrint('   🔄 Attempting to restart Ollama...');
        _isRunning = false;
        _isInitialized = false;
        await initialize();
        // Don't retry here - let the caller handle it
      }
      
      throw Exception('AI generation failed: $e');
    }
  }

  /// Check if embedded Ollama is available and ready
  Future<bool> isAvailable() async {
    if (!shouldUseEmbedded) return false;
    if (!_isRunning) return false;
    
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:$_port/api/tags'),
      ).timeout(Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Clean up resources
  Future<void> _cleanup() async {
    _isRunning = false;
    _isInitialized = false;
    
    if (_ollamaProcess != null) {
      debugPrint('🛑 Stopping Ollama process...');
      _ollamaProcess!.kill(ProcessSignal.sigterm);
      
      // Wait a bit for graceful shutdown
      await Future.delayed(Duration(seconds: 2));
      
      // Force kill if still running
      if (!_ollamaProcess!.kill()) {
        _ollamaProcess!.kill(ProcessSignal.sigkill);
      }
      
      _ollamaProcess = null;
      debugPrint('   ✅ Ollama process stopped');
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _cleanup();
  }
}