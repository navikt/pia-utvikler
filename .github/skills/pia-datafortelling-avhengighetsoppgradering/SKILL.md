---
name: pia-datafortelling-avhengighetsoppgradering
description: Periodisk avhengighetsoppgradering og patching av sårbarheter i Python-baserte datafortellinger med uv og Quarto. Dekker separat branch, lokale kontroller, valgfri prod-copy, eksisterende deploy-løp og manuell merge. Bruk ved vedlikehold av både interne utviklersider og datafortellinger som må verifiseres i en parallell instans først.
---

# Avhengighetsoppgradering for datafortellinger

Bruk denne fremgangsmåten for Python-baserte datafortellinger med uv og Quarto. Den bygger på vedlikeholdsrunden i `navikt/fia-datafortelling` i november 2026, men kan brukes i andre repoer. Hent alltid dagens versjoner, varsler og workflow-betingelser; ikke gjenbruk gamle versjonsnumre, repo-navn eller branch-navn.

Standard arbeidsdeling: Assistenten kartlegger, patcher og lager lokale commits etter avtale. Brukeren pusher, følger deploymenten, kontrollerer innholdet og merger manuelt i GitHub GUI. Ikke overta push, deployment eller merge uten eksplisitt beskjed.

## 1. Avklar omfang og opprett branch

Les `git status --short --branch` og kontroller staging før endringer. Bevar eksisterende endringer og nye filer fra blant annet `nav-pilot synk`. Ikke stash, slett eller inkluder dem automatisk.

Avklar om runden gjelder bestemte sårbarheter eller bredere periodiske oppgraderinger. Start med HIGH-varsler når brukeren ber om det, og meld fra om CRITICAL-varsler som oppdages. Hold dev-avhengigheter utenfor en avtalt runtime-patch.

Opprett en ny lokal branch fra repoets oppdaterte standardbranch, for eksempel `origin/main`, ikke fra en gammel patch-branch. Hent siste remote-status før branch-opprettelsen. Stopp hvis lokale endringer hindrer et trygt branch-bytte. Under cplt må gjeldende regler for worktrees og repo-scope følges; ikke bruk en midlertidig mappe som erstatning for en vedvarende checkout.

Les `pyproject.toml`, `uv.lock` og tilgjengelige Python-, Docker-, pre-commit- og workflow-konfigurasjoner før du velger endringer. Kontroller aktiv Python- og uv-versjon mot repoets krav og eventuelle verktøypinner.

Finn ut om prosjektet har en fungerende prod-copy. Hvis ikke, hopp over steg 4 og bruk løpet uten prod-copy i steg 7. Ikke opprett en kopi eller endre CI/Nais for å innføre en. Avklar om kort nedetid ved ordinær deploy er akseptabelt, og hvordan en feil skal rulles tilbake. En intern utviklerside kan følge dette løpet uten å kreve en parallell instans.

## 2. Kartlegg sårbarheter

Hent åpne Dependabot-varsler fra repoet du faktisk arbeider i, med paginering:

```bash
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
gh api --paginate "repos/${repo}/dependabot/alerts?state=open&severity=high&per_page=100"
```

Ta også med tilgjengelige image-/Trivy-funn. For hvert funn: noter GHSA/CVE, severity, faktisk låst eller installert versjon, dependency path, runtime/dev, første relevante patchede versjon og kilde. Skill bekreftet berørt versjon fra bekreftet utnyttbarhet. Ikke stol på GitHubs runtime/dev-merking uten å kontrollere grafen og Docker-installasjonen.

For Debian-pakker må du finne full pakkeversjon med revisjon, distro/suite, berørt image og scannerens `Fixed Version`. Kontroller Debian Security Tracker for den aktuelle CVE-en og suiten. Siste stable-security-pakke kan fortsatt være sårbar. En rettelse i sid/forky er ikke en tilgjengelig trixie-patch.

Les eksisterende APT-steg og byggeloggen før du endrer Dockerfile. Ikke legg inn en redundant `apt-get upgrade`, bland inn pakker fra en annen Debian-suite, bytt baseimage eller undertrykk scannerfunn som snarvei. Rapporter manglende tilgjengelig patch som gjenstående arbeid, ikke som løst.

## 3. Oppgrader målrettet med uv

Verifiser foreslåtte versjoner mot PyPI før endring. Kontroller at de finnes, er stabile, ikke er yanket og passer Python- og foreldrekravene.

Oppdater direkte pins i `pyproject.toml` når nødvendig. La uv generere låsefilen. Transitive sikkerhetspatcher kan relåses målrettet uten å legges til som direkte avhengigheter:

```bash
uv lock --upgrade-package 'pakkenavn==verifisert-versjon'
```

Erstatt eksempelets pakke og versjon med de verifiserte verdiene. Samle relaterte pakker i samme resolver-kjøring når kravene binder dem sammen. Ikke bruk global `--upgrade` for en avgrenset sikkerhetspatch.

Sammenlign pakkenavn og versjoner før og etter. Bare avtalte pakker og nødvendige resolver-følgeendringer skal flytte seg. Bevar lock-format, Python-krav, verktøypinner og øvrige avhengigheter med mindre endringen er avtalt. Ikke oppgrader OS, baseimage eller framework-major uten egen avklaring.

## 4. Koble branchen til prod-copy, hvis den finnes

Dette steget gjelder bare prosjekter med eksisterende prod-copy. Uten prod-copy skal ingen branch-trigger, deploy-jobb eller manifest opprettes som erstatning.

Les workflowen som deployer kopien. I `fia-datafortelling` ligger jobben `deploy-prod-copy-branch` i `.github/workflows/deploy.yml`; den er ikke en separat workflow. Andre repoer kan ha andre navn og filbaner.

Bruk navnet fra `git branch --show-current` i kopiens push-trigger og tilhørende branch-betingelser. I `fia-datafortelling` gjaldt dette `render-smoke-test-branch`, `trivy-scan-prod-copy` og `deploy-prod-copy-branch`, totalt fire forekomster i november 2026. Kontroller dagens struktur fremfor å stole på antallet eller navnene.

Bevar ordinær deploy-trigger uendret, slik at oppgraderingsbranchen bare deployer kopien. Ikke endre deploy-rekkefølge, permissions, secrets, actions eller skannepolicy som en del av branch-navnebyttet. Valider YAML og kontroller alle branch-betingelsene.

Kontroller kopiens manifest og variabler før push. I `fia-datafortelling` er disse `.nais/nais-prod-copy.yaml` og `.nais/prod-copy.yaml`. Kopien skal bruke sitt eget jobbnavn og sin egen Quarto-ressurs uten å overskrive den ordinære datafortellingen. Ved endrede mål eller rettigheter: avklar dem med brukeren. En lite kjent URL er ikke tilgangskontroll. Ikke skriv tokenverdier i kode, logger eller samtalen.

## 5. Kontroller lokalt

Kjør repoets eksisterende kontroller. For uv-/pytest-/Quarto-oppsettet brukes:

```bash
uv lock --check
uv sync --frozen
uv run --frozen pytest
uv pip check
uv run --frozen quarto render index.qmd
git diff --check
```

Bruk repoets faktiske render-fil hvis den ikke heter `index.qmd`. Ikke innfør nye testverktøy eller hooks fordi et annet prosjekt har dem.

Hvis pre-commit er konfigurert, kjør det på de faktiske endrede filene. Når bare låsefilen er endret:

```bash
uv run --frozen pre-commit run --files uv.lock
```

Utvid fillisten hvis manifest eller workflow også er endret. Hvis hooks endrer filer, inspiser endringene og kjør kontrollen på nytt. Ikke bruk `main.py` som lokal røyktest; det kan laste opp datafortellingen.

Rapporter manglende Quarto eller sandbox-avslag som blokkerte kontroller. Ikke omgå cplt, deaktivere hooks eller svekke beskyttelsen. Gi brukeren den konkrete kommandoen som må kjøres utenfor sandbox. Skill brukerbekreftet utførelse fra selvstendig verifisert output.

## 6. Commit bare avtalte filer

Gjennomgå diffen for secrets, utilsiktede følgeendringer og endret deploy-mål. Bruk eksplisitte filbaner med `git add --`, aldri `git add .`, `git add -A` eller `git commit -a`.

Kontroller `git diff --cached --name-only` og `git diff --cached` før commit. Hvis staging allerede inneholder uvedkommende arbeid, stopp og avklar; ikke fjern brukerens staging automatisk. Nye nav-pilot-filer skal ikke følge med en avhengighetscommit.

Lag en Conventional Commit med repoets påkrevde trailer. Kontroller commit-innholdet etterpå og oppgi hash. Ikke push når brukeren har ansvar for det.

## 7. Deploy og verifiser etter prosjektets løp

Følg deploymenten bare hvis det er avtalt. Registrer branch, commit, workflow-run og image-digest når de er tilgjengelige. Avklar på forhånd om push til en branch eller merge til standardbranchen utløser ordinær deploy.

### Med prod-copy

Etter brukerens push: kontroller at ordinær deploy er hoppet over, at kopiens jobb lykkes, og at opplastingen går til riktig Quarto-ressurs.

Be brukeren kontrollere prod-copy-siden: innhold, figurer og navigasjon. Hold vellykket deploy-jobb og godkjent innhold som separate bekreftelser. Ved feil: ikke merge eller deploy ordinær produksjon. Rett feilen på branchen eller avtal rollback til et kjent fungerende prod-copy-image.

Når kopien er godkjent, merger brukeren manuelt i GitHub GUI. En bekreftet merge beviser ikke at påfølgende ordinær deployment er vellykket. Kontroller den separat hvis oppgaven omfatter ordinær produksjon.

### Uten prod-copy

Lokale kontroller og avtalt risiko må være avklart før push eller merge som utløser ordinær deploy. Behold prosjektets eksisterende deploy-løp; ikke endre det til prod-copy.

Hvis merge er deploy-triggeren, merger brukeren etter godkjente lokale kontroller og nødvendige CI-sjekker. Deretter følges den ordinære deploymenten, og brukeren kontrollerer innhold, figurer og navigasjon på den faktiske siden. Ikke krev verifisert prod-copy før merge når ingen kopi finnes.

Hvis ordinær deploy skjer fra oppgraderingsbranchen, kontrolleres deployment og side etter den aktuelle pushen. Ved feil: meld fra, og avtal retting eller rollback til kjent fungerende commit/image. At kort nedetid er akseptabelt, erstatter ikke tester, synlig feilrapportering eller innholdskontroll.

### Felles kontroller

Grønn workflow er ikke bevis på at HIGH-varsler er borte. Prod-copy-gaten i `fia-datafortelling` kontrollerte bare fikserbare CRITICAL-funn i november 2026. Kontroller det aktuelle prosjektets severity- og ignore-unfixed-innstillinger, og verifiser aktuelle HIGH-funn mot det nye imaget eller en oppdatert rapport.

Ikke slett branch eller oppdater lokal checkout automatisk etter brukerens merge.

## 8. Avslutt med etterprøvbar status

Oppgi oppgraderte pakker med fra-/til-versjon, kontroller og exitkoder, commit og hvem som har bekreftet push, deployment, innhold og merge. Oppgi også gjenstående sårbarheter og hva som hindrer patching. Hvis prosjektet ikke har prod-copy, merk kopistegene som ikke aktuelle, ikke som blokkerte eller ufullførte.

Skill utført arbeid fra neste steg. Ikke merk en kontroll som bestått fordi den var planlagt eller fordi deployment-gaten var grønn. Ved feil etter merge: avklar en revert gjennom vanlig PR-/merge-prosess, ikke omskriving av Git-historikk.
