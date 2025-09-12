import 'package:d_write/core/services/quote_service.dart';
import 'package:flutter/material.dart';

class AddSentenceScreen extends StatefulWidget {
  const AddSentenceScreen({super.key});

  @override
  State<AddSentenceScreen> createState() => _AddSentenceScreenState();
}

class _AddSentenceScreenState extends State<AddSentenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sentenceController = TextEditingController();
  final _authorController = TextEditingController();
  final QuoteService _quoteService = QuoteService();

  @override
  void dispose() {
    _sentenceController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      await _quoteService.addQuote(
        _sentenceController.text,
        _authorController.text,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문장 등록'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _sentenceController,
                decoration: const InputDecoration(
                  labelText: '문장',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '문장을 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: '출처(작가)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '출처를 입력하세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('등록'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
