import 'package:d_write/ui/views/camera_screen.dart';
import 'package:flutter/material.dart';
 
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _buttonsVisible = false;

  void _toggleButtonsVisibility(bool visible) {
    setState(() {
      _buttonsVisible = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
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
                      const Text(
                        '여름은 덥다...\n그래서 여름이다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28),
                      ),
                      AnimatedOpacity(
                        opacity: _buttonsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Column(
                          children: [
                            SizedBox(height: 10),
                            Text(
                              '출처: 김정현',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                            builder: (context) => const CameraScreen(
                              overlayText: '여름은 덥다...\n그래서 여름이다.',
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