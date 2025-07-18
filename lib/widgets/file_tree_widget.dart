import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_folder.dart';
import '../models/journal_file.dart';
import '../core/theme/app_theme.dart';

class FileTreeWidget extends StatefulWidget {
  final bool showHeader; // Parameter to control header visibility
  final bool sortByLastOpened; // Parameter to control sorting by last opened date
  
  const FileTreeWidget({super.key, this.showHeader = true, this.sortByLastOpened = false});

  @override
  State<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends State<FileTreeWidget> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<JournalProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
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

        return Column(
          children: [
            // Header - only show if showHeader is true
            if (widget.showHeader)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.warmBrown.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getProfileName(provider),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => _showCreateFolderDialog(context),
                          child: const Text(
                            '+dir',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => _showCreateFileDialog(context),
                          child: const Text(
                            '+file',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // File tree
            Expanded(
              child: ListView(
                children: [
                  // Profile file pinned at top
                  ..._buildProfileSection(provider),
                  // Root folders
                  ...provider.rootFolders.map((folder) => _buildFolderTile(folder, provider)),
                  // Root files - sorted by last opened if requested (excluding profile)
                  ..._getSortedFiles(provider.files.where((file) => file.folderId == null && !provider.isProfileFile(file.id)).toList())
                    .map((file) => _buildFileTile(file, provider)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Sort files by last opened date if sortByLastOpened is true
  List<JournalFile> _getSortedFiles(List<JournalFile> files) {
    if (!widget.sortByLastOpened) {
      return files;
    }
    
    // Sort by last opened date (most recent first), then by updated date for files never opened
    files.sort((a, b) {
      final aDate = a.lastOpened ?? a.updatedAt;
      final bDate = b.lastOpened ?? b.updatedAt;
      return bDate.compareTo(aDate); // Most recent first
    });
    
    return files;
  }

  /// Get profile name for display in header
  String _getProfileName(JournalProvider provider) {
    final profileFile = provider.files.where((file) => provider.isProfileFile(file.id)).firstOrNull;
    return profileFile?.name ?? 'files';
  }

  /// Build profile section - pinned at top
  List<Widget> _buildProfileSection(JournalProvider provider) {
    final profileFile = provider.files.where((file) => provider.isProfileFile(file.id)).firstOrNull;
    
    if (profileFile == null) {
      return [];
    }
    
    return [
      _buildProfileTile(profileFile, provider),
      // Add a subtle separator after profile
      Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.warmBrown.withOpacity(0.1),
      ),
    ];
  }

  /// Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'never';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildFolderTile(JournalFolder folder, JournalProvider provider) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final subfolders = provider.folders.where((f) => f.parentId == folder.id).toList();
    final folderFiles = provider.files.where((f) => f.folderId == folder.id).toList();
    final sortedFiles = _getSortedFiles(folderFiles);
    final hasChildren = subfolders.isNotEmpty || sortedFiles.isNotEmpty;

    return Column(
      children: [
        _HoverableTile(
          leading: Text(
            hasChildren
                ? (isExpanded ? '▼' : '▶')
                : '•',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.0,
              color: AppTheme.warmBrown,
            ),
          ),
          title: Text(
            folder.name,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
              color: AppTheme.darkText,
            ),
          ),
          trailing: hasChildren
              ? Text(
                  '${subfolders.length + sortedFiles.length}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.0,
                    color: AppTheme.mediumGray,
                  ),
                )
              : null,
          onTap: () {
            if (hasChildren) {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folder.id);
                } else {
                  _expandedFolders.add(folder.id);
                }
              });
            }
            provider.selectFolder(folder.id);
          },
          onContextMenu: (context) => _showFolderContextMenu(context, folder),
        ),
        if (isExpanded && hasChildren)
          Container(
            margin: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: [
                ...subfolders.map((subfolder) => _buildFolderTile(subfolder, provider)),
                ...sortedFiles.map((file) => _buildFileTile(file, provider)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(JournalFile file, JournalProvider provider) {
    final isSelected = provider.selectedFileId == file.id;
    
    return _HoverableTile(
      leading: const Text(
        '•',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          color: AppTheme.mediumGray,
        ),
      ),
      title: Text(
        file.name,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 14.0,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppTheme.warmBrown : AppTheme.darkText,
        ),
      ),
      subtitle: Text(
        _formatDate(file.lastOpened),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          color: AppTheme.mediumGray,
        ),
      ),
      isSelected: isSelected,
      onTap: () => provider.selectFile(file.id),
      onContextMenu: (context) => _showFileContextMenu(context, file),
    );
  }

  Widget _buildProfileTile(JournalFile file, JournalProvider provider) {
    final isSelected = provider.selectedFileId == file.id;
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.warmBrown.withOpacity(0.1)
            : null,
      ),
      child: ListTile(
        leading: const Text(
          '•',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12.0,
            color: AppTheme.mediumGray,
          ),
        ),
        title: Text(
          file.name,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.warmBrown : AppTheme.darkText,
          ),
        ),
        onTap: () => provider.selectFile(file.id),
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, JournalFolder folder) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible barrier that closes the menu when tapped
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned at the button location
          Positioned(
            left: buttonPosition.dx,
            top: buttonPosition.dy + button.size.height,
            child: Material(
              color: AppTheme.creamBeige,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.creamBeige,
                  border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem('rename', () {
                        Navigator.of(context).pop();
                        _showRenameFolderDialog(context, folder);
                      }),
                      _buildMenuItem('duplicate', () {
                        Navigator.of(context).pop();
                        _duplicateFolder(folder);
                      }),
                      _buildMenuItem('properties', () {
                        Navigator.of(context).pop();
                        _showFolderProperties(context, folder);
                      }),
                      Container(height: 1, color: AppTheme.warmBrown.withOpacity(0.3)),
                      _buildMenuItem('delete', () {
                        Navigator.of(context).pop();
                        _showDeleteFolderDialog(context, folder);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFileContextMenu(BuildContext context, JournalFile file) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible barrier that closes the menu when tapped
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned at the button location
          Positioned(
            left: buttonPosition.dx,
            top: buttonPosition.dy + button.size.height,
            child: Material(
              color: AppTheme.creamBeige,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.creamBeige,
                  border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem('rename', () {
                        Navigator.of(context).pop();
                        _showRenameFileDialog(context, file);
                      }),
                      _buildMenuItem('duplicate', () {
                        Navigator.of(context).pop();
                        _duplicateFile(file);
                      }),
                      _buildMenuItem('move to...', () {
                        Navigator.of(context).pop();
                        _showMoveFileDialog(context, file);
                      }),
                      _buildMenuItem('properties', () {
                        Navigator.of(context).pop();
                        _showFileProperties(context, file);
                      }),
                      Container(height: 1, color: AppTheme.warmBrown.withOpacity(0.3)),
                      _buildMenuItem('delete', () {
                        Navigator.of(context).pop();
                        _showDeleteFileDialog(context, file);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileContextMenu(BuildContext context, JournalFile file) {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Invisible barrier that closes the menu when tapped
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned at the button location
          Positioned(
            left: buttonPosition.dx,
            top: buttonPosition.dy + button.size.height,
            child: Material(
              color: AppTheme.creamBeige,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.creamBeige,
                  border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem('properties', () {
                        Navigator.of(context).pop();
                        _showFileProperties(context, file);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
            fontWeight: FontWeight.w400,
            color: AppTheme.darkText,
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text('create folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'name',
            hintText: 'my folder',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.createFolder(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('create'),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text('create file'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'name',
            hintText: 'my journal entry',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                final fileId = await provider.createFile(name, '');
                if (fileId != null) {
                  provider.selectFile(fileId);
                }
                Navigator.of(context).pop();
              }
            },
            child: const Text('create'),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, JournalFolder folder) {
    final nameController = TextEditingController(text: folder.name);
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text('rename folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != folder.name) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFolder(folder.copyWith(name: name));
                Navigator.of(context).pop();
              }
            },
            child: const Text('rename'),
          ),
        ],
      ),
    );
  }

  void _showRenameFileDialog(BuildContext context, JournalFile file) {
    final nameController = TextEditingController(text: file.name);
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => AlertDialog(
        title: const Text('rename file'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != file.name) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFile(file.copyWith(name: name));
                Navigator.of(context).pop();
              }
            },
            child: const Text('rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, JournalFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('delete folder'),
        content: Text('delete "${folder.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              await provider.deleteFolder(folder.id);
              Navigator.of(context).pop();
            },
            child: const Text('delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFileDialog(BuildContext context, JournalFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('delete file'),
        content: Text('delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              await provider.deleteFile(file.id);
              Navigator.of(context).pop();
            },
            child: const Text('delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateFolder(JournalFolder folder) async {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    await provider.createFolder('${folder.name}_copy', parentId: folder.parentId);
  }

  void _duplicateFile(JournalFile file) async {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final originalFile = await provider.getFile(file.id);
    if (originalFile != null) {
      await provider.createFile('${file.name}_copy', originalFile.content, folderId: file.folderId);
    }
  }

  void _showMoveFileDialog(BuildContext context, JournalFile file) {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('move file'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('• root'),
              title: const Text('root'),
              onTap: () async {
                await provider.updateFile(file.copyWith(folderId: null));
                Navigator.of(context).pop();
              },
            ),
            ...provider.folders.map((folder) => ListTile(
              leading: const Text('• dir'),
              title: Text(folder.name),
              onTap: () async {
                await provider.updateFile(file.copyWith(folderId: folder.id));
                Navigator.of(context).pop();
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('cancel'),
          ),
        ],
      ),
    );
  }

  void _showFileProperties(BuildContext context, JournalFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('file properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('name: ${file.name}'),
            Text('created: ${file.createdAt.day}/${file.createdAt.month}/${file.createdAt.year}'),
            Text('modified: ${file.updatedAt.day}/${file.updatedAt.month}/${file.updatedAt.year}'),
            Text('last opened: ${_formatDate(file.lastOpened)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }

  void _showFolderProperties(BuildContext context, JournalFolder folder) {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final filesCount = provider.files.where((f) => f.folderId == folder.id).length;
    final subfoldersCount = provider.folders.where((f) => f.parentId == folder.id).length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('folder properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('name: ${folder.name}'),
            Text('files: $filesCount'),
            Text('subfolders: $subfoldersCount'),
            Text('created: ${folder.createdAt.day}/${folder.createdAt.month}/${folder.createdAt.year}'),
            Text('modified: ${folder.updatedAt.day}/${folder.updatedAt.month}/${folder.updatedAt.year}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileNameDialog(BuildContext context, JournalFile file, JournalProvider provider) {
    final nameController = TextEditingController(text: file.name);
    
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
              if (name.isNotEmpty && name != file.name) {
                await provider.updateFile(file.copyWith(name: name));
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

class _HoverableTile extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Function(BuildContext)? onContextMenu;
  final bool isSelected;

  const _HoverableTile({
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onContextMenu,
    this.isSelected = false,
  });

  @override
  State<_HoverableTile> createState() => _HoverableTileState();
}

class _HoverableTileState extends State<_HoverableTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.warmBrown.withOpacity(0.1)
              : _isHovering
                  ? AppTheme.warmBrown.withOpacity(0.05)
                  : null,
        ),
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          trailing: _isHovering && widget.onContextMenu != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.trailing != null) widget.trailing!,
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 16),
                      onPressed: () => widget.onContextMenu!(context),
                      tooltip: 'more options',
                    ),
                  ],
                )
              : widget.trailing,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}