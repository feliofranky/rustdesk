import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

/// HerzCompanionToolbar:
/// Hybrid orientation-adaptive companion toolbar.
/// - In Portrait: Two permanent rows (Row 1: Undo, Redo, D-Pad, Save, Find, Lock PC;
///   Row 2: Paste, Voice Mic, Snip, Right Click, Fit Screen Zoom).
/// - In Landscape: Single slim 38px row with all 11 tools, zero screen obstruction.
/// - D-Pad: Attached directly above toolbar rows for precise cursor navigation, zero floating gap.
/// - Voice Mic: Native speech-to-text dictation + enabled soft keyboard for instant text input to remote PC.
/// - Flat solid theme: Slate-800 (#1E293B), Slate-900 (#0F172A), Accent Blue (#2563EB).
class HerzCompanionToolbar extends StatefulWidget {
  final SessionID sessionId;
  final FFI gFFI;
  final VoidCallback? onSnip;

  const HerzCompanionToolbar({
    Key? key,
    required this.sessionId,
    required this.gFFI,
    this.onSnip,
  }) : super(key: key);

  @override
  State<HerzCompanionToolbar> createState() => _HerzCompanionToolbarState();
}

class _HerzCompanionToolbarState extends State<HerzCompanionToolbar> {
  bool _showDpad = false;

