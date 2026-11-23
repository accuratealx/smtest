# CI

How to set up GitHub Actions so runs stay fast and cheap. CI runs the same
gate as `## Commands` in AGENTS.md; nothing more, nothing less.

## Assume a fresh, slow machine

Runners may be self-hosted: few of them, shared by several repositories,
each job in a new container with its own Docker and nothing from earlier
jobs (no host Docker socket, no tool cache, no image cache). So:

- **Few jobs.** Every job pays for checkout, toolchains and apt again and
  waits for a free runner. Start with one `check` job that runs the gate;
  add a job only for something that needs its own machine (e2e, images).
- **Cheap work first.** The gate tells an agent in a few minutes whether a
  PR is good; heavy jobs (images, smoke tests) must not hold the runners
  it waits for. Give every job `timeout-minutes`.
- **Install what you use** (`sudo apt-get install -y --no-install-recommends
  …`, `npx playwright install --with-deps chromium`): the image is bare.
- **Caches survive only via GitHub:** `actions/setup-go` / `setup-node` with
  `cache:`, and `type=gha` for Docker layers.

## Docker images

- Build with `docker/setup-buildx-action` (`driver: docker`, the job's own
  daemon) and `docker/build-push-action` with
  `cache-from: type=gha,scope=<image>` and `cache-to: type=gha,mode=max,scope=<image>`.
- **Build each image once per run.** Images do not pass between jobs: build
  with `load: true` and run everything that needs it (compose smoke tests)
  in the same job. Never `docker compose up --build` in CI — it builds again
  without the cache; use `--no-build` on the loaded images.
- Order the Dockerfile from rarely to often changing (system packages,
  dependency manifests and install, then source) so a code change rebuilds
  only the last layers.

## Workflow skeleton

```yaml
name: ci
on: { push: { branches: [main] }, pull_request: {} }
permissions: { contents: read }
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  check:
    runs-on: self-hosted   # or ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      # setup-<language> with cache, apt-get install of tools, then:
      - run: <the gate command>
```

## Checklist

- [ ] The gate runs locally and in CI with the same command.
- [ ] `permissions: contents: read`; secrets only where a step needs them.
- [ ] `concurrency` cancels outdated runs of the same branch.
- [ ] Each image is built once per run, from the `type=gha` cache.
- [ ] A full run takes minutes; if not, find the slow step in the run's
      job timings (`gh api repos/{owner}/{repo}/actions/runs/<id>/jobs`)
      before adding anything.
