---
title: Maestro - Plan
type: feat
date: 2026-11-22
topic: maestro
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
input_source: file
input_path: docs/doel.md
---

# Maestro - Plan

## Goal Capsule

**Doel:** HP ziet in één oogopslag welk Claude-project op hem wacht en zit met één toets of klik in dat project, met shell en Claude naast elkaar.

**Middel:** een native Mac-app met één window: een balk met project-tiles en daaronder per project een zsh-pane en een Claude-pane.

**Product-autoriteit:** HP, enige gebruiker. `docs/doel.md` plus dit document.

**Open blockers:** geen.

## Product Contract

### Summary

Maestro vervangt de WezTerm-workspaces van HP. Elk project is een gekleurde tile in een vaste balk. De tile laat zien of Claude bezig is of op HP wacht, en wisselen gaat met een klik, Cmd+cijfer, Cmd+P of één sneltoets naar het eerstvolgende wachtende project.

### Problem Frame

HP werkt in WezTerm met 27 projecten, elk een workspace met tabs voor shell en Claude. Twee dingen schuren. Wisselen tussen projecten kost te veel handelingen. En erger: nergens is te zien welke Claude-sessie klaar is of een vraag heeft, dus sessies staan ongemerkt stil.

### Key Decisions

- **Aandacht betekent: Claude wacht op HP.** Niet elke nieuwe output. (session-settled: user-directed, gekozen boven 'elke nieuwe output' en 'alleen wachtend zonder bezig-indicatie': drie toestanden geven het volledige beeld.) Governs R12, R13.
- **Buiten de balk alleen een geluidje.** (session-settled: user-directed, gekozen boven Dock-badge en macOS-notificatie.) Governs R15.
- **Na een herstart draait er niets.** (session-settled: user-approved, gekozen boven automatisch herstarten: niets start ongevraagd.) Governs R8.
- **Claude hervat altijd het laatste gesprek.** (session-settled: user-directed, gekozen boven 'altijd vers' en 'kiezen per keer'.) Governs R7.
- **Kleur automatisch, later aanpasbaar.** (session-settled: user-approved, gekozen boven een dialoog bij aanmaken.) Governs R19, R20.
- **Alle WezTerm-projecten komen als active binnen.** (session-settled: user-directed, gekozen boven importeren als inactive: HP ruimt zelf op.) Governs R22.
- **Tile 11 tot en met 20 via Cmd+Option, niet Cmd+Shift.** (session-settled: user-directed, gekozen boven Cmd+Shift+cijfer: Cmd+Shift+3, 4 en 5 zijn de schermafbeelding-sneltoetsen van macOS.) Governs R16.
- **'Wacht' vervalt ook als HP het project verlaat.** (session-settled: user-directed, gekozen boven 'alleen bij input' en 'bij selecteren': een bekeken project hoeft niet te blijven wachten, en wat afrondt terwijl HP meekijkt blijft zichtbaar.) Governs R13.
- **Projecten zijn te verwijderen.** (session-settled: user-directed, gekozen boven met de hand `projects.json` bewerken.) Governs R29.
- **Stopt Claude vanzelf, dan blijft het project running.** (session-settled: user-approved, gekozen boven het project naar active zetten: de shell-pane en wat daarin draait blijven ongemoeid.) Governs R30.
- **Cmd+P zoekt over alle projecten, ook inactive.** (session-settled: user-approved, gekozen boven alleen de tiles in de balk.) Governs R18.
- **Native Swift.** (session-settled: user-approved, gekozen boven Tauri en Electron met xterm.js: licht en voelt als een Mac-app.)
- **Versie 1 heeft twee vaste panes; extra panes zijn de eerste uitbreiding.** Een project krijgt daarna een derde en vierde pane, elk een shell of een Claude-sessie. Een aparte server-voorziening vervalt: `./runlocal.sh` start HP zelf in zo'n extra shell-pane. (session-settled: user-approved, gekozen boven extra panes meteen in versie 1: eerst de kern werkend.) Governs R28.

### Requirements

**Window en layout**

- R1. De app heeft één resizable window, bij de eerste start gecentreerd op 3/4 van de schermbreedte en 3/4 van de schermhoogte.
- R2. Bovenaan staat een tiles-balk van 2 em hoog die altijd in beeld blijft, met rechts een + tile.
- R3. Onder de balk staat links de zsh-pane (standaard 1/3) en rechts de Claude-pane (standaard 2/3) van het gekozen project.
- R4. De scheidslijn tussen de panes is versleepbaar.
- R5. De balk is ontworpen voor 12 tot 15 tiles: bij dat aantal en de standaard windowbreedte is elke projectnaam herkenbaar. Komen er meer, dan worden de tiles smaller en wordt de naam afgekapt.

**Projecten en status**

