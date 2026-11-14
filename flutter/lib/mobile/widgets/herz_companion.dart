import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _onPaste() async {
    // 1. Check if there is text in Android phone clipboard
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final phoneText = clipData?.text;
      if (phoneText != null && phoneText.isNotEmpty) {
        bind.sessionInputString(sessionId: sessionId, value: phoneText);
        showToast('Teks dari HP berhasil ditempel!');
        return;
      }
    } catch (e) {
      debugPrint('Failed to read phone clipboard: $e');
    }

    // 2. Fallback: Send Ctrl+V to remote PC session
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
    showToast('Ctrl + V dikirim ke PC');
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
            tooltip: 'Paste (Ctrl+V / Teks HP)',
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
/// - Shifted slightly left to match green line thumb comfort zone
/// - Wide 64px hit target so thumb gestures in red zone never miss
/// - Borderless speed button at the top tip (0.3x, 1.0x, 2.0x)
/// - Zero-latency responsive accumulator for silky line-by-line scrolling
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
  static int _speedIndex = 0; // Default: 0.1x (Super Pelan / Mode Baca)
  static const List<String> _speedLabels = ['0.1x', '0.3x', '1.0x', '2.0x'];
  static const List<String> _speedDescs = [
    '0.1x (Super Pelan / Mode Baca)',
    '0.3x (Pelan)',
    '1.0x (Normal)',
    '2.0x (Cepat / Turbo)',
  ];

  double _thumbPositionRatio = 0.5; // 0.0 top, 1.0 bottom
  double _dragAccumulator = 0.0;
  double _lastPointerY = 0.0;
  bool _isDragging = false;

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedLabels.length;
    });
    showToast('Kecepatan Scroll: ${_speedDescs[_speedIndex]}');
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastPointerY = event.position.dy;
    _dragAccumulator = 0.0;
    _isDragging = true;
  }

  void _onPointerMove(PointerMoveEvent event, double trackHeight) {
    if (!_isDragging) return;
    final deltaY = event.position.dy - _lastPointerY;
    _lastPointerY = event.position.dy;

    // Physical pixel distance required per 1 wheel notch
    final double pixelsPerWheelTick;
    switch (_speedIndex) {
      case 0:
        pixelsPerWheelTick = 42.0; // 0.1x: ~42px thumb drag = 1 gentle wheel tick (3 lines of text)
        break;
      case 1:
        pixelsPerWheelTick = 22.0; // 0.3x: ~22px per tick
        break;
      case 2:
        pixelsPerWheelTick = 10.0; // 1.0x: ~10px per tick
        break;
      case 3:
      default:
        pixelsPerWheelTick = 4.0;  // 2.0x: ~4px per tick
        break;
    }

    _dragAccumulator += deltaY;

    // Dispatch scroll events per physical threshold
    while (_dragAccumulator.abs() >= pixelsPerWheelTick) {
      if (_dragAccumulator > 0) {
        // Dragging DOWN -> scroll down (negative y in RustDesk)
        widget.gFFI.inputModel.scroll(-1);
        _dragAccumulator -= pixelsPerWheelTick;
      } else {
        // Dragging UP -> scroll up (positive y in RustDesk)
        widget.gFFI.inputModel.scroll(1);
        _dragAccumulator += pixelsPerWheelTick;
      }
    }

    if (trackHeight > 0) {
      setState(() {
        _thumbPositionRatio =
            (_thumbPositionRatio + (deltaY / trackHeight)).clamp(0.0, 1.0);
      });
    }
  }

  void _onPointerUpOrCancel() {
    _isDragging = false;
    _dragAccumulator = 0.0;
    // Smoothly snap thumb back to center so user always has full stroke headroom
    Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isDragging) {
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

    // Positioned right at right edge with width: 44px
    // Track sits centered at 22px from right edge (matching green line)
    // Left edge stops at 44px from right edge (does not intrude into document)
    return Positioned(
      right: 0,
      top: isPortrait ? MediaQuery.of(context).size.height * 0.30 : 16,
      bottom: isPortrait ? 12 : 16,
      width: 44,
      child: Column(
        children: [
          // Borderless Speed button at the top tip of scroll slider
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cycleSpeed,
            child: Container(
              width: 36,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // slate-800 without blue border
                borderRadius: BorderRadius.circular(6),
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
          // Vertical Slider Track with direct Listener (unswallowable by PC canvas)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackHeight = constraints.maxHeight;
                final knobSize = 22.0;
                final topOffset =
                    ((trackHeight - knobSize) * _thumbPositionRatio)
                        .clamp(0.0, trackHeight - knobSize);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Swallows taps so background canvas isn't clicked
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: (e) => _onPointerMove(e, trackHeight),
                    onPointerUp: (_) => _onPointerUpOrCancel(),
                    onPointerCancel: (_) => _onPointerUpOrCancel(),
                    child: Container(
                      width: 44,
                      color: Colors.transparent,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Blue Track Line (centered in the 44px touch strip)
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
                    ),
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
