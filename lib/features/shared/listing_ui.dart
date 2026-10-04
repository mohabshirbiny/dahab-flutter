import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api/api_client.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/media_picker.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';

/// Asks for a file and puts it in a sell-flow slot; a filled slot asks before
/// replacing. The backend re-checks the type and size on upload.
Future<void> pickIntoSlot(BuildContext context, String key) async {
  final draft = context.read<SellDraft>();
  if (draft.has(key)) {
    final ok = await ask(context, title: 'Replace this', body: 'You can take it again if you are not happy with it.', yes: 'Replace');
    if (!ok || !context.mounted) return;
  }
  final picked = await context.read<MediaPicker>().pick(SellDraft.kindOf(key));
  if (picked == null || !context.mounted) return;
  if (picked.file == null) return showToast(context, picked.error!);
  draft.setFile(key, picked.file!);
  showToast(context, 'Added.');
}

/// What to tell a seller when the backend refuses a listing request
/// (backend spec 010 codes), in the English source wording.
String listingErrorMessage(ApiException e) {
  switch (e.code) {
    case 'seller_suspended':
      return 'This account is suspended. Contact us for help.';
    case 'photo_required':
      return 'Add at least one photo of the piece.';
    case 'branch_options_required':
      return 'Choose at least one branch you can bring the piece to.';
    case 'ownership_declaration_required':
      return 'Confirm ownership to list the piece.';
    case 'gold_needs_karat_weight':
      return 'Gold needs a karat and a weight.';
    case 'listing_not_editable':
    case 'illegal_listing_transition':
      return 'This listing has moved on, so that is no longer possible. Open My listings to see where it is.';
    case 'karat_disabled':
      return 'Dahab is not accepting this karat right now.';
    case 'upload_token_invalid':
      return 'The files took too long to send. Try again.';
    case 'not_found':
      return 'This listing is no longer available.';
    case 'validation_failed':
      if (e.fieldError('ownership_legal_doc_id') != null) return 'The declaration text changed. Read it again and confirm.';
      if (e.fieldError('description') != null) return 'Add a little more detail before continuing.';
      if (e.fieldError('piece_type_id') != null || e.fieldError('karat_code') != null) {
        return 'Dahab is not accepting this kind of piece right now. Go back and choose again.';
      }
      if (e.fieldErrors.keys.any((k) => k.startsWith('branch_option_ids'))) {
        return 'One of the branches is no longer available. Choose again.';
      }
      return 'Check the details and try again.';
  }
  return authErrorMessage(e);
}

/// One sentence per buy-request refusal (backend spec 011).
String buyRequestErrorMessage(ApiException e) {
  switch (e.code) {
    case 'price_moved':
      final fresh = (e.extra['details'] as Map?)?['current_price'] as String?;
      return fresh == null ? 'The price has changed. Check it and send again.' : 'The price is now ${moneyOf(fresh)}. Check it and send again.';
    case 'price_unavailable':
      return 'This piece cannot be priced right now. Try again in a few minutes.';
    case 'already_in_queue':
      return 'You already have a request on this piece.';
    case 'cannot_buy_own_listing':
      return 'This is your own piece.';
    case 'listing_not_purchasable':
      return 'This piece cannot be requested now.';
    case 'deposit_agreement_required':
      return 'The deposit terms changed. Read them again and send.';
    case 'not_in_queue':
      return 'This request is no longer in the queue.';
    case 'not_queue_head':
    case 'queue_empty':
      return 'The line has changed. It has been refreshed.';
    case 'branch_not_in_options':
      return 'That branch is not available any more. Choose another.';
    case 'buyer_suspended':
      return 'This buyer cannot be accepted right now. You can decline the request.';
    case 'branch_hours_unavailable':
      return 'The deadline at this branch cannot be worked out. Choose another branch.';
    case 'insufficient_funds':
      return 'Your wallet does not cover the deposit. Add funds first.';
  }
  return listingErrorMessage(e);
}

/// A photo the API streams (a listing photo). Public market photos need no
/// session; the owner's own media does ([auth]). Falls back to the paper tile
/// while loading and when the file cannot be shown.
class ApiImage extends StatefulWidget {
  const ApiImage({super.key, required this.path, this.auth = false, this.height = 96, this.iconSize = 26});

  final String? path;
  final bool auth;
  final double height;
  final double iconSize;

  @override
  State<ApiImage> createState() => _ApiImageState();
}

class _ApiImageState extends State<ApiImage> {
  // A small memory of recent photos, so scrolling a grid does not refetch.
  static final _recent = <String, Future<Uint8List>>{};
  static const _keep = 60;

  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ApiImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  void _load() {
    final path = widget.path;
    if (path == null || path.isEmpty) return _bytes = null;
    final client = context.read<ApiClient>();
    _bytes = _recent.putIfAbsent(path, () {
      if (_recent.length >= _keep) _recent.remove(_recent.keys.first);
      final f = client.getBytes(path, auth: widget.auth).then((r) => Uint8List.fromList(r.bytes));
      f.catchError((Object _) {
        _recent.remove(path);
        return Uint8List(0);
      });
      return f;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      height: widget.height,
      color: DColors.paper,
      alignment: Alignment.center,
      child: DIcon('diamond', size: widget.iconSize, color: DColors.line2),
    );
    if (_bytes == null) return tile;
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return tile;
        return Image.memory(snap.data!, height: widget.height, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => tile);
      },
    );
  }
}
