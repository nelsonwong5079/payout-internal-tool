import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class WhitelabelJsonScreen extends StatefulWidget {
  const WhitelabelJsonScreen({super.key});

  @override
  State<WhitelabelJsonScreen> createState() => _WhitelabelJsonScreenState();
}

class _WhitelabelJsonScreenState extends State<WhitelabelJsonScreen> {
  final _merchantLogoController = TextEditingController();

  String _headerBackgroundHex = '#0F172A';
  String _secureTxnHex = '#22C55E';
  String _brandPrimaryHex = '#2563EB';
  String _pageBackgroundHex = '#020617';
  String _summaryBoxHex = '#0B1120';

  bool _roundedBorder = true;

  Color get _headerBackgroundColor => _parseColor(_headerBackgroundHex);
  Color get _secureTxnColor => _parseColor(_secureTxnHex);
  Color get _brandPrimaryColor => _parseColor(_brandPrimaryHex);
  Color get _pageBackgroundColor => _parseColor(_pageBackgroundHex);
  Color get _summaryBoxColor => _parseColor(_summaryBoxHex);

  Map<String, dynamic> _buildConfig() {
    final borderRadius = _roundedBorder ? '9999px' : '4px';
    final gradient =
        'linear-gradient(180deg, $_brandPrimaryHex 0%, $_brandPrimaryHex 100%)';

    return {
      'common': {
        'logo': _merchantLogoController.text.trim(),
        'header': {
          'background': _headerBackgroundHex,
          'color': '#FFFFFF',
        },
        'secure_txn': _secureTxnHex,
        'spinner_loading_color': '#FFFFFF',
        'term_and_condition_color': '#FFFFFF',
        'help_center_color': '#FFFFFF',
        'color': '#FFFFFF',
      },
      'checkout': {
        'background': _pageBackgroundHex,
        'color': '#FFFFFF',
        'language_color': '#FFFFFF',
        'button_continue': {
          'background': _brandPrimaryHex,
          'border_radius': borderRadius,
          'color': '#000000',
        },
        'summary_box': {
          'background': _summaryBoxHex,
          'color': '#FFFFFF',
          'borderRadius': _roundedBorder ? '9999px' : '0px',
          'total_price': '#FFFF03',
          'payment_method_logo': {
            'background': '#FFFFFF',
            'padding': '2px',
          },
        },
      },
      'commonV2': {
        'logo': _merchantLogoController.text.trim(),
        'color': '#FFFFFF',
        'header': {
          'background': _headerBackgroundHex,
          'color': '#FFFFFF',
        },
        'secure_txn': _secureTxnHex,
        'background': _pageBackgroundHex,
        'bottom_sheet': {
          'background': _summaryBoxHex,
          'color': '#FFFFFF',
          'borderRadius': _roundedBorder ? '9999px' : '0px',
        },
        'language_bar': {
          'color': '#FFFFFF',
          'background': '#242424',
        },
        'language_selection': {
          'background_active': '#3D3D3D',
          'background_deactive': '#FFFFFF',
          'borderRadius': '0',
        },
        'copy_icon': {
          'color': _brandPrimaryHex,
          'background': _summaryBoxHex,
        },
        'divider': {
          'background': '#4D4D4D',
        },
        'footer': {
          'color': '#FFFFFF',
          'secure_logo_background': '#FFFFFF',
          'help_center_color': '#FFE93B',
          'term_and_condition_color': '#FFFFFF',
        },
      },
      'checkoutV2': {
        'color': '#FFFFFF',
        'background': _pageBackgroundHex,
        'payment_method_bar': {
          'background': '#242424',
          'color': '#FFFFFF',
        },
        'input_field': {
          'color': '#D4D4D4',
          'background': '#383838',
          'borderRadius': '0',
          'borderColor': '#545454',
          'placeholderColor': '#707070',
          'selection': {
            'postSelect': {
              'borderColor': '#FFE93B',
            },
          },
        },
        'rememberMe_checkbox': {
          'background_deactive': '#383838',
          'background_active': _brandPrimaryHex,
          'checkmark': '#000000',
          'borderRadius': '0px',
          'border_size': '1px',
          'border_color': '#707070',
        },
        'button_continue': {
          'background': gradient,
          'border_radius': borderRadius,
          'color': '#000000',
        },
        'summary_box': {
          'background': _summaryBoxHex,
          'color': '#FFFFFF',
        },
      },
    };
  }

  String get _jsonString =>
      const JsonEncoder.withIndent('  ').convert(_buildConfig());

