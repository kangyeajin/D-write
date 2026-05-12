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

enum _TextStyleMenu { none, font, size, color, align }

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
  _TextStyleMenu   _menuState    = _TextStyleMenu.none;
  _CameraFontSize  _camFontSize  = _CameraFontSize.medium;
  _CameraFontChoice _camFont     = _CameraFontChoice.pretendard;
  _CameraTextColor _camTextColor = _CameraTextColor.white;
  TextAlign        _camTextAlign = TextAlign.center;

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

            // 텍스트 스타일 메뉴 (우측 사이드 패널)
            if (_isInitialized && _controller != null)
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: AspectRatio(
                      aspectRatio: _ratio.aspectRatio,
                      child: _TextStyleMenuOverlay(
                        menuState: _menuState,
                        fontChoice: _camFont,
                        fontSize: _camFontSize,
                        textColor: _camTextColor,
                        textAlign: _camTextAlign,
                        onToggle: () => setState(() {
                          _menuState = _menuState == _TextStyleMenu.none
                              ? _TextStyleMenu.font
                              : _TextStyleMenu.none;
                          debugPrint('[CAM] 텍스트 메뉴 토글 → ${_menuState.name}');
                        }),
                        onCategoryTap: (cat) => setState(() {
                          _menuState = _menuState == cat
                              ? _TextStyleMenu.none
                              : cat;
                          debugPrint('[CAM] 카테고리 선택 → ${_menuState.name}');
                        }),
                        onFontChanged: (v) => setState(() {
                          _camFont = v;
                          debugPrint('[CAM] 글꼴 변경 → ${v.name}');
                        }),
                        onSizeChanged: (v) => setState(() {
                          _camFontSize = v;
                          debugPrint('[CAM] 크기 변경 → ${v.name}');
                        }),
                        onColorChanged: (v) => setState(() {
                          _camTextColor = v;
                          debugPrint('[CAM] 색상 변경 → ${v.name}');
                        }),
                        onAlignChanged: (v) => setState(() {
                          _camTextAlign = v;
                          debugPrint('[CAM] 정렬 변경 → $v');
                        }),
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
    _CameraFontSize.small  => 16.0,
    _CameraFontSize.medium => 20.0,
    _CameraFontSize.large  => 26.0,
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
              fontSize: _fontSizeDp * 0.65,
              fontWeight: FontWeight.w300,
              color: color.withValues(alpha: 0.70),
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
      padding: const EdgeInsets.only(top: 10, bottom: 60, left: 12, right: 12),
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
                        horizontal: 14,
                        vertical: 6,
                      ),
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

// ── 텍스트 스타일 메뉴 오버레이 ─────────────────────────────────────────────

class _TextStyleMenuOverlay extends StatelessWidget {
  const _TextStyleMenuOverlay({
    required this.menuState,
    required this.fontChoice,
    required this.fontSize,
    required this.textColor,
    required this.textAlign,
    required this.onToggle,
    required this.onCategoryTap,
    required this.onFontChanged,
    required this.onSizeChanged,
    required this.onColorChanged,
    required this.onAlignChanged,
  });

  final _TextStyleMenu menuState;
  final _CameraFontChoice fontChoice;
  final _CameraFontSize fontSize;
  final _CameraTextColor textColor;
  final TextAlign textAlign;
  final VoidCallback onToggle;
  final ValueChanged<_TextStyleMenu> onCategoryTap;
  final ValueChanged<_CameraFontChoice> onFontChanged;
  final ValueChanged<_CameraFontSize> onSizeChanged;
  final ValueChanged<_CameraTextColor> onColorChanged;
  final ValueChanged<TextAlign> onAlignChanged;

  bool get _isOpen => menuState != _TextStyleMenu.none;

  // 카테고리 아이콘 (선택된 정렬에 따라 정렬 아이콘을 동적으로 변경)
  IconData _alignIcon() => switch (textAlign) {
    TextAlign.left    => Icons.format_align_left,
    TextAlign.right   => Icons.format_align_right,
    TextAlign.center  => Icons.format_align_center,
    _                 => Icons.format_align_justify,
  };

  @override
  Widget build(BuildContext context) {
    const catPanelWidth = 48.0;
    const itemHeight = 52.0;
    const categories = [
      _TextStyleMenu.font,
      _TextStyleMenu.size,
      _TextStyleMenu.color,
      _TextStyleMenu.align,
    ];

    return Stack(
      children: [
        // 토글 버튼
        Positioned(
          top: 12,
          right: 0,
          child: _MenuToggleBtn(isOpen: _isOpen, onTap: onToggle),
        ),

        // 카테고리 패널
        AnimatedSlide(
          offset: _isOpen ? Offset.zero : const Offset(1.5, 0),
          duration: const Duration(milliseconds: 200),
          curve: _isOpen ? Curves.easeOut : Curves.easeIn,
          child: AnimatedOpacity(
            opacity: _isOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: _CategoryPanel(
                  menuState: menuState,
                  alignIcon: _alignIcon(),
                  onTap: onCategoryTap,
                ),
              ),
            ),
          ),
        ),

        // 세부 옵션 패널 (선택된 카테고리 좌측 fly-out)
        if (_isOpen && menuState != _TextStyleMenu.none)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            top: 60 + (categories.indexOf(menuState) * itemHeight) + 6,
            right: catPanelWidth + 6,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _DetailPanel(
                key: ValueKey(menuState),
                menuState: menuState,
                fontChoice: fontChoice,
                fontSize: fontSize,
                textColor: textColor,
                textAlign: textAlign,
                onFontChanged: onFontChanged,
                onSizeChanged: onSizeChanged,
                onColorChanged: onColorChanged,
                onAlignChanged: onAlignChanged,
              ),
            ),
          ),
      ],
    );
  }
}