- R6. Een project heeft een naam, een folder, een kleur, een positie in de balk en een status: running, active of inactive.
- R7. Running: in de projectfolder draaien een zsh-sessie en `claude --dangerously-skip-permissions`, waarbij Claude het laatste gesprek in die folder hervat. Bestaat er nog geen gesprek, dan start Claude vers.
- R8. Active: het project staat in de balk maar er draait niets. Een klik op de tile zet het op running, en selecteren via een sneltoets doet hetzelfde. Bij het afsluiten van de app stoppen alle sessies en na het openen staan alle running projecten op active.
- R9. Inactive: het project staat niet in de balk en is terug te halen via een dropdown met alle inactive projecten.
- R10. Meerdere projecten kunnen tegelijk running zijn. Wisselen van tile laat de sessies van de andere projecten doorlopen.
- R11. Via rechtsklik op een tile gaat een project van running naar active (sessies stoppen, zonder bevestiging) en van active naar inactive.
- R30. Stopt Claude vanzelf, bijvoorbeeld door `/exit`, dan blijft het project running en draait de zsh-pane door. De Claude-pane meldt dat Claude gestopt is en Enter start hem opnieuw volgens R7.

**Aandacht**

- R12. Een running tile toont één van drie toestanden: Claude is bezig, Claude wacht op HP, of rustig. 'Wacht op HP' geldt zodra Claude zijn beurt heeft afgerond of een vraag stelt.
- R13. De toestand 'wacht op HP' vervalt zodra HP in dat project input aan Claude geeft; de tile toont dan bezig. Ze vervalt ook zodra HP het project verlaat voor een ander project; de tile wordt dan rustig.
- R14. In de balk is op zicht te onderscheiden of een tile running of active is, en welke tile geselecteerd is.
- R15. Gaat een project van bezig naar 'wacht op HP', dan klinkt een kort geluid. Geen Dock-badge, geen macOS-notificatie.

**Wisselen**

- R16. Cmd+1 tot en met Cmd+9 selecteren tile 1 tot en met 9 in de balk en Cmd+0 tile 10. Cmd+Option+1 tot en met Cmd+Option+0 selecteren tile 11 tot en met 20.
- R17. Eén sneltoets (Cmd-§) springt naar het eerstvolgende project dat op HP wacht, in balkvolgorde na de huidige tile.
- R18. Cmd+P opent een fuzzy zoeker over alle projecten, ook inactive. Kiezen selecteert het project en zet het zo nodig op running.

**Projecten beheren**

- R19. De + tile opent een folderkiezer. Het nieuwe project krijgt de foldernaam als naam, de eerstvolgende vrije kleur uit een vast palet, en komt als active achteraan in de balk.
- R20. Via rechtsklik op een tile zijn naam en kleur te wijzigen.
- R29. Een active project is via rechtsklik op de tile te verwijderen, en een inactive project via de dropdown. Alleen het project in de app verdwijnt; de folder blijft staan.
- R21. Tiles zijn te verslepen om de volgorde te wijzigen.
- R22. Bij de eerste start importeert de app eenmalig de projecten (naam en folder) uit `~/.wezterm.lua` waarvan de folder bestaat, en zet ze alfabetisch als active in de balk. Het `server_command` wordt niet overgenomen.
- R23. Projecten, volgorde, kleuren, de status active of inactive en de positie van de scheidslijn blijven bewaard tussen sessies van de app.

**Terminals**

- R24. De zsh-pane is een volwaardige login-shell die `~/.zshrc` laadt, zodat Oh My Zsh met het bullet-train thema en de plugins werkt zoals in WezTerm, inclusief de prompt-symbolen.
- R25. Lettertype, lettergrootte (14) en kleuren van beide panes komen overeen met de huidige WezTerm-setup.
- R26. In beide panes openen klikbare URL's in de standaardbrowser. Een `file:`-link opent het bestand met `open`.
- R27. Cmd+C kopieert de selectie als die er is, en Cmd+V plakt.

**Uitbreidbaarheid**

- R28. De opzet van versie 1 gaat er niet van uit dat een project precies één shell en één Claude-sessie heeft: een derde en vierde pane (shell of Claude) moeten later toe te voegen zijn zonder de projectopslag, de layout of de aandacht-status om te gooien.

### Key Flows

- F1. Een wachtend project oppakken
  - **Trigger:** HP werkt in project A; Claude in project B rondt zijn beurt af.
  - **Stappen:** het geluid klinkt en tile B toont 'wacht op HP'. HP drukt de spring-sneltoets. Project B is geselecteerd met focus in de Claude-pane. HP typt een antwoord en tile B toont 'bezig'. Heeft HP niets te zeggen en gaat hij terug naar A, dan wordt tile B rustig.
  - **Covers R12, R13, R15, R17.**
- F2. Een project starten
  - **Trigger:** HP klikt op een active tile of kiest een project via Cmd+P.
  - **Stappen:** het project wordt running. Links start zsh in de projectfolder, rechts start Claude en hervat het laatste gesprek. Bestaat de folder niet, dan blijft het project active en verschijnt er een melding.
  - **Covers R7, R8, R18.**
- F3. Een project parkeren
  - **Trigger:** HP rechtsklikt op een running tile en kiest stoppen.
  - **Stappen:** beide sessies stoppen en de tile toont active. Een tweede keer rechtsklik zet het project op inactive en de tile verdwijnt uit de balk.
  - **Covers R9, R11.**

### Acceptance Examples

- AE1. **Covers R12, R15.** Claude in project B stelt halverwege een taak een vraag terwijl project A geselecteerd is. Tile B toont 'wacht op HP' en het geluid klinkt één keer.
- AE2. **Covers R15.** Claude rondt zijn beurt af in het project dat HP op dat moment voor zich heeft. De tile toont 'wacht op HP'; het geluid klinkt ook dan.
- AE3. **Covers R17.** Er wacht geen enkel project. De spring-sneltoets doet niets.
- AE4. **Covers R7.** Een nieuw toegevoegd project zonder eerder Claude-gesprek wordt op running gezet. Claude start met een leeg gesprek, zonder foutmelding.
- AE5. **Covers R8.** Drie projecten zijn running en HP sluit de app. Na het openen zijn de drie tiles active en draait er geen enkel proces.
- AE6. **Covers R18.** HP kiest via Cmd+P een inactive project. Het komt achteraan in de balk, wordt running en is geselecteerd.
- AE7. **Covers R16.** Er staan 14 tiles in de balk. Cmd+3 selecteert de derde, Cmd+0 de tiende en Cmd+Option+2 de twaalfde. Cmd+Option+5 doet niets, want er is geen vijftiende tile.
- AE8. **Covers R5, R22.** Direct na de import staan er tot 27 tiles in de balk. Ze zijn smal en de namen zijn afgekapt, maar elke tile blijft aanklikbaar en aan zijn kleur te onderscheiden.

### Scope Boundaries

Uitgesteld:

- Een derde en vierde pane per project, naar keuze shell of Claude. Trigger: versie 1 is een week in dagelijks gebruik. Dan te beslissen: waar de extra panes staan, of ze na een herstart terugkomen, en hoe de tile zich gedraagt met twee Claude-sessies in één project.
- Dock-badge en macOS-notificaties. Trigger: HP mist wachtende projecten terwijl de app op de achtergrond staat.

Buiten scope:

- Meerdere windows.
- Een apart server-commando per project; extra shell-panes vangen dat op.
- Claude starten zonder `--dangerously-skip-permissions` of met andere vlaggen per project.
- Een instellingenscherm. Kleur en naam gaan via rechtsklik, de rest volgt de WezTerm-setup.
- Distributie aan anderen (App Store, notarisatie, auto-update).

### Dependencies / Assumptions

- Normaal staan er 12 tot 15 projecten in de balk (running plus active). De tot 27 tiles direct na de import zijn een tijdelijke situatie die HP zelf opruimt.
- De Claude CLI staat op `/Users/hp/.local/bin/claude`.
- WezTerm gebruikt bij HP het standaard lettertype (JetBrains Mono met Nerd Font-symbolen als fallback) en het standaard kleurenschema; `~/.wezterm.lua` stelt alleen `font_size = 14.0` in. R25 gaat daarvan uit.
- AE2 (geluid ook bij het zichtbare project) is een aanname, niet met HP besproken.
- R11 stopt zonder bevestiging, in lijn met `skip_close_confirmation_for_processes_named` in de WezTerm-config.

### Outstanding Questions

Deferred to Planning:

- Hoe detecteert de app 'bezig' en 'wacht op HP'? Kandidaten: Claude Code hooks (`Stop`, `Notification`, `UserPromptSubmit`) of het uitlezen van de terminal-output.
- Welke terminal-component (bijvoorbeeld SwiftTerm) haalt R24 tot en met R27?
- Hoe gedraagt `claude --continue` zich in een folder zonder eerder gesprek, en wat is de fallback voor AE4?
- Hoe wordt `~/.wezterm.lua` gelezen voor R22: de Lua-tabellen parsen of een eenmalig script?

### Sources / Research

- `docs/doel.md`: het oorspronkelijke doel.
- `~/.wezterm.lua`: de huidige setup met 27 projecten (11 met eigen pad, 16 onder `~/proj/<naam>`), de sneltoetsen Cmd+P, Cmd+C en de link-afhandeling.
- `~/.zshrc`: `ZSH_THEME="bullet-train"`.
