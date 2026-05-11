import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

// ── 비율 열거형 ──────────────────────────────────────────────────────────────

enum _CameraRatio {
  square,
  fourThree,
  nineToSixteen;

  double get aspectRatio => switch (this) {
        _CameraRatio.square => 1.0,
        _CameraRatio.fourThree => 3.0 / 4.0,
        _CameraRatio.nineToSixteen => 9.0 / 16.0,
      };

  String get label => switch (this) {
        _CameraRatio.square => '1:1',
        _CameraRatio.fourThree => '3:4',
        _CameraRatio.nineToSixteen => '9:16',
      };
}

// ── 뷰파인더 화면 ────────────────────────────────────────────────────────────

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;

  CameraLensDirection _lensDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.auto;
  _CameraRatio _ratio = _CameraRatio.fourThree;

  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseScaleOnPinch = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('[CAM] 사용 가능한 카메라 없음');
      return;
    }
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == _lensDirection,
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: false);
    await ctrl.initialize();
    final minZoom = await ctrl.getMinZoomLevel();
    final maxZoom = await ctrl.getMaxZoomLevel();
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    setState(() {
      _controller = ctrl;
      _zoom = 1.0;
      _minZoom = minZoom;
      _maxZoom = maxZoom;
      _isInitialized = true;
    });
    debugPrint('[CAM] 초기화 완료 — lens=${cam.lensDirection.name}, maxZoom=$maxZoom');
  }

  Future<void> _flipCamera() async {
    setState(() => _isInitialized = false);
    await _controller?.dispose();
    _controller = null;
    _lensDirection = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    debugPrint('[CAM] lensDirection=${_lensDirection.name} → 재초기화');
    await _initCamera();
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {
      // 전면 카메라 등 플래시 미지원 시 무시
    }
    setState(() => _flashMode = next);
    debugPrint('[CAM] flashMode=${next.name}');
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _controller == null) return;
    final xfile = await _controller!.takePicture();
    debugPrint('[CAM] 사진 촬영 완료 — path=${xfile.path}');
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _CapturePreviewScreen(
          xfile: xfile,
          quote: widget.quote,
          ratio: _ratio,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: (_) => _baseScaleOnPinch = _zoom,
        onScaleUpdate: (details) async {
          if (!_isInitialized || _controller == null) return;
          final newZoom =
              (_baseScaleOnPinch * details.scale).clamp(_minZoom, _maxZoom);
          await _controller!.setZoomLevel(newZoom);
          setState(() => _zoom = newZoom);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 프리뷰 (비율 크롭)
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _ratio.aspectRatio,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      maxHeight: double.infinity,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 오버레이 텍스트 — 터치 투과
            IgnorePointer(
              child: Center(
                child: _OverlayText(quote: widget.quote),
              ),
            ),

            // 닫기 버튼 (상단 좌측)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),

            // 하단 컨트롤 바
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ControlBar(
                flashMode: _flashMode,
                ratio: _ratio,
                isReady: _isInitialized,
                onFlash: _cycleFlash,
                onRatio: (r) => setState(() => _ratio = r),
                onShutter: _takePicture,
                onFlip: _flipCamera,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 미리보기 확인 화면 ───────────────────────────────────────────────────────

class _CapturePreviewScreen extends StatefulWidget {
  const _CapturePreviewScreen({
    required this.xfile,
    required this.quote,
    required this.ratio,
  });

  final XFile xfile;
  final Quote quote;
  final _CameraRatio ratio;

  @override
  State<_CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<_CapturePreviewScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  Uint8List? _photoBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    widget.xfile.readAsBytes().then((bytes) {
      if (mounted) setState(() => _photoBytes = bytes);
    });
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary not found');
      final img = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('toByteData failed');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/d_write_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      final result =
          await GallerySaver.saveImage(file.path, albumName: 'D-Write');
      debugPrint('[CAM] 갤러리 저장 완료 — result=$result');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == true ? '사진이 갤러리에 저장되었습니다.' : '저장에 실패했습니다.',
          ),
        ),
      );
      if (result == true) Navigator.pop(context);
    } catch (e) {
      debugPrint('[ERROR] 갤러리 저장 실패 — $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    final bytes = _photoBytes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: bytes == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : AspectRatio(
                      aspectRatio: widget.ratio.aspectRatio,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRect(
                              child: Image.memory(bytes, fit: BoxFit.cover),
                            ),
                            IgnorePointer(
                              child: Center(
                                child: _OverlayText(quote: widget.quote),
                              ),
                            ),
                            if (_isSaving)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('다시 찍기'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 오버레이 텍스트 ──────────────────────────────────────────────────────────

class _OverlayText extends StatelessWidget {
  const _OverlayText({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quote.sentence,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.6,
              shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '— ${quote.author}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w300,
              height: 1.5,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 하단 컨트롤 바 ───────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.flashMode,
    required this.ratio,
    required this.isReady,
    required this.onFlash,
    required this.onRatio,
    required this.onShutter,
    required this.onFlip,
  });

  final FlashMode flashMode;
  final _CameraRatio ratio;
  final bool isReady;
  final VoidCallback onFlash;
  final ValueChanged<_CameraRatio> onRatio;
  final VoidCallback onShutter;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.50),
      padding: const EdgeInsets.only(top: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 비율 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _CameraRatio.values.map((r) {
                final selected = r == ratio;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => onRatio(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.50),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 플래시 · 셔터 · 전환
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: onFlash,
                        icon: Icon(
                          _flashIcon(flashMode),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  _ShutterButton(isReady: isReady, onTap: onShutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: onFlip,
                        icon: const Icon(
                          Icons.flip_camera_ios_outlined,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static IconData _flashIcon(FlashMode mode) => switch (mode) {
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        _ => Icons.flash_off,
      };
}

// ── 셔터 버튼 ─────────────────────────────────────────────────────────────────

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.isReady, required this.onTap});

  final bool isReady;
  final VoidCallback onTap;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isReady ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.isReady ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isReady ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isReady ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}
