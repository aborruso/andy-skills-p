#!/usr/bin/env bash
# linkedin-read.sh — read one LinkedIn post together with its comment thread,
# using the authenticated session of a dedicated agent-browser profile, and save
# a structured text file into <output-dir> (default /tmp):
#   /tmp/YYYY-MM-DD_<slug_snake_case>.txt
#
# Usage: linkedin-read.sh [--no-links] <linkedin-post-url|lnkd.in-url> [output-dir]
#        By default it follows the links found in the post body (max 3) and appends
#        their content in a LINKED SOURCES section (requires `trafilatura`).
#        --no-links skips that step and never leaves LinkedIn.
#
# Guardrails (see docs/adr/0001): ONE post per invocation, no batching, no
# scheduling. The date in the file name is the date of the run.
#
# Required: agent-browser, jq, curl, bash.
# Optional: llm (content-aware slug), trafilatura (linked sources), timeout
#           (caps those two steps; without it they run unbounded).
#
# Exit codes:
#   0 ok (file path on stdout, everything else on stderr)
#   1 bad usage / unrecognised URL / write failure
#   2 dedicated profile missing (one-off headed setup needed)
#   3 LinkedIn session expired (headed re-login needed)
#   4 post unreachable or not visible to the account
#   5 internal timeout

set -u

# Links in the post body are followed by default; --no-links skips them.
FOLLOW_LINKS=1
ARGS=""
for a in "$@"; do
  case "$a" in
    --no-links) FOLLOW_LINKS=0 ;;
    --links) : ;;  # accepted and ignored: this is the default behaviour
    *) ARGS="$ARGS $a" ;;
  esac
done
# shellcheck disable=SC2086
set -- $ARGS
URL="${1:-}"
OUTDIR="${2:-/tmp}"
# How many post-body links to follow, and how long to wait on each one.
MAX_LINKS=3
LINK_TIMEOUT=45
SESSION="linkedin"
PROFILE="$HOME/.agent-browser-profiles/linkedin"
AB="agent-browser"
EXTRACT="$(cd "$(dirname "$0")" && pwd)/extract.js"
MAX_SECONDS=240
# Tall viewport: the comment list is virtualised, and with a standard viewport
# LinkedIn only renders a handful of them (measured: 4 out of 11).
VP_W=1400
VP_H=3000

log() { printf '%s\n' "$*" >&2; }
die() { local c="$1"; shift; log "ERROR: $*"; exit "$c"; }
budget() { [ "$SECONDS" -ge "$MAX_SECONDS" ] && die 5 "internal timeout (${MAX_SECONDS}s)"; }
ncomm() { $AB --session "$SESSION" eval 'document.querySelectorAll("article.comments-comment-entity").length' 2>/dev/null | tr -dc '0-9'; }

# `timeout` is GNU coreutils and is missing on a stock macOS. Without it the two
# optional steps still run, just unbounded — that beats skipping them silently.
if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"; else TIMEOUT_BIN=""; fi
run_limited() {  # run_limited <seconds> <command...>
  if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" "$@"; else shift; "$@"; fi
}

[ -n "$URL" ] || die 1 "usage: $0 [--no-links] <linkedin-post-url> [output-dir]"
[ -r "$EXTRACT" ] || die 1 "extractor missing: $EXTRACT"
command -v jq >/dev/null 2>&1 || die 1 "jq is required"
command -v curl >/dev/null 2>&1 || die 1 "curl is required"
command -v "$AB" >/dev/null 2>&1 || die 1 "agent-browser is required (npm i -g agent-browser)"

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36'

# lnkd.in links come in two shapes: `lnkd.in/p/xxx` (a shared post) answers with a
# 3xx redirect, while `lnkd.in/xxx` (a link inside a post body) answers 200 with an
# interstitial page carrying the destination in the body. Both must be handled.
resolve_short() {
  _u="$1"
  _r="$(curl -s -o /dev/null -w '%{redirect_url}' -A "$UA" "$_u" 2>/dev/null)"
  if [ -z "$_r" ]; then
    _r="$(curl -sL -A "$UA" "$_u" 2>/dev/null \
      | grep -oE 'https?://[^"'"'"'<> ]{12,300}' \
      | grep -vE 'licdn\.com|linkedin\.com|lnkd\.in|w3\.org|schema\.org' \
      | head -n 1)"
  fi
  printf '%s' "$_r"
}

