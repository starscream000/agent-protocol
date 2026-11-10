# agent-protocol

A small set of rules and files for running a software project with several
AI agents: one **master chat** that plans and reviews, and **worker agents**
that each do one task. They coordinate through the project's GitHub
repository, never through chat history.

- Every task gets its own branch and its own pull request.
- The main branch only changes through merged pull requests.
- Only the owner merges, or the master chat merges on the owner's order.
- Everything an agent needs to know is written in the repository.

The full rules are in [`.agents/PROTOCOL.md`](.agents/PROTOCOL.md).

## Install in a project

Run this from the top folder of the project's git repository. It works for
new and existing projects.

```bash
curl -fsSL https://raw.githubusercontent.com/starscream000/agent-protocol/main/install.sh | bash
```

Then review and commit:

```bash
git status
git add -A && git commit -m "protocol: install v1.0.0"
```

The script needs `bash`, `git`, `curl`, and `tar`. On Windows, run it in
WSL or Git Bash.

## Update a project to the newest protocol

Run the same command again. `.agents/VERSION` shows which version a project
is on.

## What gets installed

| Files | Owner | On update |
|---|---|---|
| `.agents/PROTOCOL.md`, `.agents/VERSION`, `.agents/templates/` | Protocol | Replaced |
| `CLAUDE.md`, `docs/PLAN.md`, `docs/DECISIONS.md`, `docs/STATUS.md`, `tasks/`, `reports/` | Project | Created if missing, otherwise left alone |

If the project already has a `CLAUDE.md`, the script adds a short block at
the end that points to the protocol and leaves the rest as it is.

## How a project runs

1. **Plan.** In the master chat, agree on the goal and milestones. The
   master writes `docs/PLAN.md` and records choices in `docs/DECISIONS.md`.
2. **Brief.** The master writes one file per task in `tasks/`, and marks it
   `ready` once you approve it.
3. **Work.** You start a worker agent in the repository and point it at a
   task. It works on its own branch, writes a report in `reports/`, and
   opens a pull request.
4. **Review.** The master checks the pull request against the brief's
   "Done when" list and either approves or asks for changes.
5. **Merge.** You merge, or tell the master chat to merge.
6. **Record.** The master updates `docs/STATUS.md` and the plan.

## What to say to the agents

Starting a master chat on a project:

> You are the master for this project. Read CLAUDE.md, .agents/PROTOCOL.md,
> docs/PLAN.md, docs/DECISIONS.md and docs/STATUS.md, then tell me where
> things stand.

Starting a worker:

> You are a worker. Pull the latest main branch, then do task 003 as
> described in tasks/ following .agents/PROTOCOL.md.

Sending a worker back after review:

> Address the review comments on the pull request for task 003.

Handing over to a new master chat:

> Write the handover.

## Changing the protocol

Edit the files in this repository, raise the number in `.agents/VERSION`,
and re-run the install script in each project. Do not edit
`.agents/PROTOCOL.md` inside a project; the next update would overwrite it.

Version numbers follow `major.minor.patch`: raise the first number when a
rule changes in a way agents must act on differently, the second when
something is added, the third for wording fixes.

## Layout of this repository

```
.agents/        The protocol itself, copied into every project
scaffold/       Starter versions of the project-owned files
install.sh      Installs or updates the protocol in a project
```
