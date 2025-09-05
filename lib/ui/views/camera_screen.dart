
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';


Logger logger = Logger();
 
class CameraScreen extends StatefulWidget {
  final String overlayText;

  const CameraScreen({super.key, required this.overlayText});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late CameraDescription _camera;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _camera = cameras.first;
    _controller = CameraController(
      _camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;

      final XFile imageFile = await _controller.takePicture();

      // Decode the image
      final imageBytes = await imageFile.readAsBytes();
      final img.Image originalImage = img.decodeImage(imageBytes)!;

      // Load the font
      final fontData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.zip');
      final font = img.BitmapFont.fromZip(fontData.buffer.asUint8List());

      // Add text overlay
      img.drawString(
        originalImage,
        widget.overlayText,
        font: font,
        x: (originalImage.width / 2).round() - (widget.overlayText.length * 24 / 2).round(),
        y: (originalImage.height / 2).round() - 24,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Save the modified image to a temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      final String filePath = '$tempPath/${DateTime.now()}.jpg';
      final File newImage = File(filePath);
      await newImage.writeAsBytes(img.encodeJpg(originalImage));

      // Save the image to the gallery
      await GallerySaver.saveImage(filePath);
      
      logger.i("이미지가 갤러리에 저장되었습니다: $filePath");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 갤러리에 저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller),
                Center(
                  child: Text(
                    widget.overlayText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _takePicture,
                      child: const Icon(Icons.camera),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
