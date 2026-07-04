#!/usr/bin/env bash
set -u

# Evaluator-harness vacuity lint (cand-0199; from the cand-0198 found-in-
# passing finding and the 2026-07-02 candidate-store audit).
#
# The defect class: a probe written as
#
#   ( set -e; probe-cmd-1; probe-cmd-2; echo "claim" ) > trace 2>&1 \
#     && ok "$t" || bad "$t" "msg"
#
# never fails. Bash (and POSIX sh) ignore `set -e` for every command of an
# AND-OR list except the last, and that suppression extends into compound
# commands: a `set -e` executed INSIDE the subshell has no effect while the
# subshell itself is a non-final `&&`/`||` operand. Every probe command can
# fail; the body still falls through to its final `echo`, the subshell
# exits 0, and the probe attests PASS. The audit found 145 such probes
# across 28 landed candidates, several masking real failures (e.g.
# cand-0080 t01: nix build failed, PASS attested).
#
# The sound form keeps the subshell a standalone command, then tests its
# status:
#
#   ( set -e; ... ) > trace 2>&1
#   [ "$?" -eq 0 ] && ok "$t" || bad "$t" "msg"
#
# What this lint reports, per probe subshell whose closer line sits in an
# AND-OR list (`) > trace 2>&1 && ...`):
#
#   dead-set-e       ERROR  body contains `set -e`: the author relied on
#                           errexit that cannot fire in this form
#   no-failure-path  ERROR  body has no `set -e`, no `exit`, and an
#                           always-true final command (echo/printf/true/:)
#                           — the subshell status is the tail's, always 0
#   tail-status-only WARN   body has no `set -e`, no `exit`; the final
#                           command is a real check — only that last
#                           command is tested, earlier failures are masked
#
# And per whole evaluator:
#
#   worldly-assertion ERROR  string equality against `git rev-parse HEAD`
#                           (or a branch ref) is a live-world assertion, not
#                           a replay-stable contract; use
#                           `git merge-base --is-ancestor <pin> HEAD`
#
# Bodies in the AND-OR form that propagate failure explicitly (rc-tracking
# with a trailing `exit "$rc"`, or per-command `|| exit` guards) are sound
# and stay silent.
#
# Boundary (honest): line-based structural scan, not a shell parser.
# Backslash-continued lines are joined into logical lines before the scan
# (closing the cand-0199 review blind spot: `) > trace 2>&1 \` with the
# AND-OR list on the continuation line), reported at the first physical
# line. The opener is the nearest preceding line holding only `(`; heredoc
# content that happens to carry such lines can false-positive (keep
# fixture material in printf arguments, not literal heredoc lines). The
# lint advises on harness FORM; it does not and cannot judge whether a
# probe's assertions witness the candidate's claim. Landed candidates'
# evaluators are historical receipts: pointing this lint at them measures
# the history, it does not license rewriting it.
#
# The worldly-assertion scan is conservative and line-oriented: it catches
# direct equality on a live `git rev-parse` command substitution, plus simple
# variables assigned from such a command and later compared to sha-like pins.
# It intentionally does not report the monotone `git merge-base --is-ancestor`
# form.
#
# Fixture-independence lint (cand-0030; from the kcir dependency-mode pilot
# blind spots). External-interface fixtures must be shape-independent of the
# subject under test: use declared manifests/schemas for store shape, differing
# souls where souls are tested, and read-only stores for read claims.
#
# What this lint reports mechanically:
#
#   subject-fixture-copy              ERROR  the evaluator copies the subject
#                                           tree wholesale (`$ROOT`, `$STAGE`,
#                                           `$SUBJECT`, `$SUBJECT_ROOT`) with
#                                           recursive/archive copy forms or a
#                                           local `copy_tree` helper
#   subject-digest-self-comparison    ERROR  the evaluator compares a digest
#                                           or bytes for the same relative path
#                                           under two subject roots, including
#                                           simple variables assigned from
#                                           `sha_file "$ROOT/rel"` and
#                                           `sha_file "$STAGE/rel"`
#   writable-readonly-store           ERROR  a function/probe whose name or
#                                           body says read-only/readonly creates
#                                           a store fixture but has no local
#                                           read-only marker (`chmod ... -w`,
#                                           `readonly_store_fixture`, or
#                                           `readonly_manifest_store_fixture`)
#
# Boundary (honest): this is still a line/block scanner, not a semantic shell
# interpreter. It catches only direct, mechanical smells. It cannot judge
# whether a manifest row set is the right external interface, whether two soul
# payloads differ meaningfully, whether a helper not named here really produces
# a read-only tree, or whether a subject tree copy is internal staging rather
# than an external-interface fixture. Those remain reviewer judgment.
#
# Usage:
#   harness-lint.sh FILE...
#
# Exit codes:
#   0  — no ERROR-class findings (WARNs allowed)
#   1  — at least one ERROR-class finding
#   64 — usage
#   65 — a named file is missing or unreadable

