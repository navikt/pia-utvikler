#!/usr/bin/env bash
# Morgenrutine: kobler til naisdevice, logger inn i Nais og oppdaterer Homebrew-pakker.

# -e: avslutt med en gang en kommando feiler (exit-kode som ikke er 0)
# -u: behandle variabler som ikke er satt som feil (fanger skrivefeil som $attmept)
# -o pipefail: en pipeline feiler hvis NOEN av kommandoene i den feiler, ikke bare den siste
set -euo pipefail

# trap ... ERR kjører denne koden når en kommando feiler og -e er i ferd med å avslutte.
# status=$? lagrer exit-koden til kommandoen som feilet, før echo overskriver $?.
# >&2 skriver meldingen til stderr. exit "$status" beholder den opprinnelige exit-koden.
# Merk: ERR utløses IKKE for kommandoer i en if-betingelse eller i en && / ||-liste.
trap 'status=$?; echo "Morgenoppsettet feilet." >&2; exit "$status"' ERR

# || true: hilsenen skal ikke stoppe skriptet hvis Sara-stemmen mangler.
say -v Sara 'God morgen!' || true

for attempt in {1..3}; do
    if nais device connect; then
        break
    fi
    if [[ $attempt -eq 3 ]]; then
        echo "Tilkobling til naisdevice feilet etter 3 forsøk." >&2
        exit 1
    fi
    echo "Tilkobling til naisdevice feilet (forsøk $attempt/3), prøver igjen om 5 sekunder..."
    sleep 5
done

# En vanlig kommando: feiler den, stopper -e skriptet og ERR-trap skriver meldingen.
nais auth login

# a && b || { ... }: kjør upgrade bare hvis update lyktes. Feiler en av dem, kjøres blokken.
# Fordi de står i en ||-liste, utløses ikke ERR-trap, så blokken håndterer feilen selv.
brew update && brew upgrade || {
    status=$?
    echo "Oppdatering og oppgradering med Homebrew feilet." >&2
    exit "$status"
}

echo "Morgenoppsettet er ferdig."
