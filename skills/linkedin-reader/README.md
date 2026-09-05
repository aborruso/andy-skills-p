# linkedin-reader

An [Agent Skill](https://agentskills.io) that reads one LinkedIn post together
with its full comment thread and saves it as a structured text file.

It exists because no public downloader extracts LinkedIn comments: `yt-dlp` gets
the video of a post, nothing gets the discussion under it. The only practical way
to read a thread is an authenticated session, so this skill drives one — your own,
in a dedicated browser profile.

## What you get

```
/tmp/2026-09-05_texas_parcel_records_open_data.txt
```

A plain text file with a header (URL, extraction date, comments extracted and,
when they differ, the number declared by LinkedIn's own counter), the full post
text, and every comment as a numbered block with author, timestamp, headline,
reactions and full text. Nested replies are marked `(reply)`. Links found in the
post body are followed and their content appended in a `LINKED SOURCES` section.

## Guardrails, read this first

LinkedIn's User Agreement forbids scraping and bots. This skill is built for
occasional reads that a human explicitly asks for, and the limits are structural,
not decorative: **one post per invocation, no batching, no scheduling**. See
[`docs/adr/0001-guardrail-single-post.md`](docs/adr/0001-guardrail-single-post.md)
before you think about "optimising" it. You are responsible for the account you
run it with.

## Requirements

| | |
|---|---|
| Required | [`agent-browser`](https://www.npmjs.com/package/agent-browser), `jq`, `curl`, `bash` |
| Optional | `llm` (content-aware file names), `trafilatura` (linked sources), `timeout` (bounds those two steps) |

Everything optional degrades gracefully: without `llm` the file name falls back to
the first line of the post, without `trafilatura` the `LINKED SOURCES` section is
skipped with a warning.

## Install

```bash
npx skills add aborruso/andy-skills-p --skill linkedin-reader
```

That needs Node (`npx` comes with it), and it works for any AI client that reads
skills, not just one: the wizard asks which agents to install for. Answer
**global** to the scope question (or pass `-g`) and **symlink** to the other one:
global makes it available in every project, the symlink lets `npx skills update`
pick up later changes. Copying
`skills/linkedin-reader/` into the skills directory of your client by hand works
too (`~/.claude/skills/` for Claude Code, the equivalent elsewhere).

Then do the one-off login: without it the first read stops with exit 2.

## One-off login

The script uses a persistent Chrome profile at `~/.agent-browser-profiles/linkedin`,
used for LinkedIn and nothing else. Log in by hand, once:

```bash
agent-browser open 'https://www.linkedin.com/login' \
  --headed --session linkedin --profile ~/.agent-browser-profiles/linkedin
```

That needs a visible browser window. On a Linux desktop, on macOS and on Windows
this works as is; on WSL2 with WSLg too. On WSL2 **without** WSLg, point `DISPLAY`
at your own X server (X410, VcXsrv, Xming) first:

```bash
export DISPLAY=$(ip route | grep default | awk '{print $3; exit}'):0.0
```

The session survives across runs. When it expires the script exits 3 and prints
the re-login command.

## Use

Normally you do not run it yourself: you paste a LinkedIn post URL to your agent
and ask it to read or save the thread. Directly:

```bash
scripts/linkedin-read.sh 'https://www.linkedin.com/posts/...'        # into /tmp
scripts/linkedin-read.sh 'https://www.linkedin.com/posts/...' ~/notes
scripts/linkedin-read.sh 'https://lnkd.in/xxxx'                     # short links too
scripts/linkedin-read.sh --no-links 'https://www.linkedin.com/posts/...'
```

Stdout is only the path of the file written; everything else goes to stderr.

Exit codes: `1` bad usage, `2` profile missing, `3` session expired, `4` post not
reachable, `5` internal timeout. In cases 2 and 3 the script prints the commands
that fix it.

## Known limits

Extraction hangs off LinkedIn's Ember semantic class names, which are stable and
language independent — but they are LinkedIn's, and LinkedIn changes them (it did,
in September 2026). When that happens the script exits 4 and prints which hook
died. The expansion buttons for nested replies are matched by English and Italian
labels, so a UI in another language may lose some replies; the header always
reports the gap between comments extracted and comments declared. Full list in
[`SKILL.md`](SKILL.md).

## License

MIT — see [LICENSE](../../LICENSE) at the repository root.
