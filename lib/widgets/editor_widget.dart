import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          _hasUnsavedChanges = false;
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
      setState(() {
        _hasUnsavedChanges = true;
      });
      
      // Notify provider about unsaved changes
      final provider = Provider.of<JournalProvider>(context, listen: false);
      provider.markFileAsUnsaved(_currentFile!.id);
    }
    
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _saveFile();
      }
    });
  }



  Future<void> _saveFile() async {
    if (_controller == null || _currentFile == null) return;
    
    final provider = Provider.of<JournalProvider>(context, listen: false);
    
    // Save only the user content (no AI responses)
    final content = _controller!.text;
    final wordCount = JournalFile.calculateWordCount(content);
    
    final updatedFile = _currentFile!.copyWith(
      content: content,
      wordCount: wordCount,
      updatedAt: DateTime.now(),
    );
    
    await provider.updateFile(updatedFile);
    
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _currentFile = updatedFile;
      });
      
      // Notify provider that file is now saved
      provider.markFileAsSaved(updatedFile.id);
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
          return const Center(
            child: Text(
              'loading...',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
          );
        }

        if (_currentFile == null) {
          return Container(
            color: AppTheme.creamBeige,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'no file selected',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'select a file from sidebar or create new one',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14.0,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: AppTheme.creamBeige,
          child: Column(
            children: [

              // Editor with maximum focus on writing
              Expanded(
                child: _controller != null
                    ? Container(
                        padding: const EdgeInsets.all(32.0),
                        child: _buildStyledTextField(),
                      )
                    : const Center(
                        child: Text(
                          'failed to load editor',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 14.0,
                            color: AppTheme.mediumGray,
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
          color: AppTheme.mediumGray.withOpacity(0.6),
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          height: 1.6,
        ),
        hoverColor: Colors.transparent,
        fillColor: AppTheme.creamBeige,
        filled: true,
      ),
      style: const TextStyle(
        fontFamily: 'JetBrainsMono',
        color: AppTheme.darkText,
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      cursorColor: AppTheme.warmBrown,
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Edit Name',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Enter your name',
          ),
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
          autofocus: true,
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
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != _currentFile!.name) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFile(_currentFile!.copyWith(name: name));
                Navigator.of(context).pop();
              } else if (name.isEmpty) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class AIContentRange {
  final int start;
  final int end;
  
  AIContentRange(this.start, this.end);
}