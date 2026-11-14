import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Global visibility notifier for the floating D-pad bubble
final ValueNotifier<bool> herzDpadVisible = ValueNotifier<bool>(false);

/// HerzCompanionToolbar:
/// Hybrid orientation-adaptive companion toolbar.
/// - In Portrait: Two permanent rows (Row 1: Undo, Redo, D-Pad, Save, Find, Lock PC;
///   Row 2: Paste, Voice Mic, Snip, Right Click, Fit Screen Zoom).
/// - In Landscape: Single slim 38px row with all 11 tools, zero screen obstruction.
/// - Fixed height: Never expands or pushes the remote PC canvas.
/// - Flat solid theme: Slate-800 (#1E293B), Accent Blue (#2563EB).
class HerzCompanionToolbar extends StatelessWidget {
  final SessionID sessionId;
  final FFI gFFI;

  const HerzCompanionToolbar({
    Key? key,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  void _onUndo() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'z',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onRedo() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'y',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onSave() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 's',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onFind() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'f',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onLock() {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: 'LOCK_SCREEN',
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onPaste() async {
    try {
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      final phoneText = clipData?.text;
      if (phoneText != null && phoneText.isNotEmpty) {
        bind.sessionInputString(sessionId: sessionId, value: phoneText);
        return;
      }
    } catch (e) {
      debugPrint('Failed to read phone clipboard: $e');
    }

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

  void _onVoiceMic(BuildContext context) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
            left: 16,
            right: 16,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.mic_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Dikte Suara / Teks ke PC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tap icon mic di keyboard HP lalu bicara...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    bind.sessionInputString(sessionId: sessionId, value: value);
                  }
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Kirim ke PC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final text = textController.text;
                  if (text.isNotEmpty) {
                    bind.sessionInputString(sessionId: sessionId, value: text);
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
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
    bool isActive = false,
    double size = 20,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: size,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDpadTrigger() {
    return ValueListenableBuilder<bool>(
      valueListenable: herzDpadVisible,
      builder: (context, visible, child) {
        return InkWell(
          onTap: () {
            herzDpadVisible.value = !herzDpadVisible.value;
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: visible ? const Color(0xFF2563EB) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.control_camera_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      child: isPortrait
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Separate Undo, Redo, D-Pad, Save, Find, Lock PC (6 spacious buttons)
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(icon: Icons.undo_rounded, onTap: _onUndo, size: 22),
                      _buildIconButton(icon: Icons.redo_rounded, onTap: _onRedo, size: 22),
                      _buildDpadTrigger(),
                      _buildIconButton(icon: Icons.save_rounded, onTap: _onSave),
                      _buildIconButton(icon: Icons.search_rounded, onTap: _onFind),
                      _buildIconButton(icon: Icons.lock_outline_rounded, onTap: _onLock),
                    ],
                  ),
                ),
                // Row 2: Paste, Voice Mic, Snip, Right Click, Fit Screen (5 buttons)
                SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(icon: Icons.paste_rounded, onTap: _onPaste),
                      _buildIconButton(icon: Icons.mic_none_rounded, onTap: () => _onVoiceMic(context)),
                      _buildIconButton(icon: Icons.content_cut_rounded, onTap: _onSnip),
                      _buildIconButton(icon: Icons.mouse_rounded, onTap: _onRightClick),
                      _buildIconButton(icon: Icons.fit_screen_rounded, onTap: _onZoom),
                    ],
                  ),
                ),
              ],
            )
          : SizedBox(
              // Landscape: Single slim 38px row with all 11 tools
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconButton(icon: Icons.undo_rounded, onTap: _onUndo, size: 22),
                  _buildIconButton(icon: Icons.redo_rounded, onTap: _onRedo, size: 22),
                  _buildDpadTrigger(),
                  _buildIconButton(icon: Icons.save_rounded, onTap: _onSave),
                  _buildIconButton(icon: Icons.search_rounded, onTap: _onFind),
                  _buildIconButton(icon: Icons.lock_outline_rounded, onTap: _onLock),
                  _buildIconButton(icon: Icons.paste_rounded, onTap: _onPaste),
                  _buildIconButton(icon: Icons.mic_none_rounded, onTap: () => _onVoiceMic(context)),
                  _buildIconButton(icon: Icons.content_cut_rounded, onTap: _onSnip),
                  _buildIconButton(icon: Icons.mouse_rounded, onTap: _onRightClick),
                  _buildIconButton(icon: Icons.fit_screen_rounded, onTap: _onZoom),
                ],
              ),
            ),
    );
  }
}

