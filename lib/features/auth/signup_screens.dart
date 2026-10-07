import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/governorates.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../widgets/widgets.dart';
import 'login_screens.dart';

/// Registration runs the backend's six steps behind the prototype's three
/// screens (plus a code screen for the email, which the backend verifies
/// separately):
///
///   Step 1 of 3  name · phone · password        → register/start
///   Step 2 of 3  phone code · governorate · email → verify-phone-otp + email
///                email code (new screen)          → verify-email-otp
///   Step 3 of 3  ID photos · consent             → documents + submit
///   result       waiting for verification (new screen)
class _Step extends StatelessWidget {
  const _Step(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: T('Step $n of 3', style: DText.tiny),
  );
}

/// Shown when the server says the registration session is gone.
Future<void> _restartRegistration(BuildContext context, ApiException e) async {
  await tell(context, title: 'Create account', body: authErrorMessage(e));
  if (!context.mounted) return;
  context.read<AuthController>().clearDraft();
  context.enterApp(R.splash);
  context.nav(R.signup1);
}

/// `#s-signup1` — name, phone, password, terms.
class Signup1Screen extends StatefulWidget {
  const Signup1Screen({super.key});

  @override
  State<Signup1Screen> createState() => _Signup1ScreenState();
}

class _Signup1ScreenState extends State<Signup1Screen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  String _cc = '+20';
  bool _terms = false;
  String? _formError;
  bool _termsError = false;
  Map<String, String?> _fieldErrors = const {};
  bool _busy = false;

  static const _minPassword = 10; // dahab-auth.password.min_length

  @override
  void dispose() {
    for (final c in [_name, _phone, _pw1, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _formError = null;
      _termsError = false;
      _fieldErrors = const {};
    });
    if ([_name, _phone, _pw1, _pw2].any((c) => c.text.trim().isEmpty)) {
      return setState(() => _formError = 'Fill in every field to continue.');
    }
    if (_pw1.text.length < _minPassword) return setState(() => _formError = 'Your password needs at least 10 characters.');
    if (_pw1.text != _pw2.text) return setState(() => _formError = 'The two passwords are not the same.');
    if (!_terms) return setState(() => _termsError = true);

    setState(() => _busy = true);
    try {
      await context.read<AuthController>().registerStart(
        name: _name.text.trim(),
        phone: toE164(_cc, _phone.text),
        password: _pw1.text,
        lang: context.read<LangController>().isArabic ? 'ar' : 'en',
      );
      if (mounted) context.nav(R.signup2);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = {'name': e.fieldError('name'), 'phone': e.fieldError('phone'), 'password': e.fieldError('password')};
        if (_fieldErrors.values.every((v) => v == null)) _formError = authErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.signup1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Step(1),
          const T("Let's start with your phone", style: DText.h2),
          const Gap(6),
          const T('Your number is how you sign in, and it stays with your account.', style: DText.muted),
          const Gap(20),
          DField(
            label: 'Full name, as written on your ID',
            error: _fieldErrors['name'],
            child: DInput(controller: _name, hint: 'Mona Hassan Ibrahim', autofillHints: const [AutofillHints.name]),
          ),
          DField(
            label: 'Phone number',
            error: _fieldErrors['phone'],
            hint: 'Living abroad? Use your own number. Handover still happens in Cairo.',
            child: PhoneInput(code: _cc, onCode: (v) => setState(() => _cc = v), controller: _phone, hint: '10 0000 0000'),
          ),
          DField(
            label: 'Choose a password',
            error: _fieldErrors['password'],
            child: DInput(controller: _pw1, password: true, hint: 'At least 10 characters'),
          ),
          DField(
            label: 'Type it again',
            bottom: 0,
            child: DInput(controller: _pw2, password: true, hint: 'The same password'),
          ),
          DError(_formError ?? '', visible: _formError != null),
          const Gap(16),
          const DNote(icon: 'users', text: 'Everyone on Dahab is verified. That is what makes it safe to trade gold with someone you have never met.'),
          const Gap(16),
          DCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DLabel('Before you continue', bottom: 8),
                const T('The three things that matter most', style: DText.tiny),
                const Gap(10),
                const DCheckLine("Dahab is the middle party between you and the other side. We hold the money, we don't own the piece.", bottom: 6),
                const DCheckLine('Deadlines are real. Missing one can cancel the sale or cost you your deposit.', bottom: 6),
                const DCheckLine('You confirm every piece you list is yours to sell.', bottom: 10),
                DLink(
                  'Read the full terms',
                  style: DText.link12,
                  onTap: () => context.nav(R.legalDoc, query: {'code': 'terms'}),
                ),
              ],
            ),
          ),
          const Gap(14),
          DCheck(
            value: _terms,
            onChanged: (v) => setState(() {
              _terms = v;
              _termsError = false;
            }),
            text: 'I have read and accept the terms of use and the privacy policy.',
          ),
          DError('Accept the terms to create your account.', visible: _termsError),
          const Gap(10),
          DButton('Send me a code', loading: _busy, onTap: _submit),
          const Gap(18),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                T('Already have an account?', style: DText.muted.copyWith(height: 1.2)),
                const SizedBox(width: 4),
                DLink('Sign in', style: DText.link13, onTap: () => context.nav(R.login)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `#s-signup2` — phone code, governorate, email.
class Signup2Screen extends StatefulWidget {
  const Signup2Screen({super.key});

  @override
  State<Signup2Screen> createState() => _Signup2ScreenState();
}

class _Signup2ScreenState extends State<Signup2Screen> {
  late String _gov = context.read<AuthController>().draft?.governorate ?? 'cairo';
  late final _email = TextEditingController(text: context.read<AuthController>().draft?.email);
  String _otp = '';
  String? _otpError;
  String? _emailError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final auth = context.read<AuthController>();
    final phoneVerified = auth.draft?.phoneVerified ?? false;
    setState(() {
      _otpError = null;
      _emailError = null;
      _formError = null;
    });
    if (!phoneVerified && _otp.length < 6) return setState(() => _otpError = 'Enter the code we sent you.');
    final e = _email.text.trim();
    if (e.isEmpty) return setState(() => _emailError = 'Enter your email address.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return setState(() => _emailError = 'Enter a valid email address.');

    setState(() => _busy = true);
    try {
      await auth.registerPhoneAndEmail(phoneOtp: _otp, email: e, governorate: _gov);
      if (mounted) context.nav(R.signupEmail);
    } on ApiException catch (err) {
      if (!mounted) return;
      if (isRegistrationGone(err)) return _restartRegistration(context, err);
      setState(() {
        if (err.code == 'otp_invalid' || err.code == 'otp_expired') {
          _otpError = authErrorMessage(err);
        } else if (err.fieldError('email') != null) {
          _emailError = err.fieldError('email');
        } else {
          _formError = authErrorMessage(err);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<AuthController>().registerResendPhoneCode();
      if (mounted) showToast(context, 'Code sent again.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _otpError = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<AuthController>().draft;
    final phoneVerified = draft?.phoneVerified ?? false;
    return AppPage(
      id: R.signup2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Step(2),
          const T('Confirm your number', style: DText.h2),
          const Gap(6),
          phoneVerified
              ? const T('Your phone number is confirmed.', style: DText.muted)
              : Text('${context.t('Enter the six digit code we just sent you.')} ${maskPhone(draft?.phone ?? '')}', style: DText.muted),
          const Gap(18),
          if (!phoneVerified) ...[
            DOtp(onChanged: (v) => setState(() => _otp = v)),
            DError(_otpError ?? '', visible: _otpError != null),
            const Gap(14),
            Center(child: DLink('Send it again', onTap: _resend)),
            const Gap(22),
          ] else
            const Gap(4),
          DField(
            label: 'Where are you?',
            child: DSelect<String>(options: governorates, value: _gov, onChanged: (v) => setState(() => _gov = v)),
          ),
          if (!isInCoverage(_gov)) ...[
            const DNote(
              icon: 'info-circle',
              kind: NoteKind.wait,
              text: 'Inspection and handover happen at IGI in Cairo for now. You can still sign up, and we will tell you when we reach you.',
            ),
            const Gap(14),
          ],
          DField(
            label: 'Email address',
            bottom: 0,
            error: _emailError,
            child: DInput(
              controller: _email,
              hint: 'you@email.com',
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
            ),
          ),
          const Gap(13),
          const DNote(icon: 'mail', text: 'We will send a code to confirm it. Your email is the second check whenever you withdraw money.'),
          const Gap(18),
          DButton('Continue', loading: _busy, onTap: _continue),
          DError(_formError ?? '', visible: _formError != null),
        ],
      ),
    );
  }
}

/// Registration step 4 — the email code. Not a separate screen in the
/// prototype (it had no email code); laid out like the other code screens.
class SignupEmailScreen extends StatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  String _otp = '';
  String? _error;
  bool _busy = false;

  Future<void> _verify() async {
    if (_otp.length < 6) return setState(() => _error = 'Enter the code we sent you.');
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().registerVerifyEmail(_otp);
      if (mounted) context.nav(R.signup3);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (isRegistrationGone(e)) return _restartRegistration(context, e);
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<AuthController>().registerResendEmailCode();
      if (mounted) showToast(context, 'Code sent again.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthController>().draft?.email ?? '';
    return AppPage(
      id: R.signupEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Step(2),
          const T('Confirm your email', style: DText.h2),
          const Gap(6),
          Text('${context.t('Enter the six digit code we sent to')} $email', style: DText.muted),
          const Gap(20),
          DOtp(onChanged: (v) => setState(() => _otp = v)),
          const Gap(14),
          Center(
            child: Wrap(
              children: [
                const T("Didn't arrive?", style: DText.tiny),
                const SizedBox(width: 4),
                DLink('Send it again', onTap: _resend),
              ],
            ),
          ),
          const Gap(20),
          DButton('Continue', loading: _busy, onTap: _verify),
          DError(_error ?? '', visible: _error != null),
        ],
      ),
    );
  }
}

/// A picked ID image, ready to upload.
class _IdImage {
  const _IdImage(this.file);
  final UploadFile file;
}

/// `#s-signup3` — identity documents, then submit for review.
class Signup3Screen extends StatefulWidget {
  const Signup3Screen({super.key});

  @override
  State<Signup3Screen> createState() => _Signup3ScreenState();
}

class _Signup3ScreenState extends State<Signup3Screen> {
  String _doc = 'egyptian_id';
  _IdImage? _front;
  _IdImage? _back;
  bool _consent = false;
  String? _error;
  bool _busy = false;

  bool get _passport => _doc == 'passport';

  /// `dahab-identity.allowed_mimes` / `max_upload_kb`.
  static const _allowed = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxBytes = 8192 * 1024;

  Future<void> _pick(bool front) async {
    final current = front ? _front : _back;
    if (current != null) {
      final ok = await ask(context, title: 'Replace this', body: 'You can take it again if you are not happy with it.', yes: 'Replace');
      if (!ok) return;
    }
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: _allowed);
    if (picked == null || !mounted) return;
    final ext = (picked.extension ?? '').toLowerCase();
    if (!_allowed.contains(ext)) return showToast(context, 'Use a JPG, PNG or WEBP photo.');
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) return showToast(context, 'That photo is larger than 8 MB.');
    final image = _IdImage(
      UploadFile(field: front ? 'front' : 'back', filename: picked.name, bytes: bytes, contentType: ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg')),
    );
    setState(() {
      front ? _front = image : _back = image;
      _error = null;
    });
    showToast(context, 'Added.');
  }

  Future<void> _create() async {
    if (_front == null || (!_passport && _back == null)) return setState(() => _error = 'Add the photos of your ID first.');
    if (!_consent) return setState(() => _error = 'Tick the box to finish setting up your account.');
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().registerDocumentsAndSubmit(documentType: _doc, front: _front!.file, back: _passport ? null : _back!.file);
      if (mounted) context.enterApp(R.signupDone);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (isRegistrationGone(e)) return _restartRegistration(context, e);
      setState(() => _error = e.fieldError('front') ?? e.fieldError('back') ?? authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _slot(String title, _IdImage? image, bool front) => DSlot(
    title: title,
    done: image != null,
    sub: image != null ? 'Added' : 'Tap to add',
    subColor: image != null ? DColors.ok : null,
    footer: image != null
        ? [const Gap(2), Text(image.file.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: DText.tiny), const T('Tap to replace', style: DText.linkTiny)]
        : null,
    onTap: () => _pick(front),
  );

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.signup3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Step(3),
          const T('Verify your identity', style: DText.h2),
          const Gap(6),
          const T('We check your ID before your first sale or purchase.', style: DText.muted),
          const Gap(18),
          DSeg<String>(options: const [('egyptian_id', 'Egyptian ID'), ('passport', 'Passport')], value: _doc, onChanged: (v) => setState(() => _doc = v)),
          const Gap(14),
          DLabel(_passport ? 'Passport' : 'National ID'),
          if (_passport)
            _slot('The page with your photo', _front, true)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _slot('Front', _front, true)),
                  const SizedBox(width: 10),
                  Expanded(child: _slot('Back', _back, false)),
                ],
              ),
            ),
          const Gap(10),
          const T('Photograph the whole card, avoid glare, and make sure the text is readable.', style: DText.tiny),
          const Gap(16),
          DSoft.bordered(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: DIcon('lock', size: 16, color: DColors.ink3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      T('How your ID is handled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Gap(3),
                      T(
                        'Stored encrypted and used only to confirm who you are. Never shown to buyers or sellers. The photos are deleted when you close your account.',
                        style: DText.tiny,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          DCheck(
            value: _consent,
            bottom: 8,
            onChanged: (v) => setState(() {
              _consent = v;
              _error = null;
            }),
            text: 'I agree to Dahab verifying my identity and storing these documents under the privacy policy.',
          ),
          DError(_error ?? '', visible: _error != null),
          const Gap(12),
          DButton('Create account', loading: _busy, onTap: _create),
          const Gap(14),
          const Center(
            child: T('Verification usually takes under an hour.', style: DText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// After submit: the account exists as `pending_verification`. The customer can
/// sign in and look around straight away; buying and selling wait until staff
/// approve the ID (backend spec 002). Laid out like the prototype's result
/// screens (request sent / add funds first).
class SignupDoneScreen extends StatelessWidget {
  const SignupDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final submitted = context.watch<AuthController>().draft?.submitted;
    return AppPage(
      id: R.signupDone,
      padded: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
        child: Column(
          children: [
            const DIcon('clock', size: 34, color: DColors.gold),
            const Gap(14),
            const T('Your account is being checked', style: DText.h2, textAlign: TextAlign.center),
            const Gap(6),
            const T(
              'We are checking your ID. You can sign in and look around now; buying and selling open as soon as it is approved — usually in under an hour.',
              style: DText.muted,
              textAlign: TextAlign.center,
            ),
            const Gap(20),
            if (submitted != null) ...[
              DCard(
                child: Column(
                  children: [
                    DRow('Name', submitted.fullName ?? ''),
                    DRow('Phone', maskPhone(submitted.phone)),
                    DRow('Email', submitted.email ?? ''),
                    const DRow('Status', '', rule: true, valueWidget: DPill('Waiting for verification', kind: PillKind.wait)),
                  ],
                ),
              ),
              const Gap(14),
            ],
            const DNote(icon: 'mail', text: 'We will tell you on your phone and email when your account is approved.'),
            const Gap(16),
            DButton(
              'Sign in',
              onTap: () {
                context.read<AuthController>().clearDraft();
                context.enterApp(R.splash);
                context.nav(R.login);
              },
            ),
            const Gap(9),
            DButton.ghost(
              'Look around first',
              onTap: () {
                context.read<AuthController>().clearDraft();
                context.enterApp(R.home);
              },
            ),
          ],
        ),
      ),
    );
  }
}
