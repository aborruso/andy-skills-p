# LOG

## 2026-11-10

- First draft: writes a short first-steps prompt for a tool, application, pipeline, dataset or project, after read-only checks on links and package names
- Generated prompt installs nothing by default and proposes what the project requires or recommends, asking permission, extensions included
- Command-line tools: isolated install (`uv tool install`, `npx`), `--help` read first, and the prompt says so when the help is built for agents, only after checking
- From the first real case, a public dataset built by a private pipeline: datasets count as subjects, one prompt per reader (users and maintainers apart), only the traps that bite in the first steps
