import 'dart:io';
import 'dart:ui' as ui;

import 'package:d_write/core/models/quote_model.dart';
import 'package:d_write/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const Color _kAccent = Color(0xFF1AAF8A);

enum _AspectRatioMode { square, portrait }

enum _FontSize { small, medium, large }

const List<List<Color>> _kDefaultBgs = [
  [Color(0xFF2C1654), Color(0xFFFF6B35)],
  [Color(0xFF1A2A4A), Color(0xFF4A7FA5)],
  [Color(0xFF1A3A2A), Color(0xFF4A9A6A)],
  [Color(0xFF3A2A1A), Color(0xFF8A6A4A)],
];

class SaveEditScreen extends StatefulWidget {
  const SaveEditScreen({super.key, required this.quote});

  final Quote quote;

  @override
  State<SaveEditScreen> createState() => _SaveEditScreenState();
}

class _SaveEditScreenState extends State<SaveEditScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  _AspectRatioMode _ratio = _AspectRatioMode.square;
  bool _whiteText = true;
  _FontSize _fontSize = _FontSize.small;
  String _fontFamily = '';
  TextAlign _textAlign = TextAlign.left;
  bool _wordWrap = true;

  File? _bgImageFile;
  int _bgColorIndex = 0;
  bool _useCustomImage = false;

  bool _isSaving = false;

  double get _previewAspectRatio =>
      _ratio == _AspectRatioMode.square ? 1.0 : 3.0 / 4.0;

  double get _textFontSize {
    switch (_fontSize) {
      case _FontSize.small:
        return 18;
      case _FontSize.medium:
        return 24;
      case _FontSize.large:
        return 30;
    }
  }

  String get _fontFamilyLabel {
    switch (_fontFamily) {
      case 'PretendardBold':
        return 'Pretendard Bold';
      case 'PretendardSemiBold':
        return 'Pretendard SemiBold';
      case 'PretendardRegular':
        return 'Pretendard Regular';
      default:
        return '시스템글꼴';
    }
  }

  CrossAxisAlignment get _crossAxisAlignment {
    switch (_textAlign) {
      case TextAlign.right:
        return CrossAxisAlignment.end;
      case TextAlign.center:
        return CrossAxisAlignment.center;
      default:
        return CrossAxisAlignment.start;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _bgImageFile = File(picked.path);
      _useCustomImage = true;
    });
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RenderRepaintBoundary not found');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('toByteData returned null');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/quote_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final result =
          await GallerySaver.saveImage(file.path, albumName: 'D-Write');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == true ? '이미지가 갤러리에 저장되었습니다.' : '저장에 실패했습니다.',
          ),
        ),
      );
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

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했습니다.')),
        );
      }
    }
  }

  void _showFontPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (family, label) in [
              ('', '시스템글꼴'),
              ('PretendardRegular', 'Pretendard Regular'),
              ('PretendardSemiBold', 'Pretendard SemiBold'),
              ('PretendardBold', 'Pretendard Bold'),
            ])
              ListTile(
                title: Text(
                  label,
                  style: family.isNotEmpty
                      ? TextStyle(fontFamily: family)
                      : null,
                ),
                trailing: _fontFamily == family
                    ? const Icon(Icons.check, color: _kAccent)
                    : null,
                onTap: () {
                  setState(() => _fontFamily = family);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: const BackButton(color: AppColors.onBackgroundLight),
        title: const Text(
          '공유하기',
          style: TextStyle(
            color: AppColors.onBackgroundLight,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveImage,
            child: const Text(
              '저장',
              style: TextStyle(
                color: AppColors.onBackgroundLight,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          TextButton(
            onPressed: _shareImage,
            child: const Text(
              '공유',
              style: TextStyle(
                color: AppColors.onBackgroundLight,
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
          children: [
            _buildPreview(),
            _buildImageSelector(),
            const SizedBox(height: 8),
            _buildSettings(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final textColor = _whiteText ? Colors.white : Colors.black;
    final sentenceStyle = TextStyle(
      fontFamily: _fontFamily.isNotEmpty ? _fontFamily : null,
      fontSize: _textFontSize,
      color: textColor,
      height: 1.5,
      fontWeight: FontWeight.w700,
    );
    final sourceStyle = TextStyle(
      fontFamily: _fontFamily.isNotEmpty ? _fontFamily : null,
      fontSize: 13,
      color: textColor.withAlpha(204),
      height: 1.6,
    );

    return AspectRatio(
      aspectRatio: _previewAspectRatio,
      child: RepaintBoundary(
        key: _repaintKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_useCustomImage && _bgImageFile != null)
              Image.file(_bgImageFile!, fit: BoxFit.cover)
            else
              _GradientBg(colors: _kDefaultBgs[_bgColorIndex]),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: _crossAxisAlignment,
                children: [
                  Text(
                    widget.quote.sentence,
                    style: sentenceStyle,
                    textAlign: _textAlign,
                    softWrap: _wordWrap,
                    overflow: _wordWrap
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '— ${widget.quote.author}',
                    style: sourceStyle,
                    textAlign: _textAlign,
                  ),
                ],
              ),
            ),
            if (_isSaving)
              const ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelector() {
    return Container(
      color: AppColors.backgroundLight,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 72,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _AddImageButton(onTap: _pickImage),
            const SizedBox(width: 8),
            for (int i = 0; i < _kDefaultBgs.length; i++) ...[
              _DefaultBgThumb(
                colors: _kDefaultBgs[i],
                isSelected: !_useCustomImage && _bgColorIndex == i,
                onTap: () => setState(() {
                  _bgColorIndex = i;
                  _useCustomImage = false;
                }),
              ),
              const SizedBox(width: 8),
            ],
            if (_useCustomImage && _bgImageFile != null)
              _CustomImageThumb(
                file: _bgImageFile!,
                isSelected: true,
                onTap: () {},
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings() {
    return Container(
      color: AppColors.backgroundLight,
      child: Column(
        children: [
          _SettingRow(
            label: '화면비율',
            child: _SegmentedToggle<_AspectRatioMode>(
              options: const [
                _SegOption(value: _AspectRatioMode.square, label: '1:1'),
                _SegOption(value: _AspectRatioMode.portrait, label: '3:4'),
              ],
              selected: _ratio,
              onChanged: (v) => setState(() => _ratio = v),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            label: '글자색',
            child: _SegmentedToggle<bool>(
              options: const [
                _SegOption(value: true, label: '흰색'),
                _SegOption(value: false, label: '검정색'),
              ],
              selected: _whiteText,
              onChanged: (v) => setState(() => _whiteText = v),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            label: '글자크기',
            child: _SegmentedToggle<_FontSize>(
              options: const [
                _SegOption(value: _FontSize.small, label: '1'),
                _SegOption(value: _FontSize.medium, label: '2'),
                _SegOption(value: _FontSize.large, label: '3'),
              ],
              selected: _fontSize,
              onChanged: (v) => setState(() => _fontSize = v),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            label: '글꼴',
            child: GestureDetector(
              onTap: _showFontPicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fontFamilyLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.subtitleLight,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.subtitleLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            label: '문단정렬',
            child: _AlignToggle(
              value: _textAlign,
              onChanged: (v) => setState(() => _textAlign = v),
            ),
          ),
          const _RowDivider(),
          _SettingRow(
            label: '줄바꿈',
            child: _SegmentedToggle<bool>(
              options: const [
                _SegOption(value: true, label: 'ON'),
                _SegOption(value: false, label: 'OFF'),
              ],
              selected: _wordWrap,
              onChanged: (v) => setState(() => _wordWrap = v),
            ),
          ),
        ],
      ),
    );
  }
}

// ── helper widgets ─────────────────────────────────────────────────────────

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  const _AddImageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.dividerLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: AppColors.subtitleLight),
      ),
    );
  }
}

class _DefaultBgThumb extends StatelessWidget {
  const _DefaultBgThumb({
    required this.colors,
    required this.isSelected,
    required this.onTap,
  });

  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _kAccent, width: 2.5)
              : null,
        ),
      ),
    );
  }
}

class _CustomImageThumb extends StatelessWidget {
  const _CustomImageThumb({
    required this.file,
    required this.isSelected,
    required this.onTap,
  });

  final File file;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _kAccent, width: 2.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 5.5 : 8),
          child: Image.file(file, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceLight,
              ),
            ),
          ),
          Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.dividerLight,
      indent: 20,
      endIndent: 20,
    );
  }
}

class _SegOption<T> {
  const _SegOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _SegmentedToggle<T> extends StatelessWidget {
  const _SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_SegOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: _kAccent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0)
              Container(width: 1, color: _kAccent),
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
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(5) : Radius.zero,
      right: isLast ? const Radius.circular(5) : Radius.zero,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.onSurfaceLight,
          ),
        ),
      ),
    );
  }
}

class _AlignToggle extends StatelessWidget {
  const _AlignToggle({required this.value, required this.onChanged});

  final TextAlign value;
  final ValueChanged<TextAlign> onChanged;

  @override
  Widget build(BuildContext context) {
    const aligns = [
      (TextAlign.left, Icons.format_align_left),
      (TextAlign.center, Icons.format_align_center),
      (TextAlign.right, Icons.format_align_right),
      (TextAlign.justify, Icons.format_align_justify),
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: _kAccent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < aligns.length; i++) ...[
            if (i > 0) Container(width: 1, color: _kAccent),
            _AlignCell(
              icon: aligns[i].$2,
              isSelected: value == aligns[i].$1,
              isFirst: i == 0,
              isLast: i == aligns.length - 1,
              onTap: () => onChanged(aligns[i].$1),
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
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(5) : Radius.zero,
      right: isLast ? const Radius.circular(5) : Radius.zero,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        decoration: BoxDecoration(
          color: isSelected ? _kAccent : Colors.transparent,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.onSurfaceLight,
        ),
      ),
    );
  }
}
