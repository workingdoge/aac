#!/usr/bin/env bash
set -u

# Worker lanes: reserve candidate numbers under the git common dir and use
# isolated worktrees. Landing remains delegated to tools/loop in the primary
# worktree; this wrapper only serializes and transplants candidate records.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$TOOLS_DIR/.." rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$ROOT" ]] || { printf 'lane: not inside a git worktree\n' >&2; exit 1; }

POLICY_FILE="$TOOLS_DIR/schemas/lane-policy.tsv"
LANES_DIR=""
RESERVATIONS=""
RESERVE_LOCK=""
LAND_LOCK=""
HELD_LOCK=""
LANE_QUEUE_MOVED_EXIT=66

die() {
  printf 'lane: %s\n' "$*" >&2
  exit 1
}

die_code() {
  local code="$1"
  shift
  printf 'lane: %s\n' "$*" >&2
  exit "$code"
}

usage() {
  printf 'usage: lane open SLUG | lane land ID | lane status | lane release ID\n' >&2
  exit 64
}

cleanup_lock() {
  local lock
  for lock in "$HELD_LOCK" "$RESERVE_LOCK" "$LAND_LOCK"; do
    [[ -n "${lock:-}" && -d "$lock" ]] || continue
    if [[ ! -f "$lock/pid" || "$(cat "$lock/pid" 2>/dev/null)" == "$$" ]]; then
      rm -rf "$lock"
    fi
  done
}
trap cleanup_lock EXIT INT TERM

load_policy() {
  local line_no=0 key="" value="" note="" extra="" seen_ttl="" seen_initial="" seen_max="" seen_mult=""
  POLICY_LOCK_TTL_SECONDS=""
  POLICY_LOCK_RETRY_INITIAL_MS=""
  POLICY_LOCK_RETRY_MAX_MS=""
  POLICY_LOCK_RETRY_MULTIPLIER=""
  [[ -f "$POLICY_FILE" ]] || die "lane policy missing: $POLICY_FILE"

  while IFS=$'\t' read -r key value note extra || [[ -n "$key$value$note$extra" ]]; do
    line_no=$((line_no + 1))
    [[ -z "$key$value$note$extra" ]] && continue
    [[ "$key" == \#* ]] && continue
    if [[ -z "$key" || -z "$value" || -z "$note" || -n "${extra:-}" ]]; then
      die "malformed lane policy row $line_no: expected key<TAB>value<TAB>note"
    fi
    case "$key" in
      *[!a-z0-9_]*)
        die "malformed lane policy row $line_no: bad key: $key"
        ;;
      lock_ttl_seconds)
        [[ -z "$seen_ttl" ]] || die "duplicate lane policy key: $key"
        seen_ttl=1; POLICY_LOCK_TTL_SECONDS="$value"
        ;;
      lock_retry_initial_ms)
        [[ -z "$seen_initial" ]] || die "duplicate lane policy key: $key"
        seen_initial=1; POLICY_LOCK_RETRY_INITIAL_MS="$value"
        ;;
      lock_retry_max_ms)
        [[ -z "$seen_max" ]] || die "duplicate lane policy key: $key"
        seen_max=1; POLICY_LOCK_RETRY_MAX_MS="$value"
        ;;
      lock_retry_multiplier)
        [[ -z "$seen_mult" ]] || die "duplicate lane policy key: $key"
        seen_mult=1; POLICY_LOCK_RETRY_MULTIPLIER="$value"
        ;;
      *)
        :
        ;;
    esac
  done < "$POLICY_FILE"

  for value in "$POLICY_LOCK_TTL_SECONDS" "$POLICY_LOCK_RETRY_INITIAL_MS" "$POLICY_LOCK_RETRY_MAX_MS" "$POLICY_LOCK_RETRY_MULTIPLIER"; do
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "lane policy requires positive integer values for TTL and backoff"
  done
  [[ "$POLICY_LOCK_RETRY_INITIAL_MS" -le "$POLICY_LOCK_RETRY_MAX_MS" ]] \
    || die "lane policy retry initial exceeds retry max"
}

