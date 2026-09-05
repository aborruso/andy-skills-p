# andy skills

This is where I collect some of the Agent Skills I actually use, published because they may be useful to someone else. Nothing here is a product: they are tools built for my own work, cleaned up enough to be handed over. The list grows whenever one of them turns out to be worth sharing.

A skill is a folder with a `SKILL.md` inside: frontmatter that says what it does and when to use it, and a body with the instructions the agent follows. The format is the one described by the [Agent Skills specification](https://agentskills.io/specification): it is client-neutral, so these work with any AI client that reads skills - Claude Code, Cursor, Codex, Copilot, Gemini CLI and the others alike. Nothing here is tied to a specific one.

## Install

```bash
npx skills add aborruso/andy-skills-p
```

That needs Node installed (`npx` ships with it). The wizard asks which skills you want, which AI clients to install them for, whether to install globally or in the current project, and whether to link or copy the files. Answer **global** and **symlink**: global makes the skills available in every project instead of just this one, and the symlink keeps them following the repo, so `npx skills update` is enough to get later changes - a copy has to be reinstalled.

Add `--skill linkedin-reader` to take just one, `--list` to see what the repo contains without installing anything, `-g` to skip the scope question:

```bash
npx skills add aborruso/andy-skills-p --list
npx skills add aborruso/andy-skills-p --skill linkedin-reader -g
```

Copying the folder by hand works too: put `skills/<name>/` wherever your client looks for skills (`~/.claude/skills/` for Claude Code, the equivalent directory for any other client).

Each skill has its own README with requirements and usage. `linkedin-reader` needs a one-off manual login in a visible browser window before its first use: see [its README](skills/linkedin-reader#one-off-login).

## License

MIT - see [LICENSE](LICENSE).

## Index

| Skill | What it does |
| --- | --- |
| [`linkedin-reader`](skills/linkedin-reader) | Reads one LinkedIn post with its full comment thread through an authenticated browser session, and saves it as a structured text file. |
