import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import '../routing/nav.dart';
import '../routing/routes.dart';
import 'buttons.dart';
import 'd_icon.dart';
import 'mock_flag.dart';
import 'dahab_logo.dart';

/// One screen inside the phone: top bar, scrolling body, bottom tabs —
/// the `.top` / `.body` / `.tabs` layout of the prototype. Which chrome
/// shows is decided by the screen id, exactly like `go()` in the HTML.
class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.id, required this.child, this.padded = true, this.title, this.scroll = true, this.bottomPadding = 22});

  /// Screen id from [R].
  final String id;
  final Widget child;

  /// Wrap the body in the standard 16px `.pad`.
  final bool padded;

  /// Overrides the title from [R.titles].
  final String? title;
  final bool scroll;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final showTop = id != R.splash;
    final showTabs = !R.auth.contains(id);
    Widget body = padded ? Padding(padding: const EdgeInsets.all(DLayout.pad), child: child) : child;
    if (scroll) {
      body = SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: body,
      );
    }
    return Material(
      color: DColors.paper,
      child: Column(
        children: [
          if (showTop) _TopBar(id: id, title: title),
          if (mockScreens.contains(id)) const MockScreenBanner(),
          Expanded(child: body),
          if (showTabs) _TabBar(current: id),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.id, this.title});

  final String id;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final isHome = id == R.home;
    final canPop = GoRouter.of(context).canPop();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: DColors.white,
        border: Border(bottom: BorderSide(color: DColors.line)),
      ),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            if (canPop) ...[
              Tappable(
                onTap: context.back,
                child: Semantics(
                  label: 'Back',
                  button: true,
                  child: const DIcon('arrow-left', size: 19, color: DColors.ink2),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (isHome)
              const DahabLogo(width: 84, height: 24)
            else
              Expanded(
                child: Text(
                  context.t(title ?? R.titles[id] ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            if (isHome) const Spacer(),
            const SizedBox(width: 10),
            MockMark(
              bottom: -14,
              end: -12,
              child: Tappable(
                onTap: () => context.nav(R.inbox),
                child: Semantics(
                  label: context.t('Notifications'),
                  button: true,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(child: DIcon('bell', size: 18, color: DColors.ink2)),
                        PositionedDirectional(
                          top: 0,
                          end: -1,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: DColors.bad, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current});

  final String current;

  static const _tabs = [
    (R.home, 'home', 'Home'),
    (R.browse, 'search', 'Browse'),
    (R.sell1, 'plus', 'Sell'),
    (R.orders, 'clipboard-list', 'Orders'),
    (R.account, 'user', 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DColors.white,
        border: Border(top: BorderSide(color: DColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (id, icon, label) in _tabs)
              Expanded(
                child: _Tab(icon: icon, label: label, on: id == current, onTap: () => id == R.sell1 ? context.trySell() : context.nav(id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.on, required this.onTap});

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = on ? DColors.ink : DColors.ink3;
    return Tappable(
      onTap: onTap,
      child: Semantics(
        selected: on,
        button: true,
        child: Container(
          padding: const EdgeInsets.only(top: 10, bottom: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: on ? DColors.ink : Colors.transparent, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DIcon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.phone` — on wide screens the app sits in a centred 390px phone with
/// rounded corners and a shadow; at 430px and below it fills the viewport.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DColors.desk,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth <= DLayout.fullBleedBreakpoint) {
            return ColoredBox(color: DColors.paper, child: child);
          }
          final height = (c.maxHeight - 40).clamp(0.0, DLayout.phoneHeight);
          final width = (c.maxWidth - 24).clamp(0.0, DLayout.phoneWidth);
          return Center(
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: DColors.paper,
                borderRadius: BorderRadius.circular(DRadius.phone),
                boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 40, offset: Offset(0, 12))],
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
