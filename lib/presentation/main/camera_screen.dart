import 'package:camera/camera.dart';
import 'package:d_write/core/models/quote_model.dart';
import 'package:flutter/material.dart';

// ── 비율 열거형 ──────────────────────────────────────────────────────────────

enum _CameraRatio {
  square,
  fourThree,
  nineToSixteen;

  double get aspectRatio => switch (this) {
        _CameraRatio.square => 1.0,
        _CameraRatio.fourThree => 4.0 / 3.0,
        _CameraRatio.nineToSixteen => 9.0 / 16.0,
      };

  String get label => switch (this) {
        _CameraRatio.square => '1:1',
        _CameraRatio.fourThree => '4:3',
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
                  child: CameraPreview(_controller!),
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

            // 하단 컨트롤 바 — Module 2에서 구현
          ],
        ),
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
