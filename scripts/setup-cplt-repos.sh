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
    echo "Legger bare til manglende repoer og godkjenner Docker-forslaget hvis godkjenningen mangler."
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

info() {
  printf '[oppsett] %s\n' "$*"
}

run_cplt() {
  local output_mode="$1"
  shift
  printf '\n[kommando] cplt' >&2
  printf ' %q' "$@" >&2
  printf '\n' >&2
  if [ "$output_mode" = capture ]; then
    local command_output
    local command_status=0
    command_output="$(cplt "$@" 2> >(sed 's/^/  | /' >&2))" || command_status=$?
    if [ "$command_status" -ne 0 ]; then
      if [ -n "$command_output" ]; then
        printf '%s\n' "$command_output" | sed 's/^/  | /' >&2
      fi
      return "$command_status"
    fi
    printf '%s\n' "$command_output"
  else
    cplt "$@" 2>&1 | sed 's/^/  | /'
  fi
}

if [ -n "${__CPLT_WRAPPED:-}" ]; then
  info "Kjør skriptet i en vanlig terminal utenfor cplt-sandboksen." >&2
  exit 1
fi
if ! command -v cplt >/dev/null 2>&1; then
  info "Fant ikke cplt i PATH. Installer cplt før du kjører skriptet." >&2
  exit 1
fi

if [ "$REVOKE_DOCKER" = true ]; then
  cd "$ROOT_REPO_DIR"
  if ! run_cplt display trust revoke allow_docker; then
    info "Kunne ikke trekke tilbake Docker-godkjenningen. Se feilmeldingen fra cplt over." >&2
    exit 1
  fi
  info "Docker-godkjenningen for hovedrepoet er trukket tilbake for fremtidige sandboksøkter."
  info "Kjørende økter beholder tilgangen til de avsluttes. Andre lokale eller globale Docker-tillatelser påvirkes ikke."
  exit 0
fi

if [ -L "$REPOS_DIR" ]; then
  info "repos/ er en symbolsk lenke. Bruk en vanlig katalog under prosjektet." >&2
  exit 1
fi
if [ ! -d "$REPOS_DIR" ]; then
  info "Fant ikke $REPOS_DIR. Kjør scripts/clone-repos.sh først." >&2
  exit 1
fi

