import 'dart:convert';

import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'test_app.dart';

Future<FakeBackend> _start(WidgetTester tester, {FakeBackend? backend}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = backend ?? FakeBackend();
  final lang = (await tester.runAsync(LangController.load))!;
  await tester.pumpWidget((await tester.runAsync(() => testApp(lang, backend: api)))!);
  await tester.pump(const Duration(milliseconds: 300));
  return api;
}

/// Let HTTP futures (real async in the mock client) and animations finish.
Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text, {bool first = false}) async {
  final all = find.text(text);
  expect(all, findsWidgets, reason: 'no "$text" on screen');
  final f = first ? all.first : all.last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

/// The text field under a `DField` with this label.
Finder _field(String label) => find.descendant(of: find.widgetWithText(DField, label), matching: find.byType(TextField)).last;

Future<void> _typeCode(WidgetTester tester, String code) async {
  final boxes = find.descendant(of: find.byType(DOtp), matching: find.byType(TextField));
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(boxes.at(i), code[i]);
  }
  await tester.pump();
}

void _go(WidgetTester tester, String loc) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(loc);

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('sign in from a new device: login → SMS code → home, with device headers', (tester) async {
    final api = await _start(tester);
    await _tap(tester, 'I already have one');
    await tester.enterText(_field('Phone number'), '010 1234 4417');
    await tester.enterText(_field('Password'), 'Password-1234');
    await _tap(tester, 'Sign in');
    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.textContaining('+20 10 •••• 4417'), findsOneWidget);

    final login = api.requests.firstWhere((r) => r.url.path.endsWith('/customer/auth/login'));
    expect(login.body, contains('"phone":"+201012344417"'));
    expect(login.headers['X-Device-Id'], isNotEmpty);
    expect(login.headers['X-Device-Platform'], 'web');

    await _typeCode(tester, '000000');
    await _tap(tester, 'Verify');
    expect(find.text('That code is not right. Check the message and try again.'), findsOneWidget);

    await _typeCode(tester, '123456');
    await _tap(tester, 'Verify');
    expect(find.text('What will I get for my piece?'), findsOneWidget);

    // Account now shows the real customer from the API.
    await _tap(tester, 'Account');
    expect(find.text('Mona Hassan'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a wrong password shows the API reason; a pending account signs in and shows it is waiting', (tester) async {
    final api = await _start(tester, backend: FakeBackend()..pendingAccount = true);
    await _tap(tester, 'I already have one');
    await tester.enterText(_field('Phone number'), '1012344417');
    await tester.enterText(_field('Password'), 'wrong-one');
    await _tap(tester, 'Sign in');
    expect(find.text('The phone number or password is not right.'), findsOneWidget);

    // Backend spec 002: an unverified customer can sign in; trading waits for approval.
    await tester.enterText(_field('Password'), 'Password-1234');
    await _tap(tester, 'Sign in');
    expect(find.text('Enter your code'), findsOneWidget);
    await _typeCode(tester, '123456');
    await _tap(tester, 'Verify');
    expect(find.text('What will I get for my piece?'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path.endsWith('/login')).length, 2);

    await _tap(tester, 'Account');
    expect(find.text('Waiting for verification'), findsOneWidget);
    await _end(tester);
  });

  // Backend spec 007 US4: a suspended customer is told plainly, never shown the staff note.
  Future<void> signIn(WidgetTester tester) async {
    await _tap(tester, 'I already have one');
    await tester.enterText(_field('Phone number'), '010 1234 4417');
    await tester.enterText(_field('Password'), 'Password-1234');
    await _tap(tester, 'Sign in');
    await _typeCode(tester, '123456');
    await _tap(tester, 'Verify');
  }

  testWidgets('a suspended customer signs in and sees why, on home and in Account', (tester) async {
    await _start(tester, backend: FakeBackend()..suspendedReason = 'off_platform_dealing');
    await signIn(tester);

    expect(find.text('Your account is suspended'), findsOneWidget);
    expect(find.textContaining('dealing outside the app'), findsOneWidget);
    expect(find.textContaining('You can still see your account'), findsOneWidget);

    await _tap(tester, 'Account');
    expect(find.text('Your account is suspended'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('an unknown suspension reason gets the general wording; an active customer sees no notice', (tester) async {
    await _start(tester, backend: FakeBackend()..suspendedReason = 'a_reason_added_later');
    await signIn(tester);
    expect(find.text('Your account is suspended'), findsOneWidget);
    expect(find.textContaining('Contact us to find out more'), findsOneWidget);
    await _end(tester);

    await _start(tester);
    await signIn(tester);
    expect(find.text('What will I get for my piece?'), findsOneWidget);
    expect(find.text('Your account is suspended'), findsNothing);
    await _end(tester);
  });

  testWidgets('a request refused as account_suspended says the account is suspended', (tester) async {
    await _start(tester, backend: FakeBackend()..refuseLoginWith = 'account_suspended');
    await _tap(tester, 'I already have one');
    await tester.enterText(_field('Phone number'), '010 1234 4417');
    await tester.enterText(_field('Password'), 'Password-1234');
    await _tap(tester, 'Sign in');
    expect(find.text('This account is suspended. Contact us for help.'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the suspended notice is in Arabic too', (tester) async {
    await _start(tester, backend: FakeBackend()..suspendedReason = 'repeated_disputes');
    await _tap(tester, 'العربية');
    await _tap(tester, 'عندي حساب بالفعل');
    await tester.enterText(_field('رقم التليفون'), '010 1234 4417');
    await tester.enterText(_field('كلمة السر'), 'Password-1234');
    await _tap(tester, 'تسجيل الدخول');
    await _typeCode(tester, '123456');
    await _tap(tester, 'تأكيد');
    expect(find.text('حسابك موقوف'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('language switch turns the app Arabic and RTL', (tester) async {
    await _start(tester);
    await _tap(tester, 'العربية');
    final heading = find.textContaining('بيع مجوهراتك');
    expect(heading, findsOneWidget);
    expect(Directionality.of(tester.element(heading)), TextDirection.rtl);
    await _end(tester);
  });

  testWidgets('registration: step 1 validates, then walks the API steps up to the ID photos', (tester) async {
    final api = await _start(tester);
    await _tap(tester, 'Create an account');
    await _tap(tester, 'Send me a code');
    expect(find.text('Fill in every field to continue.'), findsOneWidget);

    await tester.enterText(_field('Full name, as written on your ID'), 'Mona Hassan Ibrahim');
    await tester.enterText(_field('Phone number'), '010 1234 4417');
    await tester.enterText(_field('Choose a password'), 'Password-1234');
    await tester.enterText(_field('Type it again'), 'Password-1234');
    await tester.ensureVisible(find.textContaining('I have read and accept'));
    await tester.tap(find.textContaining('I have read and accept'));
    await _tap(tester, 'Send me a code');
    expect(find.text('Confirm your number'), findsOneWidget);

    await _typeCode(tester, '123456');
    await tester.enterText(_field('Email address'), 'mona.h@email.com');
    await _tap(tester, 'Continue');
    expect(find.text('Confirm your email'), findsOneWidget);

    await _typeCode(tester, '123456');
    await _tap(tester, 'Continue');
    expect(find.text('Verify your identity'), findsOneWidget);

    await _tap(tester, 'Create account');
    expect(find.text('Add the photos of your ID first.'), findsOneWidget);

    final paths = api.requests.map((r) => r.url.path.replaceFirst('/api/v1/customer/auth/register/', '')).toList();
    expect(paths, ['start', 'verify-phone-otp', 'email', 'verify-email-otp']);
    await _end(tester);
  });

  testWidgets('guests are gated before selling and buying', (tester) async {
    await _start(tester);
    await _tap(tester, 'Look around first');
    await _tap(tester, 'Sell');
    expect(find.text('One step before you buy'), findsOneWidget);

    _go(tester, '/browse');
    await _settle(tester);
    await _tap(tester, '58,200 EGP');
    await _tap(tester, 'Send buy request');
    expect(find.text('One step before you buy'), findsOneWidget);
    await _end(tester);
  });

  // Backend spec 012: the Orders tab shows the API's orders, then the requests not accepted.
  testWidgets('orders filters narrow the carousel', (tester) async {
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(
          '0199d000-0000-7000-8000-000000000001',
          role: 'seller',
          actions: ['cancel'],
          deadline: {'kind': 'reach_branch', 'at': '2026-10-05T12:00:00+03:00', 'overdue': false},
        ),
        FakeBackend.order('0199d000-0000-7000-8000-000000000002', state: 'at_inspection', stage: 'at_igi'),
        FakeBackend.order('0199d000-0000-7000-8000-000000000003', state: 'completed', stage: 'done'),
      ]
      ..buyRequests = [FakeBackend.buyRequest('0199c000-0000-7000-8000-0000000000e1', FakeBackend.marketRingId, 'released_declined')];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/orders');
    await _settle(tester);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('Bring it to IGI'), findsWidgets);
    await _tap(tester, 'Finished', first: true);
    expect(find.text('1 of 2'), findsOneWidget); // the completed order and the declined request
    await _tap(tester, 'Selling', first: true);
    expect(find.text('Nothing here'), findsOneWidget);
    await _tap(tester, 'Needs you', first: true);
    expect(find.text('1 of 1'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the seller cancels before delivering, and the buyer is refunded', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000001';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(id, role: 'seller', actions: ['cancel'], deadline: {'kind': 'reach_branch', 'at': '2026-10-05T12:00:00+03:00', 'overdue': false}),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    expect(find.text('Bring the piece to IGI'), findsOneWidget);
    await _tap(tester, 'Cancel the sale', first: true);
    expect(find.textContaining('This cancels the sale, it does not extend it.'), findsOneWidget);
    await _tap(tester, 'Cancel the sale');
    expect(api.orders.single['state'], 'cancelled_seller');
    expect(api.requests.last.headers['Idempotency-Key'], isNotNull);
    expect(find.text('You cancelled the sale. The buyer got their deposit back.'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the buyer accepts the new price, pays the balance and sees the code', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000002';
    final api = FakeBackend()
      ..wallet = {'available': '50000.0000', 'held': '11640.0000', 'total': '61640.0000', 'currency': 'EGP'}
      ..orders = [
        FakeBackend.order(
          id,
          state: 'weight_adjust_pending',
          stage: 'decide',
          actions: ['decide'],
          deadline: {'kind': 'decision', 'at': '2026-10-03T12:00:00+03:00', 'overdue': false},
          inspection: {
            'inspection_id': '0199e000-0000-7000-8000-000000000001',
            'outcome': 'weight_adjust',
            'stated_karat': 21,
            'measured_karat': 21,
            'stated_weight_g': '8.000',
            'measured_weight_g': '7.620',
            'weight_diff_pct': '-4.75',
            'measured_stone_grade': null,
            'certificate_number': 'IGI-EG-88214',
            'inspector_note': 'Light surface wear.',
            'inspected_at': '2026-10-02T13:40:00+03:00',
            'new_price': '54884.0000',
            'price_pending': false,
            'decision_needed': true,
          },
        ),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    expect(find.text('54,884 EGP'), findsOneWidget);
    expect(find.text('IGI-EG-88214'), findsOneWidget);

    await _tap(tester, 'Accept the new price');
    final decide = api.requests.singleWhere((r) => r.url.path.endsWith('/decision'));
    expect(jsonDecode(decide.body), {'accept': true, 'inspection_id': '0199e000-0000-7000-8000-000000000001'});
    expect(find.text('Pay 43,244 EGP'), findsOneWidget);

    await _tap(tester, 'Pay 43,244 EGP');
    expect(api.orders.single['state'], 'ready_to_collect');
    expect(find.text('4 8 2 9 1 3'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a short wallet on the balance shows what is missing and leads to Add funds', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000003';
    final api = FakeBackend()
      ..wallet = {'available': '40000.0000', 'held': '11640.0000', 'total': '51640.0000', 'currency': 'EGP'}
      ..orders = [
        FakeBackend.order(
          id,
          state: 'awaiting_balance',
          stage: 'pay',
          actions: ['pay'],
          amountDue: '46560.0000',
          finalTotal: '58200.0000',
          deadline: {'kind': 'balance', 'at': '2026-10-05T10:00:00+03:00', 'overdue': false},
        ),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    await _tap(tester, 'Pay 46,560 EGP');
    expect(find.text('You need a little more'), findsOneWidget);
    expect(find.text('6,560 EGP'), findsOneWidget);
    expect(api.orders.single['state'], 'awaiting_balance');
    await _tap(tester, 'Add funds');
    expect(find.text('You need a little more'), findsNothing); // on Add funds now
    await _end(tester);
  });

  testWidgets('the seller puts a returned piece back on the market', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000004';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(
          id,
          role: 'seller',
          state: 'cancelled_inspection',
          stage: 'cancelled',
          actions: ['relist'],
          cancel: {'state': 'cancelled_inspection', 'at': '2026-10-02T10:00:00+03:00', 'reason_kind': 'declined'},
          deadline: {'kind': 'return', 'at': '2026-10-09T10:00:00+03:00', 'overdue': false},
          sellerReturn: {
            'return_deadline': '2026-10-09T10:00:00+03:00',
            'code_available': true,
            'can_relist': true,
            'collected_at': null,
            'relisted_at': null,
            'window_passed': false,
          },
          returnCode: '730215',
        ),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    expect(find.text('7 3 0 2 1 5'), findsOneWidget);
    await _tap(tester, 'Put it back on the market', first: true);
    await _tap(tester, 'Put it back');
    expect(api.requests.any((r) => r.url.path.endsWith('/relist')), isTrue);
    expect(find.text('The piece is back on the market.'), findsOneWidget);
    await _end(tester);
  });

  // ---- Backend spec 014: report a problem, ask for more time, someone else collects ----

  testWidgets('the buyer reports a problem with a photo; the order goes on hold and shows the report', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000005';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(
          id,
          state: 'awaiting_balance',
          stage: 'pay',
          actions: ['pay', 'report_problem'],
          amountDue: '46560.0000',
          finalTotal: '58200.0000',
          deadline: {'kind': 'balance', 'at': '2026-10-05T10:00:00+03:00', 'overdue': false},
        ),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    await _tap(tester, 'Report a problem');
    expect(find.text('What went wrong?'), findsOneWidget);

    // Nothing chosen: refused on the device, nothing sent.
    await _tap(tester, 'Send to Dahab');
    expect(find.text('Choose what went wrong and write a line or two.'), findsOneWidget);
    expect(api.requests.any((r) => r.url.path.endsWith('/disputes')), isFalse);

    await _tap(tester, 'I disagree with the inspection result');
    await tester.enterText(find.byType(TextField).first, 'The weight on the certificate is not what I saw at the branch.');
    await _tap(tester, 'Add a photo');
    expect(api.uploads, ['dispute_photo']);
    expect(find.text('Photo 1'), findsOneWidget);

    await _tap(tester, 'Send to Dahab');
    final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/disputes'));
    expect(sent.headers['Idempotency-Key'], isNotNull);
    expect(jsonDecode(sent.body), {
      'reason': 'disagree_inspection',
      'detail': 'The weight on the certificate is not what I saw at the branch.',
      'photo_tokens': ['dispute_photo-token-1'],
    });
    expect(find.textContaining('Your reference is DSP-41.'), findsOneWidget);
    await _tap(tester, 'OK');

    expect(api.orders.single['state'], 'disputed');
    expect(find.text('On hold'), findsOneWidget);
    expect(find.textContaining('This order is on hold while Dahab looks into a problem.'), findsOneWidget);
    expect(find.text('The problem you reported'), findsOneWidget);
    expect(find.text('DSP-41'), findsOneWidget);
    expect(find.text('Report a problem'), findsNothing);
    await _end(tester);
  });

  testWidgets('Dahab\'s answer shows on the order once the report is resolved', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000006';
    final api = FakeBackend()
      ..orders = [
        {
          ...FakeBackend.order(
            id,
            state: 'awaiting_balance',
            stage: 'pay',
            actions: ['pay'],
            amountDue: '46560.0000',
            finalTotal: '58200.0000',
            deadline: {'kind': 'balance', 'at': '2026-10-05T11:30:00+03:00', 'overdue': false},
          ),
          'dispute': {
            'ref': 'DSP-7',
            'order_ref': 'DH-2026-000006',
            'raised_as': 'buyer',
            'reason': 'disagree_inspection',
            'detail': 'The weight looks wrong to me.',
            'photo_count': 0,
            'state': 'resolved',
            'outcome': 'resume',
            'reply': 'We checked the inspection with IGI and the result stands.',
            'opened_at': '2026-10-02T11:00:00+03:00',
            'resolved_at': '2026-10-02T12:30:00+03:00',
          },
          'dispute_outcome': 'resumed',
        },
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    expect(find.text("Dahab's answer"), findsOneWidget);
    expect(find.text('We checked the inspection with IGI and the result stands.'), findsOneWidget);
    expect(find.text('Answered'), findsOneWidget);
    expect(find.text('Pay 46,560 EGP'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the seller asks for more time and sees the request waiting', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000007';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(id, role: 'seller', actions: ['cancel', 'ask_more_time'], deadline: {'kind': 'reach_branch', 'at': '2026-10-05T12:00:00+03:00', 'overdue': false}),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    await _tap(tester, 'I need more time');
    expect(find.text('Why do you need more time?'), findsOneWidget);
    await _tap(tester, 'The branch was closed when I went');
    await tester.enterText(find.byType(TextField).first, 'It was closed on Thursday for a holiday.');
    await _tap(tester, 'Send request');

    final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/extension-requests'));
    expect(sent.headers['Idempotency-Key'], isNotNull);
    expect(jsonDecode(sent.body), {'reason': 'branch_closed', 'detail': 'It was closed on Thursday for a holiday.'});
    expect(find.textContaining('You asked for more time.'), findsOneWidget);
    expect(find.text('I need more time'), findsNothing);
    await _end(tester);
  });

  testWidgets('the buyer names someone else to collect, with their ID and the authorisation, then takes it back', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000008';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(
          id,
          state: 'ready_to_collect',
          stage: 'collect',
          actions: ['name_proxy', 'report_problem'],
          deadline: {'kind': 'collect', 'at': '2026-10-23T10:00:00+03:00', 'overdue': false},
          collection: {'code_available': true, 'collect_deadline': '2026-10-23T10:00:00+03:00', 'collected_at': null, 'window_passed': false},
          collectionCode: '482913',
        ),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    await _tap(tester, 'Someone else will collect it');
    expect(find.text('Who is collecting'), findsOneWidget);

    await _tap(tester, 'Send them the collection code');
    expect(find.text('Fill in their name, a valid phone and their ID photo, and tick the box.'), findsOneWidget);

    await tester.enterText(_field('Full name, as written on their ID'), 'Karim Adel Mostafa');
    await tester.enterText(_field('Their phone number'), '010 0123 4567');
    await _tap(tester, 'Front of their ID');
    expect(api.uploads, ['proxy_id']);
    await _tap(tester, 'I authorise this person to collect the piece for me and take responsibility for choosing them.');
    await _tap(tester, 'Send them the collection code');

    final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/proxy'));
    expect(sent.headers['Idempotency-Key'], isNotNull);
    expect(jsonDecode(sent.body), {
      'name': 'Karim Adel Mostafa',
      'phone': '+201001234567',
      'id_upload_token': 'proxy_id-token-1',
      'authorisation_id': 11,
      'authorisation_accepted': true,
    });
    await _tap(tester, 'OK');
    expect(find.text('Someone else collects'), findsOneWidget);
    expect(find.text('Karim Adel Mostafa'), findsOneWidget);

    await _tap(tester, 'Change who collects');
    await _tap(tester, 'Collect it myself instead');
    await _tap(tester, 'Remove them');
    expect(api.requests.any((r) => r.url.path.endsWith('/proxy/remove')), isTrue);
    expect(api.orders.single['proxy'], isNull);
    expect(find.text('Someone else collects'), findsNothing);
    await _end(tester);
  });

  testWidgets('report a problem in Arabic', (tester) async {
    const id = '0199d000-0000-7000-8000-000000000009';
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order(id, state: 'at_inspection', stage: 'at_igi', actions: ['report_problem']),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    tester.element(find.byType(Navigator).first).read<LangController>().setLang(AppLang.ar);
    _go(tester, '/order?id=$id');
    await _settle(tester);
    await _tap(tester, 'إبلاغ عن مشكلة');
    expect(find.text('إيه اللي حصل؟'), findsOneWidget);
    expect(find.text('إرسال لدهب'), findsOneWidget);
    await _end(tester);
  });

  // ---- Live parts that used to be mock: held money, sign out everywhere, the Activity counts ----

  testWidgets('add funds without a session asks to sign in instead of failing', (tester) async {
    await _start(tester);
    _go(tester, '/addfunds');
    await _settle(tester);
    expect(find.text('Sign in to add money to your wallet.'), findsOneWidget);
    await _tap(tester, 'Sign in');
    expect(find.text('Sign in to add money to your wallet.'), findsNothing);
    await _end(tester);
  });

  testWidgets('held money shows the backend figures and each withdrawal on its way', (tester) async {
    final api = FakeBackend()
      ..wallet = {'available': '900.0000', 'held': '11740.0000', 'held_on_orders': '11640.0000', 'pending_withdrawals': '100.0000', 'total': '12640.0000', 'currency': 'EGP'}
      ..withdrawals = [
        {
          'id': 'wd-11', 'number': 'WD-11', 'amount': '100.0000', 'state': 'requested', 'on_hold': false, 'hold_message': null,
          'account': {'bank_name': 'CIB', 'number_masked': '•••• 4417'}, 'requested_at': '2026-10-02T10:00:00+03:00', 'released_at': null,
          'value_date': null, 'rejection_reason': null, 'cancelled_by_change': false, 'can_cancel': true,
        },
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/held');
    await _settle(tester);
    expect(find.text('11,640 EGP'), findsOneWidget);
    expect(find.text('On its way to your bank'), findsOneWidget);
    expect(find.text('WD-11 · CIB •••• 4417'), findsOneWidget);
    expect(find.text('MOCK — this screen is not connected to the backend yet'), findsNothing);
    await _end(tester);
  });

  testWidgets('sign out of every device revokes every session and goes to sign-in', (tester) async {
    final api = await _start(tester);
    await signIn(tester);
    _go(tester, '/security');
    await _settle(tester);
    await _tap(tester, 'Sign out of every device');
    expect(find.textContaining('this one too'), findsOneWidget);
    await _tap(tester, 'Sign out everywhere');
    expect(api.loggedOutEverywhere, isTrue);
    expect(find.text('Sign in'), findsWidgets);
    await _end(tester);
  });

  testWidgets('Account shows the real counts of open orders and listings', (tester) async {
    final api = FakeBackend()
      ..orders = [
        FakeBackend.order('0199d000-0000-7000-8000-00000000000a', role: 'seller', actions: ['cancel']),
        FakeBackend.order('0199d000-0000-7000-8000-00000000000b', state: 'awaiting_balance', stage: 'pay', actions: ['pay']),
        FakeBackend.order('0199d000-0000-7000-8000-00000000000c', state: 'completed', stage: 'done'),
      ]
      ..listings = [FakeBackend.listing('l-1', 'live'), FakeBackend.listing('l-2', 'draft')];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/account');
    await _settle(tester);
    expect(find.text('1 selling, 1 buying'), findsOneWidget);
    expect(find.text('1 live of 2'), findsOneWidget);
    expect(find.text('One selling, one ready to collect'), findsNothing);
    await _end(tester);
  });

  // Backend spec 010: the sell flow uploads the files, creates the listing and sends it for review.
  testWidgets('sell flow: photos, description, branch and declaration, then the listing waits for approval', (tester) async {
    final api = await _start(tester);
    await signIn(tester);
    _go(tester, '/sell1');
    await _settle(tester);
    expect(find.text('Earrings'), findsOneWidget); // piece types come from the API
    await _tap(tester, 'Continue to photos');
    await _tap(tester, 'Continue to review');
    expect(find.text('Add the required photos before continuing.'), findsOneWidget);
    await _tap(tester, 'Full piece');
    await _tap(tester, 'Hallmark stamp');
    await _tap(tester, 'Continue to review');
    expect(find.text('Add a little more detail before continuing.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '21K gold ring, worn twice, small scratch on the inner band.');
    await _tap(tester, 'Continue to review');
    expect(find.text('Before it goes live'), findsOneWidget);

    await _tap(tester, 'Send for approval');
    expect(find.text('Choose at least one branch you can bring the piece to.'), findsOneWidget);
    await _tap(tester, 'Nasr City');
    await _tap(tester, 'Send for approval');
    expect(find.text('Confirm ownership to list the piece.'), findsOneWidget);
    expect(api.requests.any((r) => r.url.path.endsWith('/customer/me/listings') && r.method == 'POST'), isFalse);

    await _tap(tester, 'I confirm this piece is mine to sell and the details above are accurate.');
    await _tap(tester, 'Send for approval');
    // Two uploads, the create and the submit: let each answer arrive.
    for (var i = 0; i < 4; i++) {
      await _settle(tester, 100);
    }
    expect(find.text('Sent for approval'), findsOneWidget);
    await _tap(tester, 'OK');

    expect(api.uploads, ['listing_photo', 'listing_photo']);
    final create = api.requests.singleWhere((r) => r.url.path.endsWith('/customer/me/listings') && r.method == 'POST');
    expect(create.body, contains('"category":"gold"'));
    expect(create.body, contains('"piece_type_id":1'));
    expect(create.body, contains('"karat_code":21'));
    expect(create.body, contains('"stated_weight_g":"8.0"'));
    expect(create.body, contains('"making_charge_per_g":"300"'));
    expect(create.body, contains('"branch_option_ids":[1]'));
    expect(create.body, contains('"photo_tokens":["listing_photo-token-1","listing_photo-token-2"]'));
    expect(create.body, contains('"ownership_declaration_accepted":true'));
    expect(create.body, contains('"ownership_legal_doc_id":7'));
    expect(create.body, isNot(contains('asking_price')));
    expect(create.headers['Idempotency-Key'], isNotEmpty);
    final submit = api.requests.singleWhere((r) => r.url.path.endsWith('/submit'));
    expect(submit.headers['Idempotency-Key'], isNot(create.headers['Idempotency-Key']));

    expect(api.listings.single['state'], 'in_review');
    expect(find.text('Waiting for approval'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('my listings: the reviewer message with Fix and resend, and taking a live piece down', (tester) async {
    final api = FakeBackend()
      ..listings = [
        FakeBackend.listing('0199b000-0000-7000-8000-0000000000a1', 'changes_requested', staffMessage: 'The hallmark photo is blurred. Please retake it in daylight.'),
        FakeBackend.listing('0199b000-0000-7000-8000-0000000000a2', 'live'),
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/listings');
    await _settle(tester);

    expect(find.text('Changes needed'), findsOneWidget);
    expect(find.text('The hallmark photo is blurred. Please retake it in daylight.'), findsOneWidget);
    expect(find.text('Fix and resend'), findsOneWidget);
    expect(find.text('Live'), findsWidgets);
    expect(find.text('57,744 EGP'), findsOneWidget);

    await _tap(tester, 'Take it down', first: true);
    await _tap(tester, 'Take it down');
    final withdraw = api.requests.singleWhere((r) => r.url.path.endsWith('/withdraw'));
    expect(withdraw.headers['Idempotency-Key'], isNotEmpty);
    expect(api.listings[1]['state'], 'withdrawn');
    expect(find.text('Taken down'), findsOneWidget);

    // Fixing opens the sell flow with the listing's own details, and resends it.
    await _tap(tester, 'Fix and resend');
    expect(find.text('This cannot change once a listing exists. To sell something else, start a new listing.'), findsOneWidget);
    await _tap(tester, 'Continue to photos');
    expect(find.text('2 of 2 required added'), findsOneWidget);
    await _tap(tester, 'Continue to review');
    await _tap(tester, 'I confirm this piece is mine to sell and the details above are accurate.');
    await _tap(tester, 'Send for approval');
    expect(api.requests.any((r) => r.method == 'PATCH' && r.url.path.endsWith('a1')), isTrue);
    expect(api.listings[0]['state'], 'in_review');
    await _end(tester);
  });

  testWidgets('the market comes from the API: no seller, own piece marked, a piece that left says so', (tester) async {
    final api = await _start(tester);
    await _tap(tester, 'Look around first');
    _go(tester, '/browse');
    await _settle(tester);
    expect(find.textContaining('2 pieces.'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(api.requests.where((r) => r.url.path.endsWith('/market/listings')).every((r) => r.headers['Authorization'] == null), isTrue);

    await _tap(tester, '58,200 EGP');
    expect(find.textContaining('Small scratch on the inner band'), findsOneWidget);
    expect(find.text('Nasr City'), findsOneWidget);
    expect(find.text('Watch the video'), findsOneWidget);
    expect(find.text('Open the certificate'), findsNothing);
    expect(find.text('Identity verified'), findsNothing);
    expect(find.textContaining('Seller'), findsNWidgets(1)); // only the "Seller's description" label

    _go(tester, '/detail?id=0199a000-0000-7000-8000-0000000000ff');
    await _settle(tester);
    expect(find.text('This piece is no longer on the market'), findsOneWidget);
    await _end(tester);
  });

  // Backend spec 011: buy requests.
  testWidgets('send a buy request: the deposit terms, then the API figures on Request sent', (tester) async {
    final api = FakeBackend()..wallet = {'available': '20000.0000', 'held': '0.0000', 'total': '20000.0000', 'currency': 'EGP'};
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/detail?id=${FakeBackend.marketRingId}');
    await _settle(tester);
    expect(find.text('Deposit needed to send a request: 11,640 EGP'), findsOneWidget);

    await _tap(tester, 'Send buy request');
    expect(find.textContaining('the deposit shown before I send this request'), findsOneWidget);
    await _tap(tester, 'Agree and send');

    final sent = api.requests.singleWhere((r) => r.method == 'POST' && r.url.path.endsWith('/customer/me/buy-requests'));
    expect(sent.headers['Idempotency-Key'], isNotEmpty);
    expect(jsonDecode(sent.body), {'listing_id': FakeBackend.marketRingId, 'confirm_locked_price': '58200.0000', 'deposit_legal_doc_id': 7});
    expect(find.text('Your request is with the seller'), findsOneWidget);
    expect(find.text('11,640 EGP'), findsOneWidget);
    expect(find.text('2nd, 1 ahead of you'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('a short wallet opens You need a little more with the shortfall from the API', (tester) async {
    final api = FakeBackend()..wallet = {'available': '1000.0000', 'held': '0.0000', 'total': '1000.0000', 'currency': 'EGP'};
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/detail?id=${FakeBackend.marketRingId}');
    await _settle(tester);
    await _tap(tester, 'Send buy request');
    await _tap(tester, 'Agree and send');

    expect(find.text('You need a little more'), findsOneWidget);
    expect(find.text('10,640 EGP'), findsOneWidget);
    expect(api.buyRequests, isEmpty);
    await _end(tester);
  });

  testWidgets('the piece page shows my place in line, and leaving gives the deposit back', (tester) async {
    final api = FakeBackend()..buyRequests = [FakeBackend.buyRequest('0199c000-0000-7000-8000-0000000000e1', FakeBackend.marketRingId, 'queued', place: 2, ahead: 1)];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/detail?id=${FakeBackend.marketRingId}');
    await _settle(tester);
    expect(find.textContaining('There is 1 buyer ahead of you.'), findsOneWidget);
    expect(find.text('Send buy request'), findsNothing);

    await _tap(tester, 'Leave the queue and get my deposit back');
    await _tap(tester, 'Leave and notify me');
    expect(api.buyRequests.single['state'], 'withdrawn_by_buyer');
    expect(api.buyRequests.single['notify_when_free'], isTrue);
    await _settle(tester); // the piece reloads: the market, then the requests
    expect(find.text('Send buy request'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('the seller accepts the first in line at a branch they named', (tester) async {
    const id = '0199b000-0000-7000-8000-0000000000b1';
    final api = FakeBackend()
      ..listings = [
        {...FakeBackend.listing(id, 'reserved'), 'queue_count': 1, 'order': null},
      ]
      ..queues = {
        id: [
          {
            'id': '0199c000-0000-7000-8000-0000000000f1',
            'place_in_line': 1,
            'queue_position': 1,
            'is_head': true,
            'buyer': {'display_ref': '4417'},
            'locked_total_price': '58200.0000',
            'requested_at': '2026-09-30T19:00:00+03:00',
            'seller_reply_deadline': '2026-10-02T19:00:00+03:00',
          },
        ],
      };
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/detail?id=$id&view=owner');
    await _settle(tester);
    expect(find.text('1 buyer in line'), findsOneWidget);
    expect(find.text('4417'), findsOneWidget);

    await _tap(tester, 'Accept');
    await _tap(tester, 'Nasr City');
    final accept = api.requests.singleWhere((r) => r.url.path.endsWith('/accept'));
    expect(jsonDecode(accept.body), {'buy_request_id': '0199c000-0000-7000-8000-0000000000f1', 'branch_id': 1});
    expect(api.listings.single['state'], 'accepted');
    await _settle(tester); // the listing reloads
    expect(find.textContaining('order DH-2026-000001'), findsOneWidget);
    await _end(tester);
  });

  // Backend spec 008: the wallet and its history come from the API.
  testWidgets('the wallet shows the API figures and one labelled row per movement', (tester) async {
    final api = FakeBackend()
      ..wallet = {'available': '600.0000', 'held': '400.0000', 'total': '1000.0000', 'currency': 'EGP'}
      ..walletRows = [
        {
          'id': 't2',
          'kind': 'deposit_hold',
          'created_at': '2026-09-26T19:22:00+03:00',
          'available_change': '-400.0000',
          'held_change': '400.0000',
          'available_after': '600.0000',
          'held_after': '400.0000',
          'reference': null,
        },
        {
          'id': 't1',
          'kind': 'topup',
          'created_at': '2026-09-24T14:02:00+03:00',
          'available_change': '1000.0000',
          'held_change': '0.0000',
          'available_after': '1000.0000',
          'held_after': '0.0000',
          'reference': null,
        },
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/wallet');
    await _settle(tester);

    expect(find.text('600 EGP'), findsWidgets);
    expect(find.text('400 EGP'), findsWidgets);
    expect(find.text('1,000 EGP'), findsWidgets);
    expect(find.text('Deposit held on a purchase'), findsOneWidget);
    expect(find.text('Added by bank transfer'), findsOneWidget);
    expect(find.text('- 400 EGP'), findsOneWidget);
    expect(find.text('+ 1,000 EGP'), findsOneWidget);
    expect(api.requests.any((r) => r.url.path.endsWith('/customer/me/wallet/transactions')), isTrue);
    await _end(tester);
  });

  // Backend spec 009: add funds is a manual transfer; the notice appears as waiting.
  testWidgets('add funds shows the live accounts and reference, and files a notice listed as waiting', (tester) async {
    final api = await _start(tester);
    await signIn(tester);
    _go(tester, '/addfunds');
    await _settle(tester);

    expect(find.text('DAHAB-396233'), findsOneWidget);
    expect(find.text('1000 4417 2026'), findsOneWidget);
    await _tap(tester, 'InstaPay', first: true);
    expect(find.text('dahab@instapay'), findsOneWidget);
    expect(find.text('70,000 EGP'), findsOneWidget);

    await tester.enterText(_field('How much do you want to add?'), '20000');
    await tester.pump();
    await _tap(tester, "I've sent the transfer");
    final submit = api.requests.lastWhere((r) => r.url.path.endsWith('/customer/me/wallet/topups') && r.method == 'POST');
    expect(submit.body, contains('"receiving_account_id":2'));
    expect(submit.body, contains('"amount":"20000"'));
    expect(submit.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(find.text('Thanks'), findsOneWidget);
    await _tap(tester, 'OK');

    expect(find.text('Your top-ups'), findsWidgets);
    expect(find.textContaining('TOP-128'), findsOneWidget);
    expect(find.textContaining('Waiting to be matched'), findsOneWidget);
    // InstaPay shows a 0.5% fee: about 19,900 EGP should arrive.
    expect(find.textContaining('About 19,900 EGP reaches your wallet'), findsOneWidget);

    await _tap(tester, 'Cancel');
    await _tap(tester, 'Cancel it');
    expect(find.textContaining('You cancelled it'), findsOneWidget);
    expect(api.topUps.single['status'], 'cancelled');
    await _end(tester);
  });

  testWidgets('a suspended customer cannot add money but still sees their top-ups', (tester) async {
    final api = FakeBackend()..suspendedReason = 'other';
    api.topUps = [
      {
        'id': 'tu-1',
        'number': 'TOP-7',
        'method': 'bank_transfer',
        'reference': 'DAHAB-396233',
        'status': 'credited',
        'claimed_amount': '5000.0000',
        'credited_amount': '5000.0000',
        'has_receipt': false,
        'submitted_at': '2026-09-20T10:00:00+03:00',
        'credited_at': '2026-09-20T12:00:00+03:00',
        'reject_reason': null,
        'can_cancel': false,
      },
    ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/addfunds');
    await _settle(tester);
    expect(find.text('This account is suspended. Contact us for help.'), findsOneWidget);
    expect(find.text('DAHAB-396233'), findsNothing);
    expect(api.requests.any((r) => r.url.path.endsWith('/customer/me/wallet/topups') && r.method == 'POST'), isFalse);

    _go(tester, '/topups');
    await _settle(tester);
    expect(find.textContaining('TOP-7'), findsOneWidget);
    expect(find.textContaining('Added to your wallet'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('an empty wallet says so, and an unverified customer is told to verify first', (tester) async {
    await _start(tester);
    await signIn(tester);
    _go(tester, '/wallet');
    await _settle(tester);
    expect(find.text('No movements yet.'), findsOneWidget);
    expect(find.text('0 EGP'), findsWidgets);
    await _end(tester);

    await _start(tester, backend: FakeBackend()..pendingAccount = true);
    await signIn(tester);
    _go(tester, '/wallet');
    await _settle(tester);
    expect(find.textContaining('Verify your identity before doing this'), findsOneWidget);
    expect(find.text('No movements yet.'), findsOneWidget);
    await _end(tester);
  });

  // ---- backend spec 013: payout accounts and withdrawals ----

  testWidgets('bank accounts: the account in use, one under review, one refused with the reason, and the recent changes', (tester) async {
    final api = FakeBackend()
      ..payoutAccounts = [
        FakeBackend.payoutAccount('pa-a', inUse: true),
        FakeBackend.payoutAccount('pa-b', bank: 'NBE', last4: '9001', state: 'pending_review'),
        FakeBackend.payoutAccount('pa-c', bank: 'QNB', last4: '5555', state: 'refused', refusal: 'name_shortened'),
      ]
      ..payoutChanges = [
        {
          'kind': 'verified',
          'account': {'bank_name': 'CIB', 'number_masked': '•••• 4417'},
          'at': '2026-05-12T12:00:00+03:00',
          'by': 'dahab',
        },
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/bank');
    await _settle(tester);

    expect(find.text('CIB, account ending 4417'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('Refused'), findsOneWidget);
    expect(find.text('The name is shortened. Use your full name as written on your ID.'), findsOneWidget);
    expect(find.text('Name checked against your ID'), findsOneWidget);

    await _tap(tester, 'Cancel this request');
    await _tap(tester, 'Cancel the request');
    expect(api.payoutAccounts.any((a) => a['id'] == 'pa-b'), isFalse);
    final remove = api.requests.lastWhere((r) => r.url.path.endsWith('/pa-b/remove'));
    expect(remove.headers['Idempotency-Key'], isNotEmpty);
    expect(find.text('NBE, account ending 9001'), findsNothing);
    await _end(tester);
  });

  testWidgets('add a bank account: field errors from the API, then the declaration and Sent for review', (tester) async {
    final api = await _start(tester);
    await signIn(tester);
    _go(tester, '/bankadd');
    await _settle(tester);

    expect(find.text('I confirm this bank account is in my own name and the details are correct.'), findsOneWidget);
    await tester.enterText(_field('Bank'), 'CIB');
    await tester.enterText(_field('Account holder name'), 'Mona Hassan Ibrahim');
    await tester.enterText(_field('Account number or IBAN'), '123');
    await _tap(tester, 'I confirm this bank account is in my own name and the details are correct.');
    await _tap(tester, 'Send for review');
    expect(find.text('Enter an Egyptian IBAN or a bank account number.'), findsOneWidget);

    await tester.enterText(_field('Account number or IBAN'), 'EG38 0019 0005 0000 0000 2631 8000 2');
    await _tap(tester, 'Send for review');
    expect(find.text('Sent for review'), findsOneWidget);
    final add = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/customer/me/payout-accounts'));
    final body = jsonDecode(add.body) as Map<String, dynamic>;
    expect(body['declaration_id'], 9);
    expect(body['declaration_accepted'], isTrue);
    expect(add.headers['Idempotency-Key'], isNotEmpty);
    expect(api.payoutAccounts.single['state'], 'pending_review');
    await _end(tester);
  });

  testWidgets('switching the account in use cancels the open withdrawal and shows the pause', (tester) async {
    final api = FakeBackend()
      ..wallet = {'available': '900.0000', 'held': '100.0000', 'held_on_orders': '0.0000', 'pending_withdrawals': '100.0000', 'total': '1000.0000', 'currency': 'EGP'}
      ..payoutAccounts = [FakeBackend.payoutAccount('pa-a', inUse: true), FakeBackend.payoutAccount('pa-b', bank: 'NBE', last4: '9001')]
      ..withdrawals = [
        {
          'id': 'wd-11',
          'number': 'WD-11',
          'amount': '100.0000',
          'state': 'requested',
          'on_hold': false,
          'hold_message': null,
          'account': {'bank_name': 'CIB', 'number_masked': '•••• 4417'},
          'requested_at': '2026-10-02T10:00:00+03:00',
          'released_at': null,
          'value_date': null,
          'rejection_reason': null,
          'cancelled_by_change': false,
          'can_cancel': true,
        },
      ];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/bank');
    await _settle(tester);

    await _tap(tester, 'Use this one');
    expect(find.text('Use this account'), findsOneWidget);
    await _tap(tester, 'Use this one');
    expect(find.text('Withdrawals cancelled'), findsOneWidget);
    expect(find.textContaining('WD-11'), findsOneWidget);
    await _tap(tester, 'OK');
    expect(find.textContaining('Withdrawals are paused until'), findsWidgets);
    expect(api.withdrawals.single['state'], 'cancelled');

    _go(tester, '/withdraw');
    await _settle(tester);
    expect(find.textContaining('Withdrawals are paused until'), findsOneWidget);
    expect(find.text('NBE, account ending 9001'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('withdraw: send the email link, wait, confirmed, then the request; the wallet shows it on its way and it can be cancelled', (tester) async {
    final api = FakeBackend()
      ..wallet = {'available': '30000.0000', 'held': '0.0000', 'held_on_orders': '0.0000', 'pending_withdrawals': '0.0000', 'total': '30000.0000', 'currency': 'EGP'}
      ..payoutAccounts = [FakeBackend.payoutAccount('pa-a', inUse: true)];
    await _start(tester, backend: api);
    await signIn(tester);
    _go(tester, '/withdraw');
    await _settle(tester);

    expect(find.text('30,000 EGP'), findsOneWidget);
    expect(find.text('CIB, account ending 4417'), findsOneWidget);
    expect(find.text('Code sent to your phone'), findsNothing);

    await _tap(tester, '10,000');
    await _tap(tester, 'Withdraw', first: false);
    expect(find.text('Confirm from your email first: tap Send the link.'), findsOneWidget);

    await _tap(tester, 'Send the link to your email');
    expect(find.text('Waiting'), findsOneWidget);
    final sent = api.requests.lastWhere((r) => r.url.path.endsWith('/withdrawals/confirmations'));
    expect(jsonDecode(sent.body), {'amount': '10000', 'payout_account_id': 'pa-a'});

    api.openEmailLink(api.confirmations.keys.single);
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    expect(find.text('Confirmed'), findsOneWidget);

    await _tap(tester, 'Withdraw', first: false);
    expect(find.text('Withdrawal requested'), findsOneWidget);
    final submit = api.requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/customer/me/withdrawals'));
    expect(submit.headers['Idempotency-Key'], isNotEmpty);
    expect((jsonDecode(submit.body) as Map)['confirmation_id'], api.confirmations.keys.single);
    await _tap(tester, 'OK');

    _go(tester, '/wallet');
    await _settle(tester);
    expect(find.text('On its way to your bank'), findsOneWidget);
    expect(find.text('10,000 EGP'), findsWidgets);
    expect(find.text('10,000 EGP · WD-12'), findsOneWidget);
    await _tap(tester, 'Cancel the withdrawal');
    await _tap(tester, 'Cancel the withdrawal');
    expect(api.withdrawals.single['state'], 'cancelled');
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('On its way to your bank'), findsNothing);
    await _end(tester);
  });

  testWidgets('the email link page confirms without signing in, and a used link says so', (tester) async {
    final api = FakeBackend()..confirmations['c1'] = {'id': 'c1', 'state': 'sent', 'amount': '42000.0000', 'account_id': 'pa-a', 'token': 'token-abcdefghijklmnopqrstuvwxyz'};
    await _start(tester, backend: api);
    _go(tester, '/withdraw-confirm?token=token-abcdefghijklmnopqrstuvwxyz');
    await _settle(tester);
    expect(find.text('42,000 EGP'), findsOneWidget);
    expect(find.text('CIB ••4417'), findsOneWidget);
    await _tap(tester, 'Confirm this withdrawal');
    expect(api.confirmations['c1']!['state'], 'confirmed');
    expect(find.text('Back to Withdraw'), findsOneWidget);
    expect(api.requests.last.headers['Authorization'], isNull);

    await _end(tester);

    api.confirmations['c1']!['state'] = 'used';
    await _start(tester, backend: api);
    _go(tester, '/withdraw-confirm?token=token-abcdefghijklmnopqrstuvwxyz');
    await _settle(tester);
    expect(find.text('This link has expired'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('withdraw in Arabic', (tester) async {
    final api = FakeBackend()
      ..wallet = {'available': '30000.0000', 'held': '0.0000', 'total': '30000.0000', 'currency': 'EGP'}
      ..payoutAccounts = [FakeBackend.payoutAccount('pa-a', inUse: true)]
      ..pauseUntil = '2026-10-05T10:00:00+03:00';
    await _start(tester, backend: api);
    await signIn(tester);
    final lang = tester.element(find.byType(Navigator).first).read<LangController>()..setLang(AppLang.ar);
    _go(tester, '/withdraw');
    await _settle(tester);
    expect(lang.isArabic, isTrue);
    expect(find.text('ابعت اللينك على إيميلك'), findsOneWidget);
    expect(find.text('شخص بيراجع كل سحبة. بتوصل خلال يوم عمل. من غير أي رسوم من دهب.'), findsOneWidget);
    // The pause date with the Arabic month name.
    expect(find.textContaining('السحب واقف لحد'), findsOneWidget);
    expect(find.textContaining('أكتوبر'), findsOneWidget);
    expect(find.textContaining('Oct'), findsNothing);
    await _end(tester);
  });

  testWidgets('FAQ expands and collapses', (tester) async {
    await _start(tester);
    _go(tester, '/help');
    await _settle(tester);
    expect(find.textContaining('A jeweller melts the piece'), findsNothing);
    await _tap(tester, 'Why would I get more than a jeweller?');
    expect(find.textContaining('A jeweller melts the piece'), findsOneWidget);
    await _end(tester);
  });
}
