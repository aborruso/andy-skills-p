---
name: linkedin-reader
description: 'Reads a LinkedIn post together with its full comment thread, using the authenticated session of a dedicated agent-browser profile, and saves a structured text file named YYYY-MM-DD_slug_snake_case.txt. ALWAYS use this skill when the user passes a linkedin.com/posts/ URL or an lnkd.in short link and asks to read it, save it, archive it, or extract its text or its comments — even without saying "skill": for example "read me this post", "save the comments of...", "what does this LinkedIn thread say", "leggimi questo post", "salvami i commenti di...", "cosa dice questo thread LinkedIn". Do not use it for LinkedIn Learning, for profiles or for company pages (posts only).'
---

# LinkedIn post reader (with comments)

## Before anything else: the guardrails

LinkedIn's User Agreement forbids scraping and bots. This skill is for occasional
reads that the user explicitly asks for, on their own authenticated session, and
its constraints are structural, not stylistic: **one post per invocation, no
batching, no scheduling or cron**. Do not work around them "for convenience" —
see `docs/adr/0001-guardrail-single-post.md`. Whoever runs this is responsible
for the account they run it with.

## How it works

A deterministic bash script, `scripts/linkedin-read.sh`, does all the work: it
resolves `lnkd.in` short links, opens the post on the dedicated, already
authenticated browser session, sets a tall viewport, loads comments by
scrolling `<main>` (the page does not scroll on `window`), expands nested replies
and truncated bodies ("…more"), then extracts post and comments from the DOM with
`scripts/extract.js` and writes the file.

```bash
scripts/linkedin-read.sh '<post-url>'          # output in /tmp
scripts/linkedin-read.sh '<post-url>' <dir>
scripts/linkedin-read.sh 'https://lnkd.in/xxxx'
scripts/linkedin-read.sh --no-links '<post-url>'
```

Paths are relative to this skill directory; from anywhere else use the absolute
path, i.e. `linkedin-reader/scripts/linkedin-read.sh` under wherever the client
installed the skill (`~/.claude/skills/` for Claude Code, elsewhere for others).

**Links in the post body are followed by default**: at most 3, never the ones in
comments, with the content extracted by `trafilatura` and appended to a
`LINKED SOURCES` section at the end of the file, under the resolved URL. Each read
therefore makes a few requests outside LinkedIn and takes some tens of seconds
longer. `--no-links` skips that step. If `trafilatura` is not on the PATH the step
is skipped with a warning and the rest of the file comes out normally. There is
nothing to decide case by case: use `--no-links` only if the user asks not to
leave LinkedIn, or wants the fastest possible read.

Stdout carries **only** the path of the file that was created; operational
messages go to stderr. Read the file afterwards and summarise or quote it back to
the user.

## Requirements

Required: `agent-browser`, `jq`, `curl`, `bash`.
Optional: `llm` (content-aware file name; without it the slug falls back to the
first line of the post), `trafilatura` (linked sources), `timeout` (bounds those
two steps; without it they run unbounded).

### One-off setup: the dedicated profile

The script uses a persistent Chrome profile at `~/.agent-browser-profiles/linkedin`,
used for the LinkedIn login and nothing else, on the agent-browser session named
`linkedin`. It never calls `close --all`, so other agent browsers are left alone.

The first login has to happen by hand in a visible browser window; the script
prints the exact commands when it exits 2 or 3. Run that headed command yourself,
then stop and tell the user to log in in the window that just opened and to say
when they are done: the browser stays up waiting for them, and only after their
confirmation do you re-run the read. Never ask the user for their password - they
type it themselves in that window. A headed browser needs a display:
on a Linux desktop, on macOS and on Windows it works as is; on WSL2 with WSLg too;
on WSL2 **without** WSLg, point `DISPLAY` at your own X server (X410, VcXsrv,
Xming) before running the headed command.

## Output

`/tmp/YYYY-MM-DD_<slug>.txt` — the date of the run; snake_case slug from the
first words of the post's subject (in its original language, max 64 characters).
If the file already exists, a `_2`, `_3`... suffix is added. Content: a header
(URL, extraction date, comments extracted and, when it differs, the number
declared by the LinkedIn counter) + a POST section + a COMMENTS (n) section. Each
comment is a numbered `[k]` block with author, relative timestamp, headline,
reactions and full text; nested replies are marked `(reply)`.

If the header reads `N extracted / M declared by the LinkedIn counter`, LinkedIn
did not serve every comment to this session: the file is partial and says so.

