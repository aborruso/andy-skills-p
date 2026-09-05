# LOG

## 2026-09-05 — published as a public skill

- Moved into the `andy-skills` repository, which becomes the source of truth; the
  local install is done from here.
- Translated to English (SKILL.md, README, script comments), keeping both Italian
  and English trigger phrases in the `description`: translating them away would
  stop the skill from firing on Italian prompts.
- Portability, two real defects found while generalising:
  `iconv -t ascii//TRANSLIT` in `sanitize()` is a glibc extension and fails on
  macOS; the error was swallowed by `2>/dev/null` and, since both the `llm` slug
  and the post-text fallback go through the same function, every file would have
  been named `YYYY-MM-DD_linkedin_post.txt`. Now the raw text is used when iconv
  fails. And `timeout`, missing on a stock macOS, was used for `llm` and
  `trafilatura` while only those two tools were guarded by `command -v`: the slug
  and the LINKED SOURCES section would have gone missing silently. Both steps now
  run unbounded when `timeout` is absent.
- English labels added next to the Italian ones for the expansion buttons that
  carry no class of their own ("See previous replies", "Load more comments"). Non
  Latin-alphabet UIs remain a documented limit rather than speculative code.
- The X410-specific setup instructions were replaced with neutral wording: a
  headed browser needs a display, and how you get one depends on the platform.
  No auto-detection across three platforms that cannot be tested here.

## 2026-09-05 — DOM hooks repaired

- Broken DOM hooks: LinkedIn stopped serving `data-testid` (zero across the whole
  page, verified headless and headed) and the `replaceableComment_urn:li:comment`
  ids. `extract.js` returned every field empty and `linkedin-read.sh` exited 4.
  The session was valid: the problem was not the login.
- Extractor rewritten on the Ember semantic classes: post from
  `.update-components-update-v2__commentary`, comments from
  `article.comments-comment-entity` identified by `data-id` (URN),
  author/headline/time/reactions each from its own selector instead of by line
  position.
- `ncomm()` used the same dead selector: it returned 0 and the scroll loop stopped
  at the third round. Fixed onto the extractor's selector.
- Long-text expansion by class instead of by localised label; labels remain only
  as a fallback for buttons with no class of their own.
- `die 4` prints the hook counts, so the next breakage is diagnosed in one run.
- Retry on open: two consecutive runs failed with "Could not configure browser"
  because the previous browser had not released the profile yet.
- Nested replies are now marked `(reply)` in the file: before they were
  indistinguishable from top-level comments.
- End-to-end verification on three posts: 19/19 comments (8 nested replies),
  17/18, 1/1. All exit 0, post text intact down to the last line.
- The gap of 1 on one of them is **unexplained**: on re-inspection the DOM had 18
  entities against 19 declared, none without text and none with only an image or
  a video. So it is not the already known "image-only comment" case: an entity is
  simply missing from the served DOM. The file header flags the gap regardless.
- Verified that the `die 4` diagnostic actually populates (on an arbitrary page:
  `hooks: entities=0 commentary=0 updateText=0 socialCounts=0`): the error path is
  never exercised by successful runs.
- Added reading of the links in the post body (max 3, 45s timeout each), appending
  a `LINKED SOURCES` section with the content extracted by `trafilatura`.
- Found while resolving one of those links: `lnkd.in` links come in two shapes.
  `lnkd.in/p/xxx` (a shared post) is a 3xx redirect, `lnkd.in/xxx` (a link in a
  post body) is a 200 interstitial page with the destination in the body. The old
  resolver used `%{redirect_url}` only and came back empty on the second kind;
  `resolve_short()` now covers both.
- `innerText` does not truncate URLs (no ellipsis in the extracted files, long
  query strings included): the text is enough, there is no need to read `href`
  attributes from the DOM.
- Following links became the **default** behaviour, with `--no-links` to disable
  it. Reason: as an opt-in flag, the agent decided case by case and it was not
  predictable whether the links would be read. `--links` is still accepted and
  ignored.
