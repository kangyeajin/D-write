import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/ui/views/add_sentence_screen.dart';
import 'package:d_write/ui/views/camera_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final QuoteService _quoteService = QuoteService();
  Quote? _quote;
  bool _buttonsVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRandomQuote();
  }

  Future<void> _loadRandomQuote() async {
    final quote = await _quoteService.getRandomQuote();
    if (mounted) {
      setState(() {
        _quote = quote;
      });
    }
  }

  void _toggleButtonsVisibility(bool visible) {
    setState(() {
      _buttonsVisible = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // 좌측 메뉴
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      // Handle settings press
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('내 정보'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('달력'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('좋아요 한 문장'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('내가 쓴 메모'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('문장 등록'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSentenceScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          if (_buttonsVisible) {
            _toggleButtonsVisibility(false);
          }
        },
        onVerticalDragUpdate: (details) {
          if (!_buttonsVisible && details.delta.dy < -5) {
            // Swiped up
            _toggleButtonsVisibility(true);
          }
        },
        child: Container(
          color: Colors.white,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _quote?.sentence ?? '등록된 문장이 없습니다.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28),
                      ),
                      AnimatedOpacity(
                        opacity: _buttonsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Text(
                              _quote != null ? '출처: ${_quote!.author}' : '',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedOpacity(
                        opacity: _buttonsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.thumb_up_alt_outlined),
                              label: const Text('좋아요'),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              icon: const Icon(Icons.note_alt_outlined),
                              label: const Text('메모'),
                              onPressed: () {},
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              icon: const Icon(Icons.bookmark_border),
                              label: const Text('저장'),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedOpacity(
                opacity: _buttonsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50, left: 20),
                    child: IconButton(
                      icon: const Icon(Icons.menu, size: 30),
                      onPressed: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _buttonsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50, right: 20),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt_outlined, size: 30),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraScreen(
                              overlayText: _quote?.sentence ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
