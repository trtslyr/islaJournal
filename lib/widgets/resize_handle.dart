import 'package:flutter/material.dart';

/// A resize handle widget that allows users to drag to resize adjacent panels
class ResizeHandle extends StatefulWidget {
  final Function(double) onResize;
  final bool isVertical;

  const ResizeHandle({
    super.key,
    required this.onResize,
    this.isVertical = false,
  });

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _isDragging = false;
  bool _isHovering = false;
  double? _lastPanPosition;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.isVertical ? SystemMouseCursors.resizeRow : SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() => _isDragging = true);
          _lastPanPosition = widget.isVertical ? details.localPosition.dy : details.localPosition.dx;
        },
        onPanUpdate: (details) {
          final currentPosition = widget.isVertical ? details.localPosition.dy : details.localPosition.dx;
          if (_lastPanPosition != null) {
            final delta = currentPosition - _lastPanPosition!;
            widget.onResize(delta);
            _lastPanPosition = currentPosition;
          }
        },
        onPanEnd: (details) {
          setState(() => _isDragging = false);
          _lastPanPosition = null;
        },
        child: Container(
          width: widget.isVertical ? double.infinity : 6,
          height: widget.isVertical ? 6 : double.infinity,
          color: _getHandleColor(context),
          child: widget.isVertical
              ? Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(_isHovering || _isDragging ? 0.4 : 0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                )
              : Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(_isHovering || _isDragging ? 0.4 : 0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
        ),
      ),
    );
  }

  Color _getHandleColor(BuildContext context) {
    if (_isDragging) return Theme.of(context).colorScheme.primary.withOpacity(0.3);
    if (_isHovering) return Theme.of(context).colorScheme.primary.withOpacity(0.1);
    return Theme.of(context).colorScheme.primary.withOpacity(0.05);
  }
} 