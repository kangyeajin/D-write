import 'package:d_write/core/services/quote_service.dart';
import 'package:flutter/material.dart';

class AutoCreateSentenceScreen extends StatefulWidget {
  const AutoCreateSentenceScreen({super.key});

  @override
  State<AutoCreateSentenceScreen> createState() =>
      _AutoCreateSentenceScreenState();
}

class _AutoCreateSentenceScreenState extends State<AutoCreateSentenceScreen> {
  final QuoteService _quoteService = QuoteService();
  String? _generatedSentence;
  String? _generatedAuthor;
  bool _isLoading = false;

  void _generateSentence() async {
    setState(() {
      _isLoading = true;
      _generatedSentence = null;
      _generatedAuthor = null;
    });

    try {
      final quote = await _quoteService.getRandomQuote();
      if (mounted) {
        setState(() {
          if (quote != null) {
            _generatedSentence = quote.sentence;
            _generatedAuthor = quote.author;
          } else {
            _generatedSentence = '생성된 문장이 없습니다.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generatedSentence = '문장을 생성하는 중 오류가 발생했습니다.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문장 자동 생성')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _generateSentence,
                child: const Text('문장 자동 생성'),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_generatedSentence != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _generatedSentence!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      if (_generatedAuthor != null &&
                          _generatedAuthor!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '- $_generatedAuthor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
