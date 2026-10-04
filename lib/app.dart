import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/i18n/i18n.dart';
import 'core/theme/tokens.dart';
import 'core/theme/typography.dart';
import 'routing/app_router.dart';
import 'routing/routes.dart';
import 'services/auth/auth_controller.dart';
import 'widgets/app_shell.dart';

class DahabApp extends StatefulWidget {
  const DahabApp({super.key});

  @override
  State<DahabApp> createState() => _DahabAppState();
}

class _DahabAppState extends State<DahabApp> {
  late final AuthController _auth = context.read<AuthController>();
  late final GoRouter _router = buildRouter(signedIn: _auth.isSignedIn);

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuth);
  }

  /// A session that ended on its own (refresh token rejected) sends the
  /// customer back to the start.
  void _onAuth() {
    if (_auth.takeSessionExpired()) _router.go('/${R.login}');
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    final base = DFonts.base(arabic: lang.isArabic);
    return MaterialApp.router(
      title: 'Dahab',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      locale: lang.locale,
      supportedLocales: const [Locale('en'), Locale('ar', 'EG')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const _DahabScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: DColors.gold, surface: DColors.paper, primary: DColors.ink),
        scaffoldBackgroundColor: DColors.paper,
        fontFamily: base.fontFamily,
        fontFamilyFallback: base.fontFamilyFallback,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: DColors.ink, selectionColor: Color(0x338B6F3D)),
      ),
      builder: (context, child) => DefaultTextStyle(
        style: base,
        child: PhoneFrame(child: child ?? const SizedBox()),
      ),
    );
  }
}

/// Mouse drag scrolls too, so the orders carousel works on desktop.
class _DahabScrollBehavior extends MaterialScrollBehavior {
  const _DahabScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus};
}
