#!/usr/bin/env python3
"""Generates the screen catalogues of the customer app's texts (backend spec 019, stages 2-7).

Every visible English sentence the app translates through `context.t` has a key, a default
(its own English) and an Arabic default (the app's dictionary). This script finds them:

  * the string literals of `lib/` that have an Arabic entry in `assets/i18n/ar.json` or
    `lib/core/i18n/ar_extra.dart`, and a short list of English-only visible sentences, and
  * the regex patterns of `lib/core/i18n/i18n.dart` (strings with a number, a name or a date in
    them), which become keys with `{placeholders}`.

Output: `lib/core/text/keys/screens_*.dart` and `lib/core/text/keys/patterns.dart`.

Keys are never renamed (Q1): the keys already in the generated files are read first and reused
for the same English; a new sentence gets a new key. Run from the repository root:

    python tool/gen_text_catalogue.py

then `UPDATE_TEXT_MANIFEST=1 flutter test test/text_manifest_test.dart` and copy
`assets/text/keys.json` to the backend (`database/data/app_text_keys.json`).
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/') + '/'
KEYS_DIR = ROOT + 'lib/core/text/keys/'

# (stage file, class name, header)
STAGES = {
    2: ('screens_home.dart', 'ScreensHomeKeys', 'Stage 2: Home, Browse and the piece page'),
    3: ('screens_orders.dart', 'ScreensOrdersKeys', 'Stage 3: Orders and buying'),
    4: ('screens_selling.dart', 'ScreensSellingKeys', 'Stage 4: Selling and My listings'),
    5: ('screens_wallet.dart', 'ScreensWalletKeys', 'Stage 5: Wallet, money, bank accounts and invoices'),
    6: ('screens_account.dart', 'ScreensAccountKeys', 'Stage 6: Account, settings, legal, inbox, contact changes, close account'),
    7: ('screens_shared.dart', 'ScreensSharedKeys', 'Stage 7: Sign-in, sign-up, splash, shared widgets, messages and errors'),
}

# English-only sentences that are visible today (no Arabic in the app yet); they keep showing in
# English in Arabic mode until the owner approves an Arabic text.
ENGLISH_ONLY = [
    'ID not approved',
    'Waiting for verification',
    'We are checking your ID. You can sign in and look around now; buying and selling open as soon as it is approved \u2014 usually in under an hour.',
    'Choose where to take the piece',
    'Your deadline is counted in working hours at the branch you pick.',
    'Nobody is in line right now.',
    'A buy request at',
    'From buyer',
]


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


# ---- where a file belongs: (stage, key prefix, registry area, where) ----
def classify(rel):
    p = rel
    stem = os.path.splitext(os.path.basename(p))[0]
    pretty = stem.replace('_screens', '').replace('_screen', '').replace('_', ' ').capitalize()
    where = pretty + ' screen'
    if p.startswith('lib/features/home/'):
        return 2, 'home', 'Home', 'Home screen'
    if p.endswith('catalog/browse_screen.dart'):
        return 2, 'browse', 'Browse', 'Browse screen'
    if p.endswith('catalog/detail_screen.dart'):
        return 2, 'piece', 'Browse', 'Piece page'
    if p.endswith('shared/piece_card.dart') or p.endswith('shared/listing_ui.dart'):
        return 2, 'piece', 'Browse', 'Piece cards and listing details'
    if p.endswith('catalog/buy_screens.dart'):
        return 3, 'buy', 'Orders', 'Buying a piece'
    if p.endswith('shared/order_card.dart'):
        return 3, 'orders', 'Orders', 'Order card'
    if p.startswith('lib/features/orders/'):
        return 3, 'orders', 'Orders', {'orders_screen': 'Orders list', 'order_screen': 'Order screen', 'order_flows': 'Order steps', 'order_help_screens': 'Order help screens'}.get(stem, where)
    if p.startswith('lib/features/sell/'):
        return 4, 'selling', 'Selling', {'sell1_screen': 'Sell: step 1', 'sell2_screen': 'Sell: step 2', 'sell3_screen': 'Sell: review and list'}.get(stem, where)
    if p.startswith('lib/features/wallet/'):
        return 5, 'wallet', 'Wallet', {'wallet_screens': 'Wallet screens', 'withdraw_confirm_screen': 'Confirm a withdrawal'}.get(stem, where)
    if p.endswith('account/bank_screens.dart'):
        return 5, 'bank', 'Wallet', 'Bank accounts'
    if p.startswith('lib/features/account/'):
        return 6, 'account', 'Account', {'account_screen': 'Account', 'settings_screens': 'Settings and legal screens', 'contact_change_screens': 'Change phone or email', 'account_messages': 'Account messages', 'legal_accept_screen': 'Accept the terms'}.get(stem, where)
    if p.startswith('lib/features/auth/'):
        return 7, 'auth', 'Auth', {'login_screens': 'Sign in', 'signup_screens': 'Sign up', 'splash_screen': 'Splash'}.get(stem, where)
    if p.startswith('lib/features/shared/'):
        return 7, 'shared', 'Shared', 'Shared widgets'
    if p.startswith('lib/services/'):
        return 7, 'errors', 'Shared', 'Messages and errors'
    if p.startswith('lib/widgets/'):
        return 7, 'shared', 'Shared', 'Shared widgets'
    if p.startswith('lib/routing/'):
        return 7, 'shared', 'Shared', 'Screen titles'
    return 7, 'shared', 'Shared', 'Shared texts'


# ---- the app's dictionary ----
def load_dict():
    d = json.load(open(ROOT + 'assets/i18n/ar.json', encoding='utf-8'))
    out = {norm(k): v for k, v in d.items()}
    extra = open(ROOT + 'lib/core/i18n/ar_extra.dart', encoding='utf-8').read()
    for m in re.finditer(r"^\s*'((?:[^'\\]|\\.)*)'\s*:\s*'((?:[^'\\]|\\.)*)'\s*,", extra, re.M):
        k = norm(m.group(1).replace("\\'", "'"))
        out.setdefault(k, m.group(2).replace("\\'", "'"))
    return out


# ---- Dart string literals ----
def literals(src):
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i)
            i = n if j < 0 else j + 2
            continue
        if c in '\'"':
            parts = []
            interp = False
            while i < n and src[i] in '\'"':
                q = src[i]
                if src.startswith(q * 3, i):
                    j = src.find(q * 3, i + 3)
                    i = n if j < 0 else j + 3
                    interp = True
                    break
                raw = i > 0 and src[i - 1] == 'r'
                i += 1
                buf = []
                while i < n and src[i] != q:
                    if src[i] == '\\' and not raw:
                        buf.append(src[i:i + 2])
                        i += 2
                        continue
                    if src[i] == '$' and not raw:
                        interp = True
                        if src.startswith('${', i):
                            # skip the expression, nested strings included
                            depth = 0
                            j = i + 1
                            inner = None
                            while j < n:
                                ch = src[j]
                                if inner:
                                    if ch == '\\':
                                        j += 2
                                        continue
                                    if ch == inner:
                                        inner = None
                                elif ch in ("'", '"'):
                                    inner = ch
                                elif ch == '{':
                                    depth += 1
                                elif ch == '}':
                                    depth -= 1
                                    if depth == 0:
                                        j += 1
                                        break
                                j += 1
                            buf.append(src[i:j])
                            i = j
                            continue
                    buf.append(src[i])
                    i += 1
                i += 1
                parts.append(''.join(buf))
                k = i
                while k < n and src[k] in ' \t\r\n':
                    k += 1
                if k < n and src[k] in '\'"':
                    i = k
                    continue
                break
            out.append((''.join(parts), interp))
            continue
        i += 1
    return out


def unescape(s):
    if '\\' not in s:
        return s
    t = s.replace("\\'", "'").replace('\\"', '"').replace('\\$', '$')
    t = t.replace('\\u2026', '\u2026').replace('\\u2014', '\u2014').replace('\\u2212', '\u2212')
    return t


def dart_quote(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


def slug(text, words=6, limit=36):
    t = re.sub(r'\{[a-z0-9_]+\}', ' ', text.lower())
    t = re.sub(r"[^a-z0-9]+", ' ', t.replace("'", ''))
    parts = [w for w in t.split() if w][:words]
    s = '_'.join(parts)[:limit].strip('_')
    return s or 'text'


def camel(key):
    parts = re.split(r'[._]', key)
    return parts[0] + ''.join(p[:1].upper() + p[1:] for p in parts[1:])


# ---- what is already catalogued ----
def existing():
    """en -> key for every key already declared (explicit catalogues and earlier generations)."""
    by_en = {}
    by_key = {}
    for f in glob.glob(KEYS_DIR + '*.dart'):
        if f.replace('\\', '/').endswith(('all_keys.dart', 'patterns.dart')) or os.path.basename(f).startswith('screens_'):
            continue
        s = open(f, encoding='utf-8').read()
        for m in re.finditer(r"TextKey\(\s*'([a-z0-9_.]+)',\s*'((?:[^'\\]|\\.)*)'", s):
            by_en[norm(unescape(m.group(2)))] = m.group(1)
            by_key[m.group(1)] = norm(unescape(m.group(2)))
    return by_en, by_key


def previous():
    """en -> (key, stage) from earlier generated files: keys are never renamed."""
    prev = {}
    for stage, (fname, _, _) in STAGES.items():
        p = KEYS_DIR + fname
        if not os.path.exists(p):
            continue
        s = open(p, encoding='utf-8').read()
        for m in re.finditer(r"TextKey\(\s*'([a-z0-9_.]+)',\s*'((?:[^'\\]|\\.)*)'", s):
            prev[norm(unescape(m.group(2)).replace("\\'", "'"))] = m.group(1)
    return prev


# ---- patterns of i18n.dart ----
def parse_patterns():
    src = open(ROOT + 'lib/core/i18n/i18n.dart', encoding='utf-8').read()
    a = src.index('static final List<(RegExp, String)> _patterns = [')
    b = src.index('\n  ];', a)
    body = src[a:b]
    out = []
    for m in re.finditer(r"RegExp\(\s*r(?P<q1>['\"])(?P<re>.*?)(?P=q1)\s*,?\s*\)\s*,\s*r(?P<q2>['\"])(?P<ar>.*?)(?P=q2)", body, re.S):
        out.append((m.group('re'), m.group('ar')))
    return out


def split_groups(rx):
    """The capture groups of a regex source, with the literal text between them."""
    pieces = []
    i = 0
    buf = []
    n = len(rx)
    while i < n:
        c = rx[i]
        if c == '\\' and i + 1 < n:
            buf.append(rx[i:i + 2])
            i += 2
            continue
        if c == '(' and not rx.startswith('(?:', i):
            depth = 1
            j = i + 1
            while j < n and depth:
                if rx[j] == '\\':
                    j += 2
                    continue
                if rx[j] == '(':
                    depth += 1
                elif rx[j] == ')':
                    depth -= 1
                j += 1
            pieces.append(('text', ''.join(buf)))
            buf = []
            pieces.append(('group', rx[i + 1:j - 1]))
            i = j
            continue
        buf.append(c)
        i += 1
    pieces.append(('text', ''.join(buf)))
    return pieces


def literal_text(rx_text):
    t = rx_text
    t = re.sub(r'\\([.()$^*+?\[\]{}|\\/\-])', r'\1', t)
    return t


def group_name(content, before, after, used):
    c = content
    if re.fullmatch(r'\\d\+', c):
        name = 'karat' if after.startswith('K') else 'count'
    elif re.fullmatch(r'\\d\[\\d,\]\*(?:\(\?:\\\.\\d\+\)\?)?|\[\\d,\.\]\+|\[\\d,\.\\-\]\+|\[\\d,\]\+', c) or 'd,' in c:
        name = 'amount'
    elif c == r'[\d.]+':
        name = 'weight' if after.startswith(' g') else ('percent' if after.startswith('%') else 'number')
    elif c in ('.+?', '.+', '.*'):
        name = 'text'
    elif c.startswith('DH-'):
        name = 'order_ref'
    elif c.startswith('DSP-'):
        name = 'reference'
    elif c == r'\d+ \w+':
        name = 'age'
    elif c == r'\d':
        name = 'digit'
    elif c == r'\w+':
        name = 'word'
    else:
        name = 'value'
    base = name
    k = 2
    while name in used:
        name = '%s_%d' % (base, k)
        k += 1
    used.append(name)
    return name


def pattern_entries():
    entries = []
    skipped = []
    seen_rx = set()
    for rx, ar in parse_patterns():
        if rx in seen_rx:
            continue  # a repeated expression is never reached: the first one answers
        seen_rx.add(rx)
        body = rx
        if body.startswith('^'):
            body = body[1:]
        if body.endswith('$'):
            body = body[:-1]
        pieces = split_groups(body)
        names = []
        en = ''
        leftover = ''
        for idx, (kind, content) in enumerate(pieces):
            if kind == 'text':
                en += literal_text(content)
                leftover += re.sub(r'\\.', '', content)
            else:
                nxt = ''
                if idx + 1 < len(pieces) and pieces[idx + 1][0] == 'text':
                    nxt = literal_text(pieces[idx + 1][1])
                prv = literal_text(pieces[idx - 1][1]) if idx > 0 else ''
                nm = group_name(content, prv, nxt, names)
                en += '{%s}' % nm
        if re.search(r'[\[\]*+?|^]', leftover):
            skipped.append(rx)
            continue
        def sub_ar(m):
            i = int(m.group(1)) - 1
            return '{%s}' % names[i] if i < len(names) else m.group(0)
        ar_t = re.sub(r'\$(\d)', sub_ar, ar)
        entries.append({'rx': rx, 'en': en, 'ar': ar_t, 'names': names})
    return entries, skipped


def main():
    d = load_dict()
    ex_by_en, ex_by_key = existing()
    prev = previous()

    # 1. literals of the app
    files = [f.replace('\\', '/') for f in glob.glob(ROOT + 'lib/**/*.dart', recursive=True)]
    skip = ('/core/i18n/', '/mock/', '/core/text/', '/core/config/', '/account/invite_screen.dart')
    found = {}  # en -> (stage, prefix, area, where, path)
    for f in sorted(files):
        if any(s in f for s in skip):
            continue
        rel = f.replace(ROOT, '')
        src = open(f, encoding='utf-8').read()
        info = classify(rel)
        for raw, interp in literals(src):
            if interp or '{' in raw:
                continue
            t = norm(unescape(raw))
            if len(t) < 2 or '\\' in t:
                continue
            # Referral rules are not defined (backend spec 019 OD-2): that screen stays a mock, off the catalogue.
            if re.search(r'invite|referral', t, re.I):
                continue
            ok = (t in d and d[t] != t) or t in ENGLISH_ONLY
            if not ok:
                continue
            cur = found.get(t)
            rank = ['home', 'browse', 'piece', 'buy', 'orders', 'selling', 'wallet', 'bank', 'account', 'auth', 'shared', 'errors'].index(info[1])
            if cur is None or (info[0], rank, rel) < (cur[0], cur[5], cur[4]):
                found[t] = info + (rel, rank)

    # English-only sentences that were not found in a file still get a key (the screen builds them).
    taken = set(ex_by_key)
    new_keys = {}
    rows = {s: [] for s in STAGES}
    used_keys = set(taken)
    for t, (stage, prefix, area, where, rel, _rank) in sorted(found.items(), key=lambda kv: (kv[1][0], kv[1][5], kv[1][4], kv[0])):
        if t in ex_by_en:
            continue
        key = prev.get(t)
        if key is None:
            base = '%s.%s' % (prefix, slug(t))
            key = base
            k = 2
            while key in used_keys:
                key = '%s_%d' % (base, k)
                k += 1
        used_keys.add(key)
        rows[stage].append((key, t, area, where))

    for stage, (fname, cls, header) in STAGES.items():
        lines = [
            "import '../text_key.dart';",
            '',
            '/// %s (backend spec 019, R14).' % header,
            '///',
            '/// Generated by `tool/gen_text_catalogue.py` from the screens\' own strings: the default is',
            "/// the English the screen always showed and the Arabic default is the app's dictionary, so",
            '/// nothing a customer reads changes. Keys are never renamed. Staff change the wording from App text.',
            'abstract final class %s {' % cls,
        ]
        names = []
        for key, en, area, where in sorted(rows[stage], key=lambda r: r[0]):
            nm = camel(key)
            names.append(nm)
            lines.append('  static const %s = TextKey(%s, %s, area: %s, where: %s);' % (nm, dart_quote(key), dart_quote(en), dart_quote(area), dart_quote(where)))
        lines.append('')
        lines.append('  static const all = <TextKey>[')
        for nm in names:
            lines.append('    %s,' % nm)
        lines.append('  ];')
        lines.append('}')
        open(KEYS_DIR + fname, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')

    # 2. the patterns
    entries, skipped = pattern_entries()
    plines = [
        "import '../text_key.dart';",
        '',
        "/// The app's sentences with a number, a name or a date in them (backend spec 019, R14): the",
        "/// regex patterns of `i18n.dart` as keys with `{placeholders}`. Generated by",
        '/// `tool/gen_text_catalogue.py`; the Arabic default is the pattern\'s own Arabic.',
        '///',
        "/// [table] pairs each key with the expression that recognises the English the screen builds and",
        '/// the placeholder each capture group fills, in order.',
        'class PatternKey {',
        '  const PatternKey(this.expression, this.key, this.names);',
        '',
        '  final String expression;',
        '  final TextKey key;',
        '  final List<String> names;',
        '}',
        '',
        'abstract final class PatternKeys {',
    ]
    used = set(used_keys)
    prev_patterns = {}
    pp = KEYS_DIR + 'patterns.dart'
    if os.path.exists(pp):
        for m in re.finditer(r"TextKey\(\s*'([a-z0-9_.]+)',\s*'((?:[^'\\]|\\.)*)'", open(pp, encoding='utf-8').read()):
            prev_patterns[unescape(m.group(2))] = m.group(1)
    pnames = []
    table = []
    for e in entries:
        base = 'pattern.%s' % slug(re.sub(r'\{([a-z0-9_]+)\}', r' \1 ', e['en']).replace('{', ' '), words=7, limit=40)
        key = prev_patterns.get(e['en'], base)
        k = 2
        while key in used:
            key = '%s_%d' % (base, k)
            k += 1
        used.add(key)
        nm = camel(key)
        pnames.append(nm)
        table.append((e['rx'], nm, e['names']))
        plines.append('  static const %s = TextKey(' % nm)
        plines.append('    %s,' % dart_quote(key))
        plines.append('    %s,' % dart_quote(e['en']))
        plines.append('    ar: %s,' % dart_quote(e['ar']))
        if e['names']:
            plines.append('    placeholders: [%s],' % ', '.join(dart_quote(x) for x in e['names']))
        plines.append("    area: 'Shared',")
        plines.append("    where: 'A sentence with a number, a name or a date in it',")
        plines.append('  );')
    plines.append('')
    plines.append('  static const all = <TextKey>[')
    for nm in pnames:
        plines.append('    %s,' % nm)
    plines.append('  ];')
    plines.append('')
    plines.append('  static const table = <PatternKey>[')
    for rx, nm, names in table:
        plines.append("    PatternKey(r'%s', %s, [%s])," % (rx, nm, ', '.join(dart_quote(x) for x in names)))
    plines.append('  ];')
    plines.append('}')
    open(KEYS_DIR + 'patterns.dart', 'w', encoding='utf-8', newline='\n').write('\n'.join(plines) + '\n')

    total = sum(len(v) for v in rows.values())
    print('literals keyed:', total, {s: len(v) for s, v in rows.items()})
    print('patterns keyed:', len(entries), 'skipped:', len(skipped))
    for s in skipped:
        print('  skipped pattern:', s)


main()
