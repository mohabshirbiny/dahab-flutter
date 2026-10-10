/// Screen ids, kept identical to the prototype's `s-<id>` screen ids so the
/// two can be compared side by side. Each id is served at `/#/<id>`.
abstract final class R {
  static const splash = 'splash';
  static const login = 'login';
  static const otp = 'otp';
  static const signup1 = 'signup1';
  static const signup2 = 'signup2';
  static const signup3 = 'signup3';

  /// Added for the API: the email code (registration step 4) and the
  /// "waiting for verification" result after submit.
  static const signupEmail = 'signup-email';
  static const signupDone = 'signup-done';

  static const home = 'home';
  static const browse = 'browse';
  static const sell1 = 'sell1';
  static const orders = 'orders';
  static const account = 'account';

  static const detail = 'detail';
  static const sell2 = 'sell2';
  static const sell3 = 'sell3';
  static const weight = 'weight';
  static const wallet = 'wallet';
  static const held = 'held';
  static const txn = 'txn';
  static const withdraw = 'withdraw';

  /// Backend spec 013: the withdrawal email link's page, `?token=`. No sign-in.
  static const withdrawConfirm = 'withdraw-confirm';
  static const addfunds = 'addfunds';

  /// Backend spec 009: the customer's own top-up notices.
  static const topups = 'topups';
  static const invoices = 'invoices';
  static const invoice = 'invoice';
  static const extend = 'extend';
  static const pay = 'pay';
  static const code = 'code';
  static const saved = 'saved';
  static const listings = 'listings';
  static const editprice = 'editprice';
  static const notif = 'notif';
  static const security = 'security';
  static const help = 'help';
  static const legal = 'legal';
  static const bank = 'bank';
  static const bankadd = 'bankadd';
  static const support = 'support';
  static const delete = 'delete';
  static const inbox = 'inbox';
  static const prices = 'prices';
  static const gate = 'gate';
  static const dispute = 'dispute';
  static const rate = 'rate';
  static const freeRelist = 'freerelist';
  static const invite = 'invite';
  static const report = 'report';
  static const inspection = 'inspection';
  static const proxy = 'proxy';
  static const compensate = 'compensate';
  static const codes = 'codes';
  static const codeuses = 'codeuses';
  static const mmapprove = 'mmapprove';
  static const reqsent = 'reqsent';
  static const topup = 'topup';
  static const branch = 'branch';

  /// Added for the API (backend spec 012): one order, `?id=`.
  static const order = 'order';

  // Backend spec 017: the account.
  static const changePhone = 'change-phone';
  static const changeEmail = 'change-email';
  static const emailConfirm = 'email-confirm';
  static const legalDoc = 'legal-doc';

  /// `AUTH` — no bottom tabs.
  static const auth = {splash, login, otp, signup1, signup2, signup3, signupEmail, signupDone, withdrawConfirm, emailConfirm};

  /// `ROOT` — tab roots; navigating to one resets the back stack.
  static const roots = {home, browse, sell1, orders, account};

  /// `TITLES` — the top bar title per screen.
  static const titles = <String, String>{
    login: 'Sign in',
    otp: 'Verification',
    signup1: 'Create account',
    signup2: 'Create account',
    signup3: 'Create account',
    signupEmail: 'Create account',
    signupDone: 'Create account',
    home: '',
    browse: 'Browse',
    detail: 'Gold ring',
    sell1: 'Sell your piece',
    sell2: 'Photos and description',
    sell3: 'Review and list',
    orders: 'Your orders',
    account: 'Account',
    weight: 'Not sure of the weight',
    branch: 'Choose a branch',
    reqsent: 'Request sent',
    topup: 'Add funds first',
    codes: 'Promo codes',
    codeuses: 'Code use log',
    mmapprove: 'Approve for market makers',
    compensate: 'Pay compensation',
    proxy: 'Someone else collects',
    inspection: 'Inspection result',
    order: 'Your order',
    report: 'Report this listing',
    dispute: 'Report a problem',
    rate: 'How did it go',
    freeRelist: 'Relist with no commission',
    invite: 'Invite a friend',
    prices: 'Where prices come from',
    gate: 'Create an account',
    wallet: 'Wallet',
    held: 'Held money',
    txn: 'Transaction',
    invoice: 'Tax invoice',
    withdraw: 'Withdraw',
    withdrawConfirm: 'Confirm your withdrawal',
    changePhone: 'Change your phone number',
    changeEmail: 'Change your email',
    emailConfirm: 'Confirm your new email',
    legalDoc: 'Terms and privacy',
    addfunds: 'Add funds',
    topups: 'Your top-ups',
    invoices: 'Invoices',
    extend: 'Ask for more time',
    pay: 'Pay the balance',
    code: 'Collection code',
    saved: 'Saved pieces',
    listings: 'My listings',
    editprice: 'Change making charge',
    bank: 'Payout account',
    bankadd: 'Add payout account',
    inbox: 'Notifications',
    notif: 'Notification settings',
    security: 'Password and devices',
    help: 'Help',
    support: 'Contact us',
    delete: 'Close your account',
    legal: 'Terms and privacy',
  };
}
