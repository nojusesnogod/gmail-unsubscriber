# Rebuilding the restricted local v2 delivery

Validated platform: macOS arm64, CPython 3.14.4. No system installation, service registration, signing or packaging is included.

The runtime lock is `requirements-v2.lock`. The test lock, `requirements-v2-test.lock`, includes the runtime plus pytest and its supporting packages. The older range-based requirements files remain historical inputs, not the reproducible delivery instructions.

From the project directory, with a destination environment that does not already exist:

```sh
(
set -eu
test ! -e work/p5-rebuild-venv
python3 -m venv work/p5-rebuild-venv
work/p5-rebuild-venv/bin/python -m pip --isolated --disable-pip-version-check install --no-input --keyring-provider disabled --index-url https://pypi.org/simple -r requirements-v2-test.lock
work/p5-rebuild-venv/bin/python -m pip check
work/p5-rebuild-venv/bin/python -m pytest tests_v2 -q
work/p5-rebuild-venv/bin/python app.py --demo --data-dir work/p5-rebuild-demo
)
```

For runtime-only setup, use `requirements-v2.lock` instead of the test lock and omit the `pytest` command: the runtime lock does not install the test runner. Do not overwrite an existing environment. Launchers select `.venv-v2-p5` first when present, then `.venv-v2`; they never fall back to legacy `venv` or system Python. Dependency checks reject missing/incomplete imports. Other Python versions and machines are not validated.

If the first command reports an existing directory, stop and use a new unused destination throughout; do not install into or overwrite the old environment. The check environment under `work/` does not replace the daily launcher's environment. The current launchers continue to use the existing `.venv-v2-p5`. A first-time daily runtime can use the same steps with an absent `.venv-v2` destination and the runtime-only lock.

Package retrieval uses public PyPI with keyring access disabled. This is an exact-version dependency lock, not an offline wheel archive or a package-content hash lock. Cached package artifacts may be reused by pip; this is a new environment installation, not a cold-download or offline-archive test. A future unavailable index/version can prevent reconstruction; retain the actual failure rather than assuming a working existing environment proves a new install. No pip upgrade is necessary.

On 2026-09-27, a new environment was created with CPython 3.14.4 on macOS arm64. All 32 approved runtime/test package versions installed without version changes, and `pip check` passed. The current tests were rerun in that environment. Original environments were not modified.

The test suite uses synthetic data in temporary directories. The public test command does not require a real Gmail account or sender endpoint.

Local trial and acceptance records may contain private usage details and are intentionally excluded from the public repository. A fresh install and test run should be assessed from its own command output; a successful prior run on another machine does not prove this machine is ready.

Native Finder double-click and security dialogs remain NOT_RUN if exclusive desktop ownership cannot be confirmed. Shell-launcher execution and isolated browser checks are not native desktop acceptance. Live Gmail and sender requests are outside P5.
