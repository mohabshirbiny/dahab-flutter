import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

/// The wordmark from the prototype's inline SVG:
/// `<text x="6" y="60" font-size="60" font-weight="600">Dahab</text>` in a
/// Didot / Playfair Display stack, plus a gold dot r=6 on the baseline, on a
/// 280×80 viewBox. The logo always reads left to right, even in Arabic.
///
/// The dot follows the word (so the real font's width never leaves a gap), and
/// [centred] puts the word and dot in the middle of the box (the splash, owner
/// notes of 2026-10-29); otherwise they start at the left, as in the top bar.
class DahabLogo extends StatelessWidget {
  const DahabLogo({super.key, required this.height, required this.width, this.color = DColors.ink, this.centred = false});

  final double height;
  final double width;
  final Color color;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 280,
            height: 80,
            child: Align(
              alignment: centred ? Alignment.center : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: centred ? 0 : 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Dahab'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(color: DColors.logoDot, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontFamily: DFonts.logo, fontSize: 60, fontWeight: FontWeight.w600, letterSpacing: -1, color: color, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
