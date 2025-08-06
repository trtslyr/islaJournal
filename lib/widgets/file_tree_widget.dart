import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_folder.dart';
import '../models/journal_file.dart';
import '../models/file_sort_option.dart';
import '../core/theme/app_theme.dart';
import '../services/validation_service.dart';
import '../services/database_service.dart';


class FileTreeWidget extends StatefulWidget {
  final bool showHeader; // Parameter to control header visibility
  
  const FileTreeWidget({super.key, this.showHeader = true});

  @override
  State<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends State<FileTreeWidget> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        final handled = _handleKeyPress(event, context);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: _buildFileTree(context),
    );
  }

  Widget _buildFileTree(BuildContext context) {
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
                    const Text(
                      'files',
                      style: TextStyle(
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
            // Sorting controls - always show
            _buildSortingControls(provider),
            // File tree
            Expanded(
              child: DragTarget<JournalFile>(
                onWillAcceptWithDetails: (details) => details.data.folderId != null,
                onAcceptWithDetails: (details) => _moveFileToRoot(details.data, provider),
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  
                  return Container(
                    decoration: isHighlighted
                        ? BoxDecoration(
                            color: AppTheme.warmBrown.withOpacity(0.05),
                            border: Border.all(
                              color: AppTheme.warmBrown.withOpacity(0.3),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    child: ListView(
                      children: [
                        // Pinned files section - now scrollable inline
                        ..._buildPinnedSection(provider),
                        // Regular folders only (pinned folders appear in pinned section)
                        ...provider.rootFolders.where((folder) => !folder.isPinned).map((folder) => _buildFolderTile(folder, provider)),
                        // Regular files only (excluding pinned files)
                        ..._buildRootFilesWithDropZones(
                          _getSortedFiles(provider.files.where((file) => file.folderId == null && !file.isPinned).toList(), provider),
                          provider,
                        ),
                        // Empty space at the bottom for dropping
                        if (isHighlighted)
                          Container(
                            height: 60,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.warmBrown.withOpacity(0.5),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Drop here to move to root',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 12,
                                  color: AppTheme.mediumGray,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Get sorted files from the provider
  List<JournalFile> _getSortedFiles(List<JournalFile> files, JournalProvider provider) {
    return provider.getSortedFiles(files);
  }

  /// Build sorting and filtering controls
  Widget _buildSortingControls(JournalProvider provider) {
    final selectedCount = provider.selectedFileIds.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.darkerCream,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.warmBrown.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Sort dropdown
          Expanded(
            child: GestureDetector(
              onTap: () => _showSortMenu(context, provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.warmBrown.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        provider.sortOption.shortDisplayName,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11.0,
                          color: AppTheme.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: AppTheme.mediumGray,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Selection counter
          if (selectedCount > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warmBrown,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedCount',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => provider.clearFileSelection(),
                    child: const Icon(
                      Icons.clear,
                      size: 12,
                      color: Colors.white,
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

  /// Show sorting menu
  void _showSortMenu(BuildContext context, JournalProvider provider) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + 16,
        position.dy + 100,
        position.dx + 200,
        position.dy + 200,
      ),
             items: <PopupMenuEntry<Object?>>[
         // Sort options
         const PopupMenuItem<String>(
           enabled: false,
           child: Text(
             'Sort by:',
             style: TextStyle(
               fontFamily: 'JetBrainsMono',
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: AppTheme.mediumGray,
             ),
           ),
         ),
         ...FileSortType.values.map((sortType) {
           final option = FileSortOption(sortType: sortType, filterType: provider.sortOption.filterType);
           return PopupMenuItem<FileSortOption>(
             value: option,
             child: Row(
               children: [
                 Icon(
                   provider.sortOption.sortType == sortType ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                   size: 16,
                   color: AppTheme.warmBrown,
                 ),
                 const SizedBox(width: 8),
                 Text(
                   option.sortDisplayName,
                   style: const TextStyle(
                     fontFamily: 'JetBrainsMono',
                     fontSize: 12,
                   ),
                 ),
               ],
             ),
           );
         }).cast<PopupMenuEntry<Object?>>(),
         const PopupMenuDivider(),
         // Filter options
         const PopupMenuItem<String>(
           enabled: false,
           child: Text(
             'Show:',
             style: TextStyle(
               fontFamily: 'JetBrainsMono',
               fontSize: 12,
               fontWeight: FontWeight.w600,
               color: AppTheme.mediumGray,
             ),
           ),
         ),
         ...FileFilterType.values.map((filterType) {
           final option = FileSortOption(sortType: provider.sortOption.sortType, filterType: filterType);
           return PopupMenuItem<FileSortOption>(
             value: option,
             child: Row(
               children: [
                 Icon(
                   provider.sortOption.filterType == filterType ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                   size: 16,
                   color: AppTheme.warmBrown,
                 ),
                 const SizedBox(width: 8),
                 Text(
                   option.filterDisplayName,
                   style: const TextStyle(
                     fontFamily: 'JetBrainsMono',
                     fontSize: 12,
                   ),
                 ),
               ],
             ),
           );
         }).cast<PopupMenuEntry<Object?>>(),
       ],
    ).then((selectedOption) {
      if (selectedOption != null && selectedOption is FileSortOption) {
        provider.setSortOption(selectedOption);
      }
    });
  }





  /// Build pinned files section - user-selected files for AI context
  List<Widget> _buildPinnedSection(JournalProvider provider) {
    final pinnedFiles = provider.files.where((file) => 
      file.isPinned && 
      file.folderId == null
    ).toList();
    
    final pinnedFolders = provider.folders.where((folder) => folder.isPinned).toList();
    
    if (pinnedFiles.isEmpty && pinnedFolders.isEmpty) {
      // Show empty drop zone when no pinned files
      return [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkerCream,
            borderRadius: BorderRadius.circular(4),
          ),
          margin: const EdgeInsets.only(bottom: 8.0),
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (details) {
              final data = details.data;
              if (data is JournalFile && !data.isPinned) return true;
              if (data is JournalFolder && !data.isPinned) return true;
              return false;
            },
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data is JournalFile) {
                _pinFileFromDrag(data);
              } else if (data is JournalFolder) {
                _pinFolderFromDrag(data);
              }
            },
            builder: (context, candidateData, rejectedData) {
              final isHighlighted = candidateData.isNotEmpty;
              
              return Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isHighlighted 
                    ? AppTheme.warmBrown.withOpacity(0.1)
                    : AppTheme.darkerCream,
                  border: isHighlighted 
                    ? Border.all(
                        color: AppTheme.warmBrown.withOpacity(0.3),
                        width: 2,
                      )
                    : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    isHighlighted 
                      ? 'Drop here to pin'
                      : 'Drag files or folders here to pin them',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: isHighlighted 
                        ? AppTheme.warmBrown
                        : AppTheme.mediumGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ];
    }
    
    // Show pinned files with drag target around them
    return [
      Container(
        decoration: BoxDecoration(
          color: AppTheme.darkerCream,
          borderRadius: BorderRadius.circular(4),
        ),
        margin: const EdgeInsets.only(bottom: 8.0),
        child: DragTarget<Object>(
          onWillAcceptWithDetails: (details) {
            final data = details.data;
            if (data is JournalFile && !data.isPinned) return true;
            if (data is JournalFolder && !data.isPinned) return true;
            return false;
          },
          onAcceptWithDetails: (details) {
            final data = details.data;
            if (data is JournalFile) {
              _pinFileFromDrag(data);
            } else if (data is JournalFolder) {
              _pinFolderFromDrag(data);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHighlighted = candidateData.isNotEmpty;
            
            return Container(
              decoration: BoxDecoration(
                color: isHighlighted 
                  ? AppTheme.warmBrown.withOpacity(0.1)
                  : AppTheme.darkerCream,
                border: isHighlighted 
                  ? Border.all(
                      color: AppTheme.warmBrown.withOpacity(0.3),
                      width: 2,
                    )
                  : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pinned folders list
                  ...pinnedFolders.map((folder) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: _buildPinnedFolderTile(folder, provider),
                  )),
                  // Pinned files list
                  ...pinnedFiles.map((file) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: _buildPinnedFileTile(file, provider),
                  )),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  /// Build a pinned folder tile with hyphen instead of bullet  
  Widget _buildPinnedFolderTile(JournalFolder folder, JournalProvider provider) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final subfolders = provider.folders.where((f) => f.parentId == folder.id && !f.isPinned).toList();
    final folderFiles = provider.files.where((f) => f.folderId == folder.id && !f.isPinned).toList();
    final sortedFiles = _getSortedFiles(folderFiles, provider);
    final hasChildren = subfolders.isNotEmpty || sortedFiles.isNotEmpty;

    return Column(
      children: [
        Draggable<JournalFolder>(
          data: folder,
          feedback: Material(
            elevation: 4.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.creamBeige,
                border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '-',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12.0,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _HoverableTile(
              leading: Text(
                hasChildren
                    ? (isExpanded ? '▼' : '▶')
                    : '-',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                  color: AppTheme.mediumGray,
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
              subtitle: const Text(
                'folder',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.mediumGray,
                ),
              ),
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
          ),
          child: _HoverableTile(
            leading: Text(
              hasChildren
                  ? (isExpanded ? '▼' : '▶')
                  : '-',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: AppTheme.mediumGray,
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
                         subtitle: const Text(
               'folder',
               style: TextStyle(
                 fontFamily: 'JetBrainsMono',
                 fontSize: 12.0,
                 fontWeight: FontWeight.w400,
                 color: AppTheme.mediumGray,
               ),
             ),
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
        ),
        if (isExpanded && hasChildren)
          Container(
            margin: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: [
                ...subfolders.map((subfolder) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: _buildPinnedFolderTile(subfolder, provider),
                )),
                ...sortedFiles.map((file) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: _buildPinnedFileTile(file, provider),
                )),
              ],
            ),
          ),
      ],
    );
  }

  /// Build a pinned file tile with hyphen instead of bullet
  Widget _buildPinnedFileTile(JournalFile file, JournalProvider provider) {
    final isSelected = provider.isFileSelected(file.id);
    final isMainSelected = provider.selectedFileId == file.id;
    
    return Draggable<JournalFile>(
      data: file,
      feedback: Material(
        elevation: 4.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.creamBeige,
            border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '-',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                  color: AppTheme.mediumGray,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                file.name,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _HoverableTile(
          leading: const Text(
            '-',
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
              fontWeight: isMainSelected ? FontWeight.w600 : (isSelected ? FontWeight.w500 : FontWeight.w400),
              color: isMainSelected ? AppTheme.warmBrown : (isSelected ? AppTheme.darkerBrown : AppTheme.darkText),
            ),
          ),
          isSelected: isSelected,
          onTap: () => _handleFileTap(file.id, provider),
          onContextMenu: (context) => _showFileContextMenu(context, file),
        ),
      ),
      child: _HoverableTile(
        leading: const Text(
          '-',
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
            fontWeight: isMainSelected ? FontWeight.w600 : (isSelected ? FontWeight.w500 : FontWeight.w400),
            color: isMainSelected ? AppTheme.warmBrown : (isSelected ? AppTheme.darkerBrown : AppTheme.darkText),
          ),
        ),
        isSelected: isSelected,
        onTap: () => _handleFileTap(file.id, provider),
        onContextMenu: (context) => _showFileContextMenu(context, file),
      ),
    );
  }

  /// Pin a folder from drag and drop
  void _pinFolderFromDrag(JournalFolder folder) async {
    try {
      final provider = Provider.of<JournalProvider>(context, listen: false);
      
      // CRITICAL FIX: Get the fresh folder data from provider
      final freshFolder = provider.getFolderById(folder.id);
      if (freshFolder == null) {
        throw Exception('Folder not found');
      }
      
      final updatedFolder = freshFolder.copyWith(isPinned: true);
      await provider.updateFolder(updatedFolder);
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pinned folder "${folder.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pin folder "${folder.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Pin a file from drag and drop
  void _pinFileFromDrag(JournalFile file) async {
    try {
      final provider = Provider.of<JournalProvider>(context, listen: false);
      
      // CRITICAL FIX: Get the fresh file data with current content from database
      final freshFile = await provider.getFile(file.id);
      if (freshFile == null) {
        throw Exception('File not found');
      }
      
      final updatedFile = freshFile.copyWith(isPinned: true);
      await provider.updateFile(updatedFile);
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pinned "${file.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pin "${file.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle keyboard shortcuts
  bool _handleKeyPress(KeyEvent event, BuildContext context) {
    if (event is KeyDownEvent) {
      final provider = Provider.of<JournalProvider>(context, listen: false);
      final isCtrlPressed = event.logicalKey == LogicalKeyboardKey.controlLeft ||
                           event.logicalKey == LogicalKeyboardKey.controlRight;
      final isMetaPressed = event.logicalKey == LogicalKeyboardKey.metaLeft ||
                           event.logicalKey == LogicalKeyboardKey.metaRight;
      final isModifierPressed = isCtrlPressed || isMetaPressed;

      // Ctrl+A / Cmd+A: Select all files
      if (isModifierPressed && event.logicalKey == LogicalKeyboardKey.keyA) {
        final currentFiles = provider.files
            .where((file) => file.folderId == provider.selectedFolderId && !provider.isProfileFile(file.id))
            .toList();
        
        provider.clearFileSelection();
        for (final file in currentFiles) {
          provider.toggleFileSelection(file.id);
        }
        return true;
      }

      // Escape: Clear selection
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        provider.clearFileSelection();
        return true;
      }

      // Delete: Delete selected files
      if (event.logicalKey == LogicalKeyboardKey.delete && provider.selectedFileIds.isNotEmpty) {
        if (provider.selectedFileIds.length == 1) {
          final fileId = provider.selectedFileIds.first;
          final file = provider.files.firstWhere((f) => f.id == fileId);
          _showDeleteFileDialog(context, file);
        } else {
          _showDeleteMultipleFilesDialog(context, provider.selectedFileIds);
        }
        return true;
      }
    }
    return false;
  }

  /// Handle file tap with keyboard modifier support
  void _handleFileTap(String fileId, JournalProvider provider) {
    // Check for keyboard modifiers
    final isShiftPressed = HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
                          HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);
    final isCtrlPressed = HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                         HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlRight);
    final isMetaPressed = HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.metaLeft) ||
                         HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.metaRight);
    
    final isMultiSelectModifier = isCtrlPressed || isMetaPressed; // Ctrl on Windows/Linux, Cmd on Mac
    
    if (isShiftPressed && provider.selectedFileIds.isNotEmpty) {
      // Range selection: select from last selected to this file
      final lastSelectedId = provider.selectedFileIds.last;
      provider.selectFileRange(lastSelectedId, fileId);
    } else if (isMultiSelectModifier) {
      // Toggle selection: add/remove from multi-selection
      provider.toggleFileSelection(fileId);
    } else {
      // Normal selection: clear others and select this file
      provider.selectFile(fileId);
    }
  }


  Widget _buildFolderTile(JournalFolder folder, JournalProvider provider) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final subfolders = provider.folders.where((f) => f.parentId == folder.id).toList();
    final folderFiles = provider.files.where((f) => f.folderId == folder.id).toList();
    final sortedFiles = _getSortedFiles(folderFiles, provider);
    final hasChildren = subfolders.isNotEmpty || sortedFiles.isNotEmpty;

    return Column(
      children: [
        Draggable<JournalFolder>(
          data: folder,
          feedback: Material(
            elevation: 4.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.creamBeige,
                border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '📁',
                    style: TextStyle(fontSize: 12.0),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: DragTarget<JournalFile>(
            onWillAcceptWithDetails: (details) => details.data != null && details.data.folderId != folder.id,
            onAcceptWithDetails: (details) => _moveFileToFolder(details.data, folder, provider),
            builder: (context, candidateData, rejectedData) {
              final isHighlighted = candidateData.isNotEmpty;
              
              return Container(
                decoration: isHighlighted
                    ? BoxDecoration(
                        color: AppTheme.warmBrown.withOpacity(0.1),
                        border: Border.all(
                          color: AppTheme.warmBrown.withOpacity(0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: _HoverableTile(
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
              );
            },
          ),
        ),
        if (isExpanded && hasChildren)
          Container(
            margin: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: [
                ...subfolders.where((subfolder) => !subfolder.isPinned).map((subfolder) => _buildFolderTile(subfolder, provider)),
                ...sortedFiles.where((file) => !file.isPinned).map((file) => _buildFileTile(file, provider)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(JournalFile file, JournalProvider provider) {
    final isSelected = provider.isFileSelected(file.id);
    final isMainSelected = provider.selectedFileId == file.id;
    
    return Draggable<JournalFile>(
      data: file,
      feedback: Material(
        elevation: 4.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.creamBeige,
            border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                file.isPinned ? '📌' : '•',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                  color: file.isPinned ? AppTheme.warmBrown : AppTheme.mediumGray,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                file.name,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _HoverableTile(
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
              fontWeight: isMainSelected ? FontWeight.w600 : (isSelected ? FontWeight.w500 : FontWeight.w400),
              color: isMainSelected ? AppTheme.warmBrown : (isSelected ? AppTheme.darkerBrown : AppTheme.darkText),
            ),
          ),
          isSelected: isSelected,
          onTap: () => _handleFileTap(file.id, provider),
          onContextMenu: (context) => _showFileContextMenu(context, file),
        ),
      ),
      child: _HoverableTile(
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
            fontWeight: isMainSelected ? FontWeight.w600 : (isSelected ? FontWeight.w500 : FontWeight.w400),
            color: isMainSelected ? AppTheme.warmBrown : (isSelected ? AppTheme.darkerBrown : AppTheme.darkText),
          ),
        ),
        isSelected: isSelected,
        onTap: () => _handleFileTap(file.id, provider),
        onContextMenu: (context) => _showFileContextMenu(context, file),
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
                      _buildMenuItem(folder.isPinned ? 'unpin' : 'pin', () {
                        Navigator.of(context).pop();
                        _toggleFolderPin(folder);
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
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final selectedCount = provider.selectedFileIds.length;
    final isMultiSelect = selectedCount > 1;
    
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
                      if (isMultiSelect) ...[
                        _buildMenuItem('$selectedCount files selected', () {}),
                        Container(height: 1, color: AppTheme.warmBrown.withOpacity(0.3)),
                        _buildMenuItem('delete selected', () {
                          Navigator.of(context).pop();
                          _showDeleteMultipleFilesDialog(context, provider.selectedFileIds);
                        }),
                        _buildMenuItem('clear selection', () {
                          Navigator.of(context).pop();
                          provider.clearFileSelection();
                        }),
                      ] else ...[
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
                        _buildMenuItem(file.isPinned ? 'unpin' : 'pin', () {
                          Navigator.of(context).pop();
                          _toggleFilePin(file);
                        }),
                        Container(height: 1, color: AppTheme.warmBrown.withOpacity(0.3)),
                        _buildMenuItem('delete', () {
                          Navigator.of(context).pop();
                          _showDeleteFileDialog(context, file);
                        }),
                      ],
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
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('create folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  hintText: 'my folder',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: true);
                    if (errorMessage == null) {
                      // Check for duplicates
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      final existingNames = provider.folders
                          .where((f) => f.parentId == provider.selectedFolderId)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFolderNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A folder with this name already exists';
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
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && nameController.text.trim().isNotEmpty
                  ? () async {
                      final name = nameController.text.trim();
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      await provider.createFolder(name);
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFileDialog(BuildContext context) {
    final nameController = TextEditingController();
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('create file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  hintText: 'my journal entry',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: false);
                    if (errorMessage == null) {
                      // Check for duplicates in root level (where new files are created)
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      final existingNames = provider.files
                          .where((f) => f.folderId == null)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFileNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A file with this name already exists';
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
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && nameController.text.trim().isNotEmpty
                  ? () async {
                      final name = nameController.text.trim();
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      final fileId = await provider.createFile(name, '');
                      if (fileId != null) {
                        provider.selectFile(fileId);
                      }
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, JournalFolder folder) {
    final nameController = TextEditingController(text: folder.name);
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('rename folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: true);
                    if (errorMessage == null && value.trim() != folder.name) {
                      // Check for duplicates (exclude current folder)
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      final existingNames = provider.folders
                          .where((f) => f.parentId == folder.parentId && f.id != folder.id)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFolderNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A folder with this name already exists';
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
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && 
                         nameController.text.trim().isNotEmpty && 
                         nameController.text.trim() != folder.name
                  ? () async {
                      final name = nameController.text.trim();
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      await provider.updateFolder(folder.copyWith(name: name));
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('rename'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFileDialog(BuildContext context, JournalFile file) {
    final nameController = TextEditingController(text: file.name);
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('rename file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'name',
                  errorText: errorMessage,
                ),
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    errorMessage = ValidationService.validateName(value.trim(), isFolder: false);
                    if (errorMessage == null && value.trim() != file.name) {
                      // Check for duplicates (exclude current file)
                      final provider = Provider.of<JournalProvider>(context, listen: false);
                      final existingNames = provider.files
                          .where((f) => f.folderId == file.folderId && f.id != file.id)
                          .map((f) => f.name)
                          .toList();
                      if (ValidationService.isFileNameDuplicate(value.trim(), existingNames)) {
                        errorMessage = 'A file with this name already exists';
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
              child: const Text('cancel'),
            ),
            TextButton(
              onPressed: errorMessage == null && 
                         nameController.text.trim().isNotEmpty && 
                         nameController.text.trim() != file.name
                  ? () async {
                                          final name = nameController.text.trim();
                    final provider = Provider.of<JournalProvider>(context, listen: false);
                    await provider.updateFile(file.copyWith(
                      name: name,
                      isPinned: file.isPinned, // Preserve pin status
                    ));
                    Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('rename'),
            ),
          ],
        ),
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
      // Don't pass folderId - let the system automatically assign to year folder
      await provider.createFile('${file.name}_copy', originalFile.content);
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
                await provider.updateFile(file.copyWith(
              folderId: null,
              isPinned: file.isPinned, // Preserve pin status
            ));
                Navigator.of(context).pop();
              },
            ),
            ...provider.folders.map((folder) => ListTile(
              leading: const Text('• dir'),
              title: Text(folder.name),
              onTap: () async {
                await provider.updateFile(file.copyWith(
              folderId: folder.id,
              isPinned: file.isPinned, // Preserve pin status
            ));
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
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final folder = file.folderId != null ? provider.getFolderById(file.folderId!) : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'File Properties',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyRow('Name:', file.name),
              const SizedBox(height: 8),
              _buildPropertyRow('Location:', folder?.name ?? 'Root'),
              const SizedBox(height: 8),
              _buildPropertyRow('Size:', file.displaySize),
              const SizedBox(height: 8),
              _buildPropertyRow('Word Count:', '${file.wordCount} words'),
              const SizedBox(height: 8),
              _buildPropertyRow('Created:', _formatDateTime(file.createdAt)),
              const SizedBox(height: 8),
              _buildPropertyRow('Modified:', _formatDateTime(file.updatedAt)),
              const SizedBox(height: 8),
              _buildPropertyRow('File Path:', file.filePath),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: AppTheme.mediumGray,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Move a file to a specific folder
  void _moveFileToFolder(JournalFile file, JournalFolder folder, JournalProvider provider) async {
    try {
                    await provider.updateFile(file.copyWith(
                folderId: folder.id,
                isPinned: file.isPinned, // Preserve pin status
              ));
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved "${file.name}" to "${folder.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to move "${file.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Move a file to root (no folder)
  void _moveFileToRoot(JournalFile file, JournalProvider provider) async {
    try {
                    await provider.updateFile(file.copyWith(
                folderId: null,
                isPinned: file.isPinned, // Preserve pin status
              ));
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Moved "${file.name}" to root',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to move "${file.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Reorder a file to a specific position in the root files list
  void _reorderFileInRoot(JournalFile draggedFile, int newIndex, List<JournalFile> rootFiles, JournalProvider provider) async {
    try {
      // Show warning if user is reordering while last opened sorting is not active
      if (provider.sortOption.sortType != FileSortType.lastOpened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Manual reordering may be overridden by current sorting. Switch to "Last Opened" sort for manual control.',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
      
      // Remove the dragged file from the list to get the target position
      final filteredFiles = rootFiles.where((f) => f.id != draggedFile.id).toList();
      
      // Calculate the new timestamp based on position
      DateTime newTimestamp;
      if (newIndex == 0) {
        // Moving to first position - use time after the current first file
        if (filteredFiles.isNotEmpty) {
          newTimestamp = filteredFiles[0].lastOpened?.add(const Duration(seconds: 1)) ?? DateTime.now();
        } else {
          newTimestamp = DateTime.now();
        }
      } else if (newIndex >= filteredFiles.length) {
        // Moving to last position - use time before the current last file
        newTimestamp = filteredFiles.last.lastOpened?.subtract(const Duration(seconds: 1)) ?? DateTime.now().subtract(const Duration(seconds: 1));
      } else {
        // Moving between files - use time between the files at newIndex-1 and newIndex
        final prevFile = filteredFiles[newIndex - 1];
        final nextFile = filteredFiles[newIndex];
        final prevTime = prevFile.lastOpened ?? DateTime.now();
        final nextTime = nextFile.lastOpened ?? DateTime.now();
        
        // Calculate midpoint time
        final midpointMs = (prevTime.millisecondsSinceEpoch + nextTime.millisecondsSinceEpoch) ~/ 2;
        newTimestamp = DateTime.fromMillisecondsSinceEpoch(midpointMs);
      }
      
      // Update the file with new timestamp
      await provider.updateFile(draggedFile.copyWith(
        folderId: null, // Ensure it stays in root
        lastOpened: newTimestamp,
        isPinned: draggedFile.isPinned, // Preserve pin status
      ));
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reordered "${draggedFile.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to reorder "${draggedFile.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Build a drop zone for reordering files
  Widget _buildDropZone(int index, List<JournalFile> rootFiles, JournalProvider provider) {
    return DragTarget<JournalFile>(
      onWillAcceptWithDetails: (details) => details.data != null && details.data.folderId == null && rootFiles.any((f) => f.id == details.data.id),
      onAcceptWithDetails: (details) => _reorderFileInRoot(details.data, index, rootFiles, provider),
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isHighlighted ? 24 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          decoration: isHighlighted
              ? BoxDecoration(
                  color: AppTheme.warmBrown.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.warmBrown.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: isHighlighted
              ? const Center(
                  child: Text(
                    'Drop here to reorder',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: AppTheme.mediumGray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Build root files with drop zones for reordering
  List<Widget> _buildRootFilesWithDropZones(List<JournalFile> rootFiles, JournalProvider provider) {
    final List<Widget> widgets = [];
    
    // Add drop zone before first file
    widgets.add(_buildDropZone(0, rootFiles, provider));
    
    // Add files with drop zones between them
    for (int i = 0; i < rootFiles.length; i++) {
      widgets.add(_buildFileTile(rootFiles[i], provider));
      // Add drop zone after each file
      widgets.add(_buildDropZone(i + 1, rootFiles, provider));
    }
    
    return widgets;
  }

  void _showFolderProperties(BuildContext context, JournalFolder folder) {
    final provider = Provider.of<JournalProvider>(context, listen: false);
    final parentFolder = folder.parentId != null ? provider.getFolderById(folder.parentId!) : null;
    final subfolders = provider.folders.where((f) => f.parentId == folder.id).toList();
    final files = provider.files.where((f) => f.folderId == folder.id).toList();
    final totalWords = files.fold(0, (sum, file) => sum + file.wordCount);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Folder Properties',
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 16),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropertyRow('Name:', folder.name),
              const SizedBox(height: 8),
              _buildPropertyRow('Location:', parentFolder?.name ?? 'Root'),
              const SizedBox(height: 8),
              _buildPropertyRow('Subfolders:', '${subfolders.length}'),
              const SizedBox(height: 8),
              _buildPropertyRow('Files:', '${files.length}'),
              const SizedBox(height: 8),
              _buildPropertyRow('Total Words:', '$totalWords words'),
              const SizedBox(height: 8),
              _buildPropertyRow('Created:', _formatDateTime(folder.createdAt)),
              const SizedBox(height: 8),
              _buildPropertyRow('Modified:', _formatDateTime(folder.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }



  void _showDeleteMultipleFilesDialog(BuildContext context, Set<String> fileIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Multiple Files'),
        content: Text('Delete ${fileIds.length} selected files? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              Navigator.of(context).pop();
              
              // Delete all selected files
              for (final fileId in fileIds) {
                await provider.deleteFile(fileId);
              }
              
              // Clear selection after deletion
              provider.clearFileSelection();
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  /// Toggle pin status of a folder
  void _toggleFolderPin(JournalFolder folder) async {
    try {
      final provider = Provider.of<JournalProvider>(context, listen: false);
      
      // CRITICAL FIX: Get the fresh folder data from provider
      final freshFolder = provider.getFolderById(folder.id);
      if (freshFolder == null) {
        throw Exception('Folder not found');
      }
      
      final updatedFolder = freshFolder.copyWith(isPinned: !folder.isPinned);
      await provider.updateFolder(updatedFolder);
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              folder.isPinned ? 'Unpinned folder "${folder.name}"' : 'Pinned folder "${folder.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${folder.isPinned ? 'unpin' : 'pin'} folder "${folder.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Toggle pin status of a file
  void _toggleFilePin(JournalFile file) async {
    try {
      final provider = Provider.of<JournalProvider>(context, listen: false);
      
      // CRITICAL FIX: Get the fresh file data with current content from database
      final freshFile = await provider.getFile(file.id);
      if (freshFile == null) {
        throw Exception('File not found');
      }
      
      final updatedFile = freshFile.copyWith(isPinned: !file.isPinned);
      await provider.updateFile(updatedFile);
      
      // Show feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              file.isPinned ? 'Unpinned "${file.name}"' : 'Pinned "${file.name}"',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: AppTheme.warmBrown,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${file.isPinned ? 'unpin' : 'pin'} "${file.name}": ${e.toString()}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
              await provider.updateFile(file.copyWith(
                name: name,
                isPinned: file.isPinned, // Preserve pin status
              ));
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
              ? AppTheme.warmBrown.withOpacity(0.15)
              : _isHovering
                  ? AppTheme.warmBrown.withOpacity(0.05)
                  : null,
          border: widget.isSelected
              ? Border.all(
                  color: AppTheme.warmBrown.withOpacity(0.3),
                  width: 1,
                )
              : null,
          borderRadius: widget.isSelected ? BorderRadius.circular(4) : null,
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