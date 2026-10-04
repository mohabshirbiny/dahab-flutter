import 'package:flutter/material.dart';

import '../../models/piece.dart';
import '../../widgets/widgets.dart';
import 'listing_ui.dart';

/// `cardHTML(it)` — a piece on the Home / Browse / Saved grids.
class PieceCard extends StatelessWidget {
  const PieceCard({super.key, required this.piece});

  final Piece piece;

  @override
  Widget build(BuildContext context) {
    return DCard(
      padding: EdgeInsets.zero,
      clip: true,
      borderColor: piece.mine ? DColors.gold : null,
      onTap: () => context.openPiece(view: piece.mine ? 'owner' : 'buyer', id: piece.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          piece.photoPath == null ? const PieceThumb(height: 96) : ApiImage(path: piece.photoPath, height: 96),
          Padding(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(
                  piece.priceAvailable ? money(piece.price) : 'Price not available right now',
                  style: TextStyle(fontSize: piece.priceAvailable ? 15 : 13, fontWeight: FontWeight.w600),
                ),
                const Gap(3),
                T(piece.specLine, style: DText.tiny),
                T(piece.feeLine, style: DText.tiny),
                const Gap(7),
                piece.mine ? const DPill('Yours', kind: PillKind.yours) : const DPill('IGI checks it before you pay', kind: PillKind.wait),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.thumb` — photo placeholder. The prototype has no product photography;
/// every image slot is this paper tile with a diamond glyph, so it is kept
/// as-is and isolated here for real photos later.
class PieceThumb extends StatelessWidget {
  const PieceThumb({super.key, this.height = 96, this.iconSize = 26, this.child});

  final double height;
  final double iconSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: DColors.paper,
      alignment: Alignment.center,
      child: child ?? DIcon('diamond', size: iconSize, color: DColors.line2),
    );
  }
}

/// `.grid2` — two equal columns, 10px gap; each row as tall as its tallest
/// cell, like CSS grid.
class Grid2 extends StatelessWidget {
  const Grid2({super.key, required this.children, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: gap),
              Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(SizedBox(height: gap));
    }
    return Column(children: rows);
  }
}
