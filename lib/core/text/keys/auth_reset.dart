import '../text_key.dart';

/// Forgot password (backend spec 020, US1): the two screens that take the phone, then the SMS
/// code with a new password, and the notice shown on sign-in afterwards. `auth.reset.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class AuthResetKeys {
  static const _area = 'Auth';
  static const _ask = 'Forgot password screen';
  static const _set = 'Reset password screen';
  static const _done = 'Sign in, after a reset';

  // ---- Step 1: the phone ----

  static const askTitle = TextKey('auth.reset.ask_title', 'Reset your password', ar: 'استرجاع كلمة السر', area: _area, where: _ask);
  static const askBody = TextKey(
    'auth.reset.ask_body',
    'Enter the phone number on your account. We will send you a code to set a new password.',
    ar: 'اكتب رقم الموبايل اللي على حسابك. هنبعتلك كود عشان تحط كلمة سر جديدة.',
    area: _area,
    where: _ask,
  );
  static const sendCode = TextKey('auth.reset.send_code', 'Send the code', ar: 'ابعتلي الكود', area: _area, where: _ask);
  static const phoneMissing = TextKey('auth.reset.phone_missing', 'Enter your phone number.', ar: 'اكتب رقم الموبايل.', area: _area, where: _ask);
  static const backToSignIn = TextKey('auth.reset.back_to_sign_in', 'Back to sign in', ar: 'ارجع لتسجيل الدخول', area: _area, where: _ask);

  // ---- Step 2: the code and the new password ----

  static const setTitle = TextKey('auth.reset.set_title', 'Choose a new password', ar: 'اختار كلمة سر جديدة', area: _area, where: _set);
  static const setBody = TextKey(
    'auth.reset.set_body',
    'We sent a six digit code to {phone}. Enter it with your new password.',
    ar: 'بعتنا كود من ست أرقام على {phone}. اكتبه مع كلمة السر الجديدة.',
    placeholders: ['phone'],
    area: _area,
    where: _set,
  );
  static const codeLabel = TextKey('auth.reset.code_label', 'Code', ar: 'الكود', area: _area, where: _set);
  static const newPasswordLabel = TextKey('auth.reset.new_password_label', 'New password', ar: 'كلمة السر الجديدة', area: _area, where: _set);
  static const confirmPasswordLabel = TextKey('auth.reset.confirm_password_label', 'Confirm the new password', ar: 'أكد كلمة السر الجديدة', area: _area, where: _set);
  static const passwordHint = TextKey('auth.reset.password_hint', 'At least 10 characters', ar: 'عشر حروف على الأقل', area: _area, where: _set);
  static const submit = TextKey('auth.reset.submit', 'Set the new password', ar: 'حدد كلمة السر الجديدة', area: _area, where: _set);
  static const codeMissing = TextKey('auth.reset.code_missing', 'Enter the six digit code.', ar: 'اكتب الكود المكوّن من ست أرقام.', area: _area, where: _set);
  static const passwordShort = TextKey('auth.reset.password_short', 'Choose a password of at least 10 characters.', ar: 'اختار كلمة سر من عشر حروف على الأقل.', area: _area, where: _set);
  static const passwordMismatch = TextKey('auth.reset.password_mismatch', 'The two passwords do not match.', ar: 'كلمتا السر مش زي بعض.', area: _area, where: _set);
  static const resendIn = TextKey(
    'auth.reset.resend_in',
    'You can ask for a new code in {seconds}s',
    ar: 'تقدر تطلب كود جديد بعد {seconds} ث',
    placeholders: ['seconds'],
    area: _area,
    where: _set,
  );
  static const didntArrive = TextKey('auth.reset.didnt_arrive', 'Didn\'t arrive?', ar: 'الكود ماوصلش؟', area: _area, where: _set);
  static const sendAgain = TextKey('auth.reset.send_again', 'Send it again', ar: 'ابعته تاني', area: _area, where: _set);
  static const sentAgain = TextKey('auth.reset.sent_again', 'Code sent again.', ar: 'بعتنا الكود تاني.', area: _area, where: _set);
  static const startOver = TextKey('auth.reset.start_over', 'Start again', ar: 'ابدأ من الأول', area: _area, where: _set);

  // ---- After the reset: shown on sign in ----

  static const doneTitle = TextKey('auth.reset.done_title', 'Your password was changed', ar: 'كلمة السر اتغيرت', area: _area, where: _done);
  static const doneBody = TextKey(
    'auth.reset.done_body',
    'Every device was signed out. Sign in with your new password.',
    ar: 'كل الأجهزة خرجت من الحساب. ادخل بكلمة السر الجديدة.',
    area: _area,
    where: _done,
  );
  static const donePaused = TextKey(
    'auth.reset.done_paused',
    'For your safety, withdrawals are paused until {until}.',
    ar: 'لأمانك، السحب متوقف لحد {until}.',
    placeholders: ['until'],
    area: _area,
    where: _done,
  );
  static const doneCancelled = TextKey(
    'auth.reset.done_cancelled',
    'Withdrawals that had not left ({count}) were cancelled and the money is back in your wallet.',
    ar: 'طلبات السحب اللي ماخرجتش ({count}) اتلغت والفلوس رجعت محفظتك.',
    placeholders: ['count'],
    area: _area,
    where: _done,
  );

  static const all = <TextKey>[
    askTitle,
    askBody,
    sendCode,
    phoneMissing,
    backToSignIn,
    setTitle,
    setBody,
    codeLabel,
    newPasswordLabel,
    confirmPasswordLabel,
    passwordHint,
    submit,
    codeMissing,
    passwordShort,
    passwordMismatch,
    resendIn,
    didntArrive,
    sendAgain,
    sentAgain,
    startOver,
    doneTitle,
    doneBody,
    donePaused,
    doneCancelled,
  ];
}
