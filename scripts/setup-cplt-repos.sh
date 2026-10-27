#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
LIST_ONLY=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  --list) LIST_ONLY=true ;;
  --help|-h)
    echo "Bruk: ./scripts/setup-cplt-repos.sh [--dry-run|--list]"
    echo "Registrerer Git-repoer direkte under repos/ i lokal cplt-konfigurasjon."
    echo "--list viser kun repoene under repos/ som allerede er registrert."
    echo "Kjør utenfor cplt-sandboksen. --dry-run viser kun hva som skal registreres."
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Ukjent argument: $1. Bruk --help." >&2
    exit 1
    ;;
esac
if [ "$#" -gt 1 ]; then
  echo "For mange argumenter. Bruk --help." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPOS_DIR="$ROOT_REPO_DIR/repos"

if [ -L "$REPOS_DIR" ]; then
  echo "repos/ er en symbolsk lenke. Bruk en vanlig katalog under prosjektet." >&2
  exit 1
fi
if [ ! -d "$REPOS_DIR" ]; then
  echo "Fant ikke $REPOS_DIR. Kjør scripts/clone-repos.sh først." >&2
  exit 1
fi

repo_paths=()
for repo_path in "$REPOS_DIR"/* "$REPOS_DIR"/.[!.]* "$REPOS_DIR"/..?*; do
  [ -d "$repo_path" ] || continue
  if [ -L "$repo_path" ]; then
    printf 'Hopper over symbolsk lenke: %s\n' "$repo_path"
    continue
  fi
  [ -e "$repo_path/.git" ] || continue
  repo_paths+=("$repo_path")
done

if [ "${#repo_paths[@]}" -eq 0 ]; then
  echo "Fant ingen Git-repoer direkte under $REPOS_DIR." >&2
  exit 1
fi

if [ -n "${__CPLT_WRAPPED:-}" ]; then
  echo "Kjør skriptet i en vanlig terminal utenfor cplt-sandboksen." >&2
  exit 1
fi
if ! command -v cplt >/dev/null 2>&1; then
  echo "Fant ikke cplt i PATH. Installer cplt før du kjører skriptet." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Fant ikke python3 i PATH. Skriptet krever Python 3.11 eller nyere." >&2
  exit 1
fi

cd "$ROOT_REPO_DIR"
if ! local_config="$(cplt config path --local)"; then
  echo "Kunne ikke finne stien til lokal cplt-konfigurasjon." >&2
  exit 1
fi
python3 - "$local_config" "$LIST_ONLY" "${repo_paths[@]}" <<'PY'
import os
from pathlib import Path
import sys

if sys.version_info < (3, 11):
    sys.exit("Skriptet krever Python 3.11 eller nyere.")

import tomllib

config_path = Path(sys.argv[1])
try:
    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
except FileNotFoundError:
    config = {}
except (OSError, tomllib.TOMLDecodeError):
    sys.exit(f"Kunne ikke lese lokal cplt-konfigurasjon: {config_path}")

sandbox = config.get("sandbox", {})
if not isinstance(sandbox, dict):
    sys.exit("Ugyldig sandbox-seksjon i lokal cplt-konfigurasjon.")
registered = sandbox.get("repo_dirs", [])
if not isinstance(registered, list) or not all(isinstance(path, str) for path in registered):
    sys.exit("Ugyldig sandbox.repo_dirs i lokal cplt-konfigurasjon.")

registered_paths = {os.path.realpath(os.path.expanduser(path)) for path in registered}
list_only = sys.argv[2] == "true"
print("Allerede registrerte repoer under repos/:" if list_only else "Repoer under repos/:")
found = False
for path in sys.argv[3:]:
    is_registered = os.path.realpath(path) in registered_paths
    if list_only:
        if is_registered:
            print(f"  {path}")
            found = True
    else:
        status = "allerede registrert" if is_registered else "ikke registrert"
        print(f"  [{status}] {path}")
if list_only and not found:
    print("  Ingen repoer under repos/ er registrert.")
PY

if [ "$LIST_ONLY" = true ]; then
  exit 0
fi
echo "Eksisterende registreringer beholdes. Ingen repoer klones eller endres."
if [ "$DRY_RUN" = true ]; then
  echo "Forhåndsvisning: ingen konfigurasjon er endret."
  exit 0
fi

printf 'Registrere disse repoene i lokal cplt-konfigurasjon? [y/N] '
answer=""
if ! IFS= read -r answer; then
  echo "Ingen bekreftelse mottatt. Ingen konfigurasjon er endret." >&2
  exit 1
fi
case "$answer" in
  y|Y|yes|Yes) ;;
  *)
    echo "Avbrutt. Ingen konfigurasjon er endret."
    exit 0
    ;;
esac

if ! cplt config set --local sandbox.repo_dirs "${repo_paths[@]}"; then
  echo "Registrering feilet. Se feilmeldingen fra cplt over." >&2
  exit 1
fi
echo "Repoene er registrert. Start en ny cplt-sesjon fra $ROOT_REPO_DIR."
