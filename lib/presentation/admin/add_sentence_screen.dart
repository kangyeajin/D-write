import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:flutter/material.dart';

const List<String> _kWeatherOptions = ['All', 'Clear', 'Clouds', 'Rain', 'Snow'];

const List<String> _kMonthLabels = [
  '1월', '2월', '3월', '4월', '5월', '6월',
  '7월', '8월', '9월', '10월', '11월', '12월',
];

class AddSentenceScreen extends StatefulWidget {
  const AddSentenceScreen({super.key});

  @override
  State<AddSentenceScreen> createState() => _AddSentenceScreenState();
}

class _AddSentenceScreenState extends State<AddSentenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sentenceController = TextEditingController();
  final _authorController = TextEditingController();
  final QuoteService _quoteService = QuoteService(repo: QuoteRepository());

  int _selectedMonth = DateTime.now().month;
  final Set<String> _selectedWeatherTags = {'All'};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sentenceController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _toggleWeatherTag(String tag) {
    setState(() {
      if (tag == 'All') {
        _selectedWeatherTags
          ..clear()
          ..add('All');
        return;
      }
      _selectedWeatherTags.remove('All');
      if (_selectedWeatherTags.contains(tag)) {
        _selectedWeatherTags.remove(tag);
        if (_selectedWeatherTags.isEmpty) _selectedWeatherTags.add('All');
      } else {
        _selectedWeatherTags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      await _quoteService.addQuote(
        sentence: _sentenceController.text.trim(),
        author: _authorController.text.trim(),
        month: _selectedMonth,
        weatherTags: _selectedWeatherTags.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문장이 등록되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('문장 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _sentenceController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '문장',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '문장을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: '출처 / 작가',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '출처를 입력하세요.' : null,
              ),
              const SizedBox(height: 24),
              const Text(
                '노출 월',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceLight,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_kMonthLabels[i]),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMonth = v);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '날씨 태그',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceLight,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'All 선택 시 날씨 무관하게 노출됩니다.',
                style: TextStyle(fontSize: 12, color: AppColors.subtitleLight),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kWeatherOptions.map((tag) {
                  final selected = _selectedWeatherTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (_) => _toggleWeatherTag(tag),
                    selectedColor: AppColors.primary.withAlpha(30),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.onSurfaceLight,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : AppColors.dividerLight,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('등록', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
