---
name: pia-oppgrader-backend
description: Start Team Pias periodiske backend-oppgradering fra pia-utvikler
---

Bruk [pia-dependency-upgrade](../skills/pia-dependency-upgrade/SKILL.md).

Kjør den periodiske backend-oppgraderingen fra roten av `pia-utvikler`.
Kartlegg alle backend-repoene i omfanget under `repos/`, og finn felles,
verifiserte versjonsmål for denne runden. Ikke oppdater `ia-felles`.

Arbeid med ett repo om gangen. Kjør bygg og tester, bekreft faktisk oppløste
avhengigheter og stopp for review etter første ferdig testede repo.
Ikke commit uten uttrykkelig godkjenning. Utvikleren pusher selv og gir
beskjed før du fortsetter med neste repo.

Hvis utvikleren oppgir status eller et GitHub-issue fra en påbegynt runde,
kontroller det mot dagens repoer og fortsett derfra etter skillens prosedyre.
