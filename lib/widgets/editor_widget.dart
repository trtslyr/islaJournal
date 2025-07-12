import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/ai_provider.dart';
import '../models/journal_file.dart';
import '../core/theme/app_theme.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({super.key});

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  TextEditingController? _controller;
  Timer? _saveTimer;
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  JournalFile? _currentFile;
  bool _isProcessingAI = false;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadFile();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller?.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    if (provider.selectedFileId != null) {
      final file = await provider.getFile(provider.selectedFileId!);
      if (file != null) {
        setState(() {
          _currentFile = file;
          _isLoading = false;
        });
        _initializeEditor(file.content);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeEditor(String content) {
    String plainText;
    
    try {
      // Try to parse as Delta JSON first (from previous flutter_quill content)
      jsonDecode(content);
      // Extract plain text from delta - this is a simplified extraction
      plainText = content; // For now, just use the content as-is
    } catch (e) {
      // If parsing fails, treat as plain text
      plainText = content;
    }

    _controller = TextEditingController(text: plainText);
    _controller!.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_controller != null && _currentFile != null) {
      setState(() {
        _hasUnsavedChanges = true;
      });
      
      // Debounce save
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), () {
        _saveFile();
      });
    }
  }

  Future<void> _handleKeyPress(RawKeyEvent event) async {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      await _checkForSlashCommand();
    }
  }

  Future<void> _checkForSlashCommand() async {
    if (_controller == null || _isProcessingAI) return;
    
    final text = _controller!.text;
    final cursorPosition = _controller!.selection.baseOffset;
    
    // Find the current line
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lines = textBeforeCursor.split('\n');
    
    if (lines.isEmpty) return;
    
    final currentLine = lines.last.trim();
    
    // Check if the line starts with a slash command
    if (currentLine.startsWith('/') && currentLine.length > 1) {
      final command = currentLine.substring(1).trim();
      if (command.isNotEmpty) {
        await _processSlashCommand(command, currentLine);
      }
    }
  }

  Future<void> _processSlashCommand(String command, String originalLine) async {
    if (_controller == null) return;
    
    setState(() {
      _isProcessingAI = true;
    });
    
    try {
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      
      // Check if AI is available
      if (!aiProvider.isModelLoaded) {
        _addTextAfterLine(originalLine, '\n🤖 AI not available. Please go to Settings to set up AI models.');
        return;
      }
      
      // Add processing indicator after the command
      _addTextAfterLine(originalLine, '\n🤖 Processing: $command...');
      
      // Get AI response
      final response = await aiProvider.generateResponse(command);
      
      // Replace processing indicator with response
      _replaceLastLine('🤖 Processing: $command...', '🤖 $response');
      
      // Move cursor to end
      _controller!.selection = TextSelection.collapsed(offset: _controller!.text.length);
      
    } catch (e) {
      _replaceLastLine('🤖 Processing: $command...', '🤖 Error: Unable to process command');
      debugPrint('Error processing slash command: $e');
    } finally {
      setState(() {
        _isProcessingAI = false;
      });
    }
  }

  void _addTextAfterLine(String targetLine, String textToAdd) {
    if (_controller == null) return;
    
    final text = _controller!.text;
    final lastIndex = text.lastIndexOf(targetLine);
    
    if (lastIndex != -1) {
      final insertPosition = lastIndex + targetLine.length;
      final newText = text.substring(0, insertPosition) + textToAdd + text.substring(insertPosition);
      _controller!.text = newText;
    }
  }

  void _replaceLastLine(String oldLine, String newLine) {
    if (_controller == null) return;
    
    final text = _controller!.text;
    final lastIndex = text.lastIndexOf(oldLine);
    
    if (lastIndex != -1) {
      final newText = text.substring(0, lastIndex) + newLine + text.substring(lastIndex + oldLine.length);
      _controller!.text = newText;
    }
  }

  Future<void> _saveFile() async {
    if (_controller == null || _currentFile == null) return;

    try {
      final content = _controller!.text;
      
      final updatedFile = _currentFile!.copyWith(
        content: content,
        wordCount: JournalFile.calculateWordCount(content),
      );

      final provider = Provider.of<JournalProvider>(context, listen: false);
      await provider.updateFile(updatedFile);
      
      setState(() {
        _hasUnsavedChanges = false;
        _currentFile = updatedFile;
      });
    } catch (e) {
      debugPrint('Error saving file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JournalProvider>(
      builder: (context, provider, child) {
        // Check if selected file changed
        if (provider.selectedFileId != _currentFile?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadFile();
          });
        }

        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_currentFile == null) {
          return const Center(
            child: Text('No file selected'),
          );
        }

        return Column(
          children: [
            // Clean header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.darkerCream,
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.warmBrown.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentFile!.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'JetBrainsMono',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentFile!.wordCount} words • ${_hasUnsavedChanges ? "Unsaved changes" : "Saved"}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'JetBrainsMono',
                            color: AppTheme.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasUnsavedChanges)
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: _saveFile,
                      tooltip: 'Save',
                    ),
                ],
              ),
            ),
            // Clean editor
            Expanded(
              child: _controller != null
                  ? Container(
                      padding: const EdgeInsets.all(24.0),
                      child: RawKeyboardListener(
                        focusNode: _focusNode!,
                        onKey: _handleKeyPress,
                        child: TextField(
                          controller: _controller!,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: 'Start writing...\n\nTip: Type "/" followed by a question and press Enter to ask AI',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: AppTheme.mediumGray.withOpacity(0.6),
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: AppTheme.darkText,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ),
                          cursorColor: AppTheme.warmBrown,
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('Failed to load editor'),
                    ),
            ),
          ],
        );
      },
    );
  }
}