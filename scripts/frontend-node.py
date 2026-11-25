#!/usr/bin/env python3
"""Kontroller lokal Node-runtime og lagret cplt-tillatelse uten å endre dem."""

import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

if sys.version_info < (3, 11):
    sys.exit("[node] Kontrollen krever Python 3.11 eller nyere.")

import tomllib


class CheckError(Exception):
    pass


def run(command, cwd, env=None):
    try:
        result = subprocess.run(
            command, cwd=cwd, env=env, text=True, capture_output=True, timeout=30
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise CheckError(f"Kunne ikke kjøre {command[0]}. Kontroller installasjonen og PATH.") from error
    if result.returncode:
        raise CheckError(
            f"{command[0]} feilet (exit {result.returncode}): {result.stderr.strip()}\n"
            "Kontroller Node i PATH og kjør cplt config show manuelt utenfor cplt."
        )
    return result.stdout


def satisfies(version, requirement):
    # Støtt komparatorsyntaksen i repoet. Ikke gjett ved andre npm-semver-formater.
    alternatives = requirement.split("||")
    results = []
    for alternative in alternatives:
        tokens = alternative.split()
        if not tokens:
            raise CheckError(f"Ukjent Node-krav: {requirement!r}.")
        matches = []
        for token in tokens:
            match = re.fullmatch(r"(>=|<=|>|<|=)?v?(\d+)(?:\.(\d+))?(?:\.(\d+))?", token)
            if not match:
                raise CheckError(f"Node-kravet {requirement!r} støttes ikke av kontrollen.")
            operator, *parts = match.groups()
            specified = tuple(int(part) for part in parts if part is not None)
            target = specified + (0,) * (3 - len(specified))
            if operator in (None, "="):
                matches.append(version[:len(specified)] == specified)
            else:
                upper = list(specified)
                upper[-1] += 1
                upper = tuple(upper) + (0,) * (3 - len(upper))
                matches.append({
                    ">=": version >= target,
                    ">": version >= upper if len(specified) < 3 else version > target,
                    "<=": version < upper if len(specified) < 3 else version <= target,
                    "<": version < target,
                }[operator])
        results.append(all(matches))
    return any(results)


def manifests(monorepo):
    try:
        lines = (monorepo / "pnpm-workspace.yaml").read_text().splitlines()
    except OSError as error:
        raise CheckError("Fant ikke pnpm-workspace.yaml. Kjør clone-repos.sh først.") from error
    paths = [monorepo]
    in_packages = False
    found = False
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line == "packages:":
            if found:
                raise CheckError("Flere packages-seksjoner i pnpm-workspace.yaml.")
            in_packages = found = True
            continue
        if not in_packages:
            continue
        if not line[0].isspace():
            in_packages = False
            continue
        match = re.fullmatch(r"""  - (['"]?)([A-Za-z0-9_./-]+)\1""", line)
        if not match:
            raise CheckError("Workspace-listen må inneholde eksplisitte relative mappestier.")
        relative = Path(match[2])
        path = (monorepo / relative).resolve()
        if relative.is_absolute() or ".." in relative.parts or not path.is_relative_to(monorepo):
            raise CheckError("Workspace-stien går utenfor monorepoet.")
        paths.append(path)
    if not found or len(paths) == 1:
        raise CheckError("Fant ingen workspaces i pnpm-workspace.yaml.")
    for path in dict.fromkeys(paths):
        try:
            data = json.loads((path / "package.json").read_text())
        except (OSError, ValueError) as error:
            raise CheckError(f"Kunne ikke lese {path / 'package.json'}.") from error
        if not isinstance(data, dict):
            raise CheckError(f"Ugyldig package.json i {path}.")
        engines = data.get("engines", {})
        if not isinstance(engines, dict):
            raise CheckError(f"Ugyldig engines i {path / 'package.json'}.")
        requirement = engines.get("node")
        if requirement is not None and not isinstance(requirement, str):
            raise CheckError(f"Ugyldig Node-krav i {path / 'package.json'}.")
        yield path, requirement


def runtime(root):
    monorepo = root / "repos" / "pia-frontend-monorepo"
    if monorepo.is_symlink() or not monorepo.is_dir():
        raise CheckError("Fant ikke en vanlig pia-frontend-monorepo-mappe. Kjør clone-repos.sh først.")
    monorepo = monorepo.resolve()
    environment = dict(os.environ)
    environment.pop("NODE_OPTIONS", None)
    environment.pop("NODE_PATH", None)
    detected = None
    for workspace, requirement in manifests(monorepo):
        output = run(
            ["node", "-p", "JSON.stringify({version:process.version,execPath:process.execPath})"],
            workspace, environment,
        )
        try:
            data = json.loads(output)
            if not isinstance(data, dict):
                raise ValueError("Ugyldig Node-resultat")
            version = data["version"]
            executable = data["execPath"]
            if not isinstance(version, str) or not re.fullmatch(r"v\d+\.\d+\.\d+", version):
                raise ValueError("Ugyldig Node-versjon")
            if not isinstance(executable, str) or any(ord(char) < 32 for char in executable):
                raise ValueError("Ugyldig Node-sti")
            path = Path(executable)
            if not path.is_absolute():
                raise ValueError("Relativ Node-sti")
            path = path.resolve(strict=True)
            metadata = path.stat()
            if not stat.S_ISREG(metadata.st_mode) or not os.access(path, os.X_OK):
                raise ValueError("Node er ikke en kjørbar fil")
            if metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
                raise ValueError("Node-filen er skrivbar for gruppe eller andre")
        except (ValueError, KeyError, TypeError, OSError) as error:
            raise CheckError("Kunne ikke validere faktisk Node-binær. Kontroller Node-installasjonen.") from error
        current = {
            "path": str(path), "version": version,
            "identity": [metadata.st_dev, metadata.st_ino, metadata.st_size, metadata.st_mtime_ns],
        }
        if detected is not None and current != detected:
            raise CheckError(
                "Workspaces bruker forskjellige Node-binærer. "
                "Bruk samme Node-installasjon i alle workspaces, og kjør setup på nytt."
            )
        detected = current
        numbers = tuple(int(part) for part in version[1:].split("."))
        if requirement is not None and not satisfies(numbers, requirement):
            raise CheckError(
                f"Node {version} oppfyller ikke {requirement!r} i {workspace / 'package.json'}. "
                "Oppdater lokal Node og kjør sync.sh igjen."
            )
    return detected


def covered(path, entries):
    if not isinstance(entries, list) or not all(isinstance(entry, str) for entry in entries):
        raise CheckError("Ugyldig stiliste i cplt-konfigurasjonen.")
    for entry in entries:
        parent = Path(entry).expanduser().resolve()
        if path == parent or (parent.is_dir() and path.is_relative_to(parent)):
            return True
    return False


def read_config(path):
    try:
        with path.open("rb") as config_file:
            return tomllib.load(config_file)
    except FileNotFoundError:
        return {}
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise CheckError(f"Kunne ikke lese cplt-konfigurasjon: {path}.") from error


def permitted(root, executable):
    allowed = []
    denied = []
    for options in ([], ["--local"]):
        output = run(["cplt", "config", "path", *options], root).strip()
        path = Path(output)
        if not output or not path.is_absolute() or "\n" in output:
            raise CheckError("cplt config path returnerte ikke en absolutt filsti.")
        config = read_config(path)
        allow = config.get("allow", {})
        deny = config.get("deny", {})
        if not isinstance(allow, dict) or not isinstance(deny, dict):
            raise CheckError("Ugyldig allow/deny-seksjon i cplt-konfigurasjonen.")
        allowed.append(allow.get("exec", []))
        denied.append(deny.get("paths", []))
    # Repoets forslag er ikke tillatelser. Ta likevel hensyn til repoets sperrer.
    repo_deny = read_config(root / ".cplt.toml").get("deny", {})
    if not isinstance(repo_deny, dict):
        raise CheckError("Ugyldig deny-seksjon i .cplt.toml.")
    denied.append(repo_deny.get("paths", []))
    path = Path(executable)
    grants = [covered(path, entries) for entries in allowed]
    blocks = [covered(path, entries) for entries in denied]
    return any(grants) and not any(blocks)


def main():
    if "__CPLT_WRAPPED" in os.environ:
        raise CheckError("Kjør kontrollen i en vanlig terminal utenfor cplt-sandboksen.")
    mode, directory, *arguments = sys.argv[1:]
    root = Path(directory).resolve(strict=True)
    state = runtime(root)
    if mode == "verify":
        if len(arguments) != 1 or state != json.loads(arguments[0]):
            raise CheckError("Node-binæren eller versjonen er endret. Kjør setup-cplt-repos.sh på nytt.")
        return
    permission = permitted(root, state["path"])
    if mode == "inspect":
        print(json.dumps({"runtime": state, "permitted": permission}))
    elif mode == "check":
        if not permission:
            raise CheckError(
                f"Mangler lagret exec-tillatelse for {state['path']}. "
                "Kjør scripts/setup-cplt-repos.sh utenfor cplt og start en ny økt."
            )
        print(f"[node] Node {state['version']}: {state['path']}")
        print("[node] Node-kravene er oppfylt, og lagret exec-tillatelse er funnet.")
    else:
        raise CheckError(f"Ukjent kontrollmodus: {mode}.")


if __name__ == "__main__":
    try:
        main()
    except (CheckError, OSError, ValueError) as error:
        sys.exit(f"[node] {error}")
