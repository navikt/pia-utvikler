#!/usr/bin/env bash

# Team-Pias repos to clone
REPOS=(
  "https://github.com/navikt/fia-arbeidsgiver.git"
  "https://github.com/navikt/fia-datafortelling.git"
  "https://github.com/navikt/fia-dokument-publisering.git"
  "https://github.com/navikt/forebyggingsplan.git"
  "https://github.com/navikt/ia-datafortelling.git"
  "https://github.com/navikt/ia-felles.git"
  "https://github.com/navikt/ia-tjenester-metrikker.git"
  "https://github.com/navikt/lydia-api.git"
  "https://github.com/navikt/pia-actions"
  "https://github.com/navikt/pia-bigquery-sink.git"
  "https://github.com/navikt/pia-brreg-oppdaterer.git"
  "https://github.com/navikt/pia-dvh-import.git"
  "https://github.com/navikt/pia-frontend-monorepo.git"
  "https://github.com/navikt/pia-jobbsender.git"
  "https://github.com/navikt/pia-pdfgen.git"
  "https://github.com/navikt/pia-survey.git"
  "https://github.com/navikt/pia-sykefravarsstatistikk.git"
)

clone_repo() {
  local repo_url="$1"
  local repo_name
  local repo_path

  repo_name=$(basename "$repo_url" .git)
  repo_path="$REPOS_DIR/$repo_name"

  if [ -d "$repo_path" ]; then
    echo -e "${YELLOW}⟳${NC} $repo_name eksisterer allerede — oppdaterer..."
    if git -C "$repo_path" pull --ff-only --quiet 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} Oppdatert"
    else
      echo -e "  ${RED}✗${NC} Kunne ikke oppdatere (sjekk lokale endringer)"
    fi
  else
    echo -e "${GREEN}⬇${NC} Kloner $repo_name..."
    if git clone --quiet "$repo_url" "$repo_path"; then
      echo -e "  ${GREEN}✓${NC} Klonet"
    else
      echo -e "  ${RED}✗${NC} Kloning feilet"
      return 1
    fi
  fi

  if [ -f "$repo_path/setup.sh" ]; then
    echo -e "  ${YELLOW}⚙${NC}  Kjører setup.sh..."
    (cd "$repo_path" && bash setup.sh)
  fi

  if [[ "$repo_name" == "pia-frontend-monorepo" ]]; then
    echo -e "  ${YELLOW}📦${NC} Installerer frontend-avhengigheter..."
    (cd "$repo_path" && pnpm install --frozen-lockfile)
  fi
}

clone_main() {
  set -euo pipefail

  local script_dir
  local repos_dir
  local repo_url
  local repo_name
  local output_file
  local failed=0
  local i
  local -a pids=()
  local -a output_files=()

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repos_dir="$script_dir/../repos"
  mkdir -p "$repos_dir"
  REPOS_DIR="$(cd "$repos_dir" && pwd)"

  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  NC='\033[0m'

  echo "📁 Kloner pia-repoer til: $REPOS_DIR"
  echo ""

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT

  for repo_url in "${REPOS[@]}"; do
    repo_name=$(basename "$repo_url" .git)
    output_file="$temp_dir/$repo_name"

    clone_repo "$repo_url" >"$output_file" 2>&1 &
    pids+=("$!")
    output_files+=("$output_file")
  done

  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      failed=$((failed + 1))
    fi
    cat "${output_files[$i]}"
  done

  echo ""
  if [ "$failed" -gt 0 ]; then
    echo -e "${RED}✗${NC} Ferdig med $failed feil"
    exit 1
  fi

  echo "✅ Ferdig!"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  clone_main "$@"
fi
