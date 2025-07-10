import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
  QuillController? _controller;
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
    Document document;
    
    try {
      // Try to parse as Delta JSON first
      final deltaJson = jsonDecode(content);
      document = Document.fromJson(deltaJson);
    } catch (e) {
      // If parsing fails, treat as plain text
      document = Document()..insert(0, content);
    }

    _controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

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
      final deltaJson = jsonEncode(_controller!.document.toDelta().toJson());
      final plainText = _controller!.document.toPlainText();
      
      final updatedFile = _currentFile!.copyWith(
        content: deltaJson,
        wordCount: JournalFile.calculateWordCount(plainText),
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
            // Toolbar
            if (_controller != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: AppTheme.creamBeige,
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.warmBrown.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: QuillToolbar.simple(
                  configurations: QuillSimpleToolbarConfigurations(
                    controller: _controller!,
                    sharedConfigurations: const QuillSharedConfigurations(
                      locale: Locale('en'),
                    ),
                  ),
                ),
              ),
            // Editor
            Expanded(
              child: _controller != null
                  ? Container(
                      padding: const EdgeInsets.all(16.0),
                      child: QuillEditor.basic(
                        configurations: QuillEditorConfigurations(
                          controller: _controller!,
                          sharedConfigurations: const QuillSharedConfigurations(
                            locale: Locale('en'),
                          ),
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

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export File'),
        content: const Text('Export formats will be available in the next update.'),
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
            child: const Text('Export as Text'),
          ),
        ],
      ),
    );
  }

  void _exportAsText() {
    if (_controller != null && _currentFile != null) {
      final plainText = _controller!.document.toPlainText();
      
      // For now, just show the plain text
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Export: ${_currentFile!.name}'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(plainText),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}