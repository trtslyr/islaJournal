import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/import_service.dart';
import '../providers/journal_provider.dart';
import '../core/theme/app_theme.dart';
import 'import_progress_widget.dart';

class ImportDialog extends StatefulWidget {
  @override
  _ImportDialogState createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _isImporting = false;
  ImportProgress? _currentProgress;
  StreamSubscription<ImportProgress>? _progressSubscription;
  ImportService? _importService;
  

  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.creamBeige,
      title: Text(
        'Import Markdown Files',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 16.0,
          fontWeight: FontWeight.w600,
          color: AppTheme.darkText,
        ),
      ),
      content: Container(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select markdown files (.md) to import into your journal.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 24),
            
            if (_isImporting) ...[
              _buildImportProgress(),
            ] else ...[
              _buildImportOptions(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: _isImporting ? AppTheme.mediumGray : AppTheme.warmBrown,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportOptions() {
    return Column(
      children: [
        _buildImportButton(
          icon: Icons.description,
          title: 'Select Files',
          subtitle: 'Choose individual markdown files',
          onPressed: _selectFiles,
        ),
        SizedBox(height: 12),
        _buildImportButton(
          icon: Icons.folder,
          title: 'Select Folder',
          subtitle: 'Import all .md files from a folder',
          onPressed: _selectFolder,
        ),
        SizedBox(height: 12),
        _buildImportButton(
          icon: Icons.folder_special,
          title: 'Import Obsidian Vault',
          subtitle: 'Import from Obsidian vault folder',
          onPressed: _selectObsidianVault,
        ),
        SizedBox(height: 12),
        _buildImportButton(
          icon: Icons.code,
          title: 'Manual File Path',
          subtitle: 'Enter file path manually (for testing)',
          onPressed: _showManualImport,
        ),
      ],
    );
  }

  Widget _buildImportButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.warmBrown.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child:         InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
        
            onPressed();
          },
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.warmBrown,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12.0,
                          color: AppTheme.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.mediumGray,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportProgress() {
    if (_currentProgress == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warmBrown),
          ),
          SizedBox(height: 16),
          Text(
            'Preparing import...',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14.0,
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      );
    }
    
    return ImportProgressWidget(progress: _currentProgress!);
  }

  Future<void> _selectFiles() async {
    try {
      
      
      // Use specific file type filtering with improved permissions
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        allowMultiple: true,
        dialogTitle: 'Select Markdown Files to Import',
        withData: false,  // Don't load file data, just get paths
        withReadStream: false,
      );
      
      
      
      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((file) => file.path != null)
            .map((f) => File(f.path!))
            .toList();
            
        
        await _importFiles(files);
      } else {
        
        _showPickerHelp();
      }
    } catch (e, stackTrace) {
      
      // More specific error handling
      if (e.toString().contains('Operation not permitted') || 
          e.toString().contains('PathAccessException')) {
        _showError('Permission denied: The app needs permission to access your files.\n\n'
                  'Solution:\n'
                  '1. Restart the app completely\n'
                  '2. When the file picker opens, grant permission\n'
                  '3. Check System Preferences > Security & Privacy > Files and Folders');
      } else {
        _showError('Failed to open file picker: $e\n\nTry restarting the app or use the Manual File Path option.');
      }
    }
  }

  Future<void> _selectFolder() async {
    try {
  
      final result = await FilePicker.platform.getDirectoryPath();
      

      
      if (result != null) {
        final directory = Directory(result);
        
        final files = await _findMarkdownFiles(directory);
        
        
        
        if (files.isNotEmpty) {
          await _importFiles(files);
        } else {
          _showError('No markdown files found in the selected folder.');
        }
      } else {
        
      }
    } catch (e) {
      _showError('Failed to open directory picker: $e');
    }
  }

  Future<void> _selectObsidianVault() async {
    final result = await FilePicker.platform.getDirectoryPath();
    
    if (result != null) {
      final directory = Directory(result);
      
      // Check if it's an Obsidian vault (has .obsidian folder)
      final obsidianFolder = Directory(path.join(directory.path, '.obsidian'));
      if (!await obsidianFolder.exists()) {
        _showError('The selected folder doesn\'t appear to be an Obsidian vault.');
        return;
      }
      
      final files = await _findMarkdownFiles(directory);
      
      if (files.isNotEmpty) {
        await _importFiles(files);
      } else {
        _showError('No markdown files found in the Obsidian vault.');
      }
    }
  }

  Future<List<File>> _findMarkdownFiles(Directory directory) async {
    final files = <File>[];
    
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          // Skip hidden files and files in .obsidian folder
          if (!path.basename(entity.path).startsWith('.') && 
              !entity.path.contains('.obsidian')) {
            files.add(entity);
          }
        }
      }
    } catch (e) {
      
    }
    
    return files;
  }

  Future<void> _importFiles(List<File> files) async {

    setState(() {
      _isImporting = true;
      _currentProgress = null;
    });
    
    try {

      _importService = ImportService();
      
      // Subscribe to progress updates
      _progressSubscription = _importService!.progressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _currentProgress = progress;
          });
        }
      });
      
      
      final result = await _importService!.importMarkdownFiles(files);
      
      
      
      // Brief delay to show completion state
      await Future.delayed(Duration(seconds: 1));
      
      Navigator.pop(context);
      
      // Show result dialog
      _showResultDialog(result);
      
      // Refresh the file list
      
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      await journalProvider.loadFiles();
      await journalProvider.loadFolders();
      
      
    } catch (e) {
      
      
      Navigator.pop(context);
      _showError('Import failed: $e');
    } finally {
      _progressSubscription?.cancel();
      _importService?.dispose();
      _importService = null;
      setState(() {
        _isImporting = false;
        _currentProgress = null;
      });
      
    }
  }

  void _showResultDialog(ImportResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: Text(
          'Import Complete',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✅ Files imported: ${result.filesImported}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.darkText,
              ),
            ),
            if (result.errors > 0) ...[
              SizedBox(height: 8),
              Text(
                '❌ Errors: ${result.errors}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  color: Colors.red,
                ),
              ),
            ],
            if (result.errorMessages.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                'Error details:',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
              SizedBox(height: 4),
              ...result.errorMessages.take(3).map((error) => Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  '• ${error.filename}: ${error.error}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.0,
                    color: AppTheme.mediumGray,
                  ),
                ),
              )),
              if (result.errorMessages.length > 3)
                Text(
                  '... and ${result.errorMessages.length - 3} more',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.0,
                    color: AppTheme.mediumGray,
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.warmBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14.0,
          ),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPickerHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.creamBeige,
        title: Text(
          'File Picker Permissions',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The file picker needs permission to access your files.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.darkText,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'macOS Permission Steps:',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '1. Restart the app completely (Cmd+Q → relaunch)\n'
              '2. When file picker opens, it may ask for permission\n'
              '3. Click "Allow" if prompted\n'
              '4. Check System Preferences > Security & Privacy > Files and Folders\n'
              '5. Ensure Isla Journal has file access enabled',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12.0,
                color: AppTheme.mediumGray,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Alternative: Use "Manual File Path" to bypass file picker entirely',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.0,
                  color: AppTheme.darkText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14.0,
                color: AppTheme.warmBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualImport() async {
    try {
      // Create a test file in the app's documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final testFile = File('${documentsDir.path}/test_import.md');
      
      // Create test content
      final testContent = '''---
title: Test Import File
tags: test, import, sample
date: 2025-01-18
mood: excited
---

# Test Import File

This is a test markdown file created for import testing.

## Content

- This file was created in the app's Documents directory
- It contains YAML front matter
- It has some basic markdown content

## Why This Works

This file is located at: ${testFile.path}

Since it's in the app's Documents directory, the app has full access to read it without permission issues.

## Next Steps

If this import works, we know:
1. The import functionality is working correctly
2. The issue is with file picker permissions
3. We need to fix the file picker entitlements

Happy journaling! 🎉
''';

      // Write the test file
      await testFile.writeAsString(testContent);
      
      
      // Show dialog with the app-accessible path
      final pathController = TextEditingController(text: testFile.path);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.creamBeige,
          title: Text(
            'Manual File Import',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16.0,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I\'ve created a test file in the app\'s Documents folder:',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  color: AppTheme.darkText,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGray,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  testFile.path,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.0,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'This bypasses permission issues by using a file the app can definitely access.',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11.0,
                  color: AppTheme.mediumGray,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  color: AppTheme.mediumGray,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  if (await testFile.exists()) {
            
                    await _importFiles([testFile]);
                  } else {
                    _showError('Test file was not created properly');
                  }
                } catch (e) {
                  _showError('Error accessing test file: $e');
                }
              },
              child: Text(
                'Import Test File',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14.0,
                  color: AppTheme.warmBrown,
                ),
              ),
            ),
          ],
        ),
      );
      
    } catch (e) {
      _showError('Error creating test file: $e');
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _importService?.dispose();
    super.dispose();
  }
} 