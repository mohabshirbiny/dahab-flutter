import '../models/wallet.dart';

const mockWalletSummary = WalletSummary(available: 56760, held: 11640);

/// `TXNS` from the prototype.
const mockTxns = <WalletTxn>[
  WalletTxn(
    id: 't1',
    date: '28 Aug',
    type: TxnType.moneyIn,
    label: 'Sold a gold ring',
    amount: 56952,
    reference: 'DH-2026-004417',
    typeLabel: 'Sale settled',
    balanceAfter: 68400,
    note: 'Settlement for a gold ring, 21K, 8.00 g. Commission and VAT were taken before this reached you.',
    link: 'invoice',
  ),
  WalletTxn(
    id: 't2',
    date: '26 Aug',
    type: TxnType.hold,
    label: 'Deposit held on a purchase',
    amount: -11640,
    reference: 'DH-2026-004501',
    typeLabel: 'Hold placed',
    balanceAfter: 11448,
    note: 'Set aside as your deposit on a gold ring you asked to buy. Still yours, just not spendable until the order finishes.',
    link: 'held',
  ),
  WalletTxn(
    id: 't3',
    date: '24 Aug',
    type: TxnType.moneyIn,
    label: 'Added by bank transfer',
    amount: 20000,
    reference: 'TOP-88214',
    typeLabel: 'Top-up',
    balanceAfter: 23088,
    note: 'Received from CIB account ending 4417. No fee was charged.',
  ),
  WalletTxn(
    id: 't4',
    date: '21 Aug',
    type: TxnType.moneyIn,
    label: 'Deposit returned',
    amount: 24000,
    reference: 'DH-2026-004388',
    typeLabel: 'Hold released',
    balanceAfter: 3088,
    note: 'A diamond ring was graded below the listing and you declined the new price, so your deposit came back in full.',
  ),
  WalletTxn(
    id: 't5',
    date: '19 Aug',
    type: TxnType.hold,
    label: 'Deposit held on a purchase',
    amount: -24000,
    reference: 'DH-2026-004388',
    typeLabel: 'Hold placed',
    balanceAfter: -20912,
    note: 'Set aside as your deposit on a diamond ring.',
  ),
  WalletTxn(
    id: 't6',
    date: '12 Aug',
    type: TxnType.moneyOut,
    label: 'Withdrawn to CIB 4417',
    amount: -15000,
    reference: 'WTH-77120',
    typeLabel: 'Withdrawal',
    balanceAfter: 3088,
    note: 'Sent to your payout account. Arrived the next working day.',
  ),
  WalletTxn(
    id: 't7',
    date: '2 Aug',
    type: TxnType.moneyIn,
    label: 'Sold a gold bracelet',
    amount: 41220,
    reference: 'DH-2026-004310',
    typeLabel: 'Sale settled',
    balanceAfter: 18088,
    note: 'Settlement for a gold bracelet, 18K, 5.20 g.',
    link: 'invoice',
  ),
];

/// The prototype's `FEES` and transfer details, in the shape of
/// `GET /customer/me/wallet/topup-methods` (backend spec 009).
const mockTopUpMethods = TopUpMethods(
  reference: 'DAHAB-004417',
  methods: [
    (
      'bank_transfer',
      [
        ReceivingAccount(
          id: 1,
          method: 'bank_transfer',
          label: 'CIB',
          details: [('bank_name', 'CIB'), ('account_holder', 'Dahab Trading'), ('account_number', '1000 4417 2026')],
          note: 'Dahab takes nothing on top-ups. Your bank may charge for the transfer.',
        ),
      ],
    ),
    (
      'instapay',
      [
        ReceivingAccount(
          id: 2,
          method: 'instapay',
          label: 'InstaPay',
          details: [('instapay_address', 'dahab@instapay')],
          dailyLimit: 70000,
          providerFeePercent: 0.5,
          note: 'The fee is charged by InstaPay, not by Dahab. Dahab takes nothing on top-ups.',
        ),
      ],
    ),
    (
      'vodafone_cash',
      [
        ReceivingAccount(
          id: 3,
          method: 'vodafone_cash',
          label: 'Vodafone Cash',
          details: [('wallet_number', '010 4417 2026')],
          dailyLimit: 60000,
          providerFeePercent: 1,
          note: 'The fee is charged by Vodafone, not by Dahab. Dahab takes nothing on top-ups.',
        ),
      ],
    ),
  ],
);

const mockInvoices = <InvoiceSummary>[
  InvoiceSummary(number: 'DH-2026-004417', sub: '28 Aug, sold a gold ring, 56,952 EGP', kind: 'sold'),
  InvoiceSummary(number: 'DH-2026-004392', sub: '19 Aug, bought earrings with stones, 78,400 EGP', kind: 'bought'),
  InvoiceSummary(number: 'DH-2026-004310', sub: '2 Aug, sold a gold bracelet, 41,220 EGP', kind: 'sold'),
];