# --- lnkd.in short link -> post URL
case "$URL" in
  https://lnkd.in/*)
    RESOLVED="$(resolve_short "$URL")"
    [ -n "$RESOLVED" ] || die 1 "short link could not be resolved: $URL"
    log "short link resolved: $RESOLVED"
    URL="$RESOLVED" ;;
esac
case "$URL" in
  https://www.linkedin.com/posts/*|https://linkedin.com/posts/*|https://www.linkedin.com/feed/update/*) : ;;
  *) die 1 "unrecognised URL: expected a post https://(www.)linkedin.com/posts/... (or an lnkd.in pointing to one)" ;;
esac
[ -d "$PROFILE" ] || die 2 "dedicated profile missing ($PROFILE). One-off headed setup:
  $AB --session $SESSION close
  $AB open 'https://www.linkedin.com/login' --headed --session $SESSION --profile $PROFILE
Log in by hand in the window that opens, then re-run this command.
A headed browser needs a display: on a Linux desktop, macOS or Windows this works
as is; on WSL2 without WSLg, point DISPLAY at your own X server first, e.g.
  export DISPLAY=\$(ip route | grep default | awk '{print \$3; exit}'):0.0"
mkdir -p "$OUTDIR" || die 1 "output-dir cannot be created: $OUTDIR"

# --- open on the dedicated session (never `close --all`: other agent browsers stay up)
$AB --session "$SESSION" close >/dev/null 2>&1 || true
# Retries with a growing pause: on a cold start the browser is not yet accepting
# connections, and right after the close the previous one may not have released
# the profile. Both surface as "Could not configure browser: Failed to connect"
# and both clear on their own — a single retry after 3s proved too short.
OPENERR=""
OPENED=0
for pause in 0 3 8; do
  [ "$pause" -gt 0 ] && sleep "$pause"
  budget
  if OPENERR="$($AB --session "$SESSION" --profile "$PROFILE" open "$URL" 2>&1)"; then
    OPENED=1
    break
  fi
done
[ "$OPENED" = "1" ] || die 4 "could not open: $URL
The browser did not start, or the post is not reachable. agent-browser said:
${OPENERR:-(no output)}"
$AB --session "$SESSION" set viewport "$VP_W" "$VP_H" >/dev/null 2>&1 || true
$AB --session "$SESSION" reload >/dev/null 2>&1 || true
sleep 4
budget

# --- session / post state
BODY="$($AB --session "$SESSION" get text 'body' 2>/dev/null || true)"
case "$BODY" in
  *"Sign in to view more content"*|*"Accedi per visualizzare più contenuti"*)
    die 3 "LinkedIn session expired. One-off headed re-login:
  $AB --session $SESSION close
  $AB open 'https://www.linkedin.com/login' --headed --session $SESSION --profile $PROFILE
(once you are in, re-run this command)
On WSL2 without WSLg, export DISPLAY to your X server first." ;;
esac
case "$BODY" in
  *"page isn’t available"*|*"page isn't available"*|*"pagina non è disponibile"*)
    die 4 "post not available, or not visible to this account" ;;
esac

# --- progressive loading: scroll until the comment count stops growing
# NB: the default sort order ("Most relevant") is kept. Switching to "Most recent"
# is not needed: verified on a post with 14 comments that both orders serve the
# same comments, same ids — only the order differs.
prev=-1
for round in 1 2 3 4 5 6 7 8; do
  budget
  $AB --session "$SESSION" scroll down 2500 >/dev/null 2>&1 || true
  sleep 2
  cur="$(ncomm)"; cur="${cur:-0}"
  [ "$cur" = "$prev" ] && [ "$round" -ge 3 ] && break
  prev="$cur"
