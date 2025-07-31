import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_file.dart';
import '../services/validation_service.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({super.key});

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  TextEditingController? _controller;
  Timer? _saveTimer;
  bool _isLoading = true;
  JournalFile? _currentFile;
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
      if (file != null && mounted) {
        setState(() {
          _currentFile = file;
          _isLoading = false;
        });
        
        // Initialize controller with file content
        _controller = TextEditingController(text: file.content);
        _controller!.addListener(_onTextChanged);
      }
    } else {
      setState(() {
        _isLoading = false;
        _currentFile = null;
      });
    }
  }

  void _onTextChanged() {
    if (mounted && _currentFile != null) {
      // Cancel existing timer and start new autosave countdown
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _saveFile();
        }
      });
    }
  }

  Future<void> _saveFile() async {
    if (_controller == null || _currentFile == null) return;
    
    final provider = Provider.of<JournalProvider>(context, listen: false);
    
    // Save the current content
    final content = _controller!.text;
    final wordCount = JournalFile.calculateWordCount(content);
    
    final updatedFile = _currentFile!.copyWith(
      content: content,
      wordCount: wordCount,
      updatedAt: DateTime.now(),
      isPinned: _currentFile!.isPinned, // Preserve pin status
    );
    
    await provider.updateFile(updatedFile);
    
    if (mounted) {
      setState(() {
        _currentFile = updatedFile;
      });
    }
  }

  Future<void> _saveBeforeFileSwitch() async {
    // Save current file before switching if there's content and a timer is active
    if (_controller != null && _currentFile != null && _saveTimer?.isActive == true) {
      _saveTimer!.cancel();
      await _saveFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JournalProvider>(
      builder: (context, provider, child) {
        // Check if selected file changed - save current file first
        if (provider.selectedFileId != _currentFile?.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _saveBeforeFileSwitch();
            _loadFile();
          });
        }

        if (_isLoading) {
          return Center(
            child: Text(
              'loading...',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          );
        }

        if (_currentFile == null) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no file selected',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'select a file from sidebar or create new one',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14.0,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [

              // Editor with maximum focus on writing
              Expanded(
                child: _controller != null
                    ? Container(
                        padding: const EdgeInsets.all(32.0),
                        child: _buildStyledTextField(),
                      )
                    : Center(
                        child: Text(
                          'failed to load editor',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 14.0,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStyledTextField() {
    return TextField(
      controller: _controller!,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
                        hintText: 'start writing...\n\nuse the ai chat panel on the right to interact with your journal',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: Theme.of(context).hintColor?.withOpacity(0.6),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
        hoverColor: Colors.transparent,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        filled: true,
      ),
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      cursorColor: Theme.of(context).colorScheme.primary,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(0),
    );
  }

  bool _isProfileFile() {
    if (_currentFile == null) return false;
    return _currentFile!.id == 'profile_special_file';
  }

  void _showEditTitleDialog() {
    if (_currentFile == null) return;
    
    final nameController = TextEditingController(text: _currentFile!.name);
    final isProfileFile = _currentFile!.id == 'profile_special_file';
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isProfileFile ? 'Edit Name' : 'Rename File',
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
          controller: nameController,
                decoration: InputDecoration(
                  labelText: isProfileFile ? 'Your name' : 'File name',
                  hintText: isProfileFile ? 'Enter your name' : 'Enter file name',
                  errorText: errorMessage,
          ),
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
          autofocus: true,
                onChanged: (value) {
                  setState(() {
                    if (!isProfileFile) {
                      errorMessage = ValidationService.validateName(value.trim(), isFolder: false);
                      if (errorMessage == null && value.trim() != _currentFile!.name) {
                        // Check for duplicates (exclude current file)
                        final provider = Provider.of<JournalProvider>(context, listen: false);
                        final existingNames = provider.files
                            .where((f) => f.folderId == _currentFile!.folderId && f.id != _currentFile!.id)
                            .map((f) => f.name)
                            .toList();
                        if (ValidationService.isFileNameDuplicate(value.trim(), existingNames)) {
                          errorMessage = 'A file with this name already exists';
                        }
                      }
                    }
                  });
                },
              ),
            ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
          TextButton(
              onPressed: (isProfileFile || errorMessage == null) && 
                         nameController.text.trim().isNotEmpty && 
                         nameController.text.trim() != _currentFile!.name
                  ? () async {
              final name = nameController.text.trim();
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFile(_currentFile!.copyWith(
                  name: name,
                  isPinned: _currentFile!.isPinned, // Preserve pin status
                ));
                Navigator.of(context).pop();
              }
                  : null,
            child: const Text(
              'Save',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class AIContentRange {
  final int start;
  final int end;
  
  AIContentRange(this.start, this.end);
}