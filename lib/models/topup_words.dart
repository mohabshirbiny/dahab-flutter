import 'wallet.dart';

/// Customer-facing wording for top-ups (backend spec 009). The API sends only
/// codes; these English source strings go through the app's dictionary
/// (Arabic in `core/i18n/ar_extra.dart`), like [WalletLabels].
class TopUpMethodWords {
  const TopUpMethodWords({required this.icon, required this.title, required this.sub, required this.feeLabel, required this.detailTitle, required this.copyLabel});

  final String icon;
  final String title;
  final String sub;
  final String feeLabel;
  final String detailTitle;
  final String copyLabel;
}

class TopUpWords {
  static const methods = <String, TopUpMethodWords>{
    'bank_transfer': TopUpMethodWords(
      icon: 'building-bank',
      title: 'Bank transfer',
      sub: 'No fee · arrives same working day',
      feeLabel: 'Bank fee',
      detailTitle: 'Transfer to this account',
      copyLabel: 'Copy details',
    ),
    'instapay': TopUpMethodWords(
      icon: 'device-mobile',
      title: 'InstaPay',
      sub: 'Their fee applies · instant',
      feeLabel: 'InstaPay fee',
      detailTitle: 'Send to this InstaPay address',
      copyLabel: 'Copy address',
    ),
    'vodafone_cash': TopUpMethodWords(
      icon: 'wallet',
      title: 'Vodafone Cash',
      sub: 'Their fee applies · instant',
      feeLabel: 'Vodafone Cash fee',
      detailTitle: 'Send to this wallet',
      copyLabel: 'Copy number',
    ),
  };

  static TopUpMethodWords method(String code) =>
      methods[code] ?? const TopUpMethodWords(icon: 'wallet', title: 'Transfer', sub: '', feeLabel: 'Fee', detailTitle: 'Send to', copyLabel: 'Copy');

  static String detailLabel(String key) => switch (key) {
    'bank_name' => 'Bank',
    'account_holder' => 'Account name',
    'account_number' => 'Account number',
    'iban' => 'IBAN',
    'instapay_address' => 'Address',
    'wallet_number' => 'Number',
    _ => key,
  };

  static String status(TopUpStatus s) => switch (s) {
    TopUpStatus.pending => 'Waiting to be matched',
    TopUpStatus.onHold => 'We are checking your transfer',
    TopUpStatus.credited => 'Added to your wallet',
    TopUpStatus.rejected => 'Not added',
    TopUpStatus.cancelled => 'You cancelled it',
  };

  static String rejectReason(String? code) => switch (code) {
    'money_not_received' => 'We did not receive this transfer',
    'duplicate_notice' => 'This transfer was already reported in another notice',
    'sender_not_accepted' => 'We could not accept a transfer from this sender',
    _ => 'We could not match this transfer',
  };
}