done

# --- expansion: nested replies, more comments, truncated bodies ("…more")
for round in 1 2 3 4 5; do
  budget
  clicked="$($AB --session "$SESSION" eval '(() => {
    // First by class (language independent): the "…more" toggles of the post and
    // of the comments. Then by label, for the buttons that carry no class of
    // their own: "See previous replies", "Load more comments".
    const byClass = [...document.querySelectorAll(
      ".feed-shared-inline-show-more-text__see-more-less-toggle,"
      + " .comments-comment-item__inline-show-more-text button,"
      + " .update-components-text button")];
    const want = /^(see previous replies|see previous reply|load more comments|show more comments|see more|…\s*more|more|vedi risposte precedenti|vedi risposta precedente|carica altri commenti|visualizza altri commenti|mostra altri commenti|…\s*altro|vedi altro)$/i;
    const byLabel = [...document.querySelectorAll("button,[role=button]")]
      .filter(b => want.test((b.innerText || "").replace(/\s+/g, " ").trim()));
    const els = [...new Set([...byClass, ...byLabel])];
    els.forEach(b => { try { b.click(); } catch (e) {} });
    return els.length;
  })()' 2>/dev/null | tr -dc '0-9')"
  [ "${clicked:-0}" = "0" ] && break
  sleep 3
  $AB --session "$SESSION" scroll down 1500 >/dev/null 2>&1 || true
done
sleep 1
budget

# --- structured extraction from the DOM (stable hooks, not the hashed classes)
JSON="$($AB --session "$SESSION" eval --stdin < "$EXTRACT" 2>/dev/null | jq -r . 2>/dev/null)"
$AB --session "$SESSION" close >/dev/null 2>&1 || true
printf '%s' "$JSON" | jq -e . >/dev/null 2>&1 \
  || die 1 "extraction failed (page structure changed?)"
POSTTEXT="$(printf '%s' "$JSON" | jq -r '.postText')"
# On failure the hook counts are printed: all zeros means the page structure has
# changed (and shows which selector died); populated counts mean the problem is
# somewhere else.
HOOKS="$(printf '%s' "$JSON" | jq -r '.hooks // {} | to_entries | map("\(.key)=\(.value)") | join(" ")')"
[ -n "$POSTTEXT" ] && [ "$POSTTEXT" != "null" ] \
  || die 4 "post text not found (hooks: ${HOOKS:-none})"

NC="$(printf '%s' "$JSON" | jq -r '.comments | length')"
ND="$(printf '%s' "$JSON" | jq -r '.declaredComments // "" | tostring')"

# --- structured text file
TMP="$OUTDIR/.linkedin_read_$$.txt"
{
  printf 'URL: %s\n' "$URL"
  printf 'Extracted at: %s\n' "$(date '+%F %R')"
  printf 'Comments: %s extracted' "$NC"
  [ -n "$ND" ] && [ "$ND" != "null" ] && [ "$ND" != "$NC" ] \
    && printf ' / %s declared by the LinkedIn counter' "$ND"
  printf '\nComment order: LinkedIn default (Most relevant)\n'
  printf '============================================================\nPOST\n============================================================\n'
  printf '%s' "$JSON" | jq -r '
    [.postAuthor, .postHeadline, .postTime] | map(select(. != null and . != "")) | .[]'
  printf '\n'
  printf '%s\n' "$POSTTEXT"
  printf '\n============================================================\nCOMMENTS (%s)\n============================================================\n' "$NC"
  printf '%s' "$JSON" | jq -r '.comments | to_entries[] |
    "[\(.key + 1)] \(.value.author)"
    + (if .value.reply then "  (reply)" else "" end)
    + (if .value.time   != "" then "  — \(.value.time)"   else "" end)
    + (if .value.headline != "" then "\n    \(.value.headline)" else "" end)
    + (if .value.reactions != "" then "\n    (\(.value.reactions))" else "" end)
    + "\n\(.value.text)\n"'
} > "$TMP" || { rm -f "$TMP"; die 1 "write failed"; }
[ -s "$TMP" ] || die 1 "nothing extracted"