init_paths() {
  local common
  common="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)" \
    || die "could not resolve git common dir"
  case "$common" in
    /*) ;;
    *) common="$ROOT/$common" ;;
  esac
  common="$(cd "$common" && pwd)" || die "could not enter git common dir"
  LANES_DIR="$common/boat-lanes"
  RESERVATIONS="$LANES_DIR/reservations.tsv"
  RESERVE_LOCK="$LANES_DIR/lock.d"
  LAND_LOCK="$LANES_DIR/land.lock.d"
  mkdir -p "$LANES_DIR" || die "could not create lane state dir: $LANES_DIR"
}

now_epoch() {
  date +%s
}

pid_alive() {
  local pid="${1:-}"
  case "$pid" in
    ""|*[!0-9]*) return 1 ;;
  esac
  kill -0 "$pid" 2>/dev/null
}

mtime_epoch() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || printf '0'
}

lock_created_epoch() {
  local lock="$1" created=""
  if [[ -f "$lock/created_at_epoch" ]]; then
    created="$(cat "$lock/created_at_epoch" 2>/dev/null || true)"
  fi
  if [[ "$created" =~ ^[0-9]+$ ]]; then
    printf '%s' "$created"
  else
    mtime_epoch "$lock"
  fi
}

maybe_reclaim_stale_lock() {
  local lock="$1" name="$2" pid="" created="" age="" now=""
  [[ -d "$lock" ]] || return 0
  pid="$(cat "$lock/pid" 2>/dev/null || true)"
  created="$(lock_created_epoch "$lock")"
  now="$(now_epoch)"
  age=$((now - created))
  if [[ "$age" -ge "$POLICY_LOCK_TTL_SECONDS" ]] && ! pid_alive "$pid"; then
    printf 'lane: reclaiming stale %s lock %s (pid=%s dead, age=%ss, ttl=%ss)\n' \
      "$name" "$lock" "${pid:-unknown}" "$age" "$POLICY_LOCK_TTL_SECONDS" >&2
    rm -rf "$lock"
  fi
}

sleep_backoff() {
  local ms="$1" seconds
  seconds="$(awk -v ms="$ms" 'BEGIN { printf "%.3f", ms / 1000 }')"
  sleep "$seconds"
}

next_delay() {
  local delay="$1" next
  next=$((delay * POLICY_LOCK_RETRY_MULTIPLIER))
  if [[ "$next" -gt "$POLICY_LOCK_RETRY_MAX_MS" ]]; then
    next="$POLICY_LOCK_RETRY_MAX_MS"
  fi
  printf '%s' "$next"
}

acquire_lock() {
  local lock="$1" name="$2" delay="$POLICY_LOCK_RETRY_INITIAL_MS"
  while true; do
    if mkdir "$lock" 2>/dev/null; then
      printf '%s\n' "$$" > "$lock/pid"
      printf '%s\n' "$(now_epoch)" > "$lock/created_at_epoch"
      printf '%s\n' "$ROOT" > "$lock/root"
      HELD_LOCK="$lock"
      return 0
    fi
    maybe_reclaim_stale_lock "$lock" "$name"
    sleep_backoff "$delay"
    delay="$(next_delay "$delay")"
  done
}

release_lock() {
  local lock="$1"
  if [[ -d "$lock" && "$(cat "$lock/pid" 2>/dev/null || true)" == "$$" ]]; then
    rm -rf "$lock"
  fi
  if [[ "${HELD_LOCK:-}" == "$lock" ]]; then
    HELD_LOCK=""
  fi
}

require_slug() {
  local slug="${1:-}"
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] \
    || die "slug must match [a-z0-9][a-z0-9-]*"
}

id_number() {
  local id="$1" rest
  [[ "$id" =~ ^cand-[0-9][0-9][0-9][0-9]-[a-z0-9][a-z0-9-]*$ ]] \
    || die "candidate id must look like cand-NNNN-slug: $id"
  rest="${id#cand-}"
  printf '%s' "${rest%%-*}"
}

id_slug() {
  local id="$1" rest
  rest="${id#cand-}"
  rest="${rest#*-}"
  printf '%s' "$rest"
}

reservation_row_valid_or_die() {
  local number="$1" slug="$2" wt="$3" ts="$4" pid="$5" extra="${6:-}"
  [[ -z "$extra" ]] || die "malformed reservation row: too many columns"
  [[ "$number" =~ ^[0-9][0-9][0-9][0-9]$ ]] || die "malformed reservation number: $number"
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "malformed reservation slug: $slug"
  [[ -n "$wt" ]] || die "malformed reservation worktree path for cand-$number-$slug"
  [[ "$ts" =~ ^[0-9]+$ ]] || die "malformed reservation timestamp for cand-$number-$slug"
  [[ "$pid" =~ ^[0-9]+$ ]] || die "malformed reservation pid for cand-$number-$slug"
}

max_existing_number() {
  local max=0 dir base rest number n slug wt ts pid extra
  for dir in "$ROOT"/candidates/cand-[0-9][0-9][0-9][0-9]-*; do
    [[ -d "$dir" ]] || continue
    base="$(basename "$dir")"
    rest="${base#cand-}"
    number="${rest%%-*}"
    n=$((10#$number))
    [[ "$n" -gt "$max" ]] && max="$n"
  done
  if [[ -f "$RESERVATIONS" ]]; then
    while IFS=$'\t' read -r number slug wt ts pid extra || [[ -n "$number$slug$wt$ts$pid$extra" ]]; do
      [[ -z "$number$slug$wt$ts$pid$extra" ]] && continue
      [[ "$number" == \#* ]] && continue
      reservation_row_valid_or_die "$number" "$slug" "$wt" "$ts" "$pid" "${extra:-}"
      n=$((10#$number))
      [[ "$n" -gt "$max" ]] && max="$n"
    done < "$RESERVATIONS"
  fi
  printf '%s' "$max"
}

find_reservation() {
  local id="$1" want_number want_slug number slug wt ts pid extra found=0
  want_number="$(id_number "$id")"
  want_slug="$(id_slug "$id")"
  [[ -f "$RESERVATIONS" ]] || return 1
  while IFS=$'\t' read -r number slug wt ts pid extra || [[ -n "$number$slug$wt$ts$pid$extra" ]]; do
    [[ -z "$number$slug$wt$ts$pid$extra" ]] && continue
    [[ "$number" == \#* ]] && continue
    reservation_row_valid_or_die "$number" "$slug" "$wt" "$ts" "$pid" "${extra:-}"
    if [[ "$number" == "$want_number" && "$slug" == "$want_slug" ]]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$number" "$slug" "$wt" "$ts" "$pid"
      found=$((found + 1))
    fi
  done < "$RESERVATIONS"
  [[ "$found" -eq 1 ]] || return 1
}

drop_reservation_locked() {
  local id="$1" want_number want_slug tmp number slug wt ts pid extra dropped=0
  want_number="$(id_number "$id")"
  want_slug="$(id_slug "$id")"
  tmp="$RESERVATIONS.tmp.$$"
  : > "$tmp"
  if [[ -f "$RESERVATIONS" ]]; then
    while IFS=$'\t' read -r number slug wt ts pid extra || [[ -n "$number$slug$wt$ts$pid$extra" ]]; do
      [[ -z "$number$slug$wt$ts$pid$extra" ]] && continue
      if [[ "$number" == \#* ]]; then
        printf '%s\t%s\t%s\t%s\t%s\n' "$number" "$slug" "$wt" "$ts" "$pid" >> "$tmp"
        continue
      fi
      reservation_row_valid_or_die "$number" "$slug" "$wt" "$ts" "$pid" "${extra:-}"
      if [[ "$number" == "$want_number" && "$slug" == "$want_slug" ]]; then
        dropped=$((dropped + 1))
        continue
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$number" "$slug" "$wt" "$ts" "$pid" >> "$tmp"
    done < "$RESERVATIONS"
  fi
  [[ "$dropped" -eq 1 ]] || { rm -f "$tmp"; die "no live reservation for $id"; }
  mv "$tmp" "$RESERVATIONS" || die "could not update reservations"
}

reserve_next() {
  local slug="$1" max next number id wt
  acquire_lock "$RESERVE_LOCK" "reservation"
  max="$(max_existing_number)"
  next=$((max + 1))
  number="$(printf '%04d' "$next")"
  id="cand-$number-$slug"
  wt="$LANES_DIR/wt-$id"
  printf '%s\t%s\t%s\t%s\t%s\n' "$number" "$slug" "$wt" "$(now_epoch)" "$$" >> "$RESERVATIONS" \
    || die "could not append reservation"
  release_lock "$RESERVE_LOCK"
  printf '%s\t%s\n' "$id" "$wt"
}

safe_remove_worktree() {
  local wt="$1"
  case "$wt" in
    "$LANES_DIR"/wt-cand-[0-9][0-9][0-9][0-9]-*) ;;
    *) die "refusing to remove worktree outside lane state dir: $wt" ;;
  esac
  if [[ -e "$wt" ]]; then
    git -C "$ROOT" worktree remove --force --force "$wt" >/dev/null 2>&1 || rm -rf "$wt"
  fi
  git -C "$ROOT" worktree prune >/dev/null 2>&1 || true
}

transplant_candidate_dir() {
  local src="$1" dest="$2" tmp
  [[ -d "$src" ]] || die "reserved worktree has no candidate dir: $src"
  tmp="$dest.lane-transplant.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp" "$(dirname "$dest")" || die "could not prepare transplant"
  ( cd "$src" && tar -cf - . ) | ( cd "$tmp" && tar -xf - ) \
    || { rm -rf "$tmp"; die "candidate transplant failed for $src"; }
  rm -rf "$dest"
  mv "$tmp" "$dest" || die "could not install transplanted candidate: $dest"
}

candidate_has_legacy_queue_file_row() {
  local cand="$1" src="" dest="" kind=""
  [[ -f "$cand/LANDING" ]] || return 1
  while read -r src dest kind; do
    [[ -n "$src" && "$src" != \#* ]] || continue
    kind="${kind:-file}"
    dest="${dest#./}"
    [[ "$dest" == "candidates/QUEUE.md" && "$kind" == "file" ]] && return 0
  done < "$cand/LANDING"
  return 1
}

guard_legacy_queue_file_landing() {
  local wt="$1" id="$2" cand="$wt/candidates/$id" wt_head="" base_commit="" base_queue=""
  candidate_has_legacy_queue_file_row "$cand" || return 0
  [[ -f "$ROOT/candidates/QUEUE.md" ]] \
    || die "primary candidates/QUEUE.md missing for legacy queue-file landing guard"
  wt_head="$(git -C "$wt" rev-parse HEAD 2>/dev/null)" \
    || die "could not resolve lane worktree HEAD for $id"
  base_commit="$(git -C "$ROOT" merge-base HEAD "$wt_head" 2>/dev/null)" \
    || die "could not determine primary/lane merge-base for $id"
  base_queue="$(mktemp "${TMPDIR:-/tmp}/lane-queue-base.XXXXXX")" \
    || die "could not create queue-base comparison temp file"
  if ! git -C "$wt" show "$base_commit:candidates/QUEUE.md" > "$base_queue" 2>/dev/null; then
    rm -f "$base_queue"
    die "could not read base candidates/QUEUE.md for $id at $base_commit"
  fi
  if ! cmp -s "$ROOT/candidates/QUEUE.md" "$base_queue"; then
    rm -f "$base_queue"
    die_code "$LANE_QUEUE_MOVED_EXIT" \
      "land refused: first-dogfood incident class: legacy file-kind QUEUE row when the primary queue moved; fix procedure: convert the row to kind=queue-merge (capture QUEUE.base + re-brief)"
  fi
  rm -f "$base_queue"
}

cmd_open() {
  local slug="${1:-}" row id wt
  [[ -n "$slug" ]] || usage
  require_slug "$slug"
  row="$(reserve_next "$slug")"
  id="$(printf '%s\n' "$row" | awk -F'\t' 'NR == 1 { print $1 }')"
  wt="$(printf '%s\n' "$row" | awk -F'\t' 'NR == 1 { print $2 }')"
  if ! git -C "$ROOT" worktree add --detach "$wt" HEAD; then
    acquire_lock "$RESERVE_LOCK" "reservation"
    drop_reservation_locked "$id"
    release_lock "$RESERVE_LOCK"
    die "git worktree add failed for $id"
  fi
  printf 'id\t%s\n' "$id"
  printf 'worktree\t%s\n' "$wt"
}

cmd_land() {
  local id="${1:-}" row number slug wt ts pid wt_root
  [[ -n "$id" ]] || usage
  id_number "$id" >/dev/null
  acquire_lock "$LAND_LOCK" "land"
  row="$(find_reservation "$id")" || die "land refused: no live reservation for $id"
  IFS=$'\t' read -r number slug wt ts pid <<EOF
$row
EOF
  wt_root="$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$wt_root" ]] || die "reserved worktree is not available for $id: $wt"
  [[ "$(cd "$ROOT" && pwd)" != "$(cd "$wt_root" && pwd)" ]] \
    || die "land must run from the primary worktree, not the reserved lane worktree"
  [[ ! -f "$ROOT/candidates/$id/LANDED" ]] \
    || die "land refused: $id is already landed in the primary worktree"
  guard_legacy_queue_file_landing "$wt" "$id"

  transplant_candidate_dir "$wt/candidates/$id" "$ROOT/candidates/$id"

  ( cd "$ROOT" && bash tools/loop validate "$id" ) || exit $?
  # tools/loop land performs the brief freshness check; lane land must not
  # regenerate or bypass that decision binding.
  ( cd "$ROOT" && bash tools/loop land "$id" ) || exit $?

  safe_remove_worktree "$wt"
  acquire_lock "$RESERVE_LOCK" "reservation"
  drop_reservation_locked "$id"
  release_lock "$RESERVE_LOCK"
  release_lock "$LAND_LOCK"
  printf 'lane: landed %s; reservation released; worktree removed: %s\n' "$id" "$wt"
}

cmd_release() {
  local id="${1:-}" row number slug wt ts pid
  [[ -n "$id" ]] || usage
  id_number "$id" >/dev/null
  if [[ -f "$ROOT/candidates/$id/LANDED" ]] \
    || grep -q '^status: landed$' "$ROOT/candidates/$id/META" 2>/dev/null; then
    die "release refused: $id is landed"
  fi
  acquire_lock "$RESERVE_LOCK" "reservation"
  row="$(find_reservation "$id")" || die "release refused: no live reservation for $id"
  IFS=$'\t' read -r number slug wt ts pid <<EOF
$row
EOF
  safe_remove_worktree "$wt"
  drop_reservation_locked "$id"
  release_lock "$RESERVE_LOCK"
  printf 'lane: released %s; worktree removed: %s\n' "$id" "$wt"
}

print_lock_status() {
  local label="$1" lock="$2" pid="" created="" age="" live="absent"
  if [[ ! -d "$lock" ]]; then
    printf '%s\tabsent\n' "$label"
    return 0
  fi
  pid="$(cat "$lock/pid" 2>/dev/null || true)"
  created="$(lock_created_epoch "$lock")"
  age=$(($(now_epoch) - created))
  if pid_alive "$pid"; then live="live"; else live="dead"; fi
  printf '%s\tpid=%s\tage=%ss\tliveness=%s\tpath=%s\n' "$label" "${pid:-unknown}" "$age" "$live" "$lock"
}

cmd_status() {
  local number slug wt ts pid extra age live
  printf 'lane-state\t%s\n' "$LANES_DIR"
  printf 'reservations\n'
  if [[ -f "$RESERVATIONS" ]]; then
    while IFS=$'\t' read -r number slug wt ts pid extra || [[ -n "$number$slug$wt$ts$pid$extra" ]]; do
      [[ -z "$number$slug$wt$ts$pid$extra" ]] && continue
      [[ "$number" == \#* ]] && continue
      reservation_row_valid_or_die "$number" "$slug" "$wt" "$ts" "$pid" "${extra:-}"
      age=$(($(now_epoch) - ts))
      if pid_alive "$pid"; then live="live"; else live="dead"; fi
      printf 'reservation\tcand-%s-%s\tage=%ss\tpid=%s\tliveness=%s\tworktree=%s\n' \
        "$number" "$slug" "$age" "$pid" "$live" "$wt"
    done < "$RESERVATIONS"
  fi
  printf 'worktrees\n'
  git -C "$ROOT" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree / { sub(/^worktree /, ""); print "worktree\t" $0 }'
  printf 'locks\n'
  print_lock_status reservation-lock "$RESERVE_LOCK"
  print_lock_status land-lock "$LAND_LOCK"
}

main() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || usage
  shift || true
  load_policy
  init_paths
  case "$cmd" in
    open) cmd_open "$@" ;;
    land) cmd_land "$@" ;;
    status) [[ "$#" -eq 0 ]] || usage; cmd_status ;;
    release) cmd_release "$@" ;;
    *) usage ;;
  esac
}

main "$@"
