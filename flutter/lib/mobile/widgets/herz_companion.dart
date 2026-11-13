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
/// Right-edge vertical scroll slider with:
/// - Speed button at the top tip (0.3x Pelan/Baca, 1.0x Normal, 2.0x Cepat)
/// - Sub-pixel drag accumulator for buttery smooth, line-by-line reading
/// - Blue track line with white circular knob
/// - Sized for natural thumb reach
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
  static int _speedIndex = 0; // Default: 0.3x (Slow / Reading mode)
  static const List<String> _speedLabels = ['0.3x', '1.0x', '2.0x'];
  static const List<String> _speedDescs = [
    '0.3x (Pelan / Baca Dokumen)',
    '1.0x (Normal)',
    '2.0x (Cepat / Turbo)',
  ];

  double _thumbPositionRatio = 0.5; // 0.0 top, 1.0 bottom
  double _lastDragY = 0;
  double _dragAccumulator = 0.0;

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedLabels.length;
    });
    showToast('Kecepatan Scroll: ${_speedDescs[_speedIndex]}');
  }

  void _handleDragStart(DragStartDetails details) {
    _lastDragY = details.localPosition.dy;
    _dragAccumulator = 0.0;
  }

  void _handleDragUpdate(DragUpdateDetails details, double trackHeight) {
    final delta = details.localPosition.dy - _lastDragY;
    _lastDragY = details.localPosition.dy;

    _dragAccumulator += delta;

    // Pixels of thumb drag required per 1 mouse wheel notch:
    // 0.3x (Slow): 28.0 px/tick -> line-by-line micro scrolling for easy reading
    // 1.0x (Normal): 14.0 px/tick -> standard comfortable scroll
    // 2.0x (Fast): 6.0 px/tick -> rapid skimming
    final double pixelsPerTick;
    switch (_speedIndex) {
      case 0:
        pixelsPerTick = 28.0;
        break;
      case 1:
        pixelsPerTick = 14.0;
        break;
      case 2:
      default:
        pixelsPerTick = 6.0;
        break;
    }

    final int ticks = (_dragAccumulator / pixelsPerTick).truncate();
    if (ticks != 0) {
      _dragAccumulator -= ticks * pixelsPerTick;
      // Dragging down (delta > 0) scrolls down (-ticks)
      widget.gFFI.inputModel.scroll(-ticks);
    }

    setState(() {
      _thumbPositionRatio =
          (_thumbPositionRatio + (delta / trackHeight)).clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragAccumulator = 0.0;
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
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Positioned(
      right: 4,
      top: isPortrait ? MediaQuery.of(context).size.height * 0.30 : 16,
      bottom: isPortrait ? 12 : 16,
      width: 32,
      child: Column(
        children: [
          // Speed button at the top tip of scroll slider
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              width: 32,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // slate-800
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF3B82F6), // blue-500
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _speedLabels[_speedIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Vertical Slider Track
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                final knobSize = 20.0;
                final topOffset =
                    ((trackHeight - knobSize) * _thumbPositionRatio)
                        .clamp(0.0, trackHeight - knobSize);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: _handleDragStart,
                  onVerticalDragUpdate: (d) =>
                      _handleDragUpdate(d, trackHeight),
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
          ),
        ],
      ),
    );
  }
}