die() { printf 'harness-lint: %s\n' "$2" >&2; exit "$1"; }

[ "$#" -ge 1 ] || die 64 'usage: harness-lint.sh FILE...'
for f in "$@"; do
  [ -f "$f" ] && [ -r "$f" ] || die 65 "not a readable file: $f"
done

python3 - "$@" <<'PY'
import re
import sys

CLOSER = re.compile(r'^\s*\)\s*>[^;]*?(?:2>&1)?\s*(?:&&|\|\|)')
OPENER = re.compile(r'^\s*\($')
SET_E = re.compile(r'^\s*set\s+-[a-z]*e', re.M)
HAS_EXIT = re.compile(r'\bexit\b')
ALWAYS_TRUE = re.compile(r'^(echo\b|printf\b|note\b|true\b|:(\s|$))')
PROBE_NAME = re.compile(r'^t=(\S+)')
ASSIGN = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)=.*git\s+rev-parse\b')
EQUALITY = re.compile(r'(?:\[\[|\[|\btest\b).*(?:==|(?<![<>!])=(?!=)).*')
SHA_LITERAL = re.compile(r'\b[0-9a-fA-F]{7,40}\b')
SHA_VAR = re.compile(
    r'\$\{?(?=[A-Za-z_])'
    r'(?=[A-Za-z0-9_]*(?:SHA|REV|COMMIT|PIN|BASE|OLD|EXPECTED|ANCESTOR|REF))'
    r'[A-Za-z_][A-Za-z0-9_]*\}?',
    re.I,
)
VAR_REF = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?')
SUBJECT_ROOTS = r'(?:ROOT|STAGE|SUBJECT|SUBJECT_ROOT)'
SUBJECT_ROOT_REF = r'\$\{?' + SUBJECT_ROOTS + r'\}?'
SUBJECT_WHOLE_PATH = r'"?' + SUBJECT_ROOT_REF + r'(?:/\.?)?"?(?=\s|$|[|;&)])'
SUBJECT_COPY = [
    re.compile(r'\bcp\b(?=[^#\n]*(?:-[A-Za-z]*[Rr][A-Za-z]*|--recursive|--archive|-a\b))'
               r'[^#\n]*' + SUBJECT_WHOLE_PATH),
    re.compile(r'\brsync\b(?=[^#\n]*(?:-a|--archive))[^#\n]*' + SUBJECT_WHOLE_PATH),
    re.compile(r'\bcopy_tree\s+' + SUBJECT_WHOLE_PATH),
    re.compile(r'\b(?:cd\s+' + SUBJECT_WHOLE_PATH +
               r'\s*&&\s*(?:git\s+archive|tar\s+(?:-c|cf)|tar\s+-cf))'),
    re.compile(r'\bgit\s+-C\s+' + SUBJECT_WHOLE_PATH + r'\s+archive\b'),
]
SUBJECT_PATH = re.compile(
    r'"?\$\{?(?P<root>' + SUBJECT_ROOTS + r')\}?/(?P<rel>[^"\'\s)]+)"?'
)
SHA_PATH = re.compile(
    r'sha_file\s+"?\$\{?(?P<root>' + SUBJECT_ROOTS + r')\}?/(?P<rel>[^"\')]+)"?'
)
DIGEST_ASSIGN = re.compile(
    r'^\s*(?P<var>[A-Za-z_][A-Za-z0-9_]*)=["\']?\$\(sha_file\s+'
    r'"?\$\{?(?P<root>' + SUBJECT_ROOTS + r')\}?/(?P<rel>[^"\')]+)"?\)'
)
READONLY_TEXT = re.compile(r'(?:read[-_ ]?only|readonly)', re.I)
STORE_CREATE = re.compile(
    r'\bmkdir\s+-p\b[^#\n]*(?:store|kernel-store|fake-store)|'
    r'\b(?:manifest_store_fixture|materialize_[A-Za-z0-9_]*(?:store|manifest)|make_[A-Za-z0-9_]*store)\b',
    re.I,
)
READONLY_MARK = re.compile(
    r'\b(?:chmod\b[^#\n]*-[A-Za-z]*w\b|read_?only_store_fixture|'
    r'read_?only_manifest_store_fixture|readonly_store_fixture|'
    r'readonly_manifest_store_fixture)\b',
    re.I,
)
FUNC_DEF = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{')

errors = 0
warnings = 0

def last_command(body_lines):
    for line in reversed(body_lines):
        s = line.strip()
        if s and not s.startswith('#'):
            return s
    return ''

def logical_lines(physical):
    # Join backslash-continued lines into logical lines (cand-0199 review
    # blind spot: a closer split as `) > trace 2>&1 \` + `&& ok || bad`).
    # Each logical line remembers its FIRST physical index for reporting.
    # A trailing `\\` (escaped backslash) is not a continuation.
    joined = []
    buf, start = '', None
    for idx, line in enumerate(physical):
        if start is None:
            start = idx
        stripped = line.rstrip()
        if stripped.endswith('\\') and not stripped.endswith('\\\\'):
            buf += stripped[:-1] + ' '
            continue
        joined.append((start, buf + line))
        buf, start = '', None
    if start is not None and buf:
        joined.append((start, buf))
    return joined

def probe_name(lines, start):
    for k in range(start, max(-1, start - 8), -1):
        m = PROBE_NAME.match(lines[k])
        if m:
            return ' (probe %s)' % m.group(1)
    return ''

def rev_parse_targets(text):
    targets = []
    for m in re.finditer(r'git\s+rev-parse\b([^;&|`$)]*)', text):
        tail = m.group(1).strip()
        if not tail:
            continue
        words = [w.strip('"\'') for w in tail.split()]
        refs = [w for w in words if w and not w.startswith('-')]
        if refs:
            targets.append(refs[-1])
    return targets

def is_live_rev_parse(text):
    if 'merge-base --is-ancestor' in text:
        return False
    for target in rev_parse_targets(text):
        if '$' in target:
            continue
        clean = target.removesuffix('^{commit}')
        if re.fullmatch(r'[0-9a-fA-F]{7,40}', clean):
            continue
        if clean == 'HEAD' or clean.startswith('refs/heads/') or clean.startswith('origin/'):
            return True
        if re.fullmatch(r'[A-Za-z][A-Za-z0-9._/-]*', clean):
            return True
    return False

def has_sha_pin(text):
    return bool(SHA_LITERAL.search(text) or SHA_VAR.search(text))

def has_rev_var(text, rev_vars):
    refs = set(VAR_REF.findall(text))
    return bool(refs.intersection(rev_vars))

def norm_rel(rel):
    rel = rel.strip().strip('"\'')
    while rel.startswith('./'):
        rel = rel[2:]
    if rel.endswith('/.'):
        rel = rel[:-2]
    return rel

def subject_path_matches(pattern, text):
    return [(m.group('root'), norm_rel(m.group('rel'))) for m in pattern.finditer(text)]

def same_subject_rel(paths):
    for idx, (root, rel) in enumerate(paths):
        for other_root, other_rel in paths[idx + 1:]:
            if rel == other_rel and root != other_root:
                return rel
    return None

def report_subject_copy(path, line_no, line):
    print('%s:%d: ERROR subject-fixture-copy: subject tree copied '
          'wholesale into a fixture; use manifest_store_fixture or '
          'readonly_manifest_store_fixture for external-interface fixtures '
          '(%s)' % (path, line_no, line.strip()))

def report_digest_self_comparison(path, line_no, rel):
    print('%s:%d: ERROR subject-digest-self-comparison: same subject-relative '
          'path compared across subject roots (%s); use an independent fixture '
          'or a deliberately different soul payload' % (path, line_no, rel))

def report_writable_readonly_store(path, line_no, name):
    print('%s:%d: ERROR writable-readonly-store: read-only-named store probe '
          '%s creates a store fixture without a chmod/helper read-only marker'
          % (path, line_no, name))

def function_blocks(lines, physno):
    i = 0
    while i < len(lines):
        m = FUNC_DEF.match(lines[i])
        if not m:
            i += 1
            continue
        end = None
        for j in range(i + 1, len(lines)):
            if re.match(r'^\s*}\s*$', lines[j]):
                end = j
                break
        if end is None:
            i += 1
            continue
        yield m.group(1), i, end, lines[i:end + 1], physno[i] + 1
        i = end + 1

for path in sys.argv[1:]:
    with open(path, encoding='utf-8', errors='replace') as fh:
        entries = logical_lines(fh.read().splitlines())
    lines = [text for _, text in entries]
    physno = [first for first, _ in entries]
    rev_vars = set()
    digest_vars = {}
    for i, line in enumerate(lines):
        if any(rx.search(line) for rx in SUBJECT_COPY):
            report_subject_copy(path, physno[i] + 1, line)
            errors += 1
        rel = same_subject_rel(subject_path_matches(SHA_PATH, line))
        if rel:
            report_digest_self_comparison(path, physno[i] + 1, rel)
            errors += 1
        if 'cmp' in line:
            rel = same_subject_rel(subject_path_matches(SUBJECT_PATH, line))
            if rel:
                report_digest_self_comparison(path, physno[i] + 1, rel)
                errors += 1
        dm = DIGEST_ASSIGN.match(line)
        if dm:
            digest_vars[dm.group('var')] = (dm.group('root'), norm_rel(dm.group('rel')))
        if 'merge-base --is-ancestor' in line:
            continue
        m = ASSIGN.match(line)
        if m and is_live_rev_parse(line):
            rev_vars.add(m.group(1))
        if not EQUALITY.search(line):
            continue
        direct = is_live_rev_parse(line) and has_sha_pin(line)
        assigned = has_rev_var(line, rev_vars) and has_sha_pin(line)
        refs = list(dict.fromkeys(VAR_REF.findall(line)))
        digest_refs = [(v, digest_vars[v]) for v in refs if v in digest_vars]
        digest_rel = None
        for idx, (_var, (root, rel)) in enumerate(digest_refs):
            for _other_var, (other_root, other_rel) in digest_refs[idx + 1:]:
                if rel == other_rel and root != other_root:
                    digest_rel = rel
                    break
            if digest_rel:
                break
        if digest_rel:
            report_digest_self_comparison(path, physno[i] + 1, digest_rel)
            errors += 1
        if direct or assigned:
            where = '%s:%d%s' % (path, physno[i] + 1, probe_name(lines, i))
            print('%s: ERROR worldly-assertion: live git rev-parse string '
                  'equality is not replay-stable; use git merge-base '
                  '--is-ancestor <pin> HEAD' % where)
            errors += 1
    for name, start, _end, body, line_no in function_blocks(lines, physno):
        readonly_claim = bool(READONLY_TEXT.search(name)) or any(READONLY_TEXT.search(l) for l in body)
        if not readonly_claim:
            continue
        creates_store = any(STORE_CREATE.search(l) for l in body)
        has_readonly = any(READONLY_MARK.search(l) for l in body)
        if creates_store and not has_readonly:
            report_writable_readonly_store(path, line_no, name)
            errors += 1
    for i, line in enumerate(lines):
        if not CLOSER.match(line):
            continue
        # nearest preceding standalone "(" line is the probe opener
        opener = None
        for j in range(i - 1, -1, -1):
            if CLOSER.match(lines[j]):
                break
            if OPENER.match(lines[j]):
                opener = j
                break
        if opener is None:
            continue
        body = lines[opener + 1:i]
        # comment-only lines carry no control flow; keep them out of the
        # set -e / exit detection
        text = '\n'.join(l for l in body if not l.strip().startswith('#'))
        where = '%s:%d%s' % (path, physno[i] + 1, probe_name(lines, opener - 1))
        if SET_E.search(text):
            print('%s: ERROR dead-set-e: subshell closer is a non-final '
                  'AND-OR operand, so the set -e inside the body cannot '
                  'fire; use the standalone-subshell form' % where)
            errors += 1
        elif not HAS_EXIT.search(text):
            if ALWAYS_TRUE.match(last_command(body)):
                print('%s: ERROR no-failure-path: no set -e, no exit, and '
                      'an always-true final command — this probe cannot '
                      'fail' % where)
                errors += 1
            else:
                print('%s: WARN tail-status-only: only the final command '
                      'of the body decides this probe; earlier failures '
                      'are masked' % where)
                warnings += 1

print('harness-lint: %d error(s), %d warning(s) across %d file(s)'
      % (errors, warnings, len(sys.argv) - 1))
sys.exit(1 if errors else 0)
PY
