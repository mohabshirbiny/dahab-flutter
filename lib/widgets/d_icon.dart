import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The prototype's stroke icon set (`ICONS` in the HTML), rendered with the
/// same 24×24 viewBox, 1.7 stroke width and round caps/joins.
class DIcon extends StatelessWidget {
  const DIcon(this.name, {super.key, this.size = 14, this.color, this.mirrorInRtl = false});

  final String name;
  final double size;
  final Color? color;

  /// Flip horizontally in RTL (back arrow, chevrons).
  final bool mirrorInRtl;

  static const _directional = {'arrow-left', 'chevron-right'};

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF1A1A1A);
    final hex = '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final opacity = c.a;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="$hex" stroke-opacity="$opacity" stroke-width="1.7" stroke-linecap="round" '
        'stroke-linejoin="round">${_paths[name] ?? _paths['info-circle']}</svg>';
    Widget icon = SvgPicture.string(svg, width: size, height: size);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (rtl && (mirrorInRtl || _directional.contains(name))) {
      icon = Transform.flip(flipX: true, child: icon);
    }
    return SizedBox(width: size, height: size, child: icon);
  }

  static const Map<String, String> _paths = {
    'arrow-left': '<path d="M19 12H5"/><path d="M11 18l-6-6 6-6"/>',
    'chevron-right': '<path d="M9 6l6 6-6 6"/>',
    'arrow-up-right': '<path d="M7 17L17 7"/><path d="M8 7h9v9"/>',
    'arrows-sort': '<path d="M6 4v16"/><path d="M3 7l3-3 3 3"/><path d="M18 20V4"/><path d="M15 17l3 3 3-3"/>',
    'plus': '<path d="M12 5v14"/><path d="M5 12h14"/>',
    'circle-check': '<circle cx="12" cy="12" r="9"/><path d="M8.5 12.5l2.5 2.5 4.5-5"/>',
    'shield-check': '<path d="M12 3l7 3v6c0 4-3 7.5-7 9-4-1.5-7-5-7-9V6z"/><path d="M9 12l2 2 4-4"/>',
    'shield-lock': '<path d="M12 3l7 3v6c0 4-3 7.5-7 9-4-1.5-7-5-7-9V6z"/><rect x="9.5" y="11" width="5" height="4" rx="1"/><path d="M10.5 11V9.8a1.5 1.5 0 013 0V11"/>',
    'lock': '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
    'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    'chart-line': '<path d="M4 19h16"/><path d="M4 15l4-5 4 3 5-7"/>',
    'certificate': '<circle cx="12" cy="9" r="5"/><path d="M9 13.5L8 21l4-2 4 2-1-7.5"/>',
    'diamond': '<path d="M12 4l7 6-7 10-7-10z"/><path d="M5 10h14"/>',
    'info-circle': '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><path d="M12 8h.01"/>',
    'alert-triangle': '<path d="M12 4l9 16H3z"/><path d="M12 10v4"/><path d="M12 17h.01"/>',
    'bulb': '<path d="M9 17h6"/><path d="M10 21h4"/><path d="M8.5 14a5 5 0 117 0c-.8.8-1.2 1.6-1.3 3h-4.4c-.1-1.4-.5-2.2-1.3-3z"/>',
    'square': '<rect x="4" y="4" width="16" height="16" rx="2"/>',
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6L17 7M7 17l-1.4 1.4"/>',
    'wand-off': '<path d="M4 20L20 4"/><path d="M9 6l1.5 1.5"/><path d="M15 12l1.5 1.5"/>',
    'camera': '<rect x="3" y="7" width="18" height="13" rx="2"/><circle cx="12" cy="13.5" r="3.5"/><path d="M9 7l1.5-3h3L15 7"/>',
    'video': '<rect x="3" y="6" width="12" height="12" rx="2"/><path d="M15 10l6-3v10l-6-3z"/>',
    'receipt': '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6"/><path d="M9 12h6"/>',
    'receipt-2': '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6"/><path d="M9 12h4"/>',
    'file-check': '<path d="M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8z"/><path d="M14 3v5h5"/><path d="M9.5 15l1.5 1.5 3.5-3.5"/>',
    'file-text': '<path d="M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8z"/><path d="M14 3v5h5"/><path d="M9 13h6"/><path d="M9 17h4"/>',
    'clipboard-list':
        '<rect x="8" y="3" width="8" height="4" rx="1"/><path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/><path d="M9 12h6"/><path d="M9 16h4"/>',
    'map-pin': '<path d="M12 21s7-6 7-11a7 7 0 10-14 0c0 5 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
    'wallet': '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18"/><circle cx="16.5" cy="14" r="1.2"/>',
    'building-bank': '<path d="M4 10h16"/><path d="M12 3l9 5H3z"/><path d="M6 10v8M10 10v8M14 10v8M18 10v8"/><path d="M3 21h18"/>',
    'device-mobile': '<rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/>',
    'mail': '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 8l9 6 9-6"/>',
    'bell': '<path d="M6 10a6 6 0 1112 0c0 4 1.5 5 1.5 5H4.5S6 14 6 10z"/><path d="M10 20h4"/>',
    'home': '<path d="M4 11l8-7 8 7"/><path d="M6 10v10h12V10"/>',
    'search': '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4-4"/>',
    'user': '<circle cx="12" cy="8" r="4"/><path d="M4.5 20a7.5 7.5 0 0115 0"/>',
    'user-check': '<circle cx="10" cy="8" r="4"/><path d="M3 20a7 7 0 0111.5-5.4"/><path d="M15.5 18.5l1.7 1.7 3.3-3.4"/>',
    'users': '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0113 0"/><path d="M16 5.2a3.5 3.5 0 010 5.6"/><path d="M18 15.5a6.5 6.5 0 013.5 4.5"/>',
    'heart': '<path d="M12 20s-7-4.6-7-9.3A3.9 3.9 0 0112 8a3.9 3.9 0 017 2.7C19 15.4 12 20 12 20z"/>',
    'tag': '<path d="M4 4h7l9 9-7 7-9-9z"/><circle cx="8.5" cy="8.5" r="1.3"/>',
    'language': '<path d="M4 6h9"/><path d="M8.5 4v2"/><path d="M11 6c0 4-3 8-7 9"/><path d="M6.5 11c1 2.5 3 4 5.5 5"/><path d="M13 20l4-10 4 10"/><path d="M14.5 17h5"/>',
    'help': '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.6 2.6 0 015 1c0 1.7-2.5 2-2.5 3.5"/><path d="M12 17.5h.01"/>',
    // Added for the Flutter build: password visibility toggle.
    'eye': '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
    'eye-off':
        '<path d="M3 3l18 18"/><path d="M10.6 10.6a2 2 0 002.8 2.8"/><path d="M9.4 5.2A10 10 0 0112 5c6.4 0 10 7 10 7a17 17 0 01-3.2 4.1M6.6 6.6A17 17 0 002 12s3.6 7 10 7a9.7 9.7 0 005.4-1.6"/>',
  };
}
