import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:share_plus/share_plus.dart';

// ── 열거형 ───────────────────────────────────────────────────────────────────

enum _CameraFontSize { small, medium, large }

enum _CameraFontChoice { gowunBatang, pretendard, pretendardBold }

enum _CameraTextColor { white, black }

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

  // 텍스트 스타일
  bool              _isTextMenuOpen = false;
  _CameraFontSize   _camFontSize    = _CameraFontSize.medium;
  _CameraFontChoice _camFont        = _CameraFontChoice.pretendard;
  _CameraTextColor  _camTextColor   = _CameraTextColor.white;
  TextAlign         _camTextAlign   = TextAlign.center;

  double _zoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseScaleOnPinch = 1.0;

  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _startOrientationDetection();
    _initCamera();
  }

  void _startOrientationDetection() {
    _accelerometerSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen((AccelerometerEvent e) {
      if (!mounted) return;
      final o = _orientationFromAccelerometer(e, _deviceOrientation);
      if (o != _deviceOrientation) setState(() => _deviceOrientation = o);
    });
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
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
    );
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
    debugPrint(
      '[CAM] 초기화 완료 — lens=${cam.lensDirection.name}, maxZoom=$maxZoom',
    );
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

  void _cycleFont() {
    setState(() {
      _camFont = switch (_camFont) {
        _CameraFontChoice.gowunBatang    => _CameraFontChoice.pretendard,
        _CameraFontChoice.pretendard     => _CameraFontChoice.pretendardBold,
        _CameraFontChoice.pretendardBold => _CameraFontChoice.gowunBatang,
      };
    });
    debugPrint('[CAM] 글꼴 순환 → ${_camFont.name}');
  }

  void _cycleSize() {
    setState(() {
      _camFontSize = switch (_camFontSize) {
        _CameraFontSize.small  => _CameraFontSize.medium,
        _CameraFontSize.medium => _CameraFontSize.large,
        _CameraFontSize.large  => _CameraFontSize.small,
      };
    });
    debugPrint('[CAM] 크기 순환 → ${_camFontSize.name}');
  }

  void _cycleColor() {
    setState(() {
      _camTextColor = _camTextColor == _CameraTextColor.white
          ? _CameraTextColor.black
          : _CameraTextColor.white;
    });
    debugPrint('[CAM] 색상 순환 → ${_camTextColor.name}');
  }

  void _cycleAlign() {
    setState(() {
      _camTextAlign = switch (_camTextAlign) {
        TextAlign.left    => TextAlign.center,
        TextAlign.center  => TextAlign.right,
        TextAlign.right   => TextAlign.justify,
        _                 => TextAlign.left,
      };
    });
    debugPrint('[CAM] 정렬 순환 → $_camTextAlign');
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
    final shouldClose = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => _CapturePreviewScreen(
          xfile: xfile,
          quote: widget.quote,
          ratio: _ratio,
          deviceOrientation: _deviceOrientation,
          fontSize: _camFontSize,
          fontChoice: _camFont,
          textColor: _camTextColor,
          textAlign: _camTextAlign,
        ),
      ),
    );
    if (shouldClose == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final topPadding = switch (_ratio) {
      _CameraRatio.fourThree => screenHeight * 0.08,
      _CameraRatio.nineToSixteen => screenHeight * 0.074,
      _CameraRatio.square => screenHeight * 0.08 + screenWidth / 6.0,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: (_) => _baseScaleOnPinch = _zoom,
        onScaleUpdate: (details) async {
          if (!_isInitialized || _controller == null) return;
          final newZoom = (_baseScaleOnPinch * details.scale).clamp(
            _minZoom,
            _maxZoom,
          );
          await _controller!.setZoomLevel(newZoom);
          setState(() => _zoom = newZoom);
        },
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            // 카메라 프리뷰
            if (_isInitialized && _controller != null)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding),
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
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // 오버레이 텍스트 — 카메라 뷰와 동일한 위치, 클리핑 없이 독립 레이어
            if (_isInitialized && _controller != null)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: AspectRatio(
                      aspectRatio: _ratio.aspectRatio,
                      child: IgnorePointer(
                        child: Center(
                          child: AnimatedRotation(
                            turns: _textTurns(_deviceOrientation),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _OverlayText(
                              quote: widget.quote,
                              fontSize: _camFontSize,
                              fontChoice: _camFont,
                              textColor: _camTextColor,
                              textAlign: _camTextAlign,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 뒤로가기 버튼 (상단 좌측)
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
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
                isTextMenuOpen: _isTextMenuOpen,
                camFont: _camFont,
                camFontSize: _camFontSize,
                camTextColor: _camTextColor,
                camTextAlign: _camTextAlign,
                onTextMenuToggle: () {
                  setState(() => _isTextMenuOpen = !_isTextMenuOpen);
                  debugPrint('[CAM] 텍스트 메뉴 토글 → $_isTextMenuOpen');
                },
                onCycleFont: _cycleFont,
                onCycleSize: _cycleSize,
                onCycleColor: _cycleColor,
                onCycleAlign: _cycleAlign,
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
    required this.deviceOrientation,
    required this.fontSize,
    required this.fontChoice,
    required this.textColor,
    required this.textAlign,
  });

  final XFile xfile;
  final Quote quote;
  final _CameraRatio ratio;
  final DeviceOrientation deviceOrientation;
  final _CameraFontSize fontSize;
  final _CameraFontChoice fontChoice;
  final _CameraTextColor textColor;
  final TextAlign textAlign;

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

  Future<void> _shareImage() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/d_write_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)]);
      debugPrint('[CAM] 공유 완료');
    } catch (e) {
      debugPrint('[ERROR] 공유 실패 — $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공유에 실패했습니다.')));
      }
    }
  }

  Future<void> _saveImage() async {
    final snackBgColor = AppColorTokens.of(
      context,
    ).textPrimary.withValues(alpha: 0.85);
    setState(() => _isSaving = true);
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
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
      final result = await GallerySaver.saveImage(
        file.path,
        albumName: 'D-Write',
      );
      debugPrint('[CAM] 갤러리 저장 완료 — result=$result');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == true ? '사진이 갤러리에 저장되었습니다.' : '저장에 실패했습니다.',
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 220, left: 24, right: 24),
          elevation: 0,
          backgroundColor: snackBgColor,
        ),
      );
      if (result == true) Navigator.pop(context);
    } catch (e) {
      debugPrint('[ERROR] 갤러리 저장 실패 — $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('저장에 실패했습니다.', textAlign: TextAlign.center),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 220, left: 24, right: 24),
            elevation: 0,
            backgroundColor: snackBgColor,
          ),
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
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final topPadding = switch (widget.ratio) {
      _CameraRatio.fourThree => screenHeight * 0.08,
      _CameraRatio.nineToSixteen => screenHeight * 0.074,
      _CameraRatio.square => screenHeight * 0.08 + screenWidth / 6.0,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 사진 미리보기 ────────────────────────────────────────
          if (bytes == null)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: AspectRatio(
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
                              child: RotatedBox(
                                quarterTurns: _textQuarterTurns(widget.deviceOrientation),
                                child: _OverlayText(
                                  quote: widget.quote,
                                  fontSize: widget.fontSize,
                                  fontChoice: widget.fontChoice,
                                  textColor: widget.textColor,
                                  textAlign: widget.textAlign,
                                ),
                              ),
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
            ),

          // ── 하단 그라데이션 + 액션 버튼 ─────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.75],
                  colors: [Colors.transparent, Colors.black],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 110,
                    top: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _PreviewIconBtn(
                            icon: Icons.refresh_rounded,
                            label: '다시 찍기',
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                          ),
                          _PreviewSaveBtn(
                            onPressed: _isSaving ? null : _saveImage,
                            isSaving: _isSaving,
                            accentColor: colors.accent,
                          ),
                          _PreviewIconBtn(
                            icon: Icons.share_rounded,
                            label: '공유하기',
                            onPressed: _isSaving ? null : _shareImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 상단 좌 — 뒤로가기 ──────────────────────────────────
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // ── 상단 우 — 전체 닫기 ─────────────────────────────────
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 미리보기 저장 버튼 (중앙 Primary) ──────────────────────────────────────

class _PreviewSaveBtn extends StatefulWidget {
  const _PreviewSaveBtn({
    required this.onPressed,
    required this.isSaving,
    required this.accentColor,
  });

  final VoidCallback? onPressed;
  final bool isSaving;
  final Color accentColor;

  @override
  State<_PreviewSaveBtn> createState() => _PreviewSaveBtnState();
}

class _PreviewSaveBtnState extends State<_PreviewSaveBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 160,
          height: 56,
          decoration: BoxDecoration(
            color: widget.accentColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '저장',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 미리보기 아이콘+텍스트 보조 버튼 ────────────────────────────────────────

class _PreviewIconBtn extends StatefulWidget {
  const _PreviewIconBtn({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_PreviewIconBtn> createState() => _PreviewIconBtnState();
}

class _PreviewIconBtnState extends State<_PreviewIconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: Colors.white.withValues(alpha: 0.80),
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 오버레이 텍스트 ──────────────────────────────────────────────────────────

class _OverlayText extends StatelessWidget {
  const _OverlayText({
    required this.quote,
    required this.fontSize,
    required this.fontChoice,
    required this.textColor,
    required this.textAlign,
  });

  final Quote quote;
  final _CameraFontSize fontSize;
  final _CameraFontChoice fontChoice;
  final _CameraTextColor textColor;
  final TextAlign textAlign;

  double get _fontSizeDp => switch (fontSize) {
    _CameraFontSize.small  => 18.0,
    _CameraFontSize.medium => 24.0,
    _CameraFontSize.large  => 30.0,
  };

  Color get _resolvedColor => switch (textColor) {
    _CameraTextColor.white => Colors.white,
    _CameraTextColor.black => const Color(0xFF1A1A1E),
  };

  List<Shadow> get _shadows => textColor == _CameraTextColor.black
      ? const []
      : const [Shadow(color: Colors.black54, blurRadius: 8)];

  TextStyle _buildStyle() {
    final size = _fontSizeDp;
    final color = _resolvedColor;
    final shadows = _shadows;
    return switch (fontChoice) {
      _CameraFontChoice.gowunBatang => GoogleFonts.gowunBatang(
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.7,
          shadows: shadows,
        ),
      _CameraFontChoice.pretendard => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.6,
          shadows: shadows,
        ),
      _CameraFontChoice.pretendardBold => TextStyle(
          fontFamily: 'Pretendard',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.5,
          shadows: shadows,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolvedColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (textAlign) {
          TextAlign.left    => CrossAxisAlignment.start,
          TextAlign.right   => CrossAxisAlignment.end,
          TextAlign.center  => CrossAxisAlignment.center,
          _                 => CrossAxisAlignment.stretch,
        },
        children: [
          Text(
            quote.sentence,
            textAlign: textAlign,
            style: _buildStyle(),
          ),
          const SizedBox(height: 12),
          Text(
            '— ${quote.author}',
            textAlign: textAlign,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w300,
              color: color.withValues(alpha: 0.65),
              height: 1.5,
              shadows: _shadows,
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
    required this.isTextMenuOpen,
    required this.camFont,
    required this.camFontSize,
    required this.camTextColor,
    required this.camTextAlign,
    required this.onTextMenuToggle,
    required this.onCycleFont,
    required this.onCycleSize,
    required this.onCycleColor,
    required this.onCycleAlign,
  });

  final FlashMode flashMode;
  final _CameraRatio ratio;
  final bool isReady;
  final VoidCallback onFlash;
  final ValueChanged<_CameraRatio> onRatio;
  final VoidCallback onShutter;
  final VoidCallback onFlip;
  final bool isTextMenuOpen;
  final _CameraFontChoice camFont;
  final _CameraFontSize camFontSize;
  final _CameraTextColor camTextColor;
  final TextAlign camTextAlign;
  final VoidCallback onTextMenuToggle;
  final VoidCallback onCycleFont;
  final VoidCallback onCycleSize;
  final VoidCallback onCycleColor;
  final VoidCallback onCycleAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 60, left: 12, right: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 비율 ↔ 텍스트 스타일 행
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: isTextMenuOpen
                        ? _TextStyleBar(
                            key: const ValueKey('style'),
                            camFont: camFont,
                            camFontSize: camFontSize,
                            camTextColor: camTextColor,
                            camTextAlign: camTextAlign,
                            onCycleFont: onCycleFont,
                            onCycleSize: onCycleSize,
                            onCycleColor: onCycleColor,
                            onCycleAlign: onCycleAlign,
                          )
                        : _RatioBar(
                            key: const ValueKey('ratio'),
                            ratio: ratio,
                            onRatio: onRatio,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    child: _AaToggleBtn(
                      isOpen: isTextMenuOpen,
                      onTap: onTextMenuToggle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static IconData _flashIcon(FlashMode mode) => switch (mode) {
    FlashMode.auto   => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    _                => Icons.flash_off,
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

// ── 방향 헬퍼 ─────────────────────────────────────────────────────────────────

/// 가속도계 값으로 물리적 기기 방향 판별.
/// x > 0 → landscapeRight (기기 top이 왼쪽), x < 0 → landscapeLeft (top이 오른쪽).
DeviceOrientation _orientationFromAccelerometer(
  AccelerometerEvent e,
  DeviceOrientation current,
) {
  final absX = e.x.abs();
  final absY = e.y.abs();
  const threshold = 5.5;
  if (absX > absY && absX > threshold) {
    return e.x > 0 ? DeviceOrientation.landscapeRight : DeviceOrientation.landscapeLeft;
  }
  if (absY > absX && absY > threshold) {
    return e.y > 0 ? DeviceOrientation.portraitUp : DeviceOrientation.portraitDown;
  }
  return current;
}

double _textTurns(DeviceOrientation o) => switch (o) {
  DeviceOrientation.landscapeLeft => -0.25,
  DeviceOrientation.landscapeRight => 0.25,
  DeviceOrientation.portraitDown => 0.5,
  _ => 0.0,
};

int _textQuarterTurns(DeviceOrientation o) => switch (o) {
  DeviceOrientation.landscapeLeft => -1,
  DeviceOrientation.landscapeRight => 1,
  DeviceOrientation.portraitDown => 2,
  _ => 0,
};

// ── 비율 선택 바 ─────────────────────────────────────────────────────────────

class _RatioBar extends StatelessWidget {
  const _RatioBar({super.key, required this.ratio, required this.onRatio});

  final _CameraRatio ratio;
  final ValueChanged<_CameraRatio> onRatio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _CameraRatio.values.map((r) {
        final selected = r == ratio;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onRatio(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                r.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? const Color(0xFFFFD83D)
                      : Colors.white.withValues(alpha: 0.60),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Aa 토글 버튼 ──────────────────────────────────────────────────────────────

class _AaToggleBtn extends StatelessWidget {
  const _AaToggleBtn({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 32,
        decoration: BoxDecoration(
          color: isOpen
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: isOpen
              ? const Icon(Icons.close,
                  key: ValueKey(true), color: Colors.white, size: 16)
              : Text(
                  'Aa',
                  key: const ValueKey(false),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── 텍스트 스타일 카테고리 바 ─────────────────────────────────────────────────

class _TextStyleBar extends StatelessWidget {
  const _TextStyleBar({
    super.key,
    required this.camFont,
    required this.camFontSize,
    required this.camTextColor,
    required this.camTextAlign,
    required this.onCycleFont,
    required this.onCycleSize,
    required this.onCycleColor,
    required this.onCycleAlign,
  });

  final _CameraFontChoice camFont;
  final _CameraFontSize camFontSize;
  final _CameraTextColor camTextColor;
  final TextAlign camTextAlign;
  final VoidCallback onCycleFont;
  final VoidCallback onCycleSize;
  final VoidCallback onCycleColor;
  final VoidCallback onCycleAlign;

  static IconData _alignIcon(TextAlign align) => switch (align) {
    TextAlign.left    => Icons.format_align_left,
    TextAlign.center  => Icons.format_align_center,
    TextAlign.right   => Icons.format_align_right,
    _                 => Icons.format_align_justify,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CatPill(onTap: onCycleFont, child: _FontLabel(font: camFont)),
        const SizedBox(width: 8),
        _CatPill(onTap: onCycleSize, child: _SizeLabel(size: camFontSize)),
        const SizedBox(width: 8),
        _CatPill(onTap: onCycleColor, child: _ColorDot(color: camTextColor)),
        const SizedBox(width: 8),
        _CatPill(
          onTap: onCycleAlign,
          child: Icon(_alignIcon(camTextAlign), size: 14, color: Colors.white),
        ),
      ],
    );
  }
}

class _CatPill extends StatelessWidget {
  const _CatPill({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _FontLabel extends StatelessWidget {
  const _FontLabel({required this.font});

  final _CameraFontChoice font;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Text(
        '가',
        key: ValueKey(font),
        style: switch (font) {
          _CameraFontChoice.gowunBatang    => GoogleFonts.gowunBatang(fontSize: 13, color: Colors.white),
          _CameraFontChoice.pretendard     => const TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w400, color: Colors.white),
          _CameraFontChoice.pretendardBold => const TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        },
      ),
    );
  }
}

class _SizeLabel extends StatelessWidget {
  const _SizeLabel({required this.size});

  final _CameraFontSize size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: Text(
        switch (size) {
          _CameraFontSize.small  => '소',
          _CameraFontSize.medium => '중',
          _CameraFontSize.large  => '대',
        },
        key: ValueKey(size),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final _CameraTextColor color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == _CameraTextColor.white
            ? Colors.white
            : const Color(0xFF1A1A1E),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.80),
          width: 1.5,
        ),
      ),
    );
  }
}

// ── DELETED: _TextStyleMenuOverlay (구 우측 패널 방식) ────────────────────────
// _TextStyleMenuOverlay, _MenuToggleBtn, _CategoryPanel, _CatItem,
// _DetailPanel, _FontStrip, _SizeStrip, _SizeCell, _ColorStrip, _AlignStrip