# --- file name: YYYY-MM-DD_<slug>.txt
# Slug via the `llm` CLI; fallback: first substantial line of the post text.
# Whatever llm answers, the sanitising below is deterministic.
# iconv //TRANSLIT is a glibc extension and fails on macOS: when it does, the raw
# text is used instead (accents just become word separators) rather than letting
# the whole pipeline come out empty.
sanitize() {
  _s="$(cat)"
  _t="$(printf '%s' "$_s" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null)"
  [ -n "$_t" ] || _t="$_s"
  printf '%s' "$_t" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs 'a-z0-9' '\n' | grep -v '^$' | head -n 8 | paste -sd _ -
}
slug=""
if command -v llm >/dev/null 2>&1; then
  budget
  llm_slug="$(head -c 3000 "$TMP" | run_limited 60 llm 'This is an extracted LinkedIn post (header, post text, comments). Summarise it as ONE snake_case slug for a file name: at most 8 words, lowercase ASCII letters and digits separated by underscores, content keywords in the original language of the post, no date, no prefix such as "linkedin_". Answer with the slug ONLY, no explanation, no quotes or backticks.' 2>/dev/null || true)"
  slug="$(printf '%s' "$llm_slug" | tr -d '\140\047\042' | head -n 1 | sanitize)"
  [ -n "$slug" ] && log "slug: from llm"
fi
if [ -z "$slug" ]; then
  slug="$(printf '%s' "$POSTTEXT" | tr -d '\r' | awk 'length($0)>25 {print; exit}' | sanitize)"
  [ -n "$slug" ] && log "slug: fallback from post text"
fi
[ -n "$slug" ] || { slug="linkedin_post"; log "slug: generic"; }
slug="$(printf '%s' "$slug" | cut -c1-64)"
OUT="$OUTDIR/$(date +%F)_${slug}.txt"
n=1
while [ -e "$OUT" ]; do
  n=$((n+1))
  OUT="$OUTDIR/$(date +%F)_${slug}_${n}.txt"
done
mv "$TMP" "$OUT" || die 1 "write failed: $OUT"

# --- links found in the post body (skipped with --no-links)
if [ "$FOLLOW_LINKS" = "1" ]; then
  if ! command -v trafilatura >/dev/null 2>&1; then
    log "post links not followed: trafilatura is not installed"
  else
    LINKS="$(printf '%s\n' "$POSTTEXT" | grep -oE 'https?://[^ ]+' \
      | sed 's/[),.]*$//' | grep -v 'linkedin\.com' | awk '!seen[$0]++' | head -n "$MAX_LINKS")"
    if [ -n "$LINKS" ]; then
      { printf '\n============================================================\nLINKED SOURCES\n============================================================\n'; } >> "$OUT"
      printf '%s\n' "$LINKS" | while IFS= read -r l; do
        [ -n "$l" ] || continue
        target="$l"
        case "$l" in https://lnkd.in/*) target="$(resolve_short "$l")"; [ -n "$target" ] || target="$l" ;; esac
        body="$(run_limited "$LINK_TIMEOUT" trafilatura -u "$target" 2>/dev/null)"
        {
          printf '\n--- %s\n' "$target"
          [ "$target" != "$l" ] && printf '(in the post: %s)\n' "$l"
          if [ -n "$body" ]; then printf '%s\n' "$body"; else printf '[content not extracted]\n'; fi
        } >> "$OUT"
        log "link followed: $target"
      done
    else
      log "no external link in the post text"
    fi
  fi
fi

if [ -n "$ND" ] && [ "$ND" != "null" ] && [ "$ND" != "$NC" ]; then
  log "comments: $NC extracted (the LinkedIn counter declares $ND) | file: $OUT"
else
  log "comments: $NC | file: $OUT"
fi
printf '%s\n' "$OUT"
