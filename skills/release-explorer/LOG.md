# LOG

## 2026-11-08

- Repo URL goes straight to the latest release; a bare tool name triggers a repository search, asking only if ambiguous. `gh auth status` checked first, with a warning and a `curl` fallback
- Guided test added for software the agent cannot operate (Windows desktop app with the agent in WSL): working folder on the app's side, one step at a time, the user acts in the interface
- First draft: reads release notes from GitHub, GitLab, Gitea/Forgejo, PyPI, npm or any page, tells the points that matter to the reader, offers a hands-on test in a `mktemp -d` folder after a read-only environment check
