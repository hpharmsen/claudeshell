---
title: Projectstrook - Plan
type: feat
date: 2026-11-23
topic: projectstrook
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
input_source: prompt
input_text: |
  Denk mee over ideeen voor Clauseshell om mijn werk nog efficienter te maken
---

# Projectstrook - Plan

## Goal Capsule

**Doel:** HP opent een project na dagen of weken en weet binnen tien seconden waar hij was, wat nog openstaat en hoe hij bij de site en de repo komt.

**Middel:** een vaste strook onder de tiles-balk met de links, de git-stand en de workflow-stap van het gekozen project, en een AI-samenvatting van de laatste stand van zaken.

**Product-autoriteit:** HP, enige gebruiker. `docs/doel.md` plus dit document.

**Afbakening:** dit document gaat alleen over de projectstrook. De chief of staff en de acties met splits zijn vervolgwerk en geen scope.

**Open blockers:** geen.

## Product Contract

### Summary

Onder de tiles-balk komt een strook van een paar regels die bij het gekozen project hoort. Links staan de korte gegevens: links naar live, localhost en git, de git-stand en de stap in de hp-workflow. Rechts staat de samenvatting in één of twee zinnen. De strook opent vanzelf als HP een project start en is dicht te klikken. De samenvatting wordt gemaakt op het moment dat een project stopt, zodat ze klaarstaat als HP terugkomt.

### Problem Frame

Maestro laat zien welk project wacht en brengt HP er snel heen. Eenmaal in een project dat een tijd stillag, begint het zoeken: wat deed ik hier het laatst, staat er nog iets ongepusht, zat ik midden in een plan of een build, en wat was de URL ook alweer. Het antwoord zit verspreid over het Claude-gesprek, `git status`, de `docs/`-folder en HP's geheugen.

### Key Decisions

- **Eerst de projectstrook, daarna de chief of staff.** (session-settled: user-directed, gekozen boven beginnen met de chief of staff of met acties en splits: de strook levert de gegevens per project waar de chief of staff later op bouwt.)
- **Het moment is 'terug in een project'.** (session-settled: user-directed, gekozen boven een overzicht over alle projecten, de combinatie van beide, en alleen snelle links.) Governs R1, R9.
- **Een strook in het window, geen popup.** (session-settled: user-directed, gekozen boven een popup op verzoek en een popup die vanzelf verschijnt bij starten.) Governs R1.
- **De samenvatting staat direct in de strook.** Links de korte gegevens, rechts de samenvatting; de strook is daarom een paar regels hoog. (session-settled: user-directed, gekozen boven een strook van één regel met de samenvatting achter een klik.) Governs R1, R9.
- **De strook is dicht te klikken en opent bij het starten van een project of op verzoek.** (session-settled: user-directed.) Governs R6, R7.
- **Geen apart paneel.** Alles wat de strook biedt, staat in de strook zelf. De lijst met gewijzigde bestanden en niet-gepushte commits geeft `git status` in de shell-pane ernaast. Governs R8, R12.
- **De samenvatting leunt op het gesprek en op de repo.** (session-settled: user-approved, gekozen boven alleen het gesprek of alleen de repo: zo komt ook werk in beeld dat nooit gecommit is, en werk dat buiten Maestro gebeurde.) Governs R10.
- **De samenvatting wordt gemaakt als het project stopt.** (session-settled: user-approved, gekozen boven maken bij openen en alleen op verzoek: ze staat er direct als HP terugkomt.) Governs R11.
- **Een prompt klaarzetten terwijl Claude bezig is, vervalt.** Claude Code doet dat zelf al.

### Requirements

**De strook**

- R1. Onder de tiles-balk staat een strook van een paar regels hoog met de gegevens van het geselecteerde project: links de korte gegevens (R2 tot en met R4), rechts de samenvatting met de datum waarop ze gemaakt is. Wisselt HP van project, dan wisselt de strook mee.
- R2. De strook toont links naar live, localhost en de git-repo. Een klik opent de link in de standaardbrowser. Een link die voor het project niet bekend is, staat er niet.
- R3. De strook toont de git-stand: de branch, het aantal bestanden met niet-gecommit werk en het aantal niet-gepushte commits. Een schone, gepushte repo is op zicht te onderscheiden van een repo waar nog iets openstaat. Is de folder geen git-repo, dan ontbreekt dit deel.
- R4. De strook toont de stap in de hp-workflow als kort label. Een project zonder sporen van die workflow heeft geen label. Het label laat bij aanwijzen zien uit welk document de stap volgt (het laatste plan of de open handoff).
- R5. De git-stand van het geselecteerde project loopt niet merkbaar achter: ze is bijgewerkt bij het selecteren en nadat Claude een beurt heeft afgerond, en volgt ook wat HP zelf in de shell-pane doet.

