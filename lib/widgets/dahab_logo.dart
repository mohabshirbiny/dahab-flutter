import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

/// The wordmark from the prototype's inline SVG:
/// `<text x="6" y="60" font-size="60" font-weight="600">Dahab</text>` in a
/// Didot / Playfair Display stack, plus a gold dot at (198, 56) r=6, on a
/// 280×80 viewBox. The logo always reads left to right, even in Arabic.
class DahabLogo extends StatelessWidget {
  const DahabLogo({super.key, required this.height, required this.width, this.color = DColors.ink});

  final double height;
  final double width;
  final Color color;

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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 6,
                  top: 0,
                  child: Baseline(
                    baseline: 60,
                    baselineType: TextBaseline.alphabetic,
                    child: Text(
                      'Dahab',
                      style: TextStyle(fontFamily: DFonts.logo, fontSize: 60, fontWeight: FontWeight.w600, letterSpacing: -1, color: color, height: 1),
                    ),
                  ),
                ),
                Positioned(
                  left: 192,
                  top: 50,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: DColors.logoDot, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