// ── 메뉴 토글 버튼 ────────────────────────────────────────────────────────────

class _MenuToggleBtn extends StatelessWidget {
  const _MenuToggleBtn({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.50),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: Icon(
            isOpen ? Icons.close : Icons.text_format,
            key: ValueKey(isOpen),
            color: Colors.white,
            size: isOpen ? 18 : 20,
          ),
        ),
      ),
    );
  }
}

// ── 카테고리 패널 ─────────────────────────────────────────────────────────────

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.menuState,
    required this.alignIcon,
    required this.onTap,
  });

  final _TextStyleMenu menuState;
  final IconData alignIcon;
  final ValueChanged<_TextStyleMenu> onTap;

  static const _items = [
    (_TextStyleMenu.font,  Icons.font_download_outlined),
    (_TextStyleMenu.size,  Icons.format_size),
    (_TextStyleMenu.color, Icons.palette_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final allItems = [
      ..._items,
      (_TextStyleMenu.align, alignIcon),
    ];

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < allItems.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            _CatItem(
              category: allItems[i].$1,
              icon: allItems[i].$2,
              isSelected: menuState == allItems[i].$1,
              onTap: () => onTap(allItems[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _CatItem extends StatelessWidget {
  const _CatItem({
    required this.category,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final _TextStyleMenu category;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 48,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

// ── 세부 옵션 패널 ────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    super.key,
    required this.menuState,
    required this.fontChoice,
    required this.fontSize,
    required this.textColor,
    required this.textAlign,
    required this.onFontChanged,
    required this.onSizeChanged,
    required this.onColorChanged,
    required this.onAlignChanged,
  });

  final _TextStyleMenu menuState;
  final _CameraFontChoice fontChoice;
  final _CameraFontSize fontSize;
  final _CameraTextColor textColor;
  final TextAlign textAlign;
  final ValueChanged<_CameraFontChoice> onFontChanged;
  final ValueChanged<_CameraFontSize> onSizeChanged;
  final ValueChanged<_CameraTextColor> onColorChanged;
  final ValueChanged<TextAlign> onAlignChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: switch (menuState) {
        _TextStyleMenu.font  => _FontStrip(selected: fontChoice, onChanged: onFontChanged),
        _TextStyleMenu.size  => _SizeStrip(selected: fontSize, onChanged: onSizeChanged),
        _TextStyleMenu.color => _ColorStrip(selected: textColor, onChanged: onColorChanged),
        _TextStyleMenu.align => _AlignStrip(selected: textAlign, onChanged: onAlignChanged),
        _TextStyleMenu.none  => const SizedBox.shrink(),
      },
    );
  }
}

// ── 글꼴 스트립 ───────────────────────────────────────────────────────────────

class _FontStrip extends StatelessWidget {
  const _FontStrip({required this.selected, required this.onChanged});

  final _CameraFontChoice selected;
  final ValueChanged<_CameraFontChoice> onChanged;

  static const _opts = [
    (_CameraFontChoice.gowunBatang,    '가'),
    (_CameraFontChoice.pretendard,     '가'),
    (_CameraFontChoice.pretendardBold, '가'),
  ];

  TextStyle _previewStyle(_CameraFontChoice choice, bool isSelected) {
    final color = isSelected ? Colors.black : Colors.white;
    return switch (choice) {
      _CameraFontChoice.gowunBatang    => GoogleFonts.gowunBatang(fontSize: 17, fontWeight: FontWeight.w400, color: color),
      _CameraFontChoice.pretendard     => TextStyle(fontFamily: 'Pretendard', fontSize: 17, fontWeight: FontWeight.w400, color: color),
      _CameraFontChoice.pretendardBold => TextStyle(fontFamily: 'Pretendard', fontSize: 17, fontWeight: FontWeight.w700, color: color),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _opts.map((o) {
        final isSelected = selected == o.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.90)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(o.$2, style: _previewStyle(o.$1, isSelected)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 크기 스트립 ───────────────────────────────────────────────────────────────

class _SizeStrip extends StatelessWidget {
  const _SizeStrip({required this.selected, required this.onChanged});

  final _CameraFontSize selected;
  final ValueChanged<_CameraFontSize> onChanged;

  static const _opts = [
    (_CameraFontSize.small,  '소'),
    (_CameraFontSize.medium, '중'),
    (_CameraFontSize.large,  '대'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _opts.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.50),
              ),
            _SizeCell(
              label: _opts[i].$2,
              isSelected: selected == _opts[i].$1,
              isFirst: i == 0,
              isLast: i == _opts.length - 1,
              onTap: () => onChanged(_opts[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeCell extends StatelessWidget {
  const _SizeCell({
    required this.label,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 48),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.90) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(5) : Radius.zero,
            right: isLast ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── 색상 스트립 ───────────────────────────────────────────────────────────────

class _ColorStrip extends StatelessWidget {
  const _ColorStrip({required this.selected, required this.onChanged});

  final _CameraTextColor selected;
  final ValueChanged<_CameraTextColor> onChanged;

  static const _opts = [
    (_CameraTextColor.white, Color(0xFFFFFFFF)),
    (_CameraTextColor.black, Color(0xFF1A1A1E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _opts.map((o) {
        final isSelected = selected == o.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: o.$2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 정렬 스트립 ───────────────────────────────────────────────────────────────

class _AlignStrip extends StatelessWidget {
  const _AlignStrip({required this.selected, required this.onChanged});

  final TextAlign selected;
  final ValueChanged<TextAlign> onChanged;

  static const _opts = [
    (TextAlign.left,    Icons.format_align_left),
    (TextAlign.center,  Icons.format_align_center),
    (TextAlign.right,   Icons.format_align_right),
    (TextAlign.justify, Icons.format_align_justify),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _opts.map((o) {
        final isSelected = selected == o.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                o.$2,
                size: 18,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
