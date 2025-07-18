import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class ResizeHandle extends StatefulWidget {
  final Function(double delta) onResize;
  final bool isVertical;
  final double size;
  
  const ResizeHandle({
    super.key,
    required this.onResize,
    this.isVertical = true,
    this.size = 8.0,
  });
  
  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _isHovering = false;
  bool _isDragging = false;
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.isVertical ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanUpdate: (details) {
          widget.onResize(widget.isVertical ? details.delta.dx : details.delta.dy);
        },
        child: Container(
          width: widget.isVertical ? widget.size : double.infinity,
          height: widget.isVertical ? double.infinity : widget.size,
          color: _getBackgroundColor(),
          child: widget.isVertical ? _buildVerticalHandle() : _buildHorizontalHandle(),
        ),
      ),
    );
  }
  
  Color _getBackgroundColor() {
    if (_isDragging) return AppTheme.warmBrown.withOpacity(0.3);
    if (_isHovering) return AppTheme.warmBrown.withOpacity(0.1);
    return AppTheme.warmBrown.withOpacity(0.05);
  }
  
  Widget _buildVerticalHandle() {
    return Center(
      child: Container(
        width: 1,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.warmBrown.withOpacity(_isHovering || _isDragging ? 0.4 : 0.2),
          borderRadius: BorderRadius.circular(0.5),
        ),
      ),
    );
  }
  
  Widget _buildHorizontalHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 1,
        decoration: BoxDecoration(
          color: AppTheme.warmBrown.withOpacity(_isHovering || _isDragging ? 0.4 : 0.2),
          borderRadius: BorderRadius.circular(0.5),
        ),
      ),
    );
  }
} 