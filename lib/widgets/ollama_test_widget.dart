import 'package:flutter/material.dart';
import 'dart:io';
import '../services/ollama_service.dart';

/// Simple test widget to verify ollama integration on Windows
class OllamaTestWidget extends StatefulWidget {
  const OllamaTestWidget({Key? key}) : super(key: key);

  @override
  State<OllamaTestWidget> createState() => _OllamaTestWidgetState();
}

class _OllamaTestWidgetState extends State<OllamaTestWidget> {
  final OllamaService _ollamaService = OllamaService();
  String _status = 'Initializing...';
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeOllama();
  }

  Future<void> _initializeOllama() async {
    if (!Platform.isWindows) {
      setState(() {
        _status = 'Ollama test only available on Windows';
      });
      return;
    }

    try {
      setState(() {
        _status = 'Checking ollama status...';
      });

      await _ollamaService.initialize();
      
      setState(() {
        _status = '✅ Ollama is running and ready!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Ollama not available: $e\n\n${OllamaService.getInstallationInstructions()}';
      });
    }
  }

  Future<void> _testGeneration() async {
    if (!Platform.isWindows) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await _ollamaService.generateText(
        'Say "Hello from Ollama!" in a friendly way.',
        maxTokens: 50,
      );
      
      setState(() {
        _result = result;
        _status = '✅ Test successful!';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _status = '❌ Test failed';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ollama Windows Test',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(
                color: _status.contains('✅') ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (Platform.isWindows && _status.contains('✅'))
              ElevatedButton(
                onPressed: _isLoading ? null : _testGeneration,
                child: _isLoading 
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Testing...'),
                      ],
                    )
                  : Text('Test AI Generation'),
              ),
            if (_result.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Result:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_result),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 