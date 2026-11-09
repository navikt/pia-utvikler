---
name: pia-dependency-upgrade
description: Kjør Team Pias periodiske backend-oppgradering fra pia-utvikler annenhver uke. Finn publiserte avhengighetsoppdateringer i repoene under repos/, test ett repo om gangen og stopp for review før commit. Hold ia-felles utenfor.
compatibility: Git, GitHub CLI, repoenes Gradle-wrapper, riktig JDK og Docker for integrasjonstester
---

# Periodisk backend-oppgradering

Bruk denne skillen fra roten av `pia-utvikler` når utvikleren ber om den
periodiske backend-oppgraderingen. Den beskriver teamets arbeidsflyt, også for
Gradle-prosjekter uten låsefil og for begrunnede transitive oppgraderinger.
Ikke bruk den generelle `dependency-upgrade`-skillen som en ekstra prosedyre.

## Omfang og avgrensninger

- Finn teamets repoer i [kloneskriptet](../../../scripts/clone-repos.sh).
  Undersøk backend-applikasjoner med Gradle under `repos/`.
  Ta med repoer som ikke trengte oppdatering forrige runde.
- Biblioteket `ia-felles` inngår ikke i runden. Ikke oppdater avhengigheten
  `com.github.navikt:ia-felles` i andre repoer heller.
- Rapporter manglende lokale repoer og repoer utenfor omfanget, med årsak.
  Ikke klon eller kjør oppsettsskript uten avtale.
- Oppgrader patch- og minorversjoner. Vis tilgjengelige majoroppgraderinger,
  men gjennomfør dem bare etter uttrykkelig godkjenning, i separate commits.
- Behold container-images, Gradle-wrapper, verktøypinner, CI og Nais-konfigurasjon.
  Ikke endre databaser eller Kafka-konfigurasjon som del av runden.
- Behold kompatibilitetsvarianter som `kotlinx-datetime` med `-compat`.
  Ikke erstatt dem med standardvarianten som en vanlig versjonsoppdatering.
- Ikke endre applikasjonslogikk, auth eller testatferd for å få en
  rutineoppgradering gjennom. Stopp og avtal en separat oppgave hvis det trengs.

## 1. Kartlegg hele runden før du endrer filer

Les instruksjonene i hvert repo, byggfilene, eventuelle versjonskataloger og
låsefiler, samt CI-kommandoen og JDK-versjonen. Kontroller Git-status, branch
og forholdet til remote. Ikke bytt branch med lokale endringer, overskriv arbeid,
stash, rebase eller tilbakestill commits. Be om avklaring hvis arbeidsområdet
ikke er klart. Oppdater bare et rent utgangspunkt med fast-forward etter avtale.

Finn nye versjoner for alle direkte avhengigheter og eksisterende constraints
eller BOM-overstyringer. Bruk Maven Central, deklarerte pakkeregistre og
publiserte releaser, ikke versjoner fra en tidligere samtale.

- Kontroller at målversjonens POM faktisk finnes i registeret.
  For JitPack-avhengigheter som er innenfor omfanget, kontroller også artefakten.
  En Git-tag alene er ikke bevis på at avhengigheten kan hentes.
- Utelukk release-utkast og prereleases. Hvis repoet allerede bruker en
  alpha-/beta-versjon, behold den versjonslinjen og kontroller oppdateringer der.
- Les relevante release-notater. Rapporter brudd og usikkerhet før endring.
  En nyere versjon er ikke i seg selv et bekreftet sikkerhetsfunn.
- Gjenbruk release-vurderingen for samme koordinat og målversjon innenfor runden.
  Registrer kilder, kompatibilitetsendringer og hva utvikleren har godkjent.
  Vurder på nytt hvis et repo har andre relevante forutsetninger.
- Avgrens letingen etter release-notater til offisiell release-historikk,
  upstream-releaser og changelog. Hvis målversjonen mangler der, marker
  oppgraderingen som utsatt med kildene som er sjekket. Ikke gjenta letingen
  i senere repoer uten nye opplysninger.
- Lag en felles måltabell for runden med koordinat, nåværende versjoner,
  verifisert målversjon og kilde. Ikke nedgrader repoer som allerede ligger foran.
  Avklar eventuelle konflikter mellom majorversjoner.

Vis repooversikten med antall repoer som trenger arbeid, er oppdaterte,
er blokkert eller er utenfor omfanget. Start deretter med første repo.
Hvis et nytt versjonsmål kommer til underveis, marker allerede behandlede
repoer som må vurderes på nytt. Ikke regn dem som oppdaterte mot det nye målet.

## 2. Oppgrader ett repo om gangen

Bruk `./gradlew`, aldri en global Gradle-installasjon. Ta vare på en
avhengighetsrapport fra før endringen for å skille direkte og transitive
avhengigheter fra rene constraints.

```sh
./gradlew dependencies --configuration runtimeClasspath --console=plain
./gradlew dependencies --configuration testRuntimeClasspath --console=plain
```

For repoer med andre konfigurasjoner, bruk de relevante runtime-konfigurasjonene.
Kontroller rapportene for `FAILED`, også når kommandoen gir exit 0.
`requested -> selected` betyr at den siste versjonen er valgt.
En linje merket `(c)` er en constraint, ikke bevis på at biblioteket brukes.