  void _onUndo() {
    bind.sessionInputKey(
      sessionId: widget.sessionId,
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
      sessionId: widget.sessionId,
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
      sessionId: widget.sessionId,
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
      sessionId: widget.sessionId,
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
      sessionId: widget.sessionId,
      name: 'LOCK_SCREEN',
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _sendKey(String keyName) {
    bind.sessionInputKey(
      sessionId: widget.sessionId,
      name: keyName,
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
        bind.sessionInputString(sessionId: widget.sessionId, value: phoneText);
        return;
      }
    } catch (e) {
      debugPrint('Failed to read phone clipboard: $e');
    }

    bind.sessionInputKey(
      sessionId: widget.sessionId,
      name: 'v',
      down: false,
      press: true,
      ctrl: true,
      alt: false,
      shift: false,
      command: false,
    );
  }

  void _onVoiceMic(BuildContext context) async {
    // 1. Enable soft keyboard so Android IME can show up when typing or tapping text field
    await widget.gFFI.invokeMethod("enable_soft_keyboard", true);

    final textController = TextEditingController();
    final focusNode = FocusNode();

    Future<void> startVoice(StateSetter setModalState) async {
      try {
        final spoken = await widget.gFFI.invokeMethodWithResult<String>('start_speech_recognition');
        if (spoken != null && spoken.isNotEmpty) {
          setModalState(() {
            if (textController.text.isEmpty) {
              textController.text = spoken;
            } else {
              textController.text = '${textController.text} $spoken';
            }
            textController.selection = TextSelection.fromPosition(
              TextPosition(offset: textController.text.length),
            );
          });
        }
      } catch (e) {
        debugPrint('Speech recognition error: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        void hideKeyboard() {
          focusNode.unfocus();
          FocusScope.of(ctx).unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hideKeyboard,
              child: Padding(
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
                        Material(
                          color: const Color(0xFF2563EB).withOpacity(0.2),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => startVoice(setModalState),
                            splashColor: const Color(0xFF3B82F6).withOpacity(0.35),
                            highlightColor: const Color(0xFF3B82F6).withOpacity(0.20),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.mic_rounded,
                                color: Color(0xFF60A5FA),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Dikte Suara / Teks ke PC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: hideKeyboard,
                              splashColor: const Color(0xFF3B82F6).withOpacity(0.30),
                              highlightColor: const Color(0xFF3B82F6).withOpacity(0.18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF334155), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.keyboard_hide_rounded, size: 14, color: Color(0xFF93C5FD)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Hide',
                                      style: TextStyle(
                                        color: Color(0xFF93C5FD),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              hideKeyboard();
                              Navigator.pop(ctx);
                            },
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Dedicated prominent voice button
                    Material(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => startVoice(setModalState),
                        splashColor: const Color(0xFF2563EB).withOpacity(0.35),
                        highlightColor: const Color(0xFF2563EB).withOpacity(0.20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.mic_rounded, color: Color(0xFF60A5FA), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Tap untuk Bicara (Dikte Suara)',
                                style: TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: textController,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Ketik teks atau gunakan tombol suara di atas...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => startVoice(setModalState),
                              splashColor: const Color(0xFF2563EB).withOpacity(0.35),
                              highlightColor: const Color(0xFF2563EB).withOpacity(0.20),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.mic_rounded, color: Color(0xFF3B82F6), size: 22),
                              ),
                            ),
                          ),
                        ),
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
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          bind.sessionInputString(sessionId: widget.sessionId, value: value);
                        }
                        hideKeyboard();
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // [ ⌨ Hide ] button as requested by user
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.keyboard_hide_rounded, size: 18, color: Color(0xFF94A3B8)),
                            label: const Text(
                              'Hide',
                              style: TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF475569), width: 1),
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFFE2E8F0),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.resolveWith(
                                (states) => states.contains(MaterialState.pressed)
                                    ? const Color(0xFF334155).withOpacity(0.5)
                                    : null,
                              ),
                            ),
                            onPressed: hideKeyboard,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // [ ✈ Kirim ke PC ] button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text(
                              'Kirim ke PC',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ).copyWith(
                              overlayColor: MaterialStateProperty.resolveWith(
                                (states) => states.contains(MaterialState.pressed)
                                    ? const Color(0xFF1D4ED8)
                                    : null,
                              ),
                            ),
                            onPressed: () {
                              final text = textController.text;
                              if (text.isNotEmpty) {
                                bind.sessionInputString(sessionId: widget.sessionId, value: text);
                              }
                              hideKeyboard();
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      widget.gFFI.invokeMethod("enable_soft_keyboard", false);
      textController.dispose();
      focusNode.dispose();
    });
  }

  void _onSnip() async {
    if (widget.onSnip != null) {
      widget.onSnip!();
      return;
    }
    // Launch classic Windows Snipping Tool (SnippingTool.exe)
    // 1. Send Win + R
    bind.sessionInputKey(
      sessionId: widget.sessionId,
      name: 'r',
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: false,
      command: true,
    );
    await Future.delayed(const Duration(milliseconds: 350));
    // 2. Type "snippingtool"
    bind.sessionInputString(sessionId: widget.sessionId, value: 'snippingtool');
    await Future.delayed(const Duration(milliseconds: 200));
    // 3. Press Enter (VK_RETURN)
    bind.sessionInputKey(
      sessionId: widget.sessionId,
      name: 'VK_RETURN',
      down: false,
      press: true,
      ctrl: false,
      alt: false,
      shift: false,
      command: false,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Membuka Snipping Tool di Windows...'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onRightClick() {
    widget.gFFI.inputModel.sendMouse('down', MouseButtons.right);
    Future.delayed(const Duration(milliseconds: 60), () {
      widget.gFFI.inputModel.sendMouse('up', MouseButtons.right);
    });
  }

  void _onZoom() async {
    final cur = await bind.sessionGetViewStyle(sessionId: widget.sessionId) ?? '';
    final next = (cur == kRemoteViewStyleOriginal)
        ? kRemoteViewStyleAdaptive
        : kRemoteViewStyleOriginal;
    await bind.sessionSetViewStyle(sessionId: widget.sessionId, value: next);
    widget.gFFI.canvasModel.updateViewStyle();
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool isActive = false,
    double size = 20,
  }) {
    return Material(
      color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF3B82F6).withOpacity(0.35),
        highlightColor: const Color(0xFF3B82F6).withOpacity(0.20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Icon(
            icon,
            size: size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDpadTrigger() {
    return Material(
      color: _showDpad ? const Color(0xFF2563EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _showDpad = !_showDpad;
          });
        },
        splashColor: const Color(0xFF3B82F6).withOpacity(0.35),
        highlightColor: const Color(0xFF3B82F6).withOpacity(0.20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Icon(
            Icons.control_camera_rounded,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDpadItem(IconData icon, String keyName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _sendKey(keyName),
          splashColor: const Color(0xFF3B82F6).withOpacity(0.35),
          highlightColor: const Color(0xFF3B82F6).withOpacity(0.20),
          child: SizedBox(
            width: 42,
            height: 34,
            child: Icon(
              icon,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDpadBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate-900
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1),
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
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                setState(() {
                  _showDpad = false;
                });
              },
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 20, color: Colors.white60),
              ),
            ),
          ),
        ],
      ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showDpad)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildDpadBubble(),
            ),
          if (isPortrait) ...[
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
          ] else ...[
            // Landscape: Single slim 38px row with all 11 tools
            SizedBox(
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
          ],
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

/// HerzMonitorSideDock:
/// Quick 1-tap dual/multi-monitor switching dock pinned to the left screen edge.
/// - Symmetrical to HerzScrollSlider on the right.
/// - Dynamic: automatically generates monitor buttons [1], [2], [3]... + [ALL] based on connected displays.
/// - Auto-Hide: completely hidden (SizedBox.shrink) when remote PC has only 1 monitor.
/// - Collapsible: tap '<' to slide offscreen into a sleek 20px '>' tab at screen edge.
/// - Smooth Material InkWell touch feedback with subtle #3B82F6 ripple on every clickable element.
/// - Theme consistent: Slate-900 (#0F172A), Slate-800 (#1E293B), Herz Blue (#2563EB).
class HerzMonitorSideDock extends StatefulWidget {
  final SessionID sessionId;
  final FFI gFFI;

  const HerzMonitorSideDock({
    Key? key,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  @override
  State<HerzMonitorSideDock> createState() => _HerzMonitorSideDockState();
}

class _HerzMonitorSideDockState extends State<HerzMonitorSideDock> {
  bool _isCollapsed = false;

  static const double _btnWidth = 44.0;
  static const double _btnHeight = 38.0;
  static const double _panelWidth = 56.0;
  static const double _tabWidth = 20.0;

  Widget _buildMonitorIconBox({
    required int targetDisplay,
    required String label,
    required bool isActive,
    required PeerInfo pi,
  }) {
    const activeBg = Color(0xFF2563EB); // Herz Blue
    const standbyBg = Color(0xFF1E293B); // Slate 800
    const activeBorder = Color(0xFF60A5FA); // Light Blue
    const standbyBorder = Color(0xFF334155); // Slate 700
    const activeText = Colors.white;
    const standbyText = Color(0xFF94A3B8); // Slate 400

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          splashColor: const Color(0x333B82F6),
          highlightColor: const Color(0x223B82F6),
          onTap: () {
            openMonitorInTheSameTab(targetDisplay, widget.gFFI, pi);
          },
          child: Container(
            width: _btnWidth,
            height: _btnHeight,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Screen Frame
                Container(
                  width: _btnWidth,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? activeBg : standbyBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isActive ? activeBorder : standbyBorder,
                      width: isActive ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? activeText : standbyText,
                      fontSize: label == 'ALL' ? 10 : 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      letterSpacing: label == 'ALL' ? 0.5 : 0,
                    ),
                  ),
                ),
                // Stand Neck
                Container(
                  width: 3,
                  height: 3,
                  color: isActive ? activeBorder : const Color(0xFF475569),
                ),
                // Stand Foot / Base
                Container(
                  width: 14,
                  height: 2,
                  decoration: BoxDecoration(
                    color: isActive ? activeBorder : const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pi = widget.gFFI.ffiModel.pi;

      // Ensure GetX reactive tracking on displaysCount
      final _ = pi.displaysCount.value;

      // Smart Auto-Hide: Zero clutter if target PC only has 1 monitor
      if (pi.displays.length <= 1) {
        return const Positioned(
          left: -300,
          top: 0,
          child: SizedBox.shrink(),
        );
      }

      int curDisplay = pi.currentDisplay;
      try {
        curDisplay = CurrentDisplayState.find(widget.gFFI.id).value;
      } catch (_) {
        curDisplay = pi.currentDisplay;
      }

      final isPortrait =
          MediaQuery.of(context).orientation == Orientation.portrait;

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        left: _isCollapsed ? -_panelWidth : 0,
        top: isPortrait ? MediaQuery.of(context).size.height * 0.28 : 20,
        width: _panelWidth + _tabWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. The Dock Panel (Holds monitor buttons [1], [2]... [ALL])
            Container(
              width: _panelWidth,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xF00F172A), // Slate-900 94% glass
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dynamic monitors (1, 2, 3...)
                  for (int i = 0; i < pi.displays.length; i++)
                    _buildMonitorIconBox(
                      targetDisplay: i,
                      label: '${i + 1}',
                      isActive: curDisplay == i,
                      pi: pi,
                    ),
                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    height: 1,
                    color: const Color(0xFF334155),
                  ),
                  // ALL Displays option
                  _buildMonitorIconBox(
                    targetDisplay: kAllDisplayValue,
                    label: 'ALL',
                    isActive: curDisplay == kAllDisplayValue,
                    pi: pi,
                  ),
                ],
              ),
            ),
            // 2. The Hide / Show Tab (attached to the right side of the panel)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                splashColor: const Color(0x333B82F6),
                highlightColor: const Color(0x223B82F6),
                onTap: () {
                  setState(() {
                    _isCollapsed = !_isCollapsed;
                  });
                },
                child: Container(
                  width: _tabWidth,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isCollapsed
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF1E293B),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border.all(
                      color: _isCollapsed
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF334155),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

