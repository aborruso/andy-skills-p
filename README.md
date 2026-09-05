# andy skills

This is where I collect some of the Agent Skills I actually use, published because they may be useful to someone else. Nothing here is a product: they are tools built for my own work, cleaned up enough to be handed over. The list grows whenever one of them turns out to be worth sharing.

A skill is a folder with a `SKILL.md` inside: frontmatter that says what it does and when to use it, and a body with the instructions the agent follows. The format is the one described by the [Agent Skills specification](https://agentskills.io/specification).

## Install

Copy the skill folder where your agent looks for skills. For Claude Code:

```bash
git clone https://github.com/aborruso/andy-skills-p.git
cp -r andy-skills-p/skills/linkedin-reader ~/.claude/skills/
```

Each skill has its own README with requirements and usage.

## License

MIT - see [LICENSE](LICENSE).

## Index

| Skill | What it does |
| --- | --- |
| [`linkedin-reader`](skills/linkedin-reader) | Reads one LinkedIn post with its full comment thread through an authenticated browser session, and saves it as a structured text file. |
