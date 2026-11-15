import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:path_provider/path_provider.dart';

enum MarkupTool { pen, highlighter, eraser }

class MarkupStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  MarkupStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isHighlighter = false,
  });
}

/// HerzMarkupPage:
/// Full-screen in-app screen capture and annotation editor.
/// Allows user to draw freehand with red pen, yellow highlighter, undo,
/// copy original clean snip, copy annotated snip, and paste to remote PC.
class HerzMarkupPage extends StatefulWidget {
  final Uint8List imageBytes;
  final ui.Image rawUiImage;
  final SessionID sessionId;
  final FFI gFFI;

  const HerzMarkupPage({
    Key? key,
    required this.imageBytes,
    required this.rawUiImage,
    required this.sessionId,
    required this.gFFI,
  }) : super(key: key);

  @override
  State<HerzMarkupPage> createState() => _HerzMarkupPageState();
}

class _HerzMarkupPageState extends State<HerzMarkupPage> {
  final List<MarkupStroke> _strokes = [];
  MarkupStroke? _currentStroke;

  MarkupTool _currentTool = MarkupTool.pen;
  Color _penColor = const Color(0xFFEF4444); // Vibrant Red default
  double _penWidth = 4.0;
  final double _highlighterWidth = 22.0;

  final List<Color> _availableColors = [
    const Color(0xFFEF4444), // Red (default)
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF22C55E), // Green
    const Color(0xFFEAB308), // Yellow
    const Color(0xFFFFFFFF), // White
  ];

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<Uint8List> _renderAnnotatedImage(Size canvasSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
    );

    // Draw background image
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      image: widget.rawUiImage,
      fit: BoxFit.contain,
    );

    // Draw strokes
    for (final stroke in _strokes) {
      _drawStroke(canvas, stroke);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawStroke(Canvas canvas, MarkupStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = stroke.isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = stroke.isHighlighter ? StrokeJoin.miter : StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isHighlighter) {
      paint.blendMode = BlendMode.srcOver;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  static const MethodChannel _mChannel = MethodChannel('mChannel');

  Future<void> _syncClipboard({
    required Uint8List bytes,
    required String name,
    bool copyToRemote = true,
  }) async {
    try {
      await _mChannel.invokeMethod('sync_image_clipboard', {
        'bytes': bytes,
        'name': name,
        'copyToRemote': copyToRemote,
      });
    } catch (e) {
      debugPrint('Error syncing image clipboard: $e');
    }
  }

  Future<String?> _saveToFile(Uint8List bytes, String fileName) async {
    try {
      final List<Directory> candidates = [
        Directory('/storage/emulated/0/Download'),
        Directory('/sdcard/Download'),
        Directory('/storage/emulated/0/Pictures'),
      ];

      for (final dir in candidates) {
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          debugPrint('Saved markup screenshot to: ${file.path}');
          return file.path;
        } catch (err) {
          debugPrint('Candidate dir ${dir.path} write failed: $err');
        }
      }

      // Fallback to app external storage
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final file = File('${extDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          debugPrint('Saved markup screenshot to fallback extDir: ${file.path}');
          return file.path;
        }
      } catch (err) {
        debugPrint('Fallback extDir failed: $err');
      }

      // Fallback to app documents directory
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      debugPrint('Saved markup screenshot to fallback docDir: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error saving screenshot file: $e');
      return null;
    }
  }

  void _onCopyOriginal() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'HerzView_original_$ts.png';
    await _saveToFile(widget.imageBytes, fileName);
    await _syncClipboard(
      bytes: widget.imageBytes,
      name: fileName,
      copyToRemote: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Screenshot asli disalin ke Clipboard (HP & PC)! Siap di-paste.'),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  void _onSaveOrCopyAnnotated(Size canvasSize, {bool pasteToPc = false}) async {
    final annotatedBytes = await _renderAnnotatedImage(canvasSize);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'HerzView_markup_$ts.png';
    await _saveToFile(annotatedBytes, fileName);

    // Sync image to Android system clipboard AND remote PC clipboard
    await _syncClipboard(
      bytes: annotatedBytes,
      name: fileName,
      copyToRemote: true,
    );

    if (pasteToPc) {
      // Allow remote Windows PC ~350ms to receive network packet & set clipboard
      await Future.delayed(const Duration(milliseconds: 350));

      // Trigger Ctrl+V on remote PC
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pasteToPc
              ? '✓ Coretan disalin & di-paste (Ctrl+V) ke PC!'
              : '✓ Coretan disalin ke Clipboard (HP & PC) & tersimpan di Download!',
        ),
        backgroundColor: const Color(0xFF22C55E),
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isPortrait = mediaQuery.orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth;
            // Subtract top bar (50px) and bottom toolbar (isPortrait ? 110 : 80)
            final toolbarHeight = isPortrait ? 115.0 : 75.0;
            final canvasHeight = constraints.maxHeight - 50.0 - toolbarHeight;
            final canvasSize = Size(canvasWidth, canvasHeight);

            return Column(
              children: [
                // 1. TOP HEADER BAR
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFF1E293B),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        tooltip: 'Batal',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Snip & Markup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Undo button
                      IconButton(
                        icon: const Icon(Icons.undo_rounded, color: Colors.white),
                        tooltip: 'Undo Coretan',
                        onPressed: _strokes.isNotEmpty ? _undo : null,
                      ),
                      // Clear button
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                        tooltip: 'Hapus Semua Coretan',
                        onPressed: _strokes.isNotEmpty ? _clearAll : null,
                      ),
                      const SizedBox(width: 4),
                      // "Salin Asli" button (sebelum dicoret)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF93C5FD)),
                        label: const Text(
                          'Salin Asli',
                          style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                          backgroundColor: const Color(0xFF1E293B),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _onCopyOriginal,
                      ),
                    ],
                  ),
                ),

                // 2. DRAWING CANVAS AREA
                Expanded(
                  child: Container(
                    color: Colors.black,
                    width: canvasWidth,
                    height: canvasHeight,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          final point = details.localPosition;
                          if (_currentTool == MarkupTool.eraser) {
                            _eraseAt(point);
                          } else {
                            final isHl = _currentTool == MarkupTool.highlighter;
                            _currentStroke = MarkupStroke(
                              points: [point],
                              color: isHl
                                  ? const Color(0xFFEAB308).withOpacity(0.42) // Yellow translucent
                                  : _penColor,
                              strokeWidth: isHl ? _highlighterWidth : _penWidth,
                              isHighlighter: isHl,
                            );
                          }
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          final point = details.localPosition;
                          if (_currentTool == MarkupTool.eraser) {
                            _eraseAt(point);
                          } else if (_currentStroke != null) {
                            _currentStroke!.points.add(point);
                          }
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          if (_currentStroke != null) {
                            _strokes.add(_currentStroke!);
                            _currentStroke = null;
                          }
                        });
                      },
                      child: CustomPaint(
                        size: canvasSize,
                        painter: _MarkupPainter(
                          bgImage: widget.rawUiImage,
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. BOTTOM TOOLS & ACTION BAR
                Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tool selector row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Pen / colors
                          Row(
                            children: _availableColors.map((c) {
                              final isSelected =
                                  _currentTool == MarkupTool.pen && _penColor == c;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _currentTool = MarkupTool.pen;
                                    _penColor = c;
                                    _penWidth = 4.0;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.white24,
                                      width: isSelected ? 2.5 : 1.0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          // Highlighter & Eraser
                          Row(
                            children: [
                              // Highlighter
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _currentTool = MarkupTool.highlighter;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _currentTool == MarkupTool.highlighter
                                        ? const Color(0xFFEAB308).withOpacity(0.25)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _currentTool == MarkupTool.highlighter
                                          ? const Color(0xFFEAB308)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.brush_rounded, size: 16, color: Color(0xFFFDE047)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Stabilo',
                                        style: TextStyle(color: Color(0xFFFDE047), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Eraser
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _currentTool = MarkupTool.eraser;
                                  });
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _currentTool == MarkupTool.eraser
                                        ? const Color(0xFFEF4444).withOpacity(0.25)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _currentTool == MarkupTool.eraser
                                          ? const Color(0xFFEF4444)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_fix_normal_rounded,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Action buttons row
                      Row(
                        children: [
                          // [ 💾 Simpan ke HP ]
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                'Simpan HP',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF475569)),
                                backgroundColor: const Color(0xFF334155),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _onSaveOrCopyAnnotated(canvasSize, pasteToPc: false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // [ ✈ Kirim ke PC (Paste) ]
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send_rounded, size: 15),
                              label: const Text(
                                'Kirim ke PC (Ctrl+V)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _onSaveOrCopyAnnotated(canvasSize, pasteToPc: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _eraseAt(Offset point) {
    _strokes.removeWhere((stroke) {
      for (final p in stroke.points) {
        if ((p - point).distance < 20.0) {
          return true;
        }
      }
      return false;
    });
  }
}

class _MarkupPainter extends CustomPainter {
  final ui.Image bgImage;
  final List<MarkupStroke> strokes;
  final MarkupStroke? currentStroke;

  _MarkupPainter({
    required this.bgImage,
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint background screenshot
    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(0, 0, size.width, size.height),
      image: bgImage,
      fit: BoxFit.contain,
    );

    // 2. Paint committed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 3. Paint active drawing stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, MarkupStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = stroke.isHighlighter ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = stroke.isHighlighter ? StrokeJoin.miter : StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.isHighlighter) {
      paint.blendMode = BlendMode.srcOver;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkupPainter oldDelegate) => true;
}
