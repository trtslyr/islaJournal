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
      
      setState(() {
        _isInitialized = true;
      });
      print('✅ Conversation initialization complete');
    } catch (e) {
      print('🔴 Error initializing conversation: $e');
      setState(() {
        _isInitialized = true; // Still show UI even if initialization failed
      });
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
    
    setState(() {
      _messages = messages;
    });
    
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
          // Chat title dropdown on the left
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                final activeConversation = provider.activeConversation;
                return PopupMenuButton<String>(
                  onSelected: (conversationId) async {
                    print('🔄 Switching to conversation: $conversationId');
                    final conversation = provider.getConversationById(conversationId);
                    if (conversation != null) {
                      print('✅ Found conversation: ${conversation.title} with ${conversation.history.length} messages');
                      print('📋 Context mode: ${conversation.contextSettings.mode}');
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
          ),
          // Tool buttons on the right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Context
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
                  final activeConversation = conversationProvider.activeConversation;
                  if (activeConversation == null) return;

                  final currentSettings = activeConversation.contextSettings;
                  
                                       switch (value) {
                       case 'general':
                         print('🔧 Updating context to General mode');
                         await activeConversation.updateContextSettings(ContextSettings.general);
                         break;
                       case 'timeframe':
                         print('🔧 Updating context to Timeframe mode');
                         await _showTimeframeSelector(activeConversation, currentSettings);
                         break;
                       case 'custom':
                         print('🔧 Updating context to Custom mode');
                         await _showCustomFileSelector(activeConversation, currentSettings);
                         break;
                     }
                },
                itemBuilder: (context) {
                  final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
                  final activeConversation = conversationProvider.activeConversation;
                  final currentSettings = activeConversation?.contextSettings ?? ContextSettings.general;
                  
                  return [
                    PopupMenuItem<String>(
                      value: 'general',
                      child: Row(
                        children: [
                          if (currentSettings.mode == ContextMode.general) 
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          if (currentSettings.mode == ContextMode.general) 
                            const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('General Context', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
                                Text('Recent + relevant + long-term', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'timeframe',
                      child: Row(
                        children: [
                          if (currentSettings.mode == ContextMode.timeframe) 
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          if (currentSettings.mode == ContextMode.timeframe) 
                            const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Timeframe', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
                                Text(
                                  currentSettings.mode == ContextMode.timeframe
                                      ? currentSettings.timeframe?.displayName ?? 'Select period'
                                      : 'Select time period',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'custom',
                      child: Row(
                        children: [
                          if (currentSettings.mode == ContextMode.custom) 
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          if (currentSettings.mode == ContextMode.custom) 
                            const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Custom', style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12)),
                                Text(
                                  currentSettings.mode == ContextMode.custom
                                      ? '${currentSettings.customFileIds.length} files selected'
                                      : 'Select specific files',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: const Text(
                  'context',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.warmBrown,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // New chat on far right
              TextButton(
                onPressed: _createNewChat,
                style: TextButton.styleFrom(
                  overlayColor: Colors.transparent,
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
            ],
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
        
        if (journalProvider.selectedFileId == null) {
          return const Center(
            child: Text(
              'select a file to chat about it',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
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
    setState(() {
      _messages.add(ChatMessage(
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isProcessingAI = true;
    });

    _chatController.clear();
    _scrollToBottom();

    try {
      // Add user message to conversation
      await activeConversation.addUserMessage(message);
      
      // Get AI response using existing JournalCompanionService
      final response = await JournalCompanionService().generateInsights(
        message,
        conversation: activeConversation,
      );
      
      // Add assistant response to conversation
      await activeConversation.addAssistantMessage(response);
      
      // Add AI response to chat
      setState(() {
        _messages.add(ChatMessage(
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      
      _scrollToBottom();
    } catch (e) {
      // Handle error
      setState(() {
        _messages.add(ChatMessage(
          content: 'Error: ${e.toString()}',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isProcessingAI = false;
      });
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
    
    setState(() {
      _messages.clear();
    });
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
        setState(() {
          _messages.clear();
        });
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

  Future<void> _showContextSettings() async {
    final conversationProvider = Provider.of<ConversationProvider>(context, listen: false);
    final activeConversation = conversationProvider.activeConversation;
    
    if (activeConversation == null) return;
    
    final currentSettings = activeConversation.contextSettings;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Context Settings'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${currentSettings.description}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.warmBrown,
                  ),
                ),
                const SizedBox(height: 16),
                
                // General Context Option
                ListTile(
                  leading: Radio<ContextMode>(
                    value: ContextMode.general,
                    groupValue: currentSettings.mode,
                    onChanged: (value) async {
                      if (value != null) {
                        await activeConversation.updateContextSettings(ContextSettings.general);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  title: const Text('General Context'),
                  subtitle: const Text('Recent + relevant + long-term entries (intelligent selection)'),
                ),
                
                // Timeframe Option
                ListTile(
                  leading: Radio<ContextMode>(
                    value: ContextMode.timeframe,
                    groupValue: currentSettings.mode,
                    onChanged: (value) async {
                      if (value != null) {
                        await _showTimeframeSelector(activeConversation, currentSettings);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  title: const Text('Timeframe'),
                  subtitle: Text(
                    currentSettings.mode == ContextMode.timeframe
                        ? 'Entries from ${currentSettings.timeframe?.displayName ?? 'Not set'}'
                        : 'Entries from a specific time period'
                  ),
                ),
                
                // Custom Option
                ListTile(
                  leading: Radio<ContextMode>(
                    value: ContextMode.custom,
                    groupValue: currentSettings.mode,
                    onChanged: (value) async {
                      if (value != null) {
                        await _showCustomFileSelector(activeConversation, currentSettings);
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  title: const Text('Custom'),
                  subtitle: Text(
                    currentSettings.mode == ContextMode.custom
                        ? '${currentSettings.customFileIds.length} files selected'
                        : 'Select specific files for context'
                  ),
                ),
                
                const SizedBox(height: 16),
                Text(
                  'Token limit: ${currentSettings.maxTokens}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
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
  
  Future<void> _showTimeframeSelector(ConversationSession conversation, ContextSettings currentSettings) async {
    final selectedTimeframe = await showDialog<TimeframeOption>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Timeframe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TimeframeOption.values.map((timeframe) => ListTile(
            title: Text(timeframe.displayName),
            onTap: () => Navigator.of(context).pop(timeframe),
          )).toList(),
        ),
      ),
    );
    
    if (selectedTimeframe != null) {
      await conversation.updateContextSettings(
        currentSettings.copyWith(
          mode: ContextMode.timeframe,
          timeframe: selectedTimeframe,
        ),
      );
    }
  }
  
  Future<void> _showCustomFileSelector(ConversationSession conversation, ContextSettings currentSettings) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final files = journalProvider.files;
    
    final selectedIds = List<String>.from(currentSettings.customFileIds);
    
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Files'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final isSelected = selectedIds.contains(file.id);
                
                return CheckboxListTile(
                  title: Text(file.name),
                  subtitle: Text(
                    'Words: ${file.wordCount}',
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
              onPressed: () => Navigator.of(context).pop(selectedIds),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    
    if (result != null) {
      await conversation.updateContextSettings(
        currentSettings.copyWith(
          mode: ContextMode.custom,
          customFileIds: result,
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