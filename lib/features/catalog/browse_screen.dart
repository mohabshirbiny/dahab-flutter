import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/piece.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/piece_card.dart';

/// `#s-browse` — filter chips over the grid of available pieces.
///
/// The pieces come from the public market (backend spec 010). Search and the
/// chips work on the device, over the pieces that were loaded: Rings /
/// Earrings by type, 21K by karat, and "Making charge" sorts by the making
/// charge, lowest first. "Origin" has no data behind it and only toggles, as
/// in the prototype. The search field is an addition.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final _on = <String>{};
  String _query = '';

  void _toggle(String chip) => setState(() => _on.contains(chip) ? _on.remove(chip) : _on.add(chip));

  List<Piece> _apply(List<Piece> all) {
    final kinds = <String>{if (_on.contains('Rings')) 'ring', if (_on.contains('Earrings')) 'earrings'};
    var list = all.where((p) {
      if (kinds.isNotEmpty && !kinds.contains(p.kind)) return false;
      if (_on.contains('21K') && p.karat != 21) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final hay = '${p.title} ${p.titleAr ?? ''} ${p.specLine} ${p.kind} ${p.price}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    if (_on.contains('Making charge')) {
      list.sort((a, b) => (a.makingPerGram ?? 1 << 20).compareTo(b.makingPerGram ?? 1 << 20));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.browse,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                _SearchField(onChanged: (v) => setState(() => _query = v.trim())),
                const Gap(10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DChips(
                    children: [
                      for (final c in const ['Rings', '21K', 'Earrings', 'Origin']) DChip(c, on: _on.contains(c), onTap: () => _toggle(c)),
                      DChip('Making charge', leadingIcon: 'arrows-sort', on: _on.contains('Making charge'), onTap: () => _toggle('Making charge')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AsyncView<List<Piece>>(
              load: context.read<CatalogRepository>().pieces,
              loadingHeight: 260,
              builder: (context, all) {
                final items = _apply(all);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T('${items.length} pieces. Every one is inspected by IGI before you pay the balance.', style: DText.tiny),
                    const Gap(11),
                    const DNote(icon: 'tag', text: 'Your piece shows here too, marked Yours. A useful way to see how your making charge compares.'),
                    const Gap(12),
                    if (items.isEmpty)
                      const DEmpty(icon: 'search', title: 'Nothing here', body: 'No pieces match this search.')
                    else
                      Grid2(children: [for (final p in items) PieceCard(piece: p)]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DRadius.input),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      onChanged: onChanged,
      cursorColor: DColors.ink,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: DColors.white,
        hintText: context.t('Search pieces'),
        hintStyle: const TextStyle(color: DColors.ink3, fontSize: 14),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: DIcon('search', size: 16, color: DColors.ink3),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: border(DColors.line),
        enabledBorder: border(DColors.line),
        focusedBorder: border(DColors.ink),
      ),
    );
  }
}