Oppdater direkte avhengigheter først. Hold Kotlin-plugins og Kotlin-testbiblioteker
på samme versjon. Bruk eksisterende versjonsvariabler og kataloger.
Ikke endre ubrukte katalogoppføringer.

For transitive avhengigheter: foretrekk oppgradering av avhengigheten eller BOM-en
som trekker dem inn. Endre eller legg til en constraint bare når artefakten
faktisk brukes og det finnes et begrunnet versjonsmål. Legg testavhengigheter i
`testImplementation`, ikke i produksjonskonfigurasjonen.
Ikke legg til biblioteket som en direkte avhengighet for å tvinge versjonen.

I Spring-prosjekter må du kontrollere eksisterende dependency management.
Bruk repoets BOM-er eller versjonsegenskaper der de styrer oppløsningen.
Ikke anta at en vanlig Gradle-constraint overstyrer dem.
Hvis repoet bruker dependency locking, oppdater eksisterende låser med
Gradles låsemekanisme. Ikke innfør nye låsefiler som del av runden.

## 3. Verifiser endringen

Kjør repoets bygg og tester, normalt `./gradlew build`, og CI-oppgaver som
ikke dekkes av bygget. Mange av repoene bruker `./gradlew test installDist`.
Bruk riktig JDK og kontroller at Docker er tilgjengelig før integrasjonstester.

- Les testresultatene. Rapporter antall kjørte, feilede og hoppede tester.
  Skill mellom kjørte tester, cache og `UP-TO-DATE`; ikke kall dem nye testkjøringer.
- Ved feil, undersøk om oppgraderingen er årsaken. Ikke fjern eller svekk tester,
  legg til retries eller øk tidsgrenser for å få grønt bygg. Rapporter blokkeringen.
  Ikke påstå at en feil var der fra før uten belegg fra utgangspunktet.
- Kontroller faktisk oppløste runtime- og testversjoner etter endringen.
  Sjekk også tilknyttede moduler, som Jackson core/databind, Logback core/classic,
  Flyway og Testcontainers. Deklarerte versjoner alene er ikke tilstrekkelig.
- Sammenlign modulfamiliene før og etter endringen. Skill nye blandinger av
  modulversjoner fra dem som allerede fantes. Ikke innfør en BOM, som Netty-BOM,
  automatisk for å samordne en eksisterende blanding. Avtal det som en separat
  endring. Beståtte tester beviser ikke at alle modulkombinasjoner er kompatible.
- Kontroller `git diff --check`, diffen og Git-status, inkludert nye filer.
  Ingen filer utenfor den avtalte endringen skal stages eller committes.
- Registrer nye advarsler eller kompatibilitetsrisikoer. Rapporter hvilke
  sikkerhetsskanninger som faktisk er kjørt, og hvilke som ikke er kjørt.

Ved sandbox-avslag: oppgi kommando, sti og feilmelding, og stopp den blokkerte
operasjonen. Ikke prøv å omgå avslaget eller les hemmeligheter for å løse det.

## 4. Review, commit og push

Vis en tabell med avhengighet, fra-versjon, valgt versjon og status.
Bruk faktisk oppløste versjoner før og etter i tabellen. Hvis en deklarert
versjon eller constraint avviker fra den oppløste versjonen, oppgi begge.
Oppgi endrede filer, verifiseringskommandoer med resultat og utsatte oppgraderinger.
Stopp for utviklerens review før commit.

Etter uttrykkelig godkjenning: les diffen på nytt, integrer eventuelle
utviklerendringer og kjør relevant verifisering igjen hvis innholdet er endret.
Commit bare de godkjente filene med Conventional Commits og påkrevd
`Co-authored-by`-trailer. Ikke amend tidligere commits.

Oppgi commit-hash og Git-status. Ikke push. Vent til utvikleren bekrefter at
endringen er pushet og ber om neste repo. En forespørsel om å starte runden
er ikke godkjenning av commits eller push.

Skill mellom lokalt bygg, CI og deployment i statusen. Et bestått lokalt bygg
betyr ikke at deployment har lykkes. Etter push kontrollerer du relevante
workflow-resultater hvis det er avtalt med utvikleren. Ellers oppgir du at de
ikke er kontrollert. Hold deployfikser i separat avtalte oppgaver og commits,
uten å utvide avhengighetsoppgraderingen.

## 5. Status og overlevering

Bruk rundens GitHub-issue i `navikt/pia-utvikler` hvis utvikleren oppgir et.
Be om godkjenning før du oppretter eller oppdaterer et issue. Uten et avtalt
issue leverer du statusen i samtalen, slik at utvikleren kan lagre den der.
Ikke opprett egne statusfiler i kildekoden.

Statusen skal inneholde dato og felles versjonsmål med kilder, samt én rad per repo:

| Repo | Status | Verifisering | Commit | Push bekreftet | Utsatt eller blokkert |
|---|---|---|---|---|---|
| `<repo>` | `<venter / testet / committet / ferdig / blokkert / oppdatert / utenfor omfang>` | `<kommando, resultat og testantall>` | `<hash eller ingen>` | `<ja / nei>` | `<årsak eller ingen>` |

Ta med neste repo og åpne review-punkter. Ved gjenopptakelse skal du lese denne
statusen og kontrollere dagens Git-status og versjoner, ikke stole på gamle
testresultater eller samtaleminner. En ny toukersrunde starter med ny kartlegging.
