"""Fresh-runtime and launch diagnostics exercised only with synthetic directories."""
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time

import pytest

ROOT = Path(__file__).resolve().parents[1]


def test_incomplete_environment_has_safe_diagnostic(tmp_path):
    (tmp_path / 'scripts').mkdir()
    shutil.copy(ROOT / 'scripts/launch-v2.sh', tmp_path / 'scripts/launch-v2.sh')
    binary = tmp_path / '.venv-v2-p5/bin/python'
    binary.parent.mkdir(parents=True)
    binary.write_text('#!/bin/sh\nexec "' + sys.executable + '" -S "$@"\n')
    binary.chmod(0o700)
    result = subprocess.run(['/bin/zsh', str(tmp_path / 'scripts/launch-v2.sh'), 'demo'],
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 1
    assert 'environment_incomplete' in result.stderr
    assert 'Traceback' not in result.stderr
    assert not (tmp_path / '.local').exists()


@pytest.mark.parametrize('mode', ['demo', 'live'])
def test_launcher_from_space_directory_uses_test_runtime(tmp_path, mode):
    project = tmp_path / 'Project with spaces'
    (project / 'scripts').mkdir(parents=True)
    shutil.copy(ROOT / 'scripts/launch-v2.sh', project / 'scripts/launch-v2.sh')
    shutil.copy(ROOT / 'app.py', project / 'app.py')
    shutil.copytree(ROOT / 'gmail_unsubscriber', project / 'gmail_unsubscriber',
                    ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    (project / '.venv-v2-p5').symlink_to(Path(sys.prefix), target_is_directory=True)
    log = tmp_path / 'output.log'
    with log.open('w') as output:
        proc = subprocess.Popen(['/bin/zsh', str(project / 'scripts/launch-v2.sh'), mode,
                                 '--no-browser', '--data-dir', str(tmp_path / 'synthetic'),
                                 '--credentials', str(tmp_path / 'missing.json')],
                                cwd='/tmp', stdout=output, stderr=subprocess.STDOUT)
        try:
            for _ in range(200):
                text = log.read_text()
                if re.search(r'http://127\.0\.0\.1:\d+', text):
                    break
                assert proc.poll() is None, text
                time.sleep(0.05)
            else:
                pytest.fail('startup_timeout')
            assert f'Lightmail mode: {mode}' in text
            assert '.venv-v2-p5/bin/python' in text
        finally:
            if proc.poll() is None:
                proc.send_signal(signal.SIGINT)
            proc.wait(timeout=10)
        assert proc.returncode == 0
    assert not (tmp_path / 'synthetic/token.json').exists()
