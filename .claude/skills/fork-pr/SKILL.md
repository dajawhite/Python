---
name: fork-pr
description: Create a branch from the current changes, run the checks CI runs (pre-commit hooks, then pytest with doctests), and push and open a pull request against the user's fork (the `origin` remote), not upstream TheAlgorithms/Python. Use when the user asks to open, create, or send a PR, or runs /fork-pr.
argument-hint: "[optional PR title or short description]"
---

# Branch and PR to the fork

Turn the working-tree changes into a branch on `origin` (the user's fork) and open a pull request whose base is the fork's `master`. The rules in `AGENTS.md` at the repo root apply to every step. If the user passed text after the command (`$ARGUMENTS`), use it for the PR title and summary.

## Hard rules

- **The PR targets the fork.** When `origin` is a fork, `gh pr create` defaults to the *parent* repo (TheAlgorithms/Python). Always pass `--repo <owner>/<repo>`, taken from the `origin` URL.
- **Pushing and opening a PR are visible on GitHub.** A user request for a PR, or running `/fork-pr`, counts as the go-ahead. Otherwise, confirm before pushing.
- **Never push failing checks.** Fix the cause, or stop and report the failure with the real output.
- **Never fabricate test output.** Paste exactly what the commands printed.
- **Run pre-commit only on the PR's files, never `--all-files`.** The `rumdl` and whitespace hooks would rewrite unrelated Markdown and other files. Preexisting `.md` files must stay unchanged unless the user explicitly asked to change them.
- **Stage files by name.** Never use `git add -A` or `git add .`.

## 1. Preflight

```bash
git status --short
git branch --show-current
git remote get-url origin
git fetch origin
```

- Take `<owner>/<repo>` from the `origin` URL. For example, `https://github.com/<you>/Python.git` gives `<you>/Python`.
- Run `command -v gh && gh auth status`. If `gh` is missing or not logged in, carry on and use the fallback in step 6.
- Build the PR's file list from uncommitted changes. If you're already on a feature branch, add the files changed in its commits (`git diff --name-only origin/master...HEAD`).
- If there is nothing to commit and no commits ahead of `origin/master`, stop and say so.

## 2. Scope check

Check the file list against `AGENTS.md` before going further:

- **One algorithm file per PR.** If several unrelated algorithm files changed, ask which one this PR is for. Leave the others uncommitted in the working tree.
- **Code or doctests, not both.** If both a file's logic and its doctests changed, say so and ask whether to split before continuing.
- **New files** must sit in an existing directory and have an all-lowercase filename with underscores, no spaces or dashes.
- **Unexpected files** stay out of the PR: editor config, `.venv`, a regenerated `DIRECTORY.md`, or edits to preexisting `.md` files. Mention them to the user.

## 3. Branch

- If you're already on a branch other than `master`, use it.
- Otherwise, run `git switch -c <type>/<short-slug>`. Uncommitted changes carry over.
  - `<type>` follows the repo's conventional-commit style: `feat`, `fix`, `test`, `docs`, `refactor`, `ci`, or `chore`.
  - `<short-slug>` is short, lowercase, and hyphenated, for example `feat/keith-number` or `fix/ema-window-size`.
- If local `master` is behind `origin/master` or has diverged from it, branch from the remote instead: `git switch -c <branch> origin/master`. If Git refuses because of conflicting local changes, stop and ask.

## 4. Run the checks

Run these on the PR's files. After any fix, run them again until everything passes.

### Lint and format

These are the hooks pre-commit.ci runs:

```bash
uvx pre-commit run --files <file> [<file> ...]
```

Hooks such as `ruff-format` and `auto-walrus` rewrite files in place, and the run reports "Failed". Review the changes, then run the command again until it passes.
Afterwards, `git status` should show no changes outside the PR's file list. If other files changed, stop and show the user rather than reverting anything. (`uv.lock` belongs in the PR when `pyproject.toml` changed.)

### Tests and doctests

This mirrors the CI `build` job in `.github/workflows/build.yml`. You don't need `--doctest-modules`: `pyproject.toml` already adds it.

```bash
uv run --group=test --with=pytest-run-parallel pytest \
  --iterations=8 --parallel-threads=auto --ignore-gil-enabled \
  <changed .py files>
```

- On the first run, uv downloads free-threaded Python 3.15t (from `.python-version`) and installs the dependencies. This takes a few minutes.
- `--iterations=8 --parallel-threads=auto` runs every test on several threads, as CI does. Code that isn't thread-safe then fails locally rather than in CI.
- For each new or changed algorithm file, also run `uv run python -m doctest -v <file>`, which `AGENTS.md` requires. Its last line must read `Test passed.`
- CI skips files in its `--ignore` list (for example `project_euler/` and `digital_image_processing/`). If a changed file is on that list, run it locally anyway if its dependencies install, and note in the PR that CI skips it.
- If no Python files changed, skip pytest and say so in the PR.

If anything fails, fix the cause. If the fix would go beyond the PR's scope, stop and ask. Don't go on with a failing run. Keep the final passing output, because it goes in the PR body.

### Review the diff

The `algorithms-keeper` bot checks these points, so confirm them by reading the diff:

- Every new or changed function has type hints on all its parameters and its return value.
- Every function has at least one doctest.
- A new algorithm includes a URL to Wikipedia or a similar explanation.

## 5. Commit and push

```bash
git add <file> [<file> ...]
git commit -m "<type>(<scope>): <summary>"
git push -u origin <branch>
```

- Follow the repo's commit style, for example `feat(maths): add Keith number algorithm`, `fix: handle EMA window size of one`, or `test: cover palindrome edge cases with doctests`.
- Never pass `--no-verify`. If local pre-commit hooks are installed they run again on commit, and they should pass because step 4 did.

## 6. Open the PR

Build the body from `.github/pull_request_template.md`. Read the template each time instead of working from memory. Write the body to a file in the scratchpad directory:

1. Under `### Describe your change`, above its checkboxes, summarize what changed and why. Add `Fixes #N` if the PR closes an issue.
2. Tick (`* [x]`) every box that is true. **Tick at least one box under "Describe your change"**, because `algorithms-keeper` closes PRs that have none. Leave boxes that aren't true unticked.
3. Add a `### Tests run` section with the exact commands from step 4 and a short summary of their real results, such as pass counts.

```bash
gh pr create --repo <owner>/<repo> --base master --head <branch> \
  --title "<commit subject>" --body-file <body file>
```

`--repo` is required. Without it, `gh` opens the PR against TheAlgorithms/Python.

**If `gh` isn't available:** the branch is already pushed. Give the user this link and the body file's full path, so they can paste the body in:

`https://github.com/<owner>/<repo>/compare/master...<branch>?expand=1`

Tell them to check that the page's base repository is `<owner>/<repo>`, not TheAlgorithms/Python. Also suggest `brew install gh && gh auth login` for next time.

## 7. Report

Tell the user:

- The branch name.
- The PR URL, or the compare link.
- Which checks ran, and their results.
- Anything left out of the PR, such as other changed files still in the working tree.
