#!/usr/bin/env bash
set -euo pipefail

# Snarvei til scripts/clone-repos.sh — clone alle repoer.
# Bevisst unntak fra konvensjonen om at skript bor i scripts/: dette er kun en tynn
# wrapper som gir en kort kommando (./clone.sh)
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/clone-repos.sh" "$@"
