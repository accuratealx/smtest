# smtest — guide for agents

Read this first; it is short on purpose. Details live in `docs/` and are linked.

## Mission

<!-- What this project is, who it is for, what done looks like. -->

## Map

| Path | What it is |
|------|------------|
| `docs/ARCHITECTURE.md` | how the parts fit together; read before structural changes |
| `docs/STATUS.md` | where the work stands: TL;DR, next steps, risks |
| `docs/decisions/` | ADRs: why things are the way they are |
| `scripts/check-layout.sh` | file size and folder map checks (part of the gate) |

<!-- Agents: add one row per top-level folder as the project grows. -->

## Commands

<!-- Agents: fill in as soon as the stack exists. One gate command runs everything. -->

| Command | Does |
|---------|------|
| `scripts/check-layout.sh` | file sizes and folder maps |

## Working environment

- You run inside slopmancer on a remote server. The developer usually reads your
  output on a phone: keep chat summaries short and put long details in files.
- Dev servers must listen on 0.0.0.0 (not localhost) so they can be opened from
  the developer's devices, e.g. `npm run dev -- --host 0.0.0.0`.
- Screenshots and files the developer uploads land in `.slopmancer/uploads/`.
- Instructions live only here (`CLAUDE.md`, `GEMINI.md` import this file). Tasks
  for other sessions stand alone and ask for proof in `doneWhen`.

## Keep context small

Every line an agent reads costs. Structure the project so that the next agent
finds what it needs by reading little:

- **Search, then read narrowly.** `rg`, symbol search, a folder's map, then
  the one file, then only the lines you need. Never read a whole large file
  or a lock file. Lock files and build output are listed in `.ignore`.
- **Short files.** Code and scripts stay under 250 lines, docs under 200
  (`scripts/check-layout.sh`). When a file grows, split it by responsibility,
  never by "part 1 / part 2".
- **Folder maps.** A folder with 8 or more source files has a `README.md`
  (Go: `doc.go`) listing each file in one line. Update it in the same change.
  Large folders become a hierarchy: subfolders, each with its own map.
- **Docs as a tree.** This file is the root (keep it under 150 lines) →
  `docs/ARCHITECTURE.md` → `docs/<topic>.md` → `docs/decisions/`. Every doc
  opens with a 1–3 line summary, so reading the head is enough to skip it.
  Link instead of repeating; one fact lives in one place.
- **Quiet commands.** Send long output to a file and read the tail or grep
  it; run tests so that only failures print.
- **No dead weight.** Delete dead code, stale docs and commented-out code in
  the same change that makes them obsolete.

## Code quality

- **Organise by feature,** not by kind (`billing/`, not `controllers/`).
  Each module has one job and a small public surface; dependencies point one
  way, no cycles.
- **Small functions** (about 40 lines at most), shallow nesting, early returns.
- **Names say what things are;** no abbreviations, no `utils`/`helpers`
  dumping grounds.
- **Comments say why,** not what. Every exported unit gets a one-line doc comment.
- **Errors are handled or returned,** never swallowed. Validate input at the
  edges; trust it inside.
- **Formatter, linter and type checker** run in the gate; fix warnings, do not
  silence them without a comment saying why.
- **Tests** sit next to the code they test, cover behaviour (not internals),
  are deterministic and never call real external services.
- **Dependencies are rare:** prefer the standard library; a new dependency
  needs a reason in an ADR.
- **Match the surrounding code** — its style, naming and idioms — over
  personal taste.

## Work tracking

Plans, epics and tasks are GitHub issues of this repository, not files:

- **Task:** an issue that fits one agent session, with a `## Done when`
  section and one priority label `P0`, `P1` or `P2`.
- **Epic:** an issue labelled `epic`; its tasks are sub-issues
  (`gh api -X POST repos/{owner}/{repo}/issues/<epic>/sub_issues -F sub_issue_id=<task id>`)
  and a checklist in its body; the design goes into an ADR it links.
- **Plan:** a milestone with acceptance criteria; tasks and epics belong to it.
- **Labels** `blocked` (say on top what it waits for) and `in progress`
  (an agent took it). Create missing labels with `gh label create`.
- Pick the oldest open issue of the highest priority that is neither
  `blocked` nor `in progress`; label it `in progress`; close it with
  `Closes #N` in the PR body. Work you discover on the way becomes a new issue.
- Without a GitHub remote, keep tasks under "Next" in `docs/STATUS.md`.

## Git workflow

Every change reaches the default branch through a pull request that you open
and merge yourself:

1. Work on a branch, never on the default branch; small, clear commits.
2. Rebase on the latest default branch and run the gate.
3. Push and open a PR: `git push -u origin HEAD`, `gh pr create --fill`.
   Title: what changes; body: why, and how it was tested.
4. Wait for the checks: `slopmancer-ci` (exit 0 green, 1 red, 2 no CI; never
   pipe it, read its last line) or `gh pr checks --watch` (with MCP: `ci_watch`). Red: fix, push, wait again.
5. All checks green: `pr_merge {pr}` and end your turn (outcome arrives as a message), or `slopmancer-merge` (merges in turn with other sessions,
   rebases and retests when behind, deletes the branch; 3 = conflict).
6. Never merge with failing or pending checks, never bypass them (`--admin`),
   never push or force-push to the default branch. No checks yet: run the
   gate locally; CI that runs it is a good first PR (set up per `docs/CI.md`); deploying before that takes `ci: none` on the deployment.
7. Checks you cannot get green: leave the PR open and say why in it.

Without a GitHub remote, merge locally once the gate passes.

## Deploying

Deploys are Docker Compose only (`docker compose up -d --build` of a commit on
a host). From the first runnable code on:

- `compose.yaml` at the root builds and starts everything from a clean checkout.
- State (data, models, caches) lives in named volumes, never in the image. To back it up, label the one service that can dump it, `slopmancer.backup.dump: pg_dump -U app app` (stdout, run inside that container); the owner sets where and how often.
- `expose:`, no `ports:` (hosts set routes); settings, secrets: `.env.example`. A `${NAME}` the deployment lacks and with no default (`${NAME:-x}`) refuses the commit.
- One file (+ `compose.<env>.yaml`); hosts refuse `privileged`, `build` with `image`, binds without `:ro`.
- Servers keep running after a start (the host checks after ~20 s), with a `restart:` policy: one that exits 0 and stays down reads as finished. Slow first steps run inside the service.
- One-shot jobs such as `migrate` must exit 0; start them with `depends_on` and `condition: service_completed_successfully`.
- Give servers a `healthcheck`, and a route a `healthPath`: deploys wait for both, up to 5 minutes, or roll back.
- After a merge: `slopmancer-deploy status`, `deploy <name> --wait` (`passkey` ones wait for the owner), `logs <name>`; each slopmancer script explains itself with `--help`.

## Definition of done

1. The behaviour is demonstrated by a test (a bug fix's test fails without the
   fix: run it once on the old code), or a manual check where tests cannot reach.
2. The gate passes.
3. Docs are current: folder maps, `docs/ARCHITECTURE.md` for structural
   changes, an ADR for non-obvious decisions.
4. The issue's "Done when" holds and the PR says `Closes #N`;
   `docs/STATUS.md` is updated; the PR is merged with green checks.

## Decisions

Decide yourself and record an ADR (`docs/decisions/NNNN-title.md`, see the
README there) for reversible, internal choices. Ask the developer before
anything costly, irreversible, security-relevant or that deletes data: open
an issue labelled `question` (context in plain words, options, your
recommendation, your default) and keep working on something else; without a
GitHub remote, ask in the session.
