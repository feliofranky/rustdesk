import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// HerzCompanionToolbar:
/// Clean icon-only bar directly stacked above RustDesk bottom bar.
/// 4 actions: Paste, Snip, Right-Click, Zoom Toggle.
class HerzCompanionToolbar extends StatelessWidget {
  final SessionID sessionId;
  final FFI gFFI;

  const HerzCompanionToolbar({
    Key? key,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  void _onPaste() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'v',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onSnip() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'S',
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: true,
      command: true,
    );
  }

  void _onRightClick() {
    gFFI.inputModel.sendMouse('down', MouseButtons.right);
    Future.delayed(const Duration(milliseconds: 60), () {
      gFFI.inputModel.sendMouse('up', MouseButtons.right);
    });
  }

  void _onZoom() async {
    final cur = await bind.sessionGetViewStyle(sessionId: sessionId) ?? '';
    final next = (cur == kRemoteViewStyleOriginal)
        ? kRemoteViewStyleAdaptive
        : kRemoteViewStyleOriginal;
    await bind.sessionSetViewStyle(sessionId: sessionId, value: next);
    gFFI.canvasModel.updateViewStyle();
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          icon,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // slate-800
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIconButton(
            icon: Icons.paste_rounded,
            onTap: _onPaste,
            tooltip: 'Paste (Ctrl+V)',
          ),
          _buildIconButton(
            icon: Icons.content_cut_rounded,
            onTap: _onSnip,
            tooltip: 'Snip (Win+Shift+S)',
          ),
          _buildIconButton(
            icon: Icons.mouse_rounded,
            onTap: _onRightClick,
            tooltip: 'Right Click',
          ),
          _buildIconButton(
            icon: Icons.zoom_in_rounded,
            onTap: _onZoom,
            tooltip: 'Toggle Zoom',
          ),
        ],
      ),
    );
  }
}

/// HerzScrollSlider:
/// Right-edge vertical scroll slider with a blue track and white circular knob.
/// - In portrait: Occupies the lower ~65-70% (natural thumb reach zone).
/// - In landscape: Occupies full vertical height.
class HerzScrollSlider extends StatefulWidget {
  final SessionID sessionId;
  final FFI gFFI;

  const HerzScrollSlider({
    Key? key,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  @override
  State<HerzScrollSlider> createState() => _HerzScrollSliderState();
}

class _HerzScrollSliderState extends State<HerzScrollSlider> {
  double _thumbPositionRatio = 0.5; // 0.0 top, 1.0 bottom
  double _lastDragY = 0;

  void _handleDragStart(DragStartDetails details) {
    _lastDragY = details.localPosition.dy;
  }

  void _handleDragUpdate(DragUpdateDetails details, double trackHeight) {
    final delta = details.localPosition.dy - _lastDragY;
    _lastDragY = details.localPosition.dy;

    // Send mouse wheel scroll to remote session
    // Negative delta = dragging down = scroll down
    final scrollDelta = (delta * 6).round();
    if (scrollDelta != 0) {
      widget.gFFI.inputModel.scroll(-scrollDelta);
    }

    setState(() {
      _thumbPositionRatio = (_thumbPositionRatio + (delta / trackHeight)).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    // Smoothly snap thumb back to center so user can continue scrolling freely
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _thumbPositionRatio = 0.5;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Positioned(
      right: 4,
      top: isPortrait ? MediaQuery.of(context).size.height * 0.32 : 16,
      bottom: isPortrait ? 12 : 16,
      width: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = constraints.maxHeight;
          final knobSize = 20.0;
          final topOffset = ((trackHeight - knobSize) * _thumbPositionRatio).clamp(0.0, trackHeight - knobSize);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _handleDragStart,
            onVerticalDragUpdate: (d) => _handleDragUpdate(d, trackHeight),
            onVerticalDragEnd: _handleDragEnd,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Blue Track Line
                Container(
                  width: 5,
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB), // Blue 600
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // White Circular Knob
                Positioned(
                  top: topOffset,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
