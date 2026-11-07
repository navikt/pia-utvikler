#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
LIST_ONLY=false
REVOKE_DOCKER=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  --list) LIST_ONLY=true ;;
  --revoke-docker) REVOKE_DOCKER=true ;;
  --help|-h)
    echo "Bruk: ./scripts/setup-cplt-repos.sh [--dry-run|--list|--revoke-docker]"
    echo "Registrerer Git-repoer direkte under repos/ i lokal cplt-konfigurasjon."
    echo "Godkjenner også Docker-forslaget i .cplt.toml i hovedrepoet for neste sandboksøkt."
    echo "--list viser kun repoene under repos/ som allerede er registrert."
    echo "--revoke-docker trekker tilbake hovedrepoets Docker-godkjenning uten å endre repo-registreringene."
    echo "Tilbakekallingen gjelder fremtidige økter. Kjørende økter og andre lokale eller globale Docker-tillatelser påvirkes ikke."
    echo "Kjør utenfor cplt-sandboksen. --dry-run viser registrering og Docker-godkjenning uten å endre noe."
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

if [ -n "${__CPLT_WRAPPED:-}" ]; then
  echo "Kjør skriptet i en vanlig terminal utenfor cplt-sandboksen." >&2
  exit 1
fi
if ! command -v cplt >/dev/null 2>&1; then
  echo "Fant ikke cplt i PATH. Installer cplt før du kjører skriptet." >&2
  exit 1
fi

if [ "$REVOKE_DOCKER" = true ]; then
  cd "$ROOT_REPO_DIR"
  if ! cplt trust revoke allow_docker; then
    echo "Kunne ikke trekke tilbake Docker-godkjenningen. Se feilmeldingen fra cplt over." >&2
    exit 1
  fi
  echo "Docker-godkjenningen for hovedrepoet er trukket tilbake for fremtidige sandboksøkter."
  echo "Kjørende økter beholder tilgangen til de avsluttes. Andre lokale eller globale Docker-tillatelser påvirkes ikke."
  exit 0
fi

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
if ! global_config="$(cplt config path)"; then
  echo "Kunne ikke finne stien til global cplt-konfigurasjon." >&2
  exit 1
fi
global_docker="$(python3 - "$global_config" <<'PY'
from pathlib import Path
import sys
import tomllib

config_path = Path(sys.argv[1])
try:
    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
except FileNotFoundError:
    config = {}
except (OSError, tomllib.TOMLDecodeError):
    sys.exit(f"Kunne ikke lese global cplt-konfigurasjon: {config_path}")

sandbox = config.get("sandbox", {})
if not isinstance(sandbox, dict):
    sys.exit("Ugyldig sandbox-seksjon i global cplt-konfigurasjon.")
if "allow_docker" not in sandbox:
    print("unset")
elif not isinstance(sandbox["allow_docker"], bool):
    sys.exit("Ugyldig sandbox.allow_docker i global cplt-konfigurasjon.")
else:
    print("true" if sandbox["allow_docker"] else "false")
PY
)"
case "$global_docker" in
  false)
    echo "Advarsel: Global sandbox.allow_docker = false overstyrer hovedrepoets Docker-godkjenning."
    echo "Kjør utenfor sandboksen: cplt config unset --global sandbox.allow_docker"
    echo "Skriptet lagrer fortsatt repo-godkjenningen, men endrer ikke den globale innstillingen."
    ;;
  true)
    echo "Advarsel: Global sandbox.allow_docker = true gir Docker-tilgang også uten hovedrepoets godkjenning."
    echo "Skriptet lagrer fortsatt repo-godkjenningen, slik at den beholdes hvis du fjerner den globale innstillingen."
    echo "Skriptet endrer ikke den globale innstillingen."
    ;;
esac
echo "Eksisterende registreringer beholdes. Ingen repoer klones eller endres."
printf 'Godkjenner Docker-forslaget i %s/.cplt.toml lokalt for hovedrepoet.\n' "$ROOT_REPO_DIR"
echo "Docker-tilgangen gjelder hele sandboksøkten som startes fra hovedrepoet, ikke bare testene i repos/."
echo "En separat sandboksøkt som startes fra et annet repo, arver ikke denne tilgangen, men kan ha egne eller globale tillatelser."
echo "Docker-tilgang gir tilgang til daemon-socketen og ~/.docker, som kan inneholde innloggingsdata for containerregistre."
echo "Containermonteringer kan omgå sandboksen."
if [ "$DRY_RUN" = true ]; then
  echo "Forhåndsvisning: ingen konfigurasjon er endret."
  exit 0
fi

printf 'Registrere repoene og godkjenne Docker-tilgang for %s? [y/N] ' "$ROOT_REPO_DIR"
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
if ! cplt trust accept allow_docker; then
  echo "Docker-godkjenning feilet. Repo-registreringen er allerede lagret. Se feilmeldingen fra cplt over." >&2
  exit 1
fi
if [ "$global_docker" = false ]; then
  echo "Docker-forslaget er godkjent lokalt, men den globale innstillingen blokkerer fortsatt Docker-tilgang."
  echo "Før du starter en ny sandboksøkt, kjør utenfor sandboksen: cplt config unset --global sandbox.allow_docker"
else
  echo "Docker-tilgang er godkjent og aktiveres automatisk i neste sandboksøkt som startes fra hovedrepoet."
  echo "Dette gjør det mulig å kjøre Docker-avhengige tester i registrerte repoer under repos/."
fi
echo "Tilgangen gjelder hele økten. Separate økter som startes fra andre repoer, arver ikke denne godkjenningen."
echo "Du kan trekke tilbake godkjenningen med: ./scripts/setup-cplt-repos.sh --revoke-docker"
echo "Repoene er registrert. Start en ny cplt-sesjon fra $ROOT_REPO_DIR."
