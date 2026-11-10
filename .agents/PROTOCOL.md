# Agent Protocol

This file is the rulebook for every AI agent and chat that works on this
repository. It is installed and updated by
[agent-protocol](https://github.com/starscream000/agent-protocol).
Do not edit it inside a project; change it in the agent-protocol repository
and re-run the install script.

Protocol version: see `.agents/VERSION`.

## 1. The idea

One **master chat** plans and reviews. Many **worker agents** each do one
task. The **owner** (the human) approves and merges. They never rely on what
was said in a chat: everything an agent needs is written in this repository.

## 2. Roles

| Role | Does | Never does |
|---|---|---|
| Owner | Approves plans, tells workers which task to take, merges or orders merges | — |
| Master | Keeps the plan, writes task briefs, reviews pull requests, keeps the status board | Bulk coding; merging without the owner's order |
| Worker | Completes exactly one task on its own branch and reports | Merging; editing plan files; starting a second task |

If you were not told your role, you are a **worker**.

## 3. Files

Protocol-owned (overwritten on protocol updates, never edit in a project):

- `.agents/PROTOCOL.md` — this file
- `.agents/VERSION` — protocol version installed here
- `.agents/templates/` — blank task brief, report, and handover

Project-owned (created once, then belong to the project):

| File | Purpose | Written by |
|---|---|---|
| `CLAUDE.md` | Project-specific rules and how to build, run, and test | Master |
| `docs/PLAN.md` | Roadmap and current milestone | Master |
| `docs/DECISIONS.md` | Choices made and why | Master |
| `docs/STATUS.md` | Board: every task and its state | Master |
| `docs/HANDOVER.md` | Summary so a new master chat can take over | Master |
| `tasks/NNN-name.md` | One brief per task | Master |
| `reports/NNN-name.md` | What the worker did, skipped, and needs answered | Worker |

## 4. Branches and pull requests

"Default branch" below means the repository's main line (`main` or `master`).

1. **Every task gets its own branch and its own pull request.** No exceptions
   for small tasks.
2. Branch name: `task/NNN-name`, matching the brief's file name.
3. Pull request title: `Task NNN: <brief title>`.
4. **No code reaches the default branch except through a merged pull request.**
5. **Merging:** only the owner merges, or the master merges when the owner
   orders it for that specific pull request. Workers never merge.
6. **Planning files are the one exception to rule 4.** The master may commit
   changes to `docs/`, `tasks/`, and `CLAUDE.md`, and protocol installs or
   updates in `.agents/`, straight to the default branch, because workers
   need to read them before they can start. These commits contain no code.
   Their messages start with `plan:` or `protocol:`.

## 5. Task states

A task is always in exactly one state. The master records it in the brief's
`Status:` line and in `docs/STATUS.md`.

| State | Meaning |
|---|---|
| `draft` | Brief is being written. Workers must not start. |
| `ready` | Approved by the owner. A worker may start. |
| `in progress` | A worker has started. |
| `in review` | Pull request is open and waiting for the master's review. |
| `changes requested` | Review found problems; the worker must address them. |
| `done` | Pull request merged. |
| `blocked` | Cannot continue without an answer or another task. |

## 6. Worker procedure

Follow these steps in order.

1. Update your copy of the default branch (`git pull`).
2. Read `CLAUDE.md`, this file, `docs/PLAN.md`, `docs/DECISIONS.md`, and your
   brief in `tasks/`.
3. Check the brief's `Status:` is `ready` (or `changes requested` if you are
   fixing review comments). If it is anything else, stop and tell the owner.
4. Create the branch `task/NNN-name` from the default branch. If it already
   exists, check it out and continue on it.
5. Do the work. Change only the files listed under **Files you may change**
   in the brief. Your own report file is always allowed.
6. Run every check listed in the brief and in `CLAUDE.md`.
7. Write `reports/NNN-name.md` from `.agents/templates/report.md`.
8. Commit, push the branch, and open a pull request against the default
   branch. Put the brief's "Done when" list in the description and tick what
   you completed.
9. Stop. Do not merge. Do not start another task.

**If you need to change a file that is not listed,** or the brief is unclear
or contradicts the plan: stop, describe the problem under "Questions" in your
report, push what you have, open the pull request as a draft with the title
`Blocked — Task NNN: <title>`, and stop.

**If you are fixing review comments:** read the comments on the pull request,
make the changes on the same branch, add a "Review round" section to your
report, and push. Do not open a second pull request.

**Never:** edit `docs/`, another task's brief or report, or `.agents/`;
rewrite pushed history (no force-push); merge; widen the task because
something nearby looks wrong. Note such things under "Noticed but not done"
in your report.

## 7. Master procedure

### Planning

1. Keep `docs/PLAN.md` current: the goal, milestones, and which milestone is
   active.
2. Record every decision in `docs/DECISIONS.md` with the date and the reason,
   so no agent reopens it.
3. Number tasks in order: `001`, `002`, … Never reuse a number.
4. Write each brief from `.agents/templates/task.md`. A brief must be
   understandable by an agent that has read nothing but the repository.
5. Keep tasks small: one worker session, one reviewable pull request.
6. Tasks that are `ready` at the same time must not list the same files.
   If they must, mark one as depending on the other.
7. Set a brief to `ready` only after the owner approves it.
8. Update `docs/STATUS.md` whenever a state changes.

### Review

For each pull request:

1. Read the brief, the report, and the full set of changes.
2. Check each "Done when" item against the changes, not against the report's
   claims. Run the checks yourself where you can.
3. Check that only allowed files changed.
4. Give one verdict as a pull request comment:
   - **Approve** — every item met. Tell the owner it is ready to merge.
   - **Changes requested** — list each problem and what would fix it.
5. Merge only when the owner orders it for that pull request.
6. After a merge: set the task to `done`, update `docs/STATUS.md`, move any
   "Noticed but not done" items into new briefs or the plan, and record any
   decision the task forced.

### Handover

When the chat is getting long, or the owner asks, write `docs/HANDOVER.md`
from `.agents/templates/handover.md`. A new master chat starts by reading
`CLAUDE.md`, this file, `docs/HANDOVER.md`, `docs/PLAN.md`,
`docs/DECISIONS.md`, and `docs/STATUS.md`.

## 8. Commit messages

- Task work: `task NNN: <what changed>`
- Planning files: `plan: <what changed>`
- Protocol install or update: `protocol: install vX.Y.Z`

## 9. When rules collide

1. A direct instruction from the owner wins.
2. Then the task brief.
3. Then `CLAUDE.md`.
4. Then this file.

If following an instruction would break rule 4 or 5 of section 4 (code on the
default branch without a pull request, or a merge the owner did not order),
stop and ask the owner first.
