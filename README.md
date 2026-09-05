# andy skills

Agent Skills built by [Andrea Borruso](https://github.com/aborruso), published for reuse.

A skill is a folder with a `SKILL.md` inside: frontmatter that says what it does and when to use it, and a body with the instructions the agent follows. The format is the one described by the [Agent Skills specification](https://agentskills.io/specification).

## Skills

| Skill | What it does |
| --- | --- |
| [`linkedin-reader`](skills/linkedin-reader) | Reads one LinkedIn post with its full comment thread through an authenticated browser session, and saves it as a structured text file. |

## Install

Copy the skill folder where your agent looks for skills. For Claude Code:

```bash
git clone https://github.com/aborruso/andy-skills-p.git
cp -r andy-skills-p/skills/linkedin-reader ~/.claude/skills/
```

Each skill has its own README with requirements and usage.

## License

MIT - see [LICENSE](LICENSE).
