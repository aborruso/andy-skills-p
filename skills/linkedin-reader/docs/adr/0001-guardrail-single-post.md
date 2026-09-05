# Automated LinkedIn reading with anti-scraping guardrails

LinkedIn's User Agreement forbids scraping, bots and the use of scripts to copy
the service's content, and no public downloader (`yt-dlp`, `gallery-dl`) extracts
comments; the only practical way to read a thread is an authenticated session.

Decision: automate the reading of **one single post per invocation** through the
user's own already authenticated browser session (a dedicated agent-browser
profile), with structural guardrails inside the script — no batching, no
scheduling, pauses between scrolls — and an explicit statement of the ToS risk in
the skill.

Rejected alternative: the official Comments API, because the read scope for
personal accounts (`r_member_social_feed`) is restricted to selected developers,
and the page-level scope requires a role on the page. Rejected as forbidden or
incomplete: a scheduled headless scraper, public downloaders.

Consequence: whoever finds this code in six months must not "optimise" it by
adding batching or cron — the slowness and the single-post limit are deliberate.