## Failures (exit codes)

| code | case | what to do |
|---|---|---|
| 1 | bad usage, unrecognised URL, missing required tool | fix the command line |
| 2 | dedicated profile missing | one-off headed setup (the script prints the commands) |
| 3 | session expired | one-off headed re-login (the script prints the commands), then re-run |
| 4 | browser failed to start, post unavailable, not visible to the account, or post text not extracted | read the message: it carries what agent-browser said, or the hook counts (`textBoxes=`, `commentBlocks=`, `commentary=`, `lazyColumn=`). If the browser did not start, re-run; if every hook reads 0, LinkedIn changed the page again; otherwise check the URL by hand in a browser |
| 5 | internal timeout (240 s) | retry; if it persists, the post is too heavy to load |

## Known limits

- **LinkedIn replaced its web client in September 2026.** What the page serves now
  is a server-driven UI (`data-component-type="LazyColumn"`): there is no
  `article` element anywhere, no `data-id`, and every surviving class is hashed
  (`_4a74b613`). Everything the skill used before - `article.comments-comment-entity`,
  `.update-components-*`, `.social-details-social-counts__comments` - returns 0.
  The extractor was rewritten on 2026-09-11 around what is left.
- **The hooks now are `data-testid` and the shape of the blocks.**
  `[data-testid="expandable-text-box"]` marks the post body and every comment
  body; the block owning one is the first ancestor carrying an identity link
  (`/in/`, `/company/`, `/school/`, `/showcase/`) that is **not** part of the body
  itself - the exclusion matters, because a mention inside a comment is an
  identity link too. A comment block has exactly 3 children (header, body, social
  bar); the post is the text box that is not a comment. None of this depends on
  the UI language. When extraction fails, `die 4` prints the hook counts
  (`textBoxes=`, `commentBlocks=`, `commentary=`, `lazyColumn=`): all zeros mean
  the structure changed again.
- **Author, timestamp and reactions have no hook of their own** and are read by
  position inside their block, not from a line of the whole page's innerText.
  The author name arrives as an accessibility composite ("Eric Raszewski, MBA,
  Profilo Premium 2°") and is trimmed off the degree marker, which is language
  independent; your own comments carry "Tu"/"You" in place of a degree, taken
  from the badge row of the same link.
- **The page does not scroll on `window`**: LinkedIn puts the scroll inside
  `<main>` (`overflow-y: scroll`). `agent-browser scroll` therefore moves nothing
  and no further comment is fetched - measured on a 57-comment post, 18 loaded
  that way against 62 driving `main.scrollTop`. The tall viewport (1400x3000) is
  still needed on top of that.
- **The sort order stays the default ("Most relevant")**, so comments in the file
  are not in chronological order.
- **Replies are no longer nested in the DOM**: they sit at the same depth as
  top-level comments and are told apart by horizontal indent (measured: 465 px
  against 425 px). The marker is geometric, so it holds in any language, but a
  change of layout would silently drop the `(reply)` mark - nothing else in the
  file changes if it does.
- Expansion clicks the truncation toggles by `data-testid="expandable-text-button"`,
  then the buttons that only carry a label ("See previous replies", "Load more
  comments"). English and Italian labels are covered; **on a UI in another
  language those buttons are not clicked and nested replies may be missing** -
  the count in the header still shows the gap.
- Comments made only of an image or a GIF, with no text, do not make it into the
  file (the header still flags the gap between extracted and declared). That is
  not the only cause of a gap: on a 67-comment post 65 came out, with no
  image-only comment in sight. A gap of 1-2 therefore does not imply a bug.
- **`lnkd.in` links come in two shapes**: `lnkd.in/p/xxx` (a shared post) answers
  with a 3xx redirect, `lnkd.in/xxx` (a link inside a post body) answers 200 with
  an interstitial page carrying the destination in the body. `%{redirect_url}`
  alone resolves the first and comes back empty on the second: `resolve_short()`
  handles both.
- Posts with video: to download the video use `yt-dlp`, which however does not see
  the comments (which is why this skill exists).
- Design decisions: `docs/adr/`.

## Glossary

- **thread**: the post text plus every comment and reply visible to the
  authenticated account.
- **dedicated profile**: `~/.agent-browser-profiles/linkedin`, a persistent Chrome
  profile where ONLY the LinkedIn login happens; the session survives across runs.
- **dedicated session**: the agent-browser session `linkedin`.
