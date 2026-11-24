#!/usr/bin/env bash
set -euo pipefail

info() {
  printf '[opprydding] %s\n' "$*"
}

is_cloned_repo() {
  local candidate_name="$1"
  local repo_url
  local repo_name

  for repo_url in "${REPOS[@]}"; do
    repo_name="$(basename "$repo_url" .git)"
    if [[ "$candidate_name" == "$repo_name" ]]; then
      return 0
    fi
  done
  return 1
}

check_git_safety() {
  local candidate="$1"
  local git_root
  local canonical_root
  local status
  local stashes
  local worktrees
  local index_entries

  if [[ -L "$candidate/.git" || ! -d "$candidate/.git" ]]; then
    info ".git er ikke en vanlig mappe. Det kan være en worktree. Skriptet sletter ikke worktrees."
    return 1
  fi

  if ! git_root="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)"; then
    info "Kunne ikke finne Git-roten for $candidate."
    return 1
  fi
  if ! canonical_root="$(cd "$git_root" 2>/dev/null && pwd -P)"; then
    info "Kunne ikke fastslå Git-roten for $candidate."
    return 1
  fi
  if [[ "$canonical_root" != "$candidate" ]]; then
    info "Git-roten er ikke den valgte mappen. Avbryter uten å slette."
    return 1
  fi
  if ! worktrees="$(git -C "$candidate" worktree list --porcelain)"; then
    info "Kunne ikke kontrollere worktrees. Avbryter uten å slette."
    return 1
  fi
  if [[ "$(printf '%s\n' "$worktrees" | grep -c '^worktree ')" -ne 1 ]]; then
    info "Repoet har tilknyttede worktrees. Fjern dem med git worktree remove før opprydding."
    return 1
  fi
  if ! index_entries="$(git -C "$candidate" ls-files --stage)"; then
    info "Kunne ikke kontrollere submoduler. Avbryter uten å slette."
    return 1
  fi
  if [[ -e "$candidate/.gitmodules" || -e "$candidate/.git/modules" ]] ||
    printf '%s\n' "$index_entries" | grep '^160000 ' >/dev/null; then
    info "Repoet har submoduler eller lokale submoduldata. Kontroller og rydd opp i dem manuelt."
    return 1
  fi

  if ! status="$(git -C "$candidate" status --porcelain --untracked-files=all --ignore-submodules=none 2>/dev/null)"; then
    info "Kunne ikke kontrollere Git-status. Avbryter uten å slette."
    return 1
  fi
  if [[ -n "$status" ]]; then
    info "Repoet har lokale endringer eller untracked filer. Lagre arbeidet før du prøver igjen."
    return 1
  fi

  if ! stashes="$(git -C "$candidate" stash list 2>/dev/null)"; then
    info "Kunne ikke kontrollere Git-stash. Avbryter uten å slette."
    return 1
  fi
  if [[ -n "$stashes" ]]; then
    info "Repoet har stash-oppføringer. Ta vare på arbeidet i dem før du prøver igjen."
    return 1
  fi

  python3 - "$candidate" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile

candidate = Path(sys.argv[1])


def git(path, *args):
    result = subprocess.run(
        ["git", "-C", str(path), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode:
        sys.exit("[opprydding] Git-kontrollen feilet. Sjekk nettverk og Git-oppsett. Repoet beholdes.")
    return result.stdout.strip()


remotes = git(candidate, "remote").splitlines()
if not remotes:
    sys.exit("[opprydding] Repoet har ingen remoter. Repoet beholdes.")

local_oids = [git(candidate, "rev-parse", "--verify", "HEAD")]
local_oids += git(
    candidate, "for-each-ref", "--format=%(objectname)", "refs/heads", "refs/tags"
).splitlines()

# Hent i et eget repo, slik at fetch ikke kan endre lokale tags eller trackingrefs.
with tempfile.TemporaryDirectory(prefix="pia-repo-kontroll-") as directory:
    snapshot = Path(directory)
    git(snapshot, "init", "--bare", "--template=", "--quiet")
    objects = str(candidate / ".git" / "objects")
    if "\n" in objects or "\r" in objects:
        sys.exit("[opprydding] Repo-stien inneholder linjeskift. Repoet beholdes.")
    (snapshot / "objects" / "info" / "alternates").write_text(objects + "\n")

    for index, remote in enumerate(remotes):
        url = git(candidate, "remote", "get-url", "--", remote)
        git(
            snapshot, "fetch", "--no-tags", "--no-prune", "--no-prune-tags",
            "--no-write-fetch-head", "--no-auto-maintenance", "--no-recurse-submodules",
            "--refmap=", "--", url,
            f"+refs/heads/*:refs/verified/{index}/heads/*",
            f"+refs/tags/*:refs/verified/{index}/tags/*",
        )

    remote_oids = git(
        snapshot, "for-each-ref", "--format=%(objectname)", "refs/verified"
    ).splitlines()
    if not remote_oids:
        sys.exit("[opprydding] Ingen refs ble hentet fra remoter. Repoet beholdes.")

    unpushed = git(
        snapshot, "rev-list", "--max-count=1", *local_oids, "--not", *remote_oids
    )
    if unpushed:
        sys.exit("[opprydding] Repoet har commits som ikke finnes på noen remote. Repoet beholdes.")
PY
}

main() {
  local script_dir
  local root_dir
  local repos_dir
  local candidate_path
  local candidate_name
  local choice
  local candidate_count=0
  local local_config
  local sort_i
  local sort_j
  local sort_temp
  local -a candidates=()

  if [[ "$#" -gt 1 ]]; then
    info "For mange argumenter. Bruk --help."
    return 1
  fi
  case "${1:-}" in
    --help|-h)
      printf 'Bruk: ./scripts/rydd-opp-repo.sh [--help]\n'
      printf 'Velg et repo direkte under repos/ som ikke finnes i repo-listen, og rydd opp i det.\n'
      printf 'Kjør utenfor cplt-sandboksen. Krever Git, cplt og Python 3.11 eller nyere.\n'
      printf 'Stopper ved lokale endringer, stash eller upushede commits. Sletter mappen etter bekreftelse.\n'
      return 0
      ;;
    "")
      ;;
    *)
      info "Ukjent argument: $1. Bruk --help."
      return 1
      ;;
  esac

  if [[ ${__CPLT_WRAPPED+x} ]]; then
    info "Kjør skriptet i en vanlig terminal utenfor cplt-sandboksen."
    return 1
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  root_dir="$(cd "$script_dir/.." && pwd -P)"
  export LC_ALL=C
  repos_dir="$root_dir/repos"
  if [[ -L "$repos_dir" ]]; then
    info "repos/ er en symbolsk lenke. Bruk en vanlig mappe."
    return 1
  fi
  if [[ ! -d "$repos_dir" ]]; then
    info "Fant ikke repos/. Ingenting å rydde opp."
    return 0
  fi
  repos_dir="$(cd "$repos_dir" && pwd -P)"

  source "$script_dir/clone-repos.sh"

  for candidate_path in "$repos_dir"/* "$repos_dir"/.[!.]* "$repos_dir"/..?*; do
    [[ -d "$candidate_path" && ! -L "$candidate_path" ]] || continue
    [[ -e "$candidate_path/.git" || -L "$candidate_path/.git" ]] || continue
    candidate_name="$(basename "$candidate_path")"
    if is_cloned_repo "$candidate_name"; then
      continue
    fi
    candidates+=("$candidate_path")
  done

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    info "Fant ingen Git-repoer direkte under repos/ som ikke allerede står i repo-listen."
    return 0
  fi

  for ((sort_i = 1; sort_i < ${#candidates[@]}; sort_i++)); do
    sort_j="$sort_i"
    while [[ "$sort_j" -gt 0 && "${candidates[$sort_j]}" < "${candidates[$((sort_j - 1))]}" ]]; do
      sort_temp="${candidates[$sort_j]}"
      candidates[$sort_j]="${candidates[$((sort_j - 1))]}"
      candidates[$((sort_j - 1))]="$sort_temp"
      sort_j=$((sort_j - 1))
    done
  done

  for candidate_path in "${candidates[@]}"; do
    candidate_count=$((candidate_count + 1))
    candidate_path="$(cd "$candidate_path" && pwd -P)"
    while true; do
      printf '\n[opprydding] Repo: %s\n' "$(basename "$candidate_path")"
      printf '[opprydding] 1) Hopp over  2) Rydd opp  3) Avbryt\n'
      printf '[opprydding] Velg [1/2/3]: '
      choice=""
      if ! IFS= read -r choice; then
        info "Ingen valg mottatt. Avbryter."
        return 1
      fi
      case "$choice" in
        1)
          break
          ;;
        2)
          if ! command -v cplt >/dev/null 2>&1; then
            info "Fant ikke cplt i PATH. Installer cplt før opprydding."
            return 1
          fi
          if ! command -v python3 >/dev/null 2>&1; then
            info "Fant ikke python3 i PATH. Opprydding krever Python 3.11 eller nyere."
            return 1
          fi

          if ! check_git_safety "$candidate_path"; then
            return 1
          fi

          printf '\n[opprydding] Dette fjerner repoet fra lokal cplt-konfigurasjon og sletter %s.\n' "$candidate_path"
          printf '[opprydding] Ignorerte filer slettes også. Slettingen kan ikke angres.\n'
          printf '[opprydding] Skriv ja eller j for å bekrefte: '
          choice=""
          if ! IFS= read -r choice; then
            info "Ingen bekreftelse mottatt. Avbryter uten endringer."
            return 1
          fi
          case "$choice" in
            j|J|ja|Ja|JA)
              ;;
            *)
              info "Avbrutt. Ingen cplt-konfigurasjon eller arbeidsfiler er endret."
              return 0
              ;;
          esac

          if ! check_git_safety "$candidate_path"; then
            info "Sikkerhetskontrollen etter bekreftelsen feilet. Ingen konfigurasjon er endret."
            return 1
          fi

          if ! local_config="$(cd "$root_dir" && cplt config path --local)"; then
            info "Kunne ikke finne stien til lokal cplt-konfigurasjon. Repoet beholdes."
            return 1
          fi
          if ! (cd "$root_dir" && python3 - "$local_config" "$candidate_path" <<'PY'
import os
from pathlib import Path
import subprocess
import sys

if sys.version_info < (3, 11):
    sys.exit("[opprydding] Opprydding krever Python 3.11 eller nyere.")

import tomllib

config_path = Path(sys.argv[1])
candidate = os.path.realpath(sys.argv[2])
try:
    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
except FileNotFoundError:
    config = {}
except (OSError, tomllib.TOMLDecodeError):
    sys.exit(f"[opprydding] Kunne ikke lese lokal cplt-konfigurasjon: {config_path}")

sandbox = config.get("sandbox", {})
if not isinstance(sandbox, dict):
    sys.exit("[opprydding] Ugyldig sandbox-seksjon i lokal cplt-konfigurasjon.")
registered = sandbox.get("repo_dirs", [])
if not isinstance(registered, list) or not all(isinstance(path, str) for path in registered):
    sys.exit("[opprydding] Ugyldig sandbox.repo_dirs i lokal cplt-konfigurasjon.")

matches = [
    path
    for path in registered
    if os.path.realpath(os.path.expanduser(path)) == candidate
]
if matches:
    result = subprocess.run(
        ["cplt", "config", "unset", "--local", "sandbox.repo_dirs", *matches],
        check=False,
    )
    if result.returncode:
        sys.exit(result.returncode)
PY
          ); then
            info "Kunne ikke fjerne repo-registreringer fra lokal cplt-konfigurasjon. Repoet beholdes."
            return 1
          fi

          if ! rm -rf -- "$candidate_path"; then
            info "Lokal cplt-konfigurasjon kan være oppdatert, men repo-mappen ble ikke fjernet."
            return 1
          fi
          if [[ -e "$candidate_path" || -L "$candidate_path" ]]; then
            info "Lokal cplt-konfigurasjon kan være oppdatert, men repo-mappen finnes fortsatt."
            return 1
          fi
          info "Repoet er fjernet fra lokal cplt-konfigurasjon og slettet."
          return 0
          ;;
        3)
          info "Avbrutt. Ingen endringer er gjort."
          return 0
          ;;
        *)
          info "Ugyldig valg. Skriv 1, 2 eller 3."
          ;;
      esac
    done
  done

  if [[ "$candidate_count" -gt 0 ]]; then
    info "Ingen repoer ble ryddet opp."
  fi
}

main "$@"
