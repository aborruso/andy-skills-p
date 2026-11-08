# release-explorer

An Agent Skill that reads the release notes of a software release, tells you the points that matter to you based on what your agent already knows about you, and, if you want, helps you try the new features in a throwaway folder.

## How it works

1. You give the agent a release URL. GitHub, GitLab, Codeberg and other Gitea or Forgejo hosts, PyPI, npm and plain changelog pages are supported. If you do not give one, the agent asks for it.
2. The agent gathers what it knows about you: its memory, your project instructions, the working directory, the version you have installed.
3. It tells you the three to five points most relevant to you, plus any breaking change or security fix.
4. It asks whether you want to try the release. If you say yes, it checks that your environment allows the test, without changing anything.
5. It creates a folder in the system temp directory, installs that exact version only there, and builds examples with you, showing real output.
6. At the end it asks whether to keep or delete the folder.

When the agent cannot operate the software itself, for example a Windows desktop app while the agent runs in WSL, it offers a guided test: it prepares a working folder with the useful files and proposes the steps one at a time, while you carry them out in the interface.

## Requirements

An AI client that reads Agent Skills and can run shell commands. `gh` and `glab` are used when available, with the public APIs through `curl` as a fallback. The test stage needs whatever the release itself needs, such as Python or Node.

The personal part depends on what your client knows about you: with no memory or context available, the skill says so and tells the story for a generic reader.

## Install

```bash
npx skills add aborruso/andy-skills-p --skill release-explorer
```

## License

MIT
