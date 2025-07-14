import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../providers/ai_provider.dart';
import '../providers/rag_provider.dart';
import '../providers/mood_provider.dart';
import '../providers/auto_tagging_provider.dart';
import '../services/writing_prompts_service.dart';
import '../services/mood_analysis_service.dart';
import '../models/journal_file.dart';
import '../models/mood_entry.dart';
import '../models/writing_prompt.dart';
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
  
  // AI Analysis features
  bool _showAIInsights = false;
  MoodEntry? _currentMoodAnalysis;
  List<WritingPrompt> _writingPrompts = [];
  bool _isAnalyzing = false;
  Timer? _analysisTimer;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadFile();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _analysisTimer?.cancel();
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
      
      // Debounce AI analysis
      if (_showAIInsights) {
        _analysisTimer?.cancel();
        _analysisTimer = Timer(const Duration(seconds: 5), () {
          _performAIAnalysis();
        });
      }
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
      final ragProvider = Provider.of<RAGProvider>(context, listen: false);
      
      // Check if AI is available
      if (!aiProvider.isModelLoaded) {
        _addTextAfterLine(originalLine, '\n🤖 AI not available. Please go to Settings to set up AI models.');
        return;
      }
      
      // Add processing indicator after the command
      _addTextAfterLine(originalLine, '\n🤖 Processing: $command...');
      
      // Get RAG-enhanced response if available, otherwise fall back to basic AI
      String response;
      if (ragProvider.isInitialized) {
        response = await ragProvider.generateContextualResponse(
          command,
          systemPrompt: 'You are a helpful AI assistant that has access to the user\'s journal entries and documents. Provide thoughtful, contextual responses based on their writing patterns and content.',
          maxTokens: 200,
          temperature: 0.7,
        );
      } else {
        response = await aiProvider.generateResponse(command);
      }
      
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

      // Trigger auto-tagging if enabled
      final autoTaggingProvider = Provider.of<AutoTaggingProvider>(context, listen: false);
      await autoTaggingProvider.autoTagOnSaveIfEnabled(updatedFile);
      
    } catch (e) {
      debugPrint('Error saving file: $e');
    }
  }

  Future<void> _performAIAnalysis() async {
    if (_controller == null || _currentFile == null || _isAnalyzing) return;
    
    final content = _controller!.text;
    if (content.trim().isEmpty) return;
    
    setState(() {
      _isAnalyzing = true;
    });
    
    try {
      final moodProvider = Provider.of<MoodProvider>(context, listen: false);
      final writingPromptsService = WritingPromptsService();
      
      // Analyze mood (need to pass the journal file)
      final moodAnalysis = await moodProvider.analyzeMood(_currentFile!);
      
      // Get writing prompts
      final prompts = await writingPromptsService.generateContextualPrompts(
        currentContent: content,
        count: 3,
      );
      
      setState(() {
        _currentMoodAnalysis = moodAnalysis;
        _writingPrompts = prompts;
        _isAnalyzing = false;
      });
    } catch (e) {
      debugPrint('Error performing AI analysis: $e');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _toggleAIInsights() {
    setState(() {
      _showAIInsights = !_showAIInsights;
    });
    
    if (_showAIInsights && _controller != null && _controller!.text.trim().isNotEmpty) {
      _performAIAnalysis();
    }
  }

  Widget _buildAIInsightsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.warmBrown, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warmBrown,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Analysis status
          if (_isAnalyzing)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warmBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analyzing...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          
          // Mood Analysis
          if (_currentMoodAnalysis != null) ...[
            const SizedBox(height: 16),
            _buildMoodAnalysisSection(),
          ],
          
          // Writing Prompts
          if (_writingPrompts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildWritingPromptsSection(),
          ],
          
          // Instructions
          if (_currentMoodAnalysis == null && _writingPrompts.isEmpty && !_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mediumGray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Analysis',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'JetBrainsMono',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start writing and AI will analyze your mood, suggest writing prompts, and provide insights.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodAnalysisSection() {
    final mood = _currentMoodAnalysis!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmBrown.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mood, color: AppTheme.warmBrown, size: 16),
              const SizedBox(width: 6),
              Text(
                'Mood Analysis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Valence and Arousal
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valence',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (mood.valence + 1) / 2, // Convert -1 to 1 range to 0 to 1
                      backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        mood.valence >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mood.valence >= 0 ? 'Positive' : 'Negative',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: mood.arousal,
                      backgroundColor: AppTheme.mediumGray.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.warmBrown,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mood.arousal >= 0.5 ? 'High' : 'Low',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Emotions
          if (mood.emotions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Emotions',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: mood.emotions.map((emotion) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warmBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    emotion,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: AppTheme.darkText,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWritingPromptsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warmBrown.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warmBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.warmBrown, size: 16),
              const SizedBox(width: 6),
              Text(
                'Writing Prompts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'JetBrainsMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Column(
            children: _writingPrompts.map((prompt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt.prompt,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          prompt.category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'JetBrainsMono',
                            color: AppTheme.mediumGray,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${(prompt.relevanceScore * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'JetBrainsMono',
                            color: AppTheme.warmBrown,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
                  IconButton(
                    icon: Icon(
                      _showAIInsights ? Icons.psychology : Icons.psychology_outlined,
                      color: _showAIInsights ? AppTheme.warmBrown : AppTheme.mediumGray,
                    ),
                    onPressed: _toggleAIInsights,
                    tooltip: _showAIInsights ? 'Hide AI Insights' : 'Show AI Insights',
                  ),
                ],
              ),
            ),
            // Editor and AI Insights
            Expanded(
              child: Row(
                children: [
                  // Main editor
                  Expanded(
                    flex: _showAIInsights ? 2 : 1,
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
                                  hintText: 'Start writing...\n\nTip: Type "/" followed by a question and press Enter to ask AI\nExample: "/what themes do I write about most?" or "/help me continue this thought"',
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
                  
                  // AI Insights panel
                  if (_showAIInsights)
                    Container(
                      width: 300,
                      decoration: BoxDecoration(
                        color: AppTheme.darkerCream,
                        border: Border(
                          left: BorderSide(
                            color: AppTheme.warmBrown.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _buildAIInsightsPanel(),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}