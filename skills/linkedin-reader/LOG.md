# LOG

## 2026-09-05 - install docs and the first-login path

- The install instructions now lead with `npx skills add aborruso/andy-skills-p`
  (`--skill linkedin-reader` for this one alone, `-g` for user level, `--list` to
  look first), taken from the CLI's own help: `owner/repo/skill` as a path is not
  a form it accepts. They also say which wizard answers to give - global scope
  and symlink, so the skills work in every project and follow the repo on
  `npx skills update` instead of freezing as a copy.
- Claude Code is now one example among the clients, not the assumed one, and the
  root README says up front that this skill needs a manual login before its
  first read - until now that only surfaced as exit 2.
- The exit-2 message told the user to run `close --all`, contradicting the
  guarantee that other agent browsers are left alone; it now closes only the
  `linkedin` session, like the exit-3 message already did.
- SKILL.md says who runs the headed command: the agent launches it, then stops
  and waits for the user to confirm the login before re-running the read.

## 2026-09-05 — cold start of the browser, exit 4 out of nowhere

- A run failed with exit 4 ("could not open") on a post that was perfectly
  reachable: the retry after the `close` waited 3 s and was too short for a cold
  start, when the browser is not yet accepting connections
  (`Could not configure browser: Failed to connect`). Both causes - profile not
  released after the close, and browser still starting - clear on their own, so
  the single retry became three attempts with a growing pause (0, 3, 8 s), each
  one under `budget` so a stuck launch surfaces as exit 5 instead of eating the
  240 s allowance.
- The `agent-browser` error was swallowed by `2>&1 >/dev/null`, so exit 4 said
  only "could not open" and its documented remedy ("check the URL by hand")
  pointed at the wrong suspect: the URL was blamed, first for its query string.
  The message now carries the actual `agent-browser` output, and the exit-4 row
  in SKILL.md names the launch failure.
- Verified with a stub `agent-browser` on PATH, since the real race is rare:
  failing twice then succeeding gets past the open, always failing exits 4 with
  the captured text. The URL with the `utm_source=...` query string that had
  failed reads fine (56 comments).

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