repo_paths=()
for repo_path in "$REPOS_DIR"/* "$REPOS_DIR"/.[!.]* "$REPOS_DIR"/..?*; do
  [ -d "$repo_path" ] || continue
  if [ -L "$repo_path" ]; then
    info "Hopper over symbolsk lenke: $repo_path"
    continue
  fi
  [ -e "$repo_path/.git" ] || continue
  repo_paths+=("$repo_path")
done

if [ "${#repo_paths[@]}" -eq 0 ]; then
  info "Fant ingen Git-repoer direkte under $REPOS_DIR." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  info "Fant ikke python3 i PATH. Skriptet krever Python 3.11 eller nyere." >&2
  exit 1
fi

cd "$ROOT_REPO_DIR"
if ! local_config="$(run_cplt capture config path --local)"; then
  info "Kunne ikke finne stien til lokal cplt-konfigurasjon." >&2
  exit 1
fi
repo_output="$(python3 - "$local_config" "$LIST_ONLY" "${repo_paths[@]}" <<'PY'
import os
from pathlib import Path
import sys

if sys.version_info < (3, 11):
    sys.exit("[oppsett] Skriptet krever Python 3.11 eller nyere.")

import tomllib

config_path = Path(sys.argv[1])
try:
    with config_path.open("rb") as config_file:
        config = tomllib.load(config_file)
except FileNotFoundError:
    config = {}
except (OSError, tomllib.TOMLDecodeError):
    sys.exit(f"[oppsett] Kunne ikke lese lokal cplt-konfigurasjon: {config_path}")

sandbox = config.get("sandbox", {})
if not isinstance(sandbox, dict):
    sys.exit("[oppsett] Ugyldig sandbox-seksjon i lokal cplt-konfigurasjon.")
registered = sandbox.get("repo_dirs", [])
if not isinstance(registered, list) or not all(isinstance(path, str) for path in registered):
    sys.exit("[oppsett] Ugyldig sandbox.repo_dirs i lokal cplt-konfigurasjon.")

registered_paths = {os.path.realpath(os.path.expanduser(path)) for path in registered}
list_only = sys.argv[2] == "true"
found = False
for path in sys.argv[3:]:
    is_registered = os.path.realpath(path) in registered_paths
    if list_only:
        if is_registered:
            print(f"[oppsett]   {path}")
            found = True
    elif not is_registered:
        print(path)
if list_only and not found:
    print("[oppsett]   Ingen repoer under repos/ er registrert.")
PY
)"

if [ "$LIST_ONLY" = true ]; then
  info "Allerede registrerte repoer under repos/:"
  printf '%s\n' "$repo_output"
  exit 0
fi
missing_repos=()
while IFS= read -r repo_path; do
  if [ -n "$repo_path" ]; then
    missing_repos+=("$repo_path")
  fi
done <<< "$repo_output"

if ! global_config="$(run_cplt capture config path)"; then
  info "Kunne ikke finne stien til global cplt-konfigurasjon." >&2
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
    sys.exit(f"[oppsett] Kunne ikke lese global cplt-konfigurasjon: {config_path}")

sandbox = config.get("sandbox", {})
if not isinstance(sandbox, dict):
    sys.exit("[oppsett] Ugyldig sandbox-seksjon i global cplt-konfigurasjon.")
if "allow_docker" not in sandbox:
    print("unset")
elif not isinstance(sandbox["allow_docker"], bool):
    sys.exit("[oppsett] Ugyldig sandbox.allow_docker i global cplt-konfigurasjon.")
else:
    print("true" if sandbox["allow_docker"] else "false")
PY
)"
if ! trust_status="$(run_cplt capture trust show --json)"; then
  info "Kunne ikke lese Docker-godkjenningen. Se feilmeldingen fra cplt over." >&2
  exit 1
fi
docker_approved="$(python3 - "$trust_status" <<'PY'
import json
import sys

try:
    status = json.loads(sys.argv[1])
except json.JSONDecodeError:
    sys.exit("[oppsett] Ugyldig JSON-status fra cplt trust show --json.")
if (
    not isinstance(status, dict)
    or status.get("version") != 1
    or not isinstance(status.get("drifted"), bool)
    or not isinstance(status.get("proposed"), list)
):
    sys.exit("[oppsett] Ugyldig godkjenningsstatus fra cplt trust show --json.")

docker_approved = False
for permission in status["proposed"]:
    if (
        not isinstance(permission, dict)
        or not isinstance(permission.get("key"), str)
        or not isinstance(permission.get("approved"), bool)
    ):
        sys.exit("[oppsett] Ugyldig tillatelse i status fra cplt trust show --json.")
    if permission["key"] == "allow_docker":
        docker_approved = permission["approved"] and not status["drifted"]
print("true" if docker_approved else "false")
PY
)"

printf '\n'
info "Status"
if [ "${#missing_repos[@]}" -eq 0 ]; then
  info "Alle ${#repo_paths[@]} repoer under repos/ er registrert."
else
  info "${#missing_repos[@]} av ${#repo_paths[@]} repoer mangler registrering:"
  for repo_path in "${missing_repos[@]}"; do
    info "  $repo_path"
  done
fi
if [ "$docker_approved" = true ]; then
  info "Docker-forslaget er allerede godkjent for hovedrepoet."
else
  info "Docker-forslaget mangler en gjeldende godkjenning for hovedrepoet."
fi
case "$global_docker" in
  false)
    info "Advarsel: Global sandbox.allow_docker = false overstyrer hovedrepoets Docker-godkjenning."
    info "Kjør utenfor sandboksen: cplt config unset --global sandbox.allow_docker"
    info "Skriptet endrer ikke den globale innstillingen."
    ;;
  true)
    info "Advarsel: Global sandbox.allow_docker = true gir Docker-tilgang også uten hovedrepoets godkjenning."
    info "Repo-godkjenningen beholdes hvis du fjerner den globale innstillingen."
    info "Skriptet endrer ikke den globale innstillingen."
    ;;
esac
if [ "${#missing_repos[@]}" -eq 0 ] && [ "$docker_approved" = true ]; then
  info "Ingen konfigurasjon må lagres. Ingen skrivekommandoer kjøres."
  exit 0
fi

printf '\n'
info "Endringer som gjenstår"
if [ "${#missing_repos[@]}" -gt 0 ]; then
  info "Registrer ${#missing_repos[@]} manglende repoer. Eksisterende registreringer beholdes."
fi
if [ "$docker_approved" = false ]; then
  info "Godkjenn Docker-forslaget i $ROOT_REPO_DIR/.cplt.toml lokalt for hovedrepoet."
  info "Docker-tilgangen gjelder hele sandboksøkten som startes fra hovedrepoet, ikke bare testene i repos/."
  info "Separate økter fra andre repoer arver ikke denne godkjenningen, men kan ha egne eller globale tillatelser."
  info "Docker gir tilgang til daemon-socketen og ~/.docker, som kan inneholde innloggingsdata for containerregistre."
  info "Containermonteringer kan omgå sandboksen."
fi
if [ "$DRY_RUN" = true ]; then
  info "Forhåndsvisning: ingen konfigurasjon er endret."
  exit 0
fi

printf '\n[oppsett] Utføre endringene over? [y/N] '
answer=""
if ! IFS= read -r answer; then
  info "Ingen bekreftelse mottatt. Ingen konfigurasjon er endret." >&2
  exit 1
fi
case "$answer" in
  y|Y|yes|Yes) ;;
  *)
    info "Avbrutt. Ingen konfigurasjon er endret."
    exit 0
    ;;
esac

if [ "${#missing_repos[@]}" -gt 0 ]; then
  if ! run_cplt display config set --local sandbox.repo_dirs "${missing_repos[@]}"; then
    info "Registrering feilet. Se feilmeldingen fra cplt over." >&2
    exit 1
  fi
fi
if [ "$docker_approved" = false ]; then
  if ! run_cplt display trust accept allow_docker; then
    info "Docker-godkjenning feilet. Repo-registreringene er beholdt. Se feilmeldingen fra cplt over." >&2
    exit 1
  fi
fi
printf '\n'
info "Resultat"
if [ "$global_docker" = false ]; then
  info "Docker-forslaget er godkjent lokalt, men den globale innstillingen blokkerer fortsatt Docker-tilgang."
  info "Før du starter en ny sandboksøkt, kjør utenfor sandboksen: cplt config unset --global sandbox.allow_docker"
else
  info "Docker-forslaget er godkjent for neste sandboksøkt som startes fra hovedrepoet."
fi
info "Du kan trekke tilbake godkjenningen med: ./scripts/setup-cplt-repos.sh --revoke-docker"
info "Repoene er registrert. Start en ny cplt-sesjon fra $ROOT_REPO_DIR."
