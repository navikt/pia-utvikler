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

   Dette krever Git og SSH-tilgang til GitHub, samt `pnpm` for frontend-prosjektene.
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

## Portefølje

| Repo                                                                             | Teknologi           | Beskrivelse                                                      | Dokumentasjon |
|----------------------------------------------------------------------------------|---------------------|------------------------------------------------------------------|---------------|
| [lydia-api](https://github.com/navikt/lydia-api)                                 | Kotlin + Ktor       | Backend for fagsystem Fia: IA samarbeid med virksomheter i Norge |               |
| [lydia-rådgiver-frontend](https://github.com/navikt/lydia-radgiver-frontend)     | TypeScript + vite   | Frontend for fagsystem Fia                                       |               |
| [fia-arbeidsgiver-api](https://github.com/navikt/fia-arbeidsgiver-api)           | Kotlin + Ktor       | Backend — API for arbeidsgivere til Fia                          |               |
| [fia-arbeidsgiver-frontend](https://github.com/navikt/fia-arbeidsgiver-frontend) | TypeScript + NextJS | Frontend for kartlegginger i Fia                                 |               |

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