/// HerzDpadFloatingBubble:
/// Floating D-pad bubble that hovers above the companion toolbar inside the body Stack.
/// Does NOT expand the bottom navigation bar and does NOT shrink the remote PC canvas.
class HerzDpadFloatingBubble extends StatelessWidget {
  final SessionID sessionId;
  final FFI gFFI;

  const HerzDpadFloatingBubble({
    Key? key,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  void _sendKey(String keyName) {
    bind.sessionInputKey(
      sessionId: sessionId,
      name: keyName,
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: false,
      command: false,
    );
  }

  Widget _buildDpadItem(IconData icon, String keyName) {
    return InkWell(
      onTap: () => _sendKey(keyName),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 44,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24, // Bold and thick, highly visible!
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return ValueListenableBuilder<bool>(
      valueListenable: herzDpadVisible,
      builder: (context, visible, child) {
        if (!visible) return const SizedBox.shrink();

        return Positioned(
          left: 0,
          right: 0,
          bottom: isPortrait ? 84 : 44, // Floating cleanly above companion toolbar
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Slate-900
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDpadItem(Icons.arrow_back_rounded, 'VK_LEFT'),
                  _buildDpadItem(Icons.arrow_upward_rounded, 'VK_UP'),
                  _buildDpadItem(Icons.arrow_downward_rounded, 'VK_DOWN'),
                  _buildDpadItem(Icons.arrow_forward_rounded, 'VK_RIGHT'),
                  Container(
                    height: 24,
                    width: 1,
                    color: const Color(0xFF334155),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  _buildDpadItem(Icons.keyboard_return_rounded, 'VK_RETURN'),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => herzDpadVisible.value = false,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

class _HerzScrollSliderState extends State<HerzScrollSlider>
    with SingleTickerProviderStateMixin {
  // Default: 0.3x, then cycles to 1.0x -> 2.0x -> 0.1x -> 0.3x
  static int _speedIndex = 0;
  static const List<String> _speedLabels = ['0.3x', '1.0x', '2.0x', '0.1x'];

  double _thumbPositionRatio = 0.5; // 0.0 top, 1.0 bottom
  double _dragAccumulator = 0.0;
  double _lastPointerY = 0.0;
  bool _isDragging = false;
  Timer? _returnTimer;

  late final AnimationController _animController;
  late Animation<double> _thumbAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animController.addListener(() {
      setState(() {
        _thumbPositionRatio = _thumbAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _cycleSpeed() {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speedLabels.length;
    });
    // Silent switch without toast
  }

  void _onPointerDown(PointerDownEvent event) {
    _returnTimer?.cancel();
    _animController.stop();
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
    switch (_speedLabels[_speedIndex]) {
      case '0.1x':
        pixelsPerWheelTick = 42.0; // 0.1x: ~42px thumb drag = 1 gentle wheel tick (3 lines)
        break;
      case '0.3x':
        pixelsPerWheelTick = 22.0; // 0.3x: ~22px per tick
        break;
      case '1.0x':
        pixelsPerWheelTick = 10.0; // 1.0x: ~10px per tick
        break;
      case '2.0x':
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
    _returnTimer?.cancel();

    // Silky smooth spring return to center (0.5)
    _returnTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted && !_isDragging) {
        _thumbAnimation = Tween<double>(
          begin: _thumbPositionRatio,
          end: 0.5,
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
          ),
        );
        _animController.forward(from: 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // Positioned right at right edge with width: 54px
    // Track sits centered at 27px from right edge (matching green line thumb zone)
    // Extra generous hit target for speed button so tapping directly on or right of text always registers
    return Positioned(
      right: 0,
      top: isPortrait ? MediaQuery.of(context).size.height * 0.30 : 16,
      bottom: isPortrait ? 12 : 16,
      width: 54,
      child: Column(
        children: [
          // Speed button with generous 54x42 hit target
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cycleSpeed,
            child: Container(
              width: 54,
              height: 42,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: Container(
                width: 40,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // slate-800 without blue border
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
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
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
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
                      width: 54,
                      color: Colors.transparent,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Blue Track Line (centered in the 54px touch strip)
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
