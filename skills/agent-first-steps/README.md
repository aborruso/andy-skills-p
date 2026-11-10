# agent-first-steps

An Agent Skill that writes a short first-steps prompt for a tool, application, pipeline, dataset or project. Someone pastes that prompt into their own AI agent, and the agent takes them from nothing to a first working result.

## How it works

1. You point the agent at a folder, a repository, a package or a site. With no indication, it uses the working directory.
2. It decides who the prompt is for. People who use something and people who maintain it get separate prompts.
3. It reads the README, the files written for agents and the manifests, and fills the route: prerequisites, install or clone, a check, what to read, an optional skill, human-only steps, a first small task.
4. It verifies every link and package name, read-only. It installs nothing, and what does not verify is removed and reported to you.
5. It shows you the prompt ready to copy, in the language of the project's README, and asks whether to add it to the README.

The generated prompt tells the receiving agent to install nothing by default, to tell the person what the project requires or strongly recommends and ask permission for each install, and to hand interactive logins, API keys and `sudo` back to the person.

## Requirements

An AI client that reads Agent Skills and can run shell commands, with network access for the checks.

## Install

```bash
npx skills add aborruso/andy-skills-p --skill agent-first-steps
```

## License

MIT
