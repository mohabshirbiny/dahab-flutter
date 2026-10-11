import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/account_legal.dart';
import '../../core/text/texts_controller.dart';
import '../../core/utils/idempotency.dart';
import '../../models/customer.dart';
import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';

/// `#s-legal-accept` — the live terms or privacy, shown before anything else until accepted
/// (backend spec 019 FR-025, D2). It is the same screen for the first acceptance and for a
/// material change; only the title differs. The text is read from the backend, in full, and
/// accepting sends the id that was shown, so a version published meanwhile is refused and
/// the screen reloads it.
class LegalAcceptScreen extends StatefulWidget {
  const LegalAcceptScreen({super.key});

  @override
  State<LegalAcceptScreen> createState() => _LegalAcceptScreenState();
}

class _LegalAcceptScreenState extends State<LegalAcceptScreen> {
  LegalDoc? _doc;
  String? _docCode;
  bool _failed = false;
  bool _busy = false;
  String? _error;
  String? _idemKey;

  LegalRequirement? get _next {
    final list = context.read<AuthController>().legalRequired;
    return list.isEmpty ? null : list.first;
  }

  Future<void> _load() async {
    final need = _next;
    if (need == null) return;
    setState(() {
      _failed = false;
      _doc = null;
    });
    try {
      final doc = await context.read<AccountRepository>().legalDocument(need.code);
      if (mounted) {
        setState(() {
          _doc = doc;
          _docCode = need.code;
        });
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final need = _next;
    if (need != null && need.code != _docCode && !_failed && _doc == null) _load();
  }

  Future<void> _accept() async {
    final need = _next;
    if (need == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().acceptLegal(need, idempotencyKey: _idemKey ??= newIdempotencyKey());
      _idemKey = null;
      if (!mounted) return;
      if (context.read<AuthController>().legalRequired.isEmpty) {
        context.enterApp(R.home);
      } else {
        setState(() {
          _doc = null;
          _docCode = null;
        });
        await _load();
      }
    } on ApiException catch (e) {
      if (!e.isNetwork) _idemKey = null;
      if (!mounted) return;
      if (e.code == 'legal_document_not_current' || e.code == 'legal_acceptance_not_required') {
        // A newer version went live while the screen was open: read it again.
        await context.read<AuthController>().refreshMe();
        if (mounted && context.read<AuthController>().legalRequired.isEmpty) return context.enterApp(R.home);
        await _load();
      } else {
        setState(() => _error = context.kr(AccountLegalKeys.loadError));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final need = auth.legalRequired.isEmpty ? null : auth.legalRequired.first;
    final arabic = context.watch<LangController>().isArabic;
    final doc = _doc;

    return AppPage(
      id: R.legalAccept,
      title: need == null ? '' : context.k(need.isMaterial ? AccountLegalKeys.materialTitle : AccountLegalKeys.firstTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (need != null) T(context.k(AccountLegalKeys.body), style: DText.muted),
          const Gap(14),
          if (_failed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DError(context.k(AccountLegalKeys.loadError), visible: true),
                const Gap(10),
                DButton.ghost(context.k(AccountLegalKeys.retry), onTap: _load),
              ],
            )
          else if (doc == null)
            const DLoading(height: 120)
          else ...[
            T(context.k(AccountLegalKeys.version, {'version': doc.version}), style: DText.tiny),
            const Gap(10),
            Text(arabic ? doc.bodyAr : doc.bodyEn, style: const TextStyle(fontSize: 13, height: 1.75, color: DColors.ink2)),
            const Gap(18),
            DError(_error ?? '', visible: _error != null),
            DButton(context.k(AccountLegalKeys.accept), loading: _busy, onTap: _accept),
          ],
          const Gap(12),
          DButton.ghost(context.k(AccountLegalKeys.signOut), onTap: _busy ? null : () => context.read<AuthController>().logout()),
        ],
      ),
    );
  }
}
