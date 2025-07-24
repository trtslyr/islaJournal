import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/conversation_provider.dart';
import '../core/theme/app_theme.dart';
import '../services/journal_companion_service.dart';
import '../models/conversation_session.dart';
import '../models/context_settings.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class AIChatPanel extends StatefulWidget {
  const AIChatPanel({super.key});
  
  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isProcessingAI = false;
  List<ChatMessage> _messages = [];
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConversation();
    });
  }
  
  Future<void> _initializeConversation() async {
    try {
      print('🔄 Initializing conversation...');
      final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
      await conversationProvider.initialize();
      
      // Get or create a default conversation
      final conversation = await conversationProvider.getOrCreateDefaultConversation();
      print('✅ Got conversation: ${conversation.id} - ${conversation.title}');
      
      // Load messages from conversation history
      _loadMessagesFromConversation(conversation);
      
      if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      }
      print('✅ Conversation initialization complete');
    } catch (e) {
      print('🔴 Error initializing conversation: $e');
      if (mounted) {
      setState(() {
        _isInitialized = true; // Still show UI even if initialization failed
      });
      }
    }
  }
  
  void _loadMessagesFromConversation(ConversationSession? conversation) {
    if (conversation == null) {
      print('⚠️ No conversation to load messages from');
      return;
    }
    
    print('📥 Loading ${conversation.history.length} messages from conversation: ${conversation.title}');
    
    final messages = conversation.history.map((msg) => ChatMessage(
      content: msg.content,
      isUser: msg.role == 'user',
      timestamp: msg.timestamp,
    )).toList();
    
    if (mounted) {
    setState(() {
      _messages = messages;
    });
    }
    
    print('✅ Loaded ${_messages.length} messages into UI');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }
  
  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.creamBeige,
        border: Border(
          left: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: !_isInitialized 
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.warmBrown,
              ),
            )
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildChatArea()),
                _buildInputArea(),
              ],
            ),
    );
  }
  
    Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
          // Context files button
          Consumer<ConversationProvider>(
            builder: (context, conversationProvider, child) {
              final activeConversation = conversationProvider.activeConversation;
              final selectedCount = activeConversation?.contextSettings.selectedFileIds.length ?? 0;
              
              return TextButton.icon(
                onPressed: () => _showFileContextSelector(conversationProvider),
                icon: Icon(
                  Icons.library_add,
                  size: 16,
                  color: selectedCount > 0 ? AppTheme.warmBrown : AppTheme.mediumGray,
                ),
                label: Text(
                  selectedCount > 0 ? '$selectedCount files' : 'Context',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: selectedCount > 0 ? AppTheme.warmBrown : AppTheme.mediumGray,
                    fontWeight: selectedCount > 0 ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
          
          const Spacer(),
          
          // New chat button 
          TextButton(
            onPressed: _createNewChat,
            style: TextButton.styleFrom(
              overlayColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              minimumSize: Size.zero,
            ),
            child: const Text(
              '+',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                fontWeight: FontWeight.w400,
                color: AppTheme.warmBrown,
              ),
            ),
          ),
          const SizedBox(width: 4),
          
          // Chat title dropdown positioned on the far right
          Consumer<ConversationProvider>(
            builder: (context, provider, child) {
              final activeConversation = provider.activeConversation;
              return PopupMenuButton<String>(
                onSelected: (conversationId) async {
                  print('🔄 Switching to conversation: $conversationId');
                  final conversation = provider.getConversationById(conversationId);
                  if (conversation != null) {
                    print('✅ Found conversation: ${conversation.title} with ${conversation.history.length} messages');
                    await provider.setActiveConversation(conversation);
                    _loadMessagesFromConversation(conversation);
                  } else {
                    print('❌ Conversation not found: $conversationId');
                  }
                },
                itemBuilder: (context) {
                  return provider.conversations.map((conversation) {
                    final isActive = provider.activeConversation?.id == conversation.id;
                    return PopupMenuItem<String>(
                      value: conversation.id,
                      child: Row(
                        children: [
                          if (isActive) const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          if (isActive) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              conversation.title,
                              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                            ),
                          ),
                          // Three dots menu
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              switch (action) {
                                case 'rename':
                                  await _showRenameDialog(conversation);
                                  break;
                                case 'delete':
                                  await _showDeleteConfirmation(conversation);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem<String>(
                                value: 'rename',
                                child: Text(
                                  'Rename',
                                  style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, color: Colors.red),
                                ),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text(
                                '⋯',
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
                  }).toList();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        activeConversation?.title ?? 'Chat',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '▼',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.0,
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildChatArea() {
    return Consumer2<AIProvider, JournalProvider>(
      builder: (context, aiProvider, journalProvider, child) {
        if (!aiProvider.isModelLoaded) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ai not available',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14.0,
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // Navigate to settings - implement later
                  },
                  style: TextButton.styleFrom(
                    overlayColor: Colors.transparent,
                  ),
                  child: const Text(
                    'setup models',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.warmBrown,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
                 return Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             children: [
               // Chat messages
               Expanded(
                 child: _buildMessagesList(),
               ),
             ],
           ),
         );
      },
    );
  }
  
  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        _buildQuickActionButton('analyze mood', () {
          _sendQuickMessage('Analyze the mood and emotions in my recent journal entries');
        }),
        _buildQuickActionButton('summarize', () {
          _sendQuickMessage('Summarize my recent journal entries and key themes');
        }),
        _buildQuickActionButton('continue writing', () {
          _sendQuickMessage('Help me continue writing based on my current entry');
        }),
      ],
    );
  }

  void _sendQuickMessage(String message) {
    _chatController.text = message;
    _sendMessage();
  }
  
  Widget _buildQuickActionButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.warmBrown.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        minimumSize: Size.zero,
        overlayColor: Colors.transparent,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10.0,
          fontWeight: FontWeight.w400,
          color: AppTheme.warmBrown,
        ),
      ),
    );
  }
  
  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.darkerCream,
          border: Border.all(
            color: AppTheme.warmBrown.withOpacity(0.2),
          ),
        ),
        child: const Center(
          child: Text(
            'start a conversation about your journal',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.mediumGray,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        border: Border.all(
          color: AppTheme.warmBrown.withOpacity(0.2),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.isUser ? '>' : '<',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: message.isUser ? AppTheme.warmBrown : AppTheme.mediumGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: message.isUser ? AppTheme.darkText : AppTheme.mediumGray,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty || _isProcessingAI) return;

    final aiProvider = Provider.of<AIProvider>(context, listen: false);
    if (!aiProvider.isModelLoaded) {
      print('🔴 AI model not loaded');
      return;
    }

    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final activeConversation = conversationProvider.activeConversation;
    
    if (activeConversation == null) {
      print('🔴 No active conversation found');
      return;
    }

    print('✅ Sending message: $message');

    // Add user message
    if (mounted) {
    setState(() {
      _messages.add(ChatMessage(
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessingAI = true;
    });
    }

    _chatController.clear();
    _scrollToBottom();

    try {
      // Add user message to conversation
      await activeConversation.addUserMessage(message);
      
      // Get AI response using new embeddings-based context system
      print('=== AI CHAT: About to call generateInsights ===');
      print('🔥🔥🔥 AI CHAT: About to call generateInsights for query: $message');
      final response = await JournalCompanionService().generateInsights(
        userQuery: message,
        conversation: activeConversation,
        settings: activeConversation.contextSettings,
      );
      print('🔥🔥🔥 AI CHAT: generateInsights returned: ${response.substring(0, 50)}...');
      
      // Add assistant response to conversation
      await activeConversation.addAssistantMessage(response);
      
      // Add AI response to chat
      if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      }
      
      _scrollToBottom();
    } catch (e) {
      // Handle error
      if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          content: 'Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      }
    } finally {
      if (mounted) {
      setState(() {
        _isProcessingAI = false;
      });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearChat() async {
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final activeConversation = conversationProvider.activeConversation;
    
    if (activeConversation == null) return;
    
    await activeConversation.clear();
    
    if (mounted) {
    setState(() {
      _messages.clear();
    });
    }
  }

  Future<void> _createNewChat() async {
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    try {
      final newConversation = await conversationProvider.createConversation();
      _loadMessagesFromConversation(newConversation);
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create new chat: $e')),
      );
    }
  }

  Future<void> _showRenameDialog(ConversationSession conversation) async {
    final titleController = TextEditingController(text: conversation.title);
    
    final newTitle = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text(
          'Rename Chat',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Chat title',
            hintText: 'Enter new chat title',
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
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.of(context).pop(title);
              }
            },
            child: const Text(
              'Rename',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
      ),
    );
    
    if (newTitle != null && newTitle != conversation.title) {
      print('✏️ Attempting to rename conversation: ${conversation.title} -> $newTitle');
      final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
      await conversationProvider.updateConversationTitle(conversation, newTitle);
      print('✏️ Rename completed');
    } else {
      print('✏️ Rename cancelled or same title: $newTitle');
    }
  }

  Future<void> _showDeleteConfirmation(ConversationSession conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Chat',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 14),
        ),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?\n\nThis action cannot be undone.',
          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      print('🗑️ Attempting to delete conversation: ${conversation.title} (${conversation.id})');
      final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
      
      print('📋 Conversations before delete: ${conversationProvider.conversations.length}');
      for (final conv in conversationProvider.conversations) {
        print('  - ${conv.id}: ${conv.title}');
      }
      
      await conversationProvider.deleteConversation(conversation);
      
      print('📋 Conversations after delete: ${conversationProvider.conversations.length}');
      for (final conv in conversationProvider.conversations) {
        print('  - ${conv.id}: ${conv.title}');
      }
      
      // If we deleted the active conversation, load the new active one
      if (conversationProvider.activeConversation != null) {
        print('✅ Loading new active conversation: ${conversationProvider.activeConversation!.title}');
        _loadMessagesFromConversation(conversationProvider.activeConversation);
      } else {
        print('⚠️ No active conversation remaining, clearing messages');
        if (mounted) {
        setState(() {
          _messages.clear();
        });
        }
      }
    }
  }

  Future<void> _showConversationHistory() async {
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Consumer<ConversationProvider>(
            builder: (context, provider, child) {
              if (provider.conversations.isEmpty) {
                return const Center(
                  child: Text('No conversations yet'),
                );
              }
              
              return ListView.builder(
                itemCount: provider.conversations.length,
                itemBuilder: (context, index) {
                  final conversation = provider.conversations[index];
                  final isActive = provider.activeConversation?.id == conversation.id;
                  
                  return ListTile(
                    title: Text(conversation.title),
                    subtitle: Text(
                      'Messages: ${conversation.history.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: isActive 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await provider.deleteConversation(conversation);
                              Navigator.of(context).pop();
                            },
                          ),
                    onTap: () async {
                      await provider.setActiveConversation(conversation);
                      _loadMessagesFromConversation(conversation);
                      Navigator.of(context).pop();
                    },
                  );
                },
              );
            },
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



  Future<void> _showFileContextSelector(ConversationProvider conversationProvider) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final files = journalProvider.files;
    final activeConversation = conversationProvider.activeConversation;
    
    if (activeConversation == null) return;

    // Use the same sorting as the file tree
    final sortedFiles = journalProvider.getSortedFiles(files);

    final selectedIds = List<String>.from(activeConversation.contextSettings.selectedFileIds);
    final maxTokens = activeConversation.contextSettings.maxTokens;
    final availableTokens = maxTokens - 1800; // Reserve for core context

    int _estimateTokens(String text) {
      return (text.length / 4).round(); // Rough estimate: 4 chars = 1 token
    }

    int _calculateSelectedTokens(List<String> fileIds) {
      int total = 0;
      for (final id in fileIds) {
        final file = sortedFiles.firstWhere((f) => f.id == id, orElse: () => sortedFiles.first);
        if (file.content?.isNotEmpty == true) {
          total += _estimateTokens(file.content!);
        }
      }
      return total;
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final selectedTokens = _calculateSelectedTokens(selectedIds);
          final isOverLimit = selectedTokens > availableTokens;
          
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Files for Context'),
                const SizedBox(height: 4),
                Text(
                  'Token usage: $selectedTokens / $availableTokens',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverLimit ? Colors.red : Colors.grey[600],
                    fontWeight: isOverLimit ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (isOverLimit)
                  const Text(
                    'Warning: Exceeds token limit!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: sortedFiles.length,
                itemBuilder: (context, index) {
                  final file = sortedFiles[index];
                  final isSelected = selectedIds.contains(file.id);
                  final fileTokens = _estimateTokens(file.content ?? '');
                  
                  return CheckboxListTile(
                    title: Text(file.name),
                    subtitle: Text(
                      'Words: ${file.wordCount} • Tokens: ~$fileTokens',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedIds.add(file.id);
                        } else {
                          selectedIds.remove(file.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isOverLimit 
                  ? null  // Disable if over limit
                  : () => Navigator.of(context).pop(selectedIds),
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: isOverLimit ? Colors.grey : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      await conversationProvider.updateContextSettings(
        activeConversation.contextSettings.copyWith(
          selectedFileIds: result,
        ),
      );
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        border: Border(
          top: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Quick actions above text input
          _buildQuickActions(),
          const SizedBox(height: 12),
          // Text input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'ask about your journal...',
                    hintStyle: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: AppTheme.mediumGray,
                      fontSize: 12.0,
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppTheme.warmBrown.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppTheme.warmBrown.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: AppTheme.warmBrown,
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.darkText,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: !_isProcessingAI,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isProcessingAI ? null : _sendMessage,
                icon: _isProcessingAI
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: AppTheme.warmBrown,
                        size: 18,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 