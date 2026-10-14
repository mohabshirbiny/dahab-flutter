import '../text_key.dart';

/// The invoice screen after the commission became VAT-inclusive (backend package C): the seller's
/// commission rows, and the buyer's price difference shown as Dahab's commission (item 13).
/// `invoice.vat.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class InvoiceVatKeys {
  static const _area = 'Wallet';
  static const _where = 'Invoice screen';

  static const commissionBeforeVat = TextKey(
    'invoice.vat.commission_before_vat',
    'Commission before VAT ({pct}%, VAT included)',
    ar: 'العمولة قبل الضريبة ({pct}٪ شاملة الضريبة)',
    placeholders: ['pct'],
    area: _area,
    where: _where,
  );
  static const commissionVatIncluded = TextKey('invoice.vat.commission_vat_included', 'Commission, VAT included', ar: 'العمولة شاملة الضريبة', area: _area, where: _where);
  static const commission = TextKey('invoice.vat.commission', 'Commission', ar: 'العمولة', area: _area, where: _where);

  static const all = <TextKey>[commissionBeforeVat, commissionVatIncluded, commission];
}