**Openen en sluiten**

- R6. De strook is dicht te klikken met een knop in de strook en met een sneltoets. Een dichte strook neemt geen hoogte in; de terminals krijgen die ruimte. Dezelfde sneltoets en een menu-item openen haar weer.
- R7. De strook opent vanzelf zodra een project van active naar running gaat. Dichtklikken geldt voor dat ene project en blijft gelden tot HP de strook weer opent of het project opnieuw start. Wisselen tussen running projecten opent een dichtgeklikte strook niet opnieuw.
- R8. De drie links zijn in de strook te wijzigen en leeg te maken via rechtsklik. Een link die ontbreekt, is daar ook toe te voegen.

**Links**

- R15. De app vindt de links zelf: git uit de remote van de repo, live uit de website die bij het project is ingevuld of anders uit een domein dat letterlijk in het project staat, localhost uit hoe het project lokaal start.
- R16. Een link die HP zelf heeft ingevuld of leeggemaakt, wordt niet meer door de app overschreven.

**De samenvatting**

- R9. De samenvatting is één of twee zinnen in het Nederlands: wat er het laatst gedaan is en wat er nog openstaat.
- R10. Ze is gebaseerd op het laatste Claude-gesprek in de projectfolder, de recente commits, en het nieuwste document in `docs/plans` en `docs/handoff`.
- R11. Ze wordt gemaakt en bewaard zodra een project van running naar active gaat, en voor elk running project bij het afsluiten van de app.
- R12. Bij de samenvatting staat een knop om haar nu te verversen.
- R13. Het afsluiten van de app wacht niet op samenvattingen. Een samenvatting die bij het afsluiten niet af kwam, wordt later alsnog gemaakt.
- R14. Is er sinds de vorige samenvatting geen nieuw gesprek en geen nieuwe commit, dan wordt er geen nieuwe gemaakt.
- R17. Mislukt het maken, dan blijft de vorige samenvatting staan en meldt de strook dat verversen niet lukte. Heeft een project nog geen samenvatting, dan zegt de strook dat op die plek, naast de ververs-knop.

**De workflow-stap**

- R18. De stap wordt afgeleid uit wat er in de projectfolder ligt: de documenten in `docs/brainstorms`, `docs/plans` en `docs/handoff`, en de worktrees van de repo.
- R19. De labels zijn: requirements zonder plan, plan dat nog niet gebouwd is, build of bugfix bezig, en handoff open. Past geen van die vier, dan is er geen label.

### Key Flows

- F1. Terug in een project
  - **Trigger:** HP klikt op de tile van een project waar hij twee weken niet in zat.
  - **Stappen:** het project wordt running. De strook opent en toont links de branch, twee niet-gepushte commits en het label 'plan, nog niet gebouwd', en rechts de samenvatting van twee weken geleden. HP leest haar, klikt de strook dicht en start de build.
  - **Covers R1, R3, R4, R6, R7, R9.**
- F2. Een project wegleggen
  - **Trigger:** HP zet een running project via rechtsklik op active.
  - **Stappen:** de sessies stoppen. De app maakt op de achtergrond de samenvatting en bewaart haar. HP merkt er niets van en werkt door in een ander project.
  - **Covers R10, R11.**
- F3. Een link corrigeren
  - **Trigger:** de strook toont voor live een verkeerd domein.
  - **Stappen:** HP rechtsklikt op de link en vult de goede URL in. De strook toont de nieuwe link, ook na een herstart van de app.
  - **Covers R8, R16.**

### Acceptance Examples

- AE1. **Covers R2, R3, R4.** Het geselecteerde project is een folder zonder git, zonder `docs/` en zonder website. De strook is leeg op de plek van links, git-stand en label, en de app meldt geen fout.
- AE2. **Covers R5.** HP typt `git commit` in de shell-pane. Het aantal bestanden met niet-gecommit werk in de strook daalt en het aantal niet-gepushte commits stijgt, zonder dat HP van project wisselt.
- AE3. **Covers R11, R13.** Vier projecten zijn running en HP sluit de app. De app sluit zonder merkbare vertraging. Bij de volgende keer openen van elk van die projecten staat er een samenvatting van na het laatste werk.
- AE4. **Covers R14.** HP start een project, kijkt alleen rond en zet het weer op active. De samenvatting en haar datum blijven die van de vorige keer.
- AE5. **Covers R17.** Er is geen netwerk op het moment dat een project stopt. De vorige samenvatting blijft staan met haar oude datum.
- AE6. **Covers R16.** HP heeft de localhost-link leeggemaakt. Na een herstart van de app staat er nog steeds geen localhost-link in de strook.
- AE7. **Covers R19.** Een project heeft een open handoff en ook een plan dat nog niet gebouwd is. De strook toont 'handoff open'.
- AE8. **Covers R7.** Project A en B zijn running. HP klikt de strook dicht in A, gaat naar B en weer terug naar A. In B staat de strook open, in A is ze nog dicht.
- AE9. **Covers R7.** HP zet project A op active en start het een dag later opnieuw. De strook staat open, ook al had hij haar de vorige keer dichtgeklikt.

### How This Work Fits Together

De projectstrook is het eerste van drie stukken werk die uit dezelfde brainstorm komen.

- **Chief of staff.** Een overkoepelende agent die over alle projecten heen vertelt wat er speelt. Hij bouwt op de gegevens die de strook per project verzamelt: git-stand, workflow-stap en samenvatting. Wat hij weet, wat hij mag doen en waar hij in de app woont is nog niet bepaald.
- **Acties en splits.** Knopjes en sneltoetsen voor vaste commando's zoals `./runlocal.sh`, tests en `./publish.sh`, en een verticale split binnen de shell-pane of de Claude-pane. De strook is een voor de hand liggende plek voor de knopjes; dat is een vermoeden, geen besluit.

### Scope Boundaries

Uitgesteld:

- De chief of staff. Trigger: de strook is een week in dagelijks gebruik.
- Knopjes voor vaste commando's en de verticale split. Trigger: de strook staat er, zodat te zien is hoeveel ruimte er voor knopjes overblijft.
- De git-stand op de tiles van projecten die niet geselecteerd zijn. Trigger: HP opent projecten alleen om te zien of er nog iets ongepusht staat.

Buiten scope:

- Committen of pushen vanuit de strook. Pushen blijft een handeling van HP in de shell.
- Een overzicht met een regel per project.
- De stap 'gebouwd maar nog niet gepubliceerd'. Zie Outstanding Questions.

### Dependencies / Assumptions

- Een geselecteerd project is altijd running, omdat selecteren een active project start. De strook hoeft dus geen project te tonen waar niets draait.
- R13 en R14 zijn aannames, niet met HP besproken.
- Dat dichtklikken per project geldt en niet voor de hele app (R7, AE8) is een aanname.
- Dat er geen apart paneel komt en links via rechtsklik te wijzigen zijn (R8) is een aanname.
- De volgorde in AE7 (handoff open gaat voor een plan dat nog niet gebouwd is) is een aanname.
- De samenvattingen staan bij de app-gegevens, niet in de projectfolder, zodat er niets van in een repo belandt.
- Het Claude-gesprek van een project is als bestand op de Mac terug te vinden. Niet geverifieerd.

### Outstanding Questions

Deferred to Planning:

- Waarmee maakt de app de samenvatting: de `claude` CLI zonder scherm, of een directe API-aanroep met een sleutel? Het eerste heeft geen sleutelbeheer nodig.
- Waar staan de gesprekken van Claude Code per folder, en hoeveel van een lang gesprek gaat er mee in de aanroep?
- Hoe vindt de app de localhost-URL van een project: uit `runlocal.sh`, uit de instellingen van het framework, of alleen met de hand?
- Is betrouwbaar af te leiden dat een project gebouwd maar nog niet gepubliceerd is? Zo ja, dan komt die stap bij R19.
- Hoe volgt de strook wat HP in de shell-pane doet (R5) zonder de repo voortdurend te ondervragen?
- Welke sneltoets opent en sluit de strook, en hoe hoog wordt ze zodat twee zinnen samenvatting passen zonder dat de terminals onnodig krimpen?

### Sources / Research

- `docs/doel.md` en `docs/architecture.md`.
- `docs/brainstorms/2026-11-22-maestro-requirements.md`: de statussen running, active en inactive, en het veld `website` per project.
- De hp-skills: ze laten sporen achter in `docs/brainstorms`, `docs/plans` en `docs/handoff`.
