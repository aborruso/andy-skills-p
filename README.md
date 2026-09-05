# andy skills

This is where I collect some of the Agent Skills I actually use, published because they may be useful to someone else. Nothing here is a product: they are tools built for my own work, cleaned up enough to be handed over. The list grows whenever one of them turns out to be worth sharing.

A skill is a folder with a `SKILL.md` inside: frontmatter that says what it does and when to use it, and a body with the instructions the agent follows. The format is the one described by the [Agent Skills specification](https://agentskills.io/specification): it is client-neutral, so these work with any AI client that reads skills - Claude Code, Cursor, Codex, Copilot, Gemini CLI and the others alike. Nothing here is tied to a specific one.

Each skill is installed on its own, with the command in its section below. Installing needs Node, since it goes through `npx`.

## Skills

### LinkedIn reader

[`linkedin-reader`](skills/linkedin-reader) reads one LinkedIn post together with its full comment thread - nested replies and truncated bodies included - through your own authenticated browser session, and saves it as a structured text file. You paste a post URL to your agent and ask it to read or archive the thread.

It was born out of a habit: while I am working on something, a related LinkedIn post shows up and I want to dig into it without leaving what I am doing. The point is to put that material into the AI's context - the post, the discussion under it, and the first three links cited in the body when they are readable - and then ask questions about it, instead of reading the thread by hand in the browser.

It works on a single link at a time, on purpose: one post per invocation, no batches, no scheduling. Links found in the post body are followed and appended as sources, up to three.

```bash
npx skills add aborruso/andy-skills-p --skill linkedin-reader
```

The wizard asks which AI clients to install it for, whether to install globally or only in the current project, and whether to link or copy the files. Answer **global** and **symlink**: global makes the skill available in every project, and the symlink keeps it following the repo, so later changes come down with `npx skills update linkedin-reader` - a copy has to be reinstalled instead.

Before the first read it needs a one-off manual login in a visible browser window, and it expects `agent-browser` on the PATH: see [its README](skills/linkedin-reader#one-off-login).

## License

MIT - see [LICENSE](LICENSE).
