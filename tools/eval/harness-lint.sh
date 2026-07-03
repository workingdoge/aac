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

for path in sys.argv[1:]:
    with open(path, encoding='utf-8', errors='replace') as fh:
        entries = logical_lines(fh.read().splitlines())
    lines = [text for _, text in entries]
    physno = [first for first, _ in entries]
    rev_vars = set()
    for i, line in enumerate(lines):
        if 'merge-base --is-ancestor' in line:
            continue
        m = ASSIGN.match(line)
        if m and is_live_rev_parse(line):
            rev_vars.add(m.group(1))
        if not EQUALITY.search(line):
            continue
        direct = is_live_rev_parse(line) and has_sha_pin(line)
        assigned = has_rev_var(line, rev_vars) and has_sha_pin(line)
        if direct or assigned:
            where = '%s:%d%s' % (path, physno[i] + 1, probe_name(lines, i))
            print('%s: ERROR worldly-assertion: live git rev-parse string '
                  'equality is not replay-stable; use git merge-base '
                  '--is-ancestor <pin> HEAD' % where)
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
