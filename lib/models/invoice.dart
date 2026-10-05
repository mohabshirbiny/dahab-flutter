/// A tax invoice of the signed-in customer (backend spec 016,
/// `GET /customer/me/invoices`, `GET /customer/me/invoices/{id}`). Issued
/// automatically when the balance is paid: `-S` to the seller for Dahab's
/// commission and VAT, `-B` to the buyer for the price paid with VAT 0.
/// Amounts are the backend's decimal strings, shown as they are and never
/// recomputed here. Nothing is filed with the Tax Authority yet.
class CustomerInvoice {
  const CustomerInvoice({
    required this.id,
    required this.number,
    required this.isSeller,
    required this.orderId,
    required this.orderRef,
    required this.issuedAt,
    required this.net,
    required this.vat,
    required this.gross,
    required this.credited,
    required this.status,
    required this.documentReady,
    this.category,
    this.karat,
    this.typeNameEn,
    this.typeNameAr,
    this.weight,
    this.subtotal,
    this.detail,
  });

  final String id;

  /// `DH-2026-000123-S`
  final String number;

  /// A piece you sold (`seller`) or bought (`buyer`).
  final bool isSeller;
  final String orderId;
  final String orderRef;
  final DateTime? issuedAt;

  /// Seller: Dahab's commission. Buyer: the price paid.
  final String net;
  final String vat;
  final String gross;
  final String credited;

  /// issued, partly_credited, credited
  final String status;
  final bool documentReady;

  final String? category;
  final int? karat;
  final String? typeNameEn;
  final String? typeNameAr;
  final String? weight;

  /// Seller: the gross the sale settled at; buyer: the total paid.
  final String? subtotal;

  /// Only on `GET /customer/me/invoices/{id}`.
  final InvoiceDetail? detail;

  factory CustomerInvoice.fromJson(Map<String, dynamic> j) {
    final piece = (j['piece'] as Map?)?.cast<String, dynamic>();
    final lines = (j['lines'] as Map?)?.cast<String, dynamic>();
    final source = piece ?? lines ?? const <String, dynamic>{};
    return CustomerInvoice(
      id: '${j['id']}',
      number: '${j['number'] ?? ''}',
      isSeller: j['party'] == 'seller',
      orderId: '${j['order_id'] ?? ''}',
      orderRef: '${j['order_ref'] ?? ''}',
      issuedAt: DateTime.tryParse('${j['issued_at'] ?? ''}')?.toLocal(),
      net: '${j['net'] ?? '0'}',
      vat: '${j['vat'] ?? '0'}',
      gross: '${j['gross'] ?? '0'}',
      credited: '${j['credited'] ?? '0'}',
      status: '${j['status'] ?? 'issued'}',
      documentReady: j['document_ready'] == true,
      category: _str(source['category']),
      karat: (source['karat'] as num?)?.toInt(),
      typeNameEn: _str(source['piece_type_en']),
      typeNameAr: _str(source['piece_type_ar']),
      weight: _str(source['weight_g']),
      subtotal: _str(source['subtotal']),
      detail: lines == null ? null : InvoiceDetail.fromJson(j, lines),
    );
  }
}

/// The settlement lines and credit notes of one invoice (copied at issue).
class InvoiceDetail {
  const InvoiceDetail({
    required this.vatRate,
    this.unitRate,
    this.goldValue,
    this.makingTotal,
    this.askingPrice,
    this.commissionPct,
    this.paidToWallet,
    this.issuerNameEn,
    this.issuerNameAr,
    this.taxRegistrationNo,
    this.creditNotes = const [],
  });

  final String vatRate;
  final String? unitRate;
  final String? goldValue;
  final String? makingTotal;
  final String? askingPrice;
  final String? commissionPct;

  /// Seller only: what reached the wallet at settlement.
  final String? paidToWallet;
  final String? issuerNameEn;
  final String? issuerNameAr;
  final String? taxRegistrationNo;
  final List<InvoiceCreditNote> creditNotes;

  factory InvoiceDetail.fromJson(Map<String, dynamic> j, Map<String, dynamic> lines) {
    final issuer = (j['issuer'] as Map?)?.cast<String, dynamic>();
    return InvoiceDetail(
      vatRate: '${j['vat_rate'] ?? '0'}',
      unitRate: _str(lines['unit_rate']),
      goldValue: _str(lines['gold_value']),
      makingTotal: _str(lines['making_total']),
      askingPrice: _str(lines['asking_price']),
      commissionPct: _str(lines['commission_pct']),
      paidToWallet: _str(lines['paid_to_wallet']),
      issuerNameEn: _str(issuer?['legal_name_en']),
      issuerNameAr: _str(issuer?['legal_name_ar']),
      taxRegistrationNo: _str(issuer?['tax_registration_no']),
      creditNotes: [for (final n in (j['credit_notes'] as List? ?? const [])) InvoiceCreditNote.fromJson((n as Map).cast<String, dynamic>())],
    );
  }
}

/// A correction of one of your invoices: Dahab gave back part or all of its
/// commission and VAT to your wallet (backend spec 016).
class InvoiceCreditNote {
  const InvoiceCreditNote({
    required this.id,
    required this.number,
    required this.reason,
    required this.gross,
    required this.vat,
    required this.issuedAt,
    required this.documentReady,
  });

  final String id;

  /// `CN-2026-000001`
  final String number;
  final String reason;
  final String gross;
  final String vat;
  final DateTime? issuedAt;
  final bool documentReady;

  factory InvoiceCreditNote.fromJson(Map<String, dynamic> j) => InvoiceCreditNote(
    id: '${j['id']}',
    number: '${j['number'] ?? ''}',
    reason: '${j['reason'] ?? ''}',
    gross: '${j['gross'] ?? '0'}',
    vat: '${j['vat'] ?? '0'}',
    issuedAt: DateTime.tryParse('${j['issued_at'] ?? ''}')?.toLocal(),
    documentReady: j['document_ready'] == true,
  );
}

/// A downloaded PDF.
class InvoiceFile {
  const InvoiceFile({required this.filename, required this.bytes});

  final String filename;
  final List<int> bytes;
}

String? _str(Object? v) => v == null ? null : '$v';
