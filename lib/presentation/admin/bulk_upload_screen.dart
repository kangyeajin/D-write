import 'dart:convert';

import 'package:csv/csv.dart' show CsvDecoder;
import 'package:d_write/core/services/quote_service.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:d_write/repositories/quote_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class _ParsedRow {
  final int rowNum;
  final String sentence;
  final String author;
  final int month;
  final List<String> weatherTags;
  final String? error;

  const _ParsedRow({
    required this.rowNum,
    required this.sentence,
    required this.author,
    required this.month,
    required this.weatherTags,
    this.error,
  });

  bool get isValid => error == null;

  Map<String, dynamic> toFirestoreMap() => {
        'sentence': sentence,
        'author': author,
        'month': month,
        'weatherTags': weatherTags,
      };
}

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  final QuoteService _service = QuoteService(repo: QuoteRepository());

  List<_ParsedRow> _rows = [];
  String? _fileName;
  bool _isUploading = false;
  String? _resultMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _fileName = file.name;
      _rows = [];
      _resultMessage = null;
    });

    try {
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      final rows = const CsvDecoder(skipEmptyLines: true).convert(content);
      _parseRows(rows);
    } catch (e) {
      if (mounted) {
        setState(() => _resultMessage = '파일을 읽는 중 오류가 발생했습니다: $e');
      }
    }
  }

  void _parseRows(List<List<dynamic>> raw) {
    final parsed = <_ParsedRow>[];

    for (int i = 0; i < raw.length; i++) {
      final row = raw[i];
      final rowNum = i + 1;

      // 헤더 행 건너뛰기
      if (i == 0) {
        final first = row.isNotEmpty ? row[0].toString().trim() : '';
        if (first.toLowerCase() == 'sentence' ||
            first.toLowerCase() == '문장') {
          continue;
        }
      }

      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
        continue;
      }

      final sentence = row.isNotEmpty ? row[0].toString().trim() : '';
      final author = row.length > 1 ? row[1].toString().trim() : '';
      final monthRaw = row.length > 2 ? row[2].toString().trim() : '';
      final tagsRaw = row.length > 3 ? row[3].toString().trim() : 'All';

      if (sentence.isEmpty) {
        parsed.add(_ParsedRow(
          rowNum: rowNum, sentence: sentence, author: author,
          month: 0, weatherTags: [], error: '문장이 비어 있습니다.',
        ));
        continue;
      }
      if (author.isEmpty) {
        parsed.add(_ParsedRow(
          rowNum: rowNum, sentence: sentence, author: author,
          month: 0, weatherTags: [], error: '출처/작가가 비어 있습니다.',
        ));
        continue;
      }

      final month = int.tryParse(monthRaw);
      if (month == null || month < 1 || month > 12) {
        parsed.add(_ParsedRow(
          rowNum: rowNum, sentence: sentence, author: author,
          month: 0, weatherTags: [],
          error: '월 값이 올바르지 않습니다: "$monthRaw" (1~12 정수)',
        ));
        continue;
      }

      const validTags = {'All', 'Clear', 'Clouds', 'Rain', 'Snow'};
      final tags = tagsRaw
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final invalidTag =
          tags.firstWhere((t) => !validTags.contains(t), orElse: () => '');
      if (invalidTag.isNotEmpty) {
        parsed.add(_ParsedRow(
          rowNum: rowNum, sentence: sentence, author: author,
          month: month, weatherTags: tags,
          error: '알 수 없는 날씨 태그: "$invalidTag"',
        ));
        continue;
      }

      parsed.add(_ParsedRow(
        rowNum: rowNum, sentence: sentence, author: author,
        month: month,
        weatherTags: tags.isEmpty ? ['All'] : tags,
      ));
    }

    setState(() => _rows = parsed);
  }

  Future<void> _upload() async {
    final validRows = _rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) return;

    setState(() {
      _isUploading = true;
      _resultMessage = null;
    });

    try {
      final count = await _service.bulkAddQuotes(
        validRows.map((r) => r.toFirestoreMap()).toList(),
      );
      if (mounted) {
        setState(() {
          _resultMessage = '$count개 문장이 등록되었습니다.';
          _rows = [];
          _fileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _resultMessage = '업로드 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _rows.where((r) => r.isValid).length;
    final errorCount = _rows.where((r) => !r.isValid).length;

    return Scaffold(
      appBar: AppBar(title: const Text('CSV 일괄 업로드')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 파일 선택 영역 ──────────────────────────────────
          GestureDetector(
            onTap: _isUploading ? null : _pickFile,
            child: Container(
              margin: const EdgeInsets.all(20),
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _fileName != null
                      ? AppColors.primary
                      : AppColors.dividerLight,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: _fileName != null
                  ? _buildFileSelectedState(_fileName!)
                  : _buildEmptyDropZone(),
            ),
          ),

          // ── 상태 메시지 ─────────────────────────────────────
          if (_resultMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                _resultMessage!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _resultMessage!.contains('실패')
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
            ),

          // ── 파싱 결과 요약 ──────────────────────────────────
          if (_rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  _Badge(
                    label: '유효 $validCount',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  if (errorCount > 0)
                    _Badge(
                      label: '오류 $errorCount',
                      color: AppColors.error,
                    ),
                ],
              ),
            ),

          // ── 미리보기 목록 ───────────────────────────────────
          if (_rows.isNotEmpty) ...[
            const Divider(height: 1),
            Expanded(child: _buildPreviewList()),
          ] else
            Expanded(child: _buildFormatGuide()),

          // ── 등록 버튼 ───────────────────────────────────────
          if (_rows.isNotEmpty)
            _buildUploadBar(validCount),
        ],
      ),
    );
  }

  Widget _buildEmptyDropZone() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.upload_file_outlined,
          size: 48,
          color: AppColors.subtitleLight,
        ),
        SizedBox(height: 12),
        Text(
          'CSV 파일 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceLight,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '탭하여 파일을 선택하세요',
          style: TextStyle(fontSize: 13, color: AppColors.subtitleLight),
        ),
      ],
    );
  }

  Widget _buildFileSelectedState(String name) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 36,
          color: AppColors.success,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onBackgroundLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '다른 파일을 선택하려면 탭하세요',
          style: TextStyle(fontSize: 12, color: AppColors.subtitleLight),
        ),
      ],
    );
  }

  Widget _buildFormatGuide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CSV 형식 안내',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '엑셀에서 "파일 → 다른 이름으로 저장 → CSV UTF-8"로 내보낸 후 업로드하세요.',
            style: TextStyle(fontSize: 13, color: AppColors.subtitleLight, height: 1.5),
          ),
          const SizedBox(height: 14),
          _FormatTable(),
          const SizedBox(height: 12),
          const Text(
            '• 날씨 태그: All / Clear / Clouds / Rain / Snow\n'
            '  여러 개는 쉼표로 구분 (예: Clear,Rain)\n'
            '• 1행이 "sentence" 또는 "문장"으로 시작하면 헤더로 인식해 건너뜁니다.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.subtitleLight,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _rows.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final row = _rows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${row.rowNum}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtitleLight,
                  ),
                ),
              ),
              Expanded(
                child: row.isValid
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.sentence,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onBackgroundLight,
                            ),
                          ),
                          Text(
                            '— ${row.author}  |  ${row.month}월  |  ${row.weatherTags.join(', ')}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.subtitleLight,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (row.sentence.isNotEmpty)
                            Text(
                              row.sentence,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceLight,
                              ),
                            ),
                          Text(
                            row.error!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
              ),
              Icon(
                row.isValid
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 18,
                color: row.isValid ? AppColors.success : AppColors.error,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadBar(int validCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(top: BorderSide(color: AppColors.dividerLight)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: (_isUploading || validCount == 0) ? null : _upload,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  '유효한 $validCount개 등록',
                  style: const TextStyle(fontSize: 16),
                ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FormatTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headers = ['열', '필드', '예시'];
    const rows = [
      ['A', 'sentence (문장)', '봄은 언제나 다시 온다'],
      ['B', 'author (출처/작가)', '헤르만 헤세'],
      ['C', 'month (월)', '4'],
      ['D', 'weatherTags (날씨)', 'Clear,Rain'],
    ];

    return Table(
      border: TableBorder.all(color: AppColors.dividerLight, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(28),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(3),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceLight),
          children: headers.map((h) => _cell(h, isHeader: true)).toList(),
        ),
        ...rows.map(
          (r) => TableRow(children: r.map((c) => _cell(c)).toList()),
        ),
      ],
    );
  }

  Widget _cell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
          color: isHeader
              ? AppColors.onBackgroundLight
              : AppColors.onSurfaceLight,
        ),
      ),
    );
  }
}