  @override
  void dispose() {
    _merchantLogoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 380,
              child: _buildLeftPanel(context),
            ),
            const VerticalDivider(
              width: 1,
              color: Color(0xFF1F2937),
            ),
            Expanded(
              child: _buildRightPanel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF020617),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unified Whitelabel JSON',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.08,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter each value once and we sync V1 + V2 JSON.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade400,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF1D4ED8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4060A5FA),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'V1 + V2 in sync',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBFDBFE),
                          fontSize: 11,
                          letterSpacing: 0.08,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              title: 'Header',
              children: [
                _buildTextField(
                  context,
                  label: 'Merchant Logo URL',
                  hintText: 'https://cdn.payout.com/merchant-logo.png',
                  controller: _merchantLogoController,
                  helper:
                      'Maps to logo in common & commonV2',
                ),
                const SizedBox(height: 12),
                _buildColorField(
                  context,
                  label: 'Header Background',
                  helper:
                      'common.header.background & commonV2.header.background',
                  hexValue: _headerBackgroundHex,
                  color: _headerBackgroundColor,
                  onChanged: (hex, color) {
                    setState(() {
                      _headerBackgroundHex = hex;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildColorField(
                  context,
                  label: 'Secure Transaction Color',
                  helper: 'common.secure_txn & commonV2.secure_txn',
                  hexValue: _secureTxnHex,
                  color: _secureTxnColor,
                  onChanged: (hex, color) {
                    setState(() {
                      _secureTxnHex = hex;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Buttons',
              children: [
                _buildColorField(
                  context,
                  label: 'Brand Primary (Button)',
                  helper:
                      'checkout.button_continue.background & gradient in checkoutV2',
                  hexValue: _brandPrimaryHex,
                  color: _brandPrimaryColor,
                  onChanged: (hex, color) {
                    setState(() {
                      _brandPrimaryHex = hex;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildBorderRadiusToggle(context),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Layout & Surfaces',
              children: [
                _buildColorField(
                  context,
                  label: 'Page Background',
                  helper: 'checkout.background & commonV2.background',
                  hexValue: _pageBackgroundHex,
                  color: _pageBackgroundColor,
                  onChanged: (hex, color) {
                    setState(() {
                      _pageBackgroundHex = hex;
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildColorField(
                  context,
                  label: 'Summary Box Background',
                  helper:
                      'summary_box.background & commonV2.bottom_sheet.background',
                  hexValue: _summaryBoxHex,
                  color: _summaryBoxColor,
                  onChanged: (hex, color) {
                    setState(() {
                      _summaryBoxHex = hex;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF020617).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade200,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required String label,
    required String hintText,
    required TextEditingController controller,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade200,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (helper != null)
              Flexible(
                child: Text(
                  helper,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF020617),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade800),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade800),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildColorField(
    BuildContext context, {
    required String label,
    required String helper,
    required String hexValue,
    required Color color,
    required void Function(String hex, Color color) onChanged,
  }) {
    final controller = TextEditingController(text: hexValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade200,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Flexible(
              child: Text(
                helper,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDialog<Color>(
                  context: context,
                  builder: (context) {
                    Color tempColor = color;
                    return AlertDialog(
                      backgroundColor: const Color(0xFF020617),
                      title: const Text(
                        'Pick color',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: color,
                          onColorChanged: (value) {
                            tempColor = value;
                          },
                          enableAlpha: false,
                          hexInputBar: true,
                          labelTypes: const [],
                          portraitOnly: true,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(tempColor),
                          child: const Text('Apply'),
                        ),
                      ],
                    );
                  },
                );

                if (picked != null) {
                  final hex = _colorToHex(picked);
                  onChanged(hex, picked);
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade700),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '#000000',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFF020617),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade800),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) {
                  final hex = _normalizeHex(value);
                  if (hex != null) {
                    onChanged(hex, _parseColor(hex));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBorderRadiusToggle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Border Radius',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade200,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              'Applies to button_continue (V1 + V2)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            setState(() {
              _roundedBorder = !_roundedBorder;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF020617),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _roundedBorder
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF111827),
                    border: Border.all(
                      color: _roundedBorder
                          ? const Color(0xFF16A34A)
                          : Colors.grey.shade700,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 160),
                    alignment: _roundedBorder
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _roundedBorder ? 'Rounded (9999px)' : 'Standard (4px)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade200,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Whitelabel JSON Generator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live unified config for common, checkout, commonV2, checkoutV2.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Single source of truth',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade300,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade800),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      color: const Color(0xFF020617),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade800),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x4022C55E),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Unified Output',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.grey.shade300,
                                    letterSpacing: 0.1,
                                  ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF020617),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: Colors.grey.shade700),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'V1 + V2',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.grey.shade400,
                                          fontSize: 10,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _jsonString),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('JSON copied to clipboard'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text(
                            'Copy JSON',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0369A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade800),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: SelectableText(
                              _jsonString,
                              style:
                                  const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final normalized = _normalizeHex(hex) ?? '#000000';
    final buffer = StringBuffer();
    buffer.write('ff');
    buffer.write(normalized.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String? _normalizeHex(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('#')) {
      value = '#$value';
    }
    if (value.length == 4) {
      final r = value[1];
      final g = value[2];
      final b = value[3];
      value = '#$r$r$g$g$b$b';
    }
    if (RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(value)) {
      return value.toUpperCase();
    }
    return null;
  }

  String _colorToHex(Color color) {
    return '#'
        '${color.red.toRadixString(16).padLeft(2, '0')}'
        '${color.green.toRadixString(16).padLeft(2, '0')}'
        '${color.blue.toRadixString(16).padLeft(2, '0')}'
            .toUpperCase();
  }
}

