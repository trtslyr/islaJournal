import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/journal_provider.dart';
import '../models/journal_folder.dart';
import '../models/journal_file.dart';
import '../core/theme/app_theme.dart';

class FileTreeWidget extends StatefulWidget {
  const FileTreeWidget({super.key});

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
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Header
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
                    'Files',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.create_new_folder),
                        onPressed: () => _showCreateFolderDialog(context),
                        tooltip: 'New Folder',
                      ),
                      IconButton(
                        icon: const Icon(Icons.note_add),
                        onPressed: () => _showCreateFileDialog(context),
                        tooltip: 'New File',
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
                  // Root folders
                  ...provider.rootFolders.map((folder) => _buildFolderTile(folder, provider)),
                  // Root files
                  ...provider.files.where((file) => file.folderId == null).map((file) => _buildFileTile(file, provider)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFolderTile(JournalFolder folder, JournalProvider provider) {
    final isExpanded = _expandedFolders.contains(folder.id);
    final subfolders = provider.folders.where((f) => f.parentId == folder.id).toList();
    final files = provider.files.where((f) => f.folderId == folder.id).toList();
    final hasChildren = subfolders.isNotEmpty || files.isNotEmpty;

    return Column(
      children: [
        ListTile(
          leading: Icon(
            hasChildren
                ? (isExpanded ? Icons.folder_open : Icons.folder)
                : Icons.folder,
            color: AppTheme.warmBrown,
          ),
          title: Text(
            folder.name,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          trailing: hasChildren
              ? Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.mediumGray,
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
          onLongPress: () => _showFolderContextMenu(context, folder),
        ),
        if (isExpanded && hasChildren)
          Container(
            margin: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: [
                ...subfolders.map((subfolder) => _buildFolderTile(subfolder, provider)),
                ...files.map((file) => _buildFileTile(file, provider)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(JournalFile file, JournalProvider provider) {
    final isSelected = provider.selectedFileId == file.id;
    
    return ListTile(
      leading: Icon(
        Icons.description,
        color: AppTheme.mediumGray,
      ),
      title: Text(
        file.name,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppTheme.warmBrown : AppTheme.darkText,
        ),
      ),
      subtitle: Text(
        '${file.wordCount} words',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.warmBrown.withOpacity(0.1),
      onTap: () => provider.selectFile(file.id),
      onLongPress: () => _showFileContextMenu(context, file),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'My Folder',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.createFolder(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New File'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'File Name',
            hintText: 'My Journal Entry',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showFolderContextMenu(BuildContext context, JournalFolder folder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(context).pop();
              _showRenameFolderDialog(context, folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.of(context).pop();
              _showDeleteFolderDialog(context, folder);
            },
          ),
        ],
      ),
    );
  }

  void _showFileContextMenu(BuildContext context, JournalFile file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.of(context).pop();
              _showRenameFileDialog(context, file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.of(context).pop();
              _showDeleteFileDialog(context, file);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, JournalFolder folder) {
    final nameController = TextEditingController(text: folder.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != folder.name) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFolder(folder.copyWith(name: name));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showRenameFileDialog(BuildContext context, JournalFile file) {
    final nameController = TextEditingController(text: file.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'File Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != file.name) {
                final provider = Provider.of<JournalProvider>(context, listen: false);
                await provider.updateFile(file.copyWith(name: name));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(BuildContext context, JournalFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Are you sure you want to delete "${folder.name}"? Files inside will be moved to the parent folder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              await provider.deleteFolder(folder.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFileDialog(BuildContext context, JournalFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<JournalProvider>(context, listen: false);
              await provider.deleteFile(file.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}