import 'dart:io';
import 'dart:ui' as ui;

import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum _Ratio { square, portrait }

enum _FontSize { small, medium, large }

enum _FontChoice { gowunBatang, pretendard, pretendardBold }

class _BgOption {
  const _BgOption({
    required this.id,
    required this.label,
    required this.begin,
    required this.end,
    required this.light,
  });

  final String id;
  final String label;
  final Color begin;
  final Color end;

  // light=true → auto dark text, light=false → auto white text
  final bool light;
}

// D-Write 팔레트에서 추출한 6종 배경 — 앱 고유 색상 시스템
const _kBgs = [
  _BgOption(id: 'fog',   label: '안개',  begin: Color(0xFFF5F5F3), end: Color(0xFFD0D0CD), light: true),
  _BgOption(id: 'sand',  label: '모래',  begin: Color(0xFFF8F4EF), end: Color(0xFFDFC9AC), light: true),
  _BgOption(id: 'moss',  label: '이끼',  begin: Color(0xFFF3F4EF), end: Color(0xFFBCCFAE), light: true),
  _BgOption(id: 'dawn',  label: '새벽',  begin: Color(0xFFFAF7F4), end: Color(0xFFE8BDB0), light: true),
  _BgOption(id: 'dark',  label: '밤',    begin: Color(0xFF1A1A1E), end: Color(0xFF2C2C30), light: false),
  _BgOption(id: 'slate', label: '새벽빛', begin: Color(0xFF1E2538), end: Color(0xFF2E3A58), light: false),
];

class SaveEditScreen extends StatefulWidget {
  const SaveEditScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<SaveEditScreen> createState() => _SaveEditScreenState();
}

class _SaveEditScreenState extends State<SaveEditScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  _Ratio _ratio = _Ratio.square;
  _FontSize _fontSize = _FontSize.small;
  _FontChoice _font = _FontChoice.gowunBatang;
  TextAlign _textAlign = TextAlign.left;
  bool _wordWrap = true;
  bool _dimBg = false;

  File? _bgImageFile;
  int _bgIndex = 0;
  bool _useCustomImage = false;
  bool _whiteText = false; // 배경 변경 시 자동 전환됨

  bool _isSaving = false;

  double get _aspectRatio => _ratio == _Ratio.square ? 1.0 : 3.0 / 4.0;

  double get _fontSizeDp {
    switch (_fontSize) {
      case _FontSize.small:
        return 18;
      case _FontSize.medium:
        return 24;
      case _FontSize.large:
        return 30;
    }
  }

  void _selectBg(int index) {
    setState(() {
      _bgIndex = index;
      _useCustomImage = false;
      _whiteText = !_kBgs[index].light;
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _bgImageFile = File(picked.path);
      _useCustomImage = true;
    });
  }

  TextStyle _buildSentenceStyle(Color color) {
    final size = _fontSizeDp;
    switch (_font) {
      case _FontChoice.gowunBatang:
        return GoogleFonts.gowunBatang(
          fontSize: size,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.7,
        );
      case _FontChoice.pretendard:
        return TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
          fontSize: size,
          color: color,
          height: 1.6,
        );
      case _FontChoice.pretendardBold:
        return TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
          fontSize: size,
          color: color,
          height: 1.5,
        );
    }
  }

  CrossAxisAlignment get _crossAxis {
    switch (_textAlign) {
      case TextAlign.right:
        return CrossAxisAlignment.end;
      case TextAlign.center:
        return CrossAxisAlignment.center;
      default:
        return CrossAxisAlignment.start;
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception();
      final img = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      final result =
          await GallerySaver.saveImage(file.path, albumName: 'D-Write');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result == true ? '이미지가 갤러리에 저장되었습니다.' : '저장에 실패했습니다.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        title: Text(
          '공유하기',
          style: TextStyle(
            fontFamily: 'Pretendard',
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveImage,
            child: Text(
              '저장',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: _shareImage,
            child: Text(
              '공유',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: colors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPreview(),
            _buildBgSection(colors),
            const SizedBox(height: 8),
            _buildTextSection(colors),
            const SizedBox(height: 8),
            _buildLayoutSection(colors),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── 미리보기 (floating card) ──────────────────────────────────────────────

  Widget _buildPreview() {
    final textColor = _whiteText ? Colors.white : const Color(0xFF1E1E1E);
    final bg = _useCustomImage ? null : _kBgs[_bgIndex];

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
                fit: StackFit.expand,
                children: [
                  // 배경
                  if (_useCustomImage && _bgImageFile != null)
                    Image.file(_bgImageFile!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [bg!.begin, bg.end],
                        ),
                      ),
                    ),
                  // 배경 어둡게 오버레이
                  if (_dimBg)
                    Container(
                        color: Colors.black.withValues(alpha: 0.30)),
                  // 문장 + 출처
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: _crossAxis,
                      children: [
                        Text(
                          widget.quote.sentence,
                          style: _buildSentenceStyle(textColor),
                          textAlign: _textAlign,
                          softWrap: _wordWrap,
                          overflow: _wordWrap
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '— ${widget.quote.author}',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: textColor.withValues(alpha: 0.65),
                            height: 1.5,
                          ),
                          textAlign: _textAlign,
                        ),
                      ],
                    ),
                  ),
                  // D·Write 워터마크
                  Positioned(
                    right: 14,
                    bottom: 12,
                    child: Text(
                      'D·Write',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: textColor.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                  // 저장 중 오버레이
                  if (_isSaving)
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
        ),
      ),
    );
  }

  // ── 배경 선택 ─────────────────────────────────────────────────────────────

  Widget _buildBgSection(AppColorTokens colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: '배경', colors: colors),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _AddPhotoButton(onTap: _pickImage),
              const SizedBox(width: 8),
              if (_useCustomImage && _bgImageFile != null) ...[
                _CustomPhotoThumb(
                  file: _bgImageFile!,
                  isSelected: true,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
              ],
              for (int i = 0; i < _kBgs.length; i++) ...[
                _PaletteThumb(
                  option: _kBgs[i],
                  isSelected: !_useCustomImage && _bgIndex == i,
                  onTap: () => _selectBg(i),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── 텍스트 설정 ───────────────────────────────────────────────────────────

  Widget _buildTextSection(AppColorTokens colors) {
    return _SettingsGroup(
      label: '텍스트',
      colors: colors,
      children: [
        _SettingRow(
          label: '글꼴',
          child: _FontTabs(
            selected: _font,
            onChanged: (v) => setState(() => _font = v),
          ),
        ),
        _RowDivider(colors: colors),
        _SettingRow(
          label: '글자 크기',
          child: _SegmentedToggle<_FontSize>(
            options: const [
              _SegOpt(value: _FontSize.small, label: '소'),
              _SegOpt(value: _FontSize.medium, label: '중'),
              _SegOpt(value: _FontSize.large, label: '대'),
            ],
            selected: _fontSize,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
        ),
        _RowDivider(colors: colors),
        _SettingRow(
          label: '글자색',
          child: _TextColorToggle(
            isWhite: _whiteText,
            onChanged: (v) => setState(() => _whiteText = v),
          ),
        ),
        _RowDivider(colors: colors),
        _SettingRow(
          label: '정렬',
          child: _AlignToggle(
            value: _textAlign,
            onChanged: (v) => setState(() => _textAlign = v),
          ),
        ),
      ],
    );
  }

  // ── 레이아웃 설정 ─────────────────────────────────────────────────────────

  Widget _buildLayoutSection(AppColorTokens colors) {
    return _SettingsGroup(
      label: '레이아웃',
      colors: colors,
      children: [
        _SettingRow(
          label: '화면 비율',
          child: _SegmentedToggle<_Ratio>(
            options: const [
              _SegOpt(value: _Ratio.square, label: '1:1'),
              _SegOpt(value: _Ratio.portrait, label: '3:4'),
            ],
            selected: _ratio,
            onChanged: (v) => setState(() => _ratio = v),
          ),
        ),
        _RowDivider(colors: colors),
        _SettingRow(
          label: '줄 바꿈',
          child: Switch(
            value: _wordWrap,
            onChanged: (v) => setState(() => _wordWrap = v),
            activeThumbColor: AppColorTokens.of(context).accent,
            activeTrackColor:
                AppColorTokens.of(context).accent.withValues(alpha: 0.4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        _RowDivider(colors: colors),
        _SettingRow(
          label: '배경 어둡게',
          child: Switch(
            value: _dimBg,
            onChanged: (v) => setState(() => _dimBg = v),
            activeThumbColor: AppColorTokens.of(context).accent,
            activeTrackColor:
                AppColorTokens.of(context).accent.withValues(alpha: 0.4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// ── 섹션 레이블 ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});

  final String label;
  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── 설정 그룹 카드 ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.label,
    required this.colors,
    required this.children,
  });

  final String label;
  final AppColorTokens colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label, colors: colors),
        ColoredBox(
          color: colors.background,
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── 설정 행 ───────────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.colors});

  final AppColorTokens colors;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: colors.divider,
      indent: 20,
      endIndent: 20,
    );
  }
}

// ── 글꼴 인라인 탭 ────────────────────────────────────────────────────────────

class _FontTabs extends StatelessWidget {
  const _FontTabs({required this.selected, required this.onChanged});

  final _FontChoice selected;
  final ValueChanged<_FontChoice> onChanged;

  static const _opts = [
    (_FontChoice.gowunBatang, '고운바탕'),
    (_FontChoice.pretendard, 'Pretendard'),
    (_FontChoice.pretendardBold, '볼드체'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _opts.map((o) {
        final isSelected = selected == o.$1;
        final textStyle = o.$1 == _FontChoice.gowunBatang
            ? GoogleFonts.gowunBatang(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : colors.textPrimary,
              )
            : TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: o.$1 == _FontChoice.pretendardBold
                    ? FontWeight.w700
                    : FontWeight.w400,
                fontSize: 13,
                color: isSelected ? Colors.white : colors.textPrimary,
              );
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () => onChanged(o.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? colors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? colors.accent : colors.divider,
                ),
              ),
              child: Text(o.$2, style: textStyle),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 글자색 토글 (시각적 A 원형 버튼) ─────────────────────────────────────────

class _TextColorToggle extends StatelessWidget {
  const _TextColorToggle({required this.isWhite, required this.onChanged});

  final bool isWhite;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorCircle(
          isSelected: !isWhite,
          onTap: () => onChanged(false),
          bg: const Color(0xFFF5F5F3),
          textColor: const Color(0xFF1E1E1E),
          borderColor: colors.accent,
        ),
        const SizedBox(width: 8),
        _ColorCircle(
          isSelected: isWhite,
          onTap: () => onChanged(true),
          bg: const Color(0xFF1A1A1E),
          textColor: Colors.white,
          borderColor: colors.accent,
        ),
      ],
    );
  }
}

class _ColorCircle extends StatelessWidget {
  const _ColorCircle({
    required this.isSelected,
    required this.onTap,
    required this.bg,
    required this.textColor,
    required this.borderColor,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final Color bg;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? borderColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'A',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ── 세그먼트 토글 ─────────────────────────────────────────────────────────────

class _SegOpt<T> {
  const _SegOpt({required this.value, required this.label});

  final T value;
  final String label;
}

class _SegmentedToggle<T> extends StatelessWidget {
  const _SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_SegOpt<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) Container(width: 1, color: colors.accent),
            _SegCell(
              label: options[i].label,
              isSelected: selected == options[i].value,
              isFirst: i == 0,
              isLast: i == options.length - 1,
              onTap: () => onChanged(options[i].value),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegCell extends StatelessWidget {
  const _SegCell({
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
    final colors = AppColorTokens.of(context);
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(5) : Radius.zero,
      right: isLast ? const Radius.circular(5) : Radius.zero,
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── 정렬 토글 ─────────────────────────────────────────────────────────────────

class _AlignToggle extends StatelessWidget {
  const _AlignToggle({required this.value, required this.onChanged});

  final TextAlign value;
  final ValueChanged<TextAlign> onChanged;

  static const _aligns = [
    (TextAlign.left, Icons.format_align_left),
    (TextAlign.center, Icons.format_align_center),
    (TextAlign.right, Icons.format_align_right),
    (TextAlign.justify, Icons.format_align_justify),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: colors.accent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < _aligns.length; i++) ...[
            if (i > 0) Container(width: 1, color: colors.accent),
            _AlignCell(
              icon: _aligns[i].$2,
              isSelected: value == _aligns[i].$1,
              isFirst: i == 0,
              isLast: i == _aligns.length - 1,
              onTap: () => onChanged(_aligns[i].$1),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlignCell extends StatelessWidget {
  const _AlignCell({
    required this.icon,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(5) : Radius.zero,
      right: isLast ? const Radius.circular(5) : Radius.zero,
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : colors.textPrimary,
        ),
      ),
    );
  }
}

// ── 배경 썸네일 위젯들 ────────────────────────────────────────────────────────

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: colors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: colors.textSecondary,
          size: 22,
        ),
      ),
    );
  }
}

class _PaletteThumb extends StatelessWidget {
  const _PaletteThumb({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _BgOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [option.begin, option.end],
          ),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: colors.accent, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            option.label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: option.light
                  ? const Color(0x991E1E1E)
                  : const Color(0x99FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomPhotoThumb extends StatelessWidget {
  const _CustomPhotoThumb({
    required this.file,
    required this.isSelected,
    required this.onTap,
  });

  final File file;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: colors.accent, width: 2.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 7.5 : 10),
          child: Image.file(file, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
