# andy skills

This is where I collect some of the Agent Skills I actually use, published because they may be useful to someone else. Nothing here is a product: they are tools built for my own work, cleaned up enough to be handed over. The list grows whenever one of them turns out to be worth sharing.

A skill is a folder with a `SKILL.md` inside: frontmatter that says what it does and when to use it, and a body with the instructions the agent follows. The format is the one described by the [Agent Skills specification](https://agentskills.io/specification): it is client-neutral, so these work with any AI client that reads skills - Claude Code, Cursor, Codex, Copilot, Gemini CLI and the others alike. Nothing here is tied to a specific one.

## Installing and updating

Each skill is installed on its own, with the command in its section below. Installing needs Node, since it goes through `npx` and the [`skills`](https://github.com/vercel-labs/skills) CLI.

The rule is: always install through the CLI, pointing it at this repo, and then update through the CLI. Never link or copy a skill folder by hand into a client directory: the CLI does not know about it, so `list`, `update` and `remove` ignore it, and it stays frozen at the version you copied.

The wizard asks which AI clients to install it for, whether to install globally or only in the current project, and whether to link or copy the files. Answer **global** and **symlink**: global makes the skill available in every project, and the symlink lets every client share one copy, which lives in `~/.agents/skills/`. To skip the wizard:

```bash
npx skills add aborruso/andy-skills-p --skill <skill-name> -g -a '*' -y
```

The installed copy is a snapshot downloaded from GitHub: it does not change on its own. To pick up a new version, run the update and the CLI compares the installed files with the repo and downloads them again when they differ:

```bash
npx skills update <skill-name> -g
```

If you work on a local clone of this repo, the CLI also accepts a path as source, `npx skills add ./andy-skills-p --skill <skill-name>` or an absolute path, and `update` then reads from that clone. The online repo is still the way to go unless you are changing the skill yourself.

Running `npx skills add` again for a skill that is already installed also works: it warns that it overwrites the existing one and replaces it.

## Skills

### LinkedIn reader

[`linkedin-reader`](skills/linkedin-reader) reads one LinkedIn post together with its full comment thread - nested replies and truncated bodies included - through your own authenticated browser session, and saves it as a structured text file. You paste a post URL to your agent and ask it to read or archive the thread.

It was born out of a habit: while I am working on something, a related LinkedIn post shows up and I want to dig into it without leaving what I am doing. The point is to put that material into the AI's context - the post, the discussion under it, and the first three links cited in the body when they are readable - and then ask questions about it, instead of reading the thread by hand in the browser.

It works on a single link at a time, on purpose: one post per invocation, no batches, no scheduling. Links found in the post body are followed and appended as sources, up to three.

```bash
npx skills add aborruso/andy-skills-p --skill linkedin-reader
```

Before the first read it needs a one-off manual login in a visible browser window, and it expects `agent-browser` on the PATH: see [its README](skills/linkedin-reader#one-off-login).

### Release explorer

[`release-explorer`](skills/release-explorer) reads the release notes of a project you follow, on GitHub or elsewhere, and tells you the points that matter to you, based on what your agent already knows about you. It then asks whether you want to try the release: if you do, it checks that your environment allows the test, installs that exact version in a temporary system folder, and builds the examples with you. When the agent cannot operate the software itself, as with a Windows desktop app and an agent running in WSL, it prepares the working files and guides you one step at a time.

```bash
npx skills add aborruso/andy-skills-p --skill release-explorer
```

## License

MIT - see [LICENSE](LICENSE).
