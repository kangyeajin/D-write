import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:d_write/core/models/user_model.dart';
import 'package:d_write/core/services/firebase_service.dart';
import 'package:d_write/ui/views/login_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _nameController = TextEditingController();
  final _infoController = TextEditingController();

  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _firebaseService.getUserProfile(widget.user.uid);
    if (profile != null) {
      setState(() {
        _userProfile = profile;
        _nameController.text = profile.name ?? '';
        _infoController.text = profile.info ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    await _firebaseService.saveUserProfile(
      widget.user.uid,
      _nameController.text,
      _infoController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('정보가 저장되었습니다.')),
    );
  }

  Future<void> _signOut() async {
    await _firebaseService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('홈'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로그인 이메일: ${widget.user.email}'),
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: _infoController,
              decoration: InputDecoration(labelText: '소개'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: Text('정보 저장'),
            ),
            SizedBox(height: 20),
            Text('저장된 정보', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_userProfile != null)
              Card(
                child: ListTile(
                  title: Text('이름: ${_userProfile!.name ?? '없음'}'),
                  subtitle: Text('소개: ${_userProfile!.info ?? '없음'}'),
                ),
              )
            else
              Text('저장된 정보가 없습니다.'),
          ],
        ),
      ),
    );
  }
}