import 'package:flutter/foundation.dart';

class LayoutProvider extends ChangeNotifier {
  // Panel visibility state
  bool _isFileTreeVisible = true;
  bool _isAIChatVisible = true;
  
  // Panel sizes
  double _fileTreeWidth = 300.0;
  double _aiChatWidth = 350.0;
  
  // Minimum panel sizes
  static const double _minFileTreeWidth = 200.0;
  static const double _minAIChatWidth = 250.0;
  static const double _minEditorWidth = 400.0;
  
  // Maximum panel sizes (as percentage of screen)
  static const double _maxPanelWidthRatio = 0.6;
  
  // Getters
  bool get isFileTreeVisible => _isFileTreeVisible;
  bool get isAIChatVisible => _isAIChatVisible;
  double get fileTreeWidth => _fileTreeWidth;
  double get aiChatWidth => _aiChatWidth;
  
  // Panel visibility methods
  void toggleFileTree() {
    _isFileTreeVisible = !_isFileTreeVisible;
    notifyListeners();
  }
  
  void toggleAIChat() {
    _isAIChatVisible = !_isAIChatVisible;
    notifyListeners();
  }
  
  void setFileTreeVisible(bool visible) {
    if (_isFileTreeVisible != visible) {
      _isFileTreeVisible = visible;
      notifyListeners();
    }
  }
  
  void setAIChatVisible(bool visible) {
    if (_isAIChatVisible != visible) {
      _isAIChatVisible = visible;
      notifyListeners();
    }
  }
  
  // Panel sizing methods
  void setFileTreeWidth(double width, double screenWidth) {
    final maxWidth = screenWidth * _maxPanelWidthRatio;
    _fileTreeWidth = width.clamp(_minFileTreeWidth, maxWidth);
    notifyListeners();
  }
  
  void setAIChatWidth(double width, double screenWidth) {
    final maxWidth = screenWidth * _maxPanelWidthRatio;
    _aiChatWidth = width.clamp(_minAIChatWidth, maxWidth);
    notifyListeners();
  }
  
  // Utility methods
  double calculateEditorWidth(double screenWidth) {
    double usedWidth = 0;
    if (_isFileTreeVisible) usedWidth += _fileTreeWidth;
    if (_isAIChatVisible) usedWidth += _aiChatWidth;
    
    final editorWidth = screenWidth - usedWidth;
    return editorWidth.clamp(_minEditorWidth, double.infinity);
  }
  
  bool canResizeFileTree(double screenWidth) {
    return calculateEditorWidth(screenWidth) > _minEditorWidth;
  }
  
  bool canResizeAIChat(double screenWidth) {
    return calculateEditorWidth(screenWidth) > _minEditorWidth;
  }
  
  // Reset to defaults
  void resetToDefaults() {
    _isFileTreeVisible = true;
    _isAIChatVisible = true;
    _fileTreeWidth = 300.0;
    _aiChatWidth = 350.0;
    notifyListeners();
  }
} 