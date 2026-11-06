# pia-utvikler

Inngangsport og utviklermiljø for utvikler i **Team Pia**.

> Team Pia utvikler både Fia og innloggede-sider under 'Forebygge og redusere fravær' på arbeidsgiver.nav.no
> Fia er et fagsystem for Nav-ansatte som tillrettelegger samarbeid mellom Nav og virksomheter i Norge om IA - Inkluderende arbeidsliv, med
> mål om å forebygge og redusere fravær

Denne repoen inneholder dokumentasjon for utviklere som ønsker å bidra til Team Pia sine prosjekter.

## Kom i gang med cplt

Hvis du bruker Copilot CLI gjennom cplt, kjør [`scripts/setup-cplt-repos.sh`](scripts/setup-cplt-repos.sh)
etter at du har klonet teamets repoer til `repos/`, og før du starter en cplt-sesjon fra `pia-utvikler`.
Bruker du ikke cplt, trenger du ikke dette steget.

### Logg inn på GitHub med HTTPS

Før du kloner teamets repoer, må du ha GitHub CLI (`gh`) installert og være logget inn
med HTTPS som Git-protokoll. Vi bruker ikke SSH-nøkler i cplt-sandboksen.
Sandboksen stenger tilgangen til SSH-nøklene dine, så Git bruker HTTPS med tokenet fra `gh`.

Kjør dette i en vanlig terminal utenfor cplt-sandboksen:

```sh
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

`gh auth setup-git` setter opp Git til å bruke innloggingen fra `gh`.
Se [guiden til Git og GitHub i sandboksen](https://ki-utvikling.nav.no/nav-pilot/guider/cplt-git).

Har du klonet repoene med SSH tidligere, endrer ikke kloneskriptet de eksisterende
remote-URL-ene. Sjekk med `git remote -v` i hvert repo. Viser den `git@github.com:`,
følg [guiden for Permission denied (publickey)](https://ki-utvikling.nav.no/nav-pilot/guider/cplt-feilmeldinger#publickey)
for å bytte til HTTPS utenfor sandboksen.

### Hvorfor registrere repoene?

Teamets prosjekter er egne Git-repoer under `repos/`. Skriptet registrerer dem i
`sandbox.repo_dirs` i den lokale cplt-konfigurasjonen for `pia-utvikler`, slik at cplt
kjenner dem som repoer i arbeidsområdet. Å klone `pia-utvikler` alene registrerer dem ikke.
Skriptet kloner ingen repoer og endrer ikke kildekoden.

### Slik kjører du skriptet

Bruk en vanlig terminal utenfor cplt-sandboksen. Du må ha `cplt` og Python 3.11 eller nyere i `PATH`.
Kjør kommandoene fra rotmappen til `pia-utvikler`.

1. Klon teamets repoer hvis du ikke allerede har dem under `repos/`:

   ```sh
   bash scripts/clone-repos.sh
   ```

   Skriptet kloner repoene over HTTPS. Dette krever Git og GitHub-innloggingen over,
   samt `pnpm` for frontend-prosjektene.
   Skriptet kjører også repoenes eventuelle `setup.sh` og installerer frontend-avhengigheter.
   Repoer som allerede finnes, oppdateres med `git pull --ff-only`.

2. Se hvilke repoer som vil bli registrert, uten å endre konfigurasjonen:

   ```sh
   bash scripts/setup-cplt-repos.sh --dry-run
   ```

3. Registrer repoene:

   ```sh
   bash scripts/setup-cplt-repos.sh
   ```

   Kontroller listen og svar `y` på bekreftelsen. Start deretter en ny cplt-sesjon fra `pia-utvikler`.

### Når må du kjøre det igjen?

Kjør skriptet på nytt når du legger til Git-repoer direkte under `repos/`, eller flytter
arbeidsområdet til en ny sti. Du trenger ikke kjøre det før hver økt eller etter en vanlig `git pull`.
Skriptet hopper over symbolske lenker og søker ikke i undermapper av repoene.

Se hvilke repoer under `repos/` som er registrert i den lokale konfigurasjonen:

```sh
bash scripts/setup-cplt-repos.sh --list
```

---

## Periodisk oppgradering av backend-avhengigheter

Annenhver uke kan du bruke Copilot fra roten av `pia-utvikler` til å oppgradere
backend-avhengighetene i teamets repoer under `repos/`. Repoene må være klonet.
Du trenger Git, GitHub CLI, riktig JDK for hvert repo og Docker for integrasjonstester.
Bruker du cplt, må repoene være registrert som beskrevet over.

Skriv:

```text
Kjør den periodiske backend-oppgraderingen. Bruk pia-dependency-upgrade.
```

Du kan også bruke [startprompten pia-oppgrader-backend](.github/prompts/pia-oppgrader-backend.prompt.md).
[Skillen pia-dependency-upgrade](.github/skills/pia-dependency-upgrade/SKILL.md)
beskriver repo-utvalg, versjonskontroll og arbeidsflyt. Den finner nye publiserte
versjoner hver runde, uten å bruke versjonsmål fra tidligere samtaler.

Copilot tester ett repo om gangen og stopper for review. Du godkjenner commit,
pusher selv og gir beskjed før arbeidet fortsetter med neste repo.
`ia-felles` holdes utenfor. Majoroppgraderinger krever egen godkjenning og egne
commits; container-images, CI og verktøypinner inngår ikke i rutinerunden.

Ved overlevering til en annen utvikler: lagre rundens status i et GitHub-issue
i `navikt/pia-utvikler`, og oppgi issuet når arbeidet gjenopptas.
Statusen skal vise versjonsmål, testresultater, commits, bekreftede push og
utsatte oppgraderinger per repo. Skillen inneholder formatet.
Følg [rundens statusformat](.github/skills/pia-dependency-upgrade/SKILL.md#5-status-og-overlevering)
også for repoer som allerede er oppdaterte eller er blokkert.

---

## Portefølje

| Repo                                                                       | Teknologi            | Beskrivelse                                                            | Dokumentasjon |
|----------------------------------------------------------------------------|----------------------|------------------------------------------------------------------------|---------------|
| [fia-arbeidsgiver](https://github.com/navikt/fia-arbeidsgiver)                 | Kotlin + Ktor        | Backend for arbeidsgivere i Fia                                         |               |
| [fia-arbeidsgiver-frontend](https://github.com/navikt/fia-arbeidsgiver-frontend) | TypeScript + Next.js | Frontend for kartlegginger i Fia                                        |               |
| [fia-dokument-publisering](https://github.com/navikt/fia-dokument-publisering) | Kotlin + Ktor        | Deling og arkivering av Fia-dokumenter til arbeidsgivere                 |               |
| [forebyggingsplan](https://github.com/navikt/forebyggingsplan)                 | Kotlin + Ktor        | Backend for forebyggingsplan                                            |               |
| [ia-felles](https://github.com/navikt/ia-felles)                               | Kotlin               | Bibliotek med felles definisjoner for IA-domenet                         |               |
| [ia-tjenester-metrikker](https://github.com/navikt/ia-tjenester-metrikker)     | Kotlin + Spring Boot | Mottar og lagrer metrikker fra IA-applikasjoner                          |               |
| [lydia-api](https://github.com/navikt/lydia-api)                               | Kotlin + Ktor        | Backend for fagsystemet Fia: IA-samarbeid med virksomheter i Norge        |               |
| [lydia-radgiver-frontend](https://github.com/navikt/lydia-radgiver-frontend)   | TypeScript + Vite    | Frontend for fagsystemet Fia                                            |               |
| [min-ia](https://github.com/navikt/min-ia)                                     | TypeScript + Next.js | Landingsside for selvbetjente IA-tjenester                               |               |
| [pia-actions](https://github.com/navikt/pia-actions)                           | GitHub Actions       | Gjenbrukbare actions for Team Pia                                       |               |
| [pia-bigquery-sink](https://github.com/navikt/pia-bigquery-sink)               | Kotlin + Ktor        | Lagrer Kafka-meldinger i BigQuery                                        |               |
| [pia-brreg-oppdaterer](https://github.com/navikt/pia-brreg-oppdaterer)         | Kotlin               | Naisjob som henter virksomhetsoppdateringer fra Brønnøysundregistrene     |               |
| [pia-dvh-import](https://github.com/navikt/pia-dvh-import)                     | Kotlin + Ktor        | Leser kvartalsvis sykefraværsstatistikk fra DVH                          |               |
| [pia-jobbsender](https://github.com/navikt/pia-jobbsender)                     | Kotlin               | Naisjob som sender forespørsler om engangsjobber via Kafka               |               |
| [pia-pdfgen](https://github.com/navikt/pia-pdfgen)                             | pdfgenrs + Handlebars | PDF-generator for dokumenter fra Fia                                    |               |
| [pia-survey](https://github.com/navikt/pia-survey)                             | Kotlin + Ktor        | Backend for spørreundersøkelser                                         |               |
| [pia-sykefravarsstatistikk](https://github.com/navikt/pia-sykefravarsstatistikk) | Kotlin + Ktor        | API for sykefraværsstatistikk                                            |               |

---

# Henvendelser

Spørsmål knyttet til koden eller prosjektet kan stilles som
et [issue her på GitHub](https://github.com/navikt/pia-utvikler/issues).

## For NAV-ansatte

Interne henvendelser kan sendes via Slack i kanalen #team-pia.

# Krediteringer

## Inspirasjon / utgangspunkt

Dette repoet er **veldig** inspirert av [navikt/watson-developer](https://github.com/navikt/watson-developer)

## Kode generert av GitHub Copilot

Dette repoet bruker GitHub Copilot til å generere kode.
