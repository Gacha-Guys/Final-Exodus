"""Regression checks for the local Godot launcher boundary."""
import argparse
import os
from pathlib import Path

import pytest

from demo.google_ui_check import godot_environment, godot_executable


def test_godot_environment_excludes_backend_and_unrelated_secrets(monkeypatch):
    secrets = (
        'FINAL_EXODUS_DB_PASSWORD', 'FINAL_EXODUS_JWT_SECRET',
        'FINAL_EXODUS_GOOGLE_CLIENT_SECRET', 'UNRELATED_ACCESS_TOKEN',
    )
    for name in secrets:
        monkeypatch.setenv(name, 'test-sentinel')
    monkeypatch.setenv('FINAL_EXODUS_API_ORIGIN', 'https://unused.example.com')
    monkeypatch.setenv('FINAL_EXODUS_TEST_ARTIFACT_DIR', 'test-artifacts')

    environment = godot_environment()

    assert set(secrets).isdisjoint(environment)
    assert environment['FINAL_EXODUS_API_ORIGIN'] == 'http://127.0.0.1:8009'
    assert environment['FINAL_EXODUS_TEST_ARTIFACT_DIR'] == 'test-artifacts'


def test_godot_executable_resolves_a_path_with_spaces(tmp_path, monkeypatch):
    executable = tmp_path / ('Godot Engine.exe' if os.name == 'nt' else 'Godot Engine')
    executable.touch(mode=0o700)
    monkeypatch.chdir(tmp_path)

    assert godot_executable(argparse.ArgumentParser(), Path(executable.name)) == executable.resolve()


@pytest.mark.parametrize('name', ['missing.exe', 'directory.exe'])
def test_godot_executable_rejects_invalid_targets(tmp_path, capsys, name):
    (tmp_path / 'directory.exe').mkdir()

    with pytest.raises(SystemExit) as error:
        godot_executable(argparse.ArgumentParser(), tmp_path / name)

    assert error.value.code == 2
    assert '--godot' in capsys.readouterr().err


def test_godot_executable_rejects_non_executable_or_windows_script(tmp_path, capsys):
    candidate = tmp_path / 'godot.cmd'
    candidate.touch(mode=0o600)

    with pytest.raises(SystemExit) as error:
        godot_executable(argparse.ArgumentParser(), candidate)

    assert error.value.code == 2
    assert '--godot' in capsys.readouterr().err
