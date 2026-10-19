# Sjekkliste for nye utviklere — Team Pia

Velkommen til Team Pia! Følg denne sjekklisten for å komme i gang med Pia-porteføljen.
Spør en kollega dersom noe er uklart — vi hjelper gjerne.

---

## 🔑 Tilganger (be om hjelp fra leder eller teammedlem)

- [ ] Tilgang til GitHub-organisasjon [navikt](https://github.com/navikt) og
  team [pia](https://github.com/orgs/navikt/teams/pia)
- [ ] Tilgang til [Nais console](https://console.nav.cloud.nais.io) — namespace `pia` i dev og prod
- [ ] Azure AD-grupper: teamPiaGroup og lese tilgang i Prod (TODO: legg til navn til AD-grupper)
- [ ] Tilgang til [Grafana](https://grafana.nav.cloud.nais.io) for overvåking
- [ ] Invitasjon til relevante Slack-kanaler

---

## 🛠 Verktøy

Kjør `./scripts/doctor.sh` — det sjekker hva som mangler automatisk.

Manuell sjekkliste:

- [ ] [Homebrew](https://brew.sh) er installert (`/opt/homebrew/bin/brew` eller `/usr/local/bin/brew`)
- [ ] `kind` — `brew install kind`
- [ ] `tilt` — `brew install tilt`
- [ ] `kubectl` — `brew install kubectl`
- [ ] `gcloud` — [installer fra Google](https://cloud.google.com/sdk/docs/install)
- [ ] `k9s` — `brew install k9s` (valgfritt, men anbefalt)
- [ ] Java 25 — `brew install --cask temurin@25`
- [ ] Node.js LTS — `brew install node`
- [ ] pnpm — `corepack enable` (etter Node er installert)

---

## 📂 Lokal oppsett

- [ ] Klon `pia-utvikler`: `git clone git@github.com:navikt/pia-utvikler.git`
- [ ] Klon alle pia-repoer: `./scripts/clone-repos.sh`

---

## 📚 Les deg opp

- [ ] [Nais docs](https://docs.nais.io) — plattformdokumentasjon
- [ ] [Aksel designsystem](https://aksel.nav.no) — UI-komponenter

---

## ✅ Du er klar når

- [ ] Alle verktøy er installert og fungerer (`./scripts/doctor.sh`)

---

> Problemer med oppsettet? Se [docs/SETUP.md](../SETUP.md) eller spør i `#team-pia-intern` 🔒på Slack.