# C01 dependency locks

HONOR commits resolved dependency graphs and installs those graphs without opportunistic upgrades.

## Node / npm

Runtime/build baseline: Node 22 LTS and npm 10.x. `package-lock.json` is npm lockfileVersion 3 and includes the complete resolved workspace dependency graph, registry tarball URLs, and integrity metadata.

Regenerate only when dependency changes are intentional and checkpoint-reviewed:

```sh
rm -rf node_modules
npm install --package-lock-only --workspaces --include-workspace-root --ignore-scripts
npm ci --workspaces --include-workspace-root --ignore-scripts
git diff --exit-code -- package-lock.json
```

Normal local, CI, and container installation uses `npm ci`; `npm install` is not an installation path for a frozen checkout. `scripts/check_lockfiles.py` rejects unresolved graph entries and committed TypeScript build caches.

## Python

Runtime baseline: CPython 3.13.15 in CI/API/worker images. The deterministic resolver is `uv==0.10.0` targeting Python 3.13 on x86_64 Linux. Frozen top-level requirements remain in `pyproject.toml`; the resolved graph is `requirements.lock`.

Regenerate intentionally with network access:

```sh
python -m pip install uv==0.10.0
uv pip compile pyproject.toml --extra dev --python-version 3.13 \
  --python-platform x86_64-unknown-linux-gnu --no-header --no-annotate \
  --output-file requirements.lock
```

CI installs `requirements.lock`, independently re-resolves the graph from `pyproject.toml` with the same pinned resolver/target, and compares normalized package/version pairs using `scripts/compare_python_lock.py`. API and worker Docker images install only from `requirements.lock`.
