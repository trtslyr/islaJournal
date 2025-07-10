import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller?.dispose();
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
      final deltaJson = jsonDecode(content);
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
            // Header with file info
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
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${_currentFile!.wordCount} words • ${_hasUnsavedChanges ? "Unsaved changes" : "Saved"}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _hasUnsavedChanges ? _saveFile : null,
                        tooltip: 'Save',
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_download),
                        onPressed: () => _showExportDialog(context),
                        tooltip: 'Export',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Editor
            Expanded(
              child: _controller != null
                  ? Container(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _controller!,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Start writing your journal entry...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: AppTheme.mediumGray,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: AppTheme.darkText,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                        cursorColor: AppTheme.warmBrown,
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

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export File'),
        content: const Text('Export functionality will be enhanced in the next update. For now, you can copy your text directly from the editor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportAsText();
            },
            child: const Text('Copy Text'),
          ),
        ],
      ),
    );
  }

  void _exportAsText() {
    if (_controller != null) {
      // For now, just show a snackbar. In a full implementation,
      // this would copy to clipboard or save to file
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text ready to copy from editor'),
          backgroundColor: AppTheme.warmBrown,
        ),
      );
    }
  }
}