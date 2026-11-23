---
title: Projectstrook - Plan
type: feat
date: 2026-11-23
topic: projectstrook
artifact_contract: ce-unified-plan/v1
product_contract_source: legacy-requirements
origin: docs/brainstorms/2026-11-23-projectstrook-requirements.md
execution: code
deepened: 2026-11-23
---

# Projectstrook - Plan

## Goal Capsule

**Doel:** HP opent een project na dagen of weken en weet binnen tien seconden waar hij was, wat nog openstaat en hoe hij bij de site en de repo komt.

**Middel:** een strook onder de tiles-balk met links de links, de git-stand en de workflow-stap van het gekozen project, en rechts een AI-samenvatting van de laatste stand van zaken.

**Product-autoriteit:** HP, enige gebruiker. `docs/doel.md` plus dit document.

**Afbakening:** dit plan gaat alleen over de projectstrook. De chief of staff en de acties met splits zijn vervolgwerk en geen scope.

**Open blockers:** geen.

## Product Contract

### Summary

Onder de tiles-balk komt een strook van een paar regels die bij het gekozen project hoort. Links staan de korte gegevens: links naar live, localhost en git, de git-stand en de stap in de hp-workflow. Rechts staat de samenvatting in één of twee zinnen. De strook opent vanzelf als HP een project start en is dicht te klikken. De samenvatting wordt gemaakt op het moment dat een project stopt, zodat ze klaarstaat als HP terugkomt, en bij het starten gecontroleerd op gemist werk.

### Problem Frame

Claudeshell laat zien welk project wacht en brengt HP er snel heen. Eenmaal in een project dat een tijd stillag, begint het zoeken: wat deed ik hier het laatst, staat er nog iets ongepusht, zat ik midden in een plan of een build, en wat was de URL ook alweer. Het antwoord zit verspreid over het Claude-gesprek, `git status`, de `docs/`-folder en HP's geheugen.

### Key Decisions

- **Eerst de projectstrook, daarna de chief of staff.** (session-settled: user-directed, gekozen boven beginnen met de chief of staff of met acties en splits: de strook levert de gegevens per project waar de chief of staff later op bouwt.)
- **Het moment is 'terug in een project'.** (session-settled: user-directed, gekozen boven een overzicht over alle projecten, de combinatie van beide, en alleen snelle links.) Governs R47, R55.
- **Een strook in het window, geen popup.** (session-settled: user-directed, gekozen boven een popup op verzoek en een popup die vanzelf verschijnt bij starten.) Governs R47.
- **De samenvatting staat direct in de strook.** Links de korte gegevens, rechts de samenvatting; de strook is daarom een paar regels hoog. (session-settled: user-directed, gekozen boven een strook van één regel met de samenvatting achter een klik.) Governs R47, R55.
- **De strook is dicht te klikken en opent bij het starten van een project of op verzoek.** (session-settled: user-directed.) Governs R52, R53.
- **Geen apart paneel.** Alles wat de strook biedt, staat in de strook zelf. De lijst met gewijzigde bestanden en niet-gepushte commits geeft `git status` in de shell-pane ernaast. Governs R54, R58.
- **De samenvatting leunt op het gesprek en op de repo.** (session-settled: user-approved, gekozen boven alleen het gesprek of alleen de repo: zo komt ook werk in beeld dat nooit gecommit is, en werk dat buiten Claudeshell gebeurde.) Governs R56.
- **De samenvatting wordt gemaakt als het project stopt.** (session-settled: user-approved, gekozen boven maken bij openen en alleen op verzoek: ze staat er direct als HP terugkomt.) Governs R57.

### Requirements

De nummering loopt door op `docs/plans/2026-11-23-002-feature-tile-iconen-plan.md`. R47 tot en met R65 zijn R1 tot en met R19 uit het origin, AE19 tot en met AE27 zijn AE1 tot en met AE9, en F6 tot en met F8 zijn F1 tot en met F3.

**De strook**

- R47. Onder de tiles-balk staat een strook van een paar regels hoog met de gegevens van het geselecteerde project: links de korte gegevens (R48 tot en met R50), rechts de samenvatting met de datum waarop ze gemaakt is. Wisselt HP van project, dan wisselt de strook mee.
- R48. De strook toont links naar live, localhost en de git-repo. Een klik opent de link in de standaardbrowser. Een link die voor het project niet bekend is, staat er niet.
- R49. De strook toont de git-stand: de branch, het aantal bestanden met niet-gecommit werk en het aantal niet-gepushte commits. Een schone, gepushte repo is op zicht te onderscheiden van een repo waar nog iets openstaat. Is de folder geen git-repo, dan ontbreekt dit deel.
- R50. De strook toont de stap in de hp-workflow als kort label. Een project zonder sporen van die workflow heeft geen label. Het label laat bij aanwijzen zien uit welk document de stap volgt (het laatste plan of de open handoff).
- R51. De git-stand van het geselecteerde project loopt niet merkbaar achter: ze is bijgewerkt bij het selecteren en nadat Claude een beurt heeft afgerond, en volgt ook wat HP zelf in de shell-pane doet.

**Openen en sluiten**

- R52. De strook is dicht te klikken met een knop in de strook en met een sneltoets. Een dichte strook neemt geen hoogte in; de terminals krijgen die ruimte. Dezelfde sneltoets en een menu-item openen haar weer.
- R53. De strook opent vanzelf zodra een project van active naar running gaat. Dichtklikken geldt voor dat ene project en blijft gelden tot HP de strook weer opent of het project opnieuw start. Wisselen tussen running projecten opent een dichtgeklikte strook niet opnieuw.
- R54. De drie links zijn in de strook te wijzigen en leeg te maken via rechtsklik. Een link die ontbreekt, is daar ook toe te voegen.

**De samenvatting**

- R55. De samenvatting is één of twee zinnen in het Nederlands: wat er het laatst gedaan is en wat er nog openstaat.
- R56. Ze is gebaseerd op het laatste Claude-gesprek in de projectfolder, de recente commits, en het nieuwste document in `docs/plans` en `docs/handoff`.
- R57. Ze wordt gemaakt en bewaard zodra een project van running naar active gaat. Voor een project dat bij het afsluiten van de app nog running was, en voor werk dat buiten Claudeshell gebeurde, wordt ze bijgewerkt bij de volgende start van de app of van het project.
- R58. Bij de samenvatting staat een knop om haar nu te verversen.
- R59. Het afsluiten van de app wacht niet op samenvattingen. Een samenvatting die bij het afsluiten niet af kwam, wordt later alsnog gemaakt.
- R60. Is er sinds de vorige samenvatting geen nieuw gesprek en geen nieuwe commit, dan wordt er geen nieuwe gemaakt.
- R63. Mislukt het maken, dan blijft de vorige samenvatting staan en meldt de strook dat verversen niet lukte. Heeft een project nog geen samenvatting, dan zegt de strook dat op die plek, naast de ververs-knop.

**Links**

- R61. De app vindt de links zelf: git uit de remote van de repo, live uit de website die bij het project is ingevuld of anders uit een domein dat letterlijk in het project staat, localhost uit hoe het project lokaal start.
- R62. Een link die HP zelf heeft ingevuld of leeggemaakt, wordt niet meer door de app overschreven.

**De workflow-stap**

- R64. De stap wordt afgeleid uit wat er in de projectfolder ligt: de documenten in `docs/brainstorms`, `docs/plans` en `docs/handoff`, en de worktrees van de repo.
- R65. De labels zijn: requirements zonder plan, plan dat nog niet gebouwd is, build of bugfix bezig, en handoff open. Past geen van die vier, dan is er geen label.

### Key Flows

- F6. Terug in een project
  - **Trigger:** HP klikt op de tile van een project waar hij twee weken niet in zat.
  - **Stappen:** het project wordt running. De strook opent en toont links de branch, twee niet-gepushte commits en het label 'plan, nog niet gebouwd', en rechts de samenvatting van twee weken geleden. HP leest haar, klikt de strook dicht en start de build.
  - **Covers R47, R49, R50, R52, R53, R55.**
- F7. Een project wegleggen
  - **Trigger:** HP zet een running project via rechtsklik op active.
  - **Stappen:** de sessies stoppen. De app maakt op de achtergrond de samenvatting en bewaart haar. HP merkt er niets van en werkt door in een ander project.
  - **Covers R56, R57.**
- F8. Een link corrigeren
  - **Trigger:** de strook toont voor live een verkeerd domein.
  - **Stappen:** HP rechtsklikt op de link en vult de goede URL in. De strook toont de nieuwe link, ook na een herstart van de app.
  - **Covers R54, R62.**

### Acceptance Examples

- AE19. **Covers R48, R49, R50.** Het geselecteerde project is een folder zonder git, zonder `docs/` en zonder website. De strook is leeg op de plek van links, git-stand en label, en de app meldt geen fout.
- AE20. **Covers R51.** HP typt `git commit` in de shell-pane. Het aantal bestanden met niet-gecommit werk in de strook daalt en het aantal niet-gepushte commits stijgt, zonder dat HP van project wisselt.
- AE21. **Covers R57, R59.** Vier projecten zijn running en HP sluit de app. De app sluit zonder merkbare vertraging. Bij de volgende keer openen van elk van die projecten staat er een samenvatting van na het laatste werk.
- AE22. **Covers R60.** HP start een project, kijkt alleen rond en zet het weer op active. De samenvatting en haar datum blijven die van de vorige keer.
- AE23. **Covers R63.** Er is geen netwerk op het moment dat een project stopt. De vorige samenvatting blijft staan met haar oude datum.
- AE24. **Covers R62.** HP heeft de localhost-link leeggemaakt. Na een herstart van de app staat er nog steeds geen localhost-link in de strook.
- AE25. **Covers R65.** Een project heeft een open handoff en ook een plan dat nog niet gebouwd is. De strook toont 'handoff open'.
- AE26. **Covers R53.** Project A en B zijn running. HP klikt de strook dicht in A, gaat naar B en weer terug naar A. In B staat de strook open, in A is ze nog dicht.
- AE27. **Covers R53.** HP zet project A op active en start het een dag later opnieuw. De strook staat open, ook al had hij haar de vorige keer dichtgeklikt.

### How This Work Fits Together

De projectstrook is het eerste van drie stukken werk die uit dezelfde brainstorm komen.

- **Chief of staff.** Een overkoepelende agent die over alle projecten heen vertelt wat er speelt. Hij bouwt op de gegevens die de strook per project verzamelt: git-stand, workflow-stap en samenvatting. Wat hij weet, wat hij mag doen en waar hij in de app woont is nog niet bepaald.
- **Acties en splits.** Knopjes en sneltoetsen voor vaste commando's zoals `./runlocal.sh`, tests en `./publish.sh`, en een verticale split binnen de shell-pane of de Claude-pane. De strook is een voor de hand liggende plek voor de knopjes; dat is een vermoeden, geen besluit.

### Scope Boundaries

Uitgesteld:

- De chief of staff. Trigger: de strook is een week in dagelijks gebruik.
- Knopjes voor vaste commando's en de verticale split. Trigger: de strook staat er, zodat te zien is hoeveel ruimte er voor knopjes overblijft.
- De git-stand op de tiles van projecten die niet geselecteerd zijn. Trigger: HP opent projecten alleen om te zien of er nog iets ongepusht staat.
- De stap 'gebouwd, nog niet gepubliceerd'. Trigger: HP vergeet een publish in een project waar de strook 'schoon' toonde.

Buiten scope:

- Committen of pushen vanuit de strook. Pushen blijft een handeling van HP in de shell.
- Een overzicht met een regel per project.

### Dependencies / Assumptions

- Een geselecteerd project is altijd running, omdat selecteren een active project start. De strook hoeft dus geen project te tonen waar niets draait.
- R59 en R60 zijn aannames, niet met HP besproken.
- De volgorde in AE25 (handoff open gaat voor een plan dat nog niet gebouwd is) is een aanname.
- Dat dichtklikken per project geldt en niet voor de hele app (R53, AE26) is een aanname.
- Dat er geen apart paneel komt en links via rechtsklik te wijzigen zijn (R54) is een aanname.
- De samenvattingen staan bij de app-gegevens, niet in de projectfolder, zodat er niets van in een repo belandt.

### Sources / Research

- Origin: `docs/brainstorms/2026-11-23-projectstrook-requirements.md`. De open vragen daaruit zijn beantwoord in de Key Technical Decisions hieronder.
- De layout van het window en alle gebruikersacties: `Sources/Claudeshell/MainWindowController.swift`. Tussen balk en split zit precies één constraint.
- Het patroon voor achtergrondwerk met een geïnjecteerde functie: `Sources/Claudeshell/IconStore.swift` en `Sources/ClaudeshellCore/IconResolver.swift`.
- Het patroon voor setters met validatie: `setWebsite` in `Sources/ClaudeshellCore/ProjectStore.swift`.
- De Claude CLI 2.1.319: `claude --help`, de CLI-referentie, en tien proefaanroepen in een lege map op 2026-11-23, waarvan acht met een verzonnen invoer van 49 KB.
- De gespreksbestanden van Claude Code in `~/.claude/projects/`: 345 stuks bekeken op opbouw, omvang en wat hervatten erin schrijft.
- De hp-skills `start`, `build`, `bug`, `finish`, `handoff`, `pickup` en `publish`.
- De regels voor de workflow-stap en de links, nagelopen op de 27 projecten in `projects.json` en op de 103 gecommitte plannen daarin.

---


## Planning Contract

### Key Technical Decisions

**De strook in het window**

- KTD1. **De strook is een SwiftUI-view in een eigen `NSHostingView` tussen de balk en de split, met een vaste hoogte.** De constraint `splitView.topAnchor == bar.bottomAnchor` in `buildLayout` wordt vervangen door twee die klaarstaan: de split onder de strook, en de split onder de balk. Eén van de twee is actief, en de strook is zichtbaar of verborgen. Een hoogte van nul botst met de eigen maat van een `NSHostingView`; de balk bewijst dat een vaste hoogte werkt. De hoogte is gelijk wat er aan gegevens is, zodat binnenkomende gegevens de terminals nooit laten verspringen. Governs R47, R52.
- KTD2. **Open of dicht is een set van dichtgeklikte project-id's in het geheugen.** De strook is zichtbaar als er een project geselecteerd is dat niet in die set zit. `select` haalt een project uit de set nadat `sessions.start` is geslaagd, dus op het moment dat het van active naar running gaat. De set wordt niet bewaard: na een herstart van de app draait er niets, dus elke start opent de strook. Governs R53.
- KTD3. **De sneltoets is Cmd+I, als menu-item 'Projectstrook' in een menu 'Beeld'.** Cmd+I is vrij in `MainMenu.swift`, en SwiftTerm laat Cmd-toetsen aan het menu. Zonder geselecteerd project doet de actie niets. Governs R52.
- KTD4. **Open- en dichtklikken geeft de terminals een nieuwe hoogte, één keer per wissel.** SwiftTerm verwerkt elke maatwijziging direct en meldt haar aan zsh en Claude, net als bij het verslepen van het window. De volgorde is daarom: eerst de stand van de strook zetten, dan de layout laten doorrekenen, dan pas de panes plaatsen, zonder animatie. Governs R52, R53.
- KTD5. **De strook neemt de focus niet over.** De knoppen zijn niet focusbaar en de samenvatting is geen selecteerbare tekst; kopiëren gaat via rechtsklik. Open- en dichtklikken en de link-dialogen lopen niet via `refresh()`, want die zet de focus altijd in de Claude-pane, en niet via `show()`, want die meldt het project af bij de aandacht-tracker. Governs R52, R54.

**Gegevens verzamelen**

- KTD6. **Alle logica in `ClaudeshellCore`, met het starten van een proces als geïnjecteerde functie.** Net als `fetch` bij `IconResolver` krijgen de onderdelen een `run` mee: programma, argumenten, werkmap en optioneel invoer, met de uitvoer als tekst terug. `GitState`, `WorkflowStep`, `ProjectLinks` en `SummaryWriter` zijn `Sendable` structs met asynchrone functies buiten de main actor, naar het model van `IconResolver`. Tests gebruiken de echte `Subprocess.run` met git-repo's in een tijdelijke map, of geven een functie met vaste antwoorden mee.
- KTD7. **`Subprocess.run` houdt geen thread van de taken-pool bezet.** Het einde van het proces hervat de wachtende taak, de pipes worden op een eigen queue leeggelezen, en het annuleren van de taak beëindigt het proces. Een aanroep van `claude` mag 60 seconden duren; die tijd mag de rest van de app niet ophouden.
- KTD8. **De git-stand komt uit één aanroep: `git --no-optional-locks status --porcelain=v2 --branch`.** Zonder `--no-optional-locks` houdt `git status` kort `index.lock` vast, en dan kan een `git commit` van Claude of HP in dezelfde repo mislukken. `# branch.head` geeft de branch, het aantal regels zonder `#` het aantal gewijzigde bestanden inclusief nieuwe, en `# branch.ab +N` de niet-gepushte commits. Ontbreekt `# branch.ab`, dan heeft de branch geen upstream en toont de strook 'geen upstream' in plaats van een nul. Een fout van git betekent: geen repo, en het deel ontbreekt. Governs R49.
- KTD9. **Eén lus haalt de git-stand en de workflow-stap op: ophalen, vijf seconden wachten, opnieuw.** De lus loopt alleen voor het geselecteerde project, alleen als de strook open is en de app vooraan staat. Hij begint opnieuw, met direct een ronde, bij het wisselen van project, bij het openen van de strook en als de app weer vooraan komt. Een aanroep kost 0,05 seconde. De rondes lopen na elkaar, dus er loopt nooit meer dan één tegelijk, en het resultaat van een afgebroken ronde wordt weggegooid. Dat dekt de beurt van Claude en wat HP in de shell doet zonder de hooks of de shell te hoeven volgen. Governs R50, R51.
- KTD10. **De workflow-stap gaat elke ronde mee en hangt niet aan de git-stand.** Een nieuwe worktree in het genegeerde `.worktrees/` en een tweede wijziging in een al gewijzigd bestand veranderen de uitvoer van `git status` niet. Een ronde kost een handvol aanroepen van git en een handvol kleine bestanden. Governs R50.
- KTD11. **Alle gegevens staan per project-id, en de strook leest die van het geselecteerde project.** Een laat antwoord voor project A komt bij A terecht en nooit in de strook van B.

**Links**

- KTD12. **Een project krijgt één optioneel veld: `linkOverrides`, een tabel van soort (`live`, `localhost`, `git`) naar tekst.** Een ingevulde waarde is de link van HP. Een lege tekst betekent: door HP leeggemaakt. Ontbreekt de soort, dan geldt wat de app zelf vindt. Gevonden links worden niet bewaard maar bij het selecteren en na een link-dialoog opnieuw bepaald. Het veld is optioneel in de JSON, dus een bestaand `projects.json` laadt zonder migratie. Governs R54, R62.
- KTD13. **Zelf gevonden links.** Git: `git remote get-url origin`, omgezet naar `https://host/gebruiker/repo` zonder inloggegevens en zonder `.git`; remotes van Heroku en Dokku leveren geen link. Live: de `website` van het project, anders het eerste domein van `DomainGuesser`. Localhost: de poort uit `runlocal.sh` in de projectroot. Voor de 27 projecten van nu levert dat 26 keer een git-link, 10 keer een live-link en 11 keer een localhost-link. Governs R61.
- KTD14. **De poort komt uit `runlocal.sh`, zo nodig via `.env`.** Regels die met `#` beginnen, tellen niet. Herkend worden, in deze volgorde: `runserver N`, `http.server N`, `--port N`, en pas daarna `localhost:N` en `127.0.0.1:N`. Staat er op die plek een variabele, ook tussen aanhalingstekens (`$PORT`, `"$PORT"`, `${LOCAL_PORT}`, `${PORT:-8000}`), dan geldt een toewijzing met een getal in het script zelf, daarna de waarde van precies die variabele in `.env` naast het script, daarna de standaardwaarde achter `:-`. Een toewijzing in het script zonder getal wordt overgeslagen. Zonder poort is er geen localhost-link. Uit `.env` wordt alleen die ene regel gelezen en er gaat niets van naar de log. Governs R61.
- KTD15. **De live-link in de strook staat los van het icoon.** Een live-link wijzigen via de strook zet `linkOverrides`, niet `website`, en start dus geen zoekronde voor het icoon. Governs R54.

**De workflow-stap**

- KTD16. **Eén label, de eerste die past in deze volgorde.** Het nieuwste document is overal in dit plan het bestand met de hoogste naam in sorteervolgorde; de namen beginnen met een datum. De wijzigingstijd telt niet, want een checkout zet die opnieuw. Nagelopen op de 27 projecten van nu geeft dit zes labels, die alle zes kloppen. Governs R64, R65.
  1. **Handoff open:** `docs/handoff/README.md` bestaat en zijn takentabel heeft een rij waarvan de cel onder de kop `Status` begint met `todo`, `doing` of `blocked`. Een map met alleen `done`-rijen telt niet; in de praktijk blijft die map soms staan.
  2. **Build bezig** of **bugfix bezig:** `git worktree list --porcelain` noemt een extra worktree waarvan de branch commits heeft die `HEAD` mist. Begint die branch met `fix/`, dan is het een bugfix. Een worktree zonder eigen commits telt niet: een achtergebleven worktree van een branch die al gemerged is, geeft anders blijvend een label. De eerste minuten van een build, vóór de eerste commit, valt het label daardoor terug op stap 3.
  3. **Plan, nog niet gebouwd:** het nieuwste bestand `*-plan.md` in `docs/plans` is nog niet gebouwd volgens KTD17.
  4. **Requirements, nog geen plan:** van de bestanden `*-requirements.md` in `docs/brainstorms` met de hoogste datum in hun naam hoort er bij minstens één geen plan; het label wijst naar de hoogste daarvan. Brainstorms hebben geen volgnummer, dus twee van dezelfde dag sorteren op onderwerp. Een plan hoort bij een requirementsdocument als zijn `origin:` de bestandsnaam bevat, of anders als het de topic-slug in zijn naam heeft en niet ouder is.
- KTD17. **Een plan geldt als gebouwd zodra een commit iets buiten `docs/` raakt: de commit die het plan toevoegde zelf, of een latere.** Commits waarvan het onderwerp met `publish` begint, tellen niet; die raken alleen het versienummer. Geen enkele hp-skill markeert een plan als gebouwd, en het veld `status:` staat in 73 van de 131 plannen onder `~/proj` en wordt niet bijgehouden. De commit die het plan toevoegde is de nieuwste commit die het bestand toevoegt, zonder hernoemingen te volgen. Een plan dat nog niet gecommit is, is niet gebouwd. Is de folder geen repo of negeert git het planbestand (`git check-ignore`), dan is 'gebouwd' niet vast te stellen en geeft stap 3 geen label. Een `status:` met `completed`, `complete`, `done`, `uitgevoerd` of `superseded` telt ook als gebouwd. Governs R65.
- KTD18. **Het document bij het label is de bestandsnaam van het plan, het requirementsdocument of de handoff, en bij een worktree de naam van de branch.** Governs R50.

**De samenvatting: de aanroep**

- KTD19. **De samenvatting maakt de app met de `claude` CLI zonder scherm, op het account waarmee HP al is ingelogd.** Geen API-sleutel en geen sleutelbeheer. De aanroep: `claude -p --model haiku --safe-mode --no-session-persistence --tools "" --strict-mcp-config --disable-slash-commands --output-format json --system-prompt <opdracht>`, met alleen het materiaal op de standaardinvoer. Gemeten met Claude Code 2.1.319 en 49 KB invoer: 3 tot 6 seconden en ongeveer $0,004 per aanroep, een schatting van de CLI die meetelt in het gebruik van het abonnement. Governs R55, R56.
  - `--safe-mode` houdt de eigen `~/.claude/CLAUDE.md`, de plugins en hun hooks buiten de aanroep en laat de inlog werken. Zonder die vlag draait de `SessionStart`-hook van een plugin mee, gaan er 5000 tokens extra in en komt er tien keer zoveel uitvoer.
  - `--bare` valt af: die leest de inlog van het abonnement niet.
  - De opdracht in `--system-prompt` maakt het gesprek op de invoer materiaal en geen opdracht. Met `--tools ""` is het ergste gevolg van een gekaapte prompt een verkeerde samenvatting, geen handeling.
- KTD20. **De aanroep draait in de support-folder van de app, nooit in de projectfolder.** Een `claude -p` in een projectfolder leest de `CLAUDE.md`, de hooks en de MCP-servers van dat project. `--no-session-persistence` voorkomt dat de aanroep een gespreksbestand achterlaat; een gewone `claude -p` schrijft er per keer één van 315 KB bij. Governs R56.
- KTD21. **`claude` staat op `~/.local/bin/claude`.** Staat hij daar niet, dan vraagt de app het pad één keer op met `zsh -lic 'command -v claude'`, waarvan de laatste regel van de uitvoer telt, en onthoudt het. De aanroep werkt met alleen `HOME` en `USER` in de omgeving, dus zonder het `PATH` van de shell. Git is `/usr/bin/git`.
- KTD22. **Mislukt is: een exitcode ongelijk aan nul, uitvoer die geen JSON is, `is_error` op waar, of een lege `result`.** Bij een fout staat er in `result` een Engelse foutmelding en blijft `subtype` op `success`; geen van beide is dus een teken van succes. Het bestand blijft zoals het was, de strook toont 'Verversen lukte niet' tot de volgende geslaagde poging, en er gaat een regel naar `os.Logger`, categorie `Summary`, op niveau error, met `api_error_status` en `terminal_reason`. Is er geen gesprek en geen repo, dan is er niets samen te vatten en volgt er geen aanroep. Governs R63.

**De samenvatting: het gesprek**

- KTD23. **De gesprekken van een project staan in `~/.claude/projects/<map>/`.** De mapnaam is het echte pad van de projectfolder met elk teken buiten letters en cijfers vervangen door een koppelteken. Alleen `.jsonl`-bestanden op het hoogste niveau tellen; subagents staan dieper. Een sessie die in een worktree of submap verder ging, blijft in de map van de projectroot. Governs R56.
- KTD24. **Het laatste gesprek is niet het nieuwste bestand.** Een gesprek hervatten zonder iets te zeggen verzet de wijzigingstijd, soms met weken, en `/clear` begint een nieuw, leeg bestand. De app neemt de drie nieuwste bestanden met `entrypoint` `cli` en kiest daaruit het bestand waarvan het laatste echte bericht de nieuwste tijd draagt. Een bestand zonder echt bericht valt af. Governs R56.
- KTD25. **Een echt bericht is wat HP of Claude zei.** Governs R56.
  - Van HP: een regel van het type `user` zonder `isMeta`, zonder `isCompactSummary`, zonder `tool_result`-blok, waarvan `origin.kind` niet `task-notification` is, en waarvan de tekst niet begint met `<task-notification>`, `<command-name>`, `<local-command-stdout>`, `<local-command-caveat>`, `<bash-input>`, `<bash-stdout>` of `[Request interrupted`. Een slash-commando met argumenten (`<command-message>`) telt wel: daar staat de bedoeling van HP in.
  - Van Claude: een regel van het type `assistant` met een niet-leeg `text`-blok, waarvan het model niet `<synthetic>` is en die geen `isApiErrorMessage` draagt.
  - Zonder dit filter is 39% van de berichten 'van HP' geen tekst van HP.
- KTD26. **Mee gaan de laatste acht berichten van HP, elk met het slotantwoord van Claude op die beurt, elk afgekapt op 2000 tekens.** Het slotantwoord is de laatste tekst van Claude vóór het volgende bericht van HP; de helft van wat Claude schrijft is tussentijds commentaar van een regel. Dat is mediaan 11 KB en hooguit 32 KB. Daar komt de laatste tussenstand bij die Claude Code zelf in het bestand schrijft (`system`, subtype `away_summary`, rond 240 tekens), als die na het laatste echte bericht staat. Governs R56.
- KTD27. **Het gespreksbestand wordt van achteren naar voren gelezen, in blokken, tot het venster vol is.** De bestanden zijn mediaan 828 KB en lopen op tot 19,5 MB; het venster van KTD26 ligt mediaan in de laatste 600 KB. Een regel wordt pas gedecodeerd als hij de tekst `"type":"user"`, `"type":"assistant"` of `"subtype":"away_summary"` bevat en niet `"sourceToolAssistantUUID"`; die laatste staat in elk toolresultaat, samen 196 MB in de bekeken bestanden. De som: de grootste regel die het filter doorlaat is 1,3 MB, gedecodeerd een orde groter, één regel tegelijk. Het geheugen blijft onder enkele tientallen MB en meestal ver daaronder.
- KTD28. **Naast het gesprek gaan mee:** de laatste 15 commits (datum en onderwerp), de git-stand, en de eerste 4000 tekens van het nieuwste plan en van `docs/handoff/README.md`. Governs R56.

**De samenvatting: wanneer**

- KTD29. **Bij elke samenvatting hoort een vingerafdruk: de naam van het gespreksbestand, de `uuid` van het laatste echte bericht daarin, en de commit van `HEAD`.** Is de vingerafdruk gelijk aan die van de bewaarde samenvatting, dan volgt er geen aanroep. Een hervat gesprek waarin niets gezegd wordt, schrijft alleen regels van andere types bij (`system`, `cost-state`, `last-prompt`, `permission-mode`), sommige met een eigen `uuid`; daarom telt alleen de `uuid` van een echt bericht. Governs R60.
- KTD30. **Vier momenten brengen de samenvatting bij:** een project gaat van running naar active, de app start, een project gaat van active naar running, en de ververs-knop. Bij de start loopt de app alle projecten in de balk na; dat vangt het afsluiten op (R59), en ook een crash. De app staat dagen open, dus het starten van een project controleert opnieuw: dat vangt werk op dat buiten Claudeshell gebeurde en een project dat net is toegevoegd. De ververs-knop slaat de vingerafdruk over. Governs R57, R58, R59.
- KTD31. **Een wachtrij maakt de samenvattingen één voor één, met een time-out van 60 seconden per aanroep en zonder retries.** Het project dat HP start en het project waarvan hij op verversen drukt, gaan vooraan. Een project staat er hooguit één keer in; komt het erbij terwijl het aan de beurt is, dan volgt er daarna nog één ronde. De eerste start kost bij 19 projecten een tot twee minuten op de achtergrond en ongeveer $0,08. Governs R59.
- KTD32. **Mislukt een aanroep in de ronde bij de start, dan stopt die ronde.** Zonder netwerk of zonder inlog zouden er anders 19 mislukkingen op een rij volgen. De rest volgt bij het starten van een project of bij de volgende start van de app.
- KTD33. **Na het stoppen van een project wacht de app twee seconden met de samenvatting.** `SessionManager.stop` stuurt SIGHUP en na één seconde SIGKILL; daarna schrijft niemand meer in het gespreksbestand. Governs R57.
- KTD34. **Een samenvatting staat in `summaries/<project-id>.json` in de support-folder:** de tekst, het moment van maken en de vingerafdruk. Een project verwijderen verwijdert zijn bestand, ook als er op dat moment nog een aanroep voor loopt. Governs R57.
- KTD35. **Bij het afsluiten en bij 'Herstart Claudeshell' breekt de app lopende aanroepen af zonder erop te wachten.** Governs R59.

### Maten van de strook

Startwaarden; kleine bijstellingen bij het bouwen zijn geen afwijking van het plan.

| Onderdeel | Waarde |
|---|---|
| Hoogte | 62 punten: drie regels tekst van 12 punten met marge. Altijd dezelfde, met of zonder gegevens |
| Linker kolom | 300 punten breed: regel 1 de links, regel 2 de git-stand, regel 3 het workflow-label. Een link of label dat ontbreekt, laat de rest van de regel opschuiven |
| Rechter kolom | de rest: de samenvatting op hooguit drie regels, met klein de datum |
| Knoppen | ververs naast de datum, sluiten helemaal rechts |
| Git-stand schoon | grijs, bijvoorbeeld `main · schoon` |
| Git-stand met werk | donker en vet, bijvoorbeeld `main · 3 gewijzigd · 2 niet gepusht` |

### Opbouw

```mermaid
flowchart LR
    Select[project geselecteerd] --> Info[ProjectInfoStore]
    Loop[lus van 5 seconden] --> Info
    Moments[project stopt of start, app start, ververs-knop] --> Queue[SummaryQueue]
    Queue --> Info
    Info -- buiten de main actor --> Git[GitState]
    Info --> Links[ProjectLinks + LocalhostGuesser]
    Info --> Step[WorkflowStep]
    Info --> Writer[SummaryWriter]
    Writer --> Reader[TranscriptReader]
    Writer -- claude -p --> File[(summaries/id.json)]
    Git --> Run[Subprocess.run]
    Step --> Run
    Writer --> Run
    Info --> Strip[ProjectStripView]
```

### Output Structure

```
Sources/ClaudeshellCore/
  Project.swift            (gewijzigd: linkOverrides, LinkKind)
  ProjectStore.swift       (gewijzigd: setLink, clearLinkOverrides)
  Subprocess.swift         (nieuw)
  GitState.swift           (nieuw: de stand, en origin naar https)
  LocalhostGuesser.swift   (nieuw)
  ProjectLinks.swift       (nieuw)
  WorkflowStep.swift       (nieuw)
  TranscriptReader.swift   (nieuw)
  ProjectSummary.swift     (nieuw: het bestand en de vingerafdruk)
  SummaryWriter.swift      (nieuw)
  SummaryQueue.swift       (nieuw)
  ProjectInfoStore.swift   (nieuw)
Sources/Claudeshell/
  ProjectStripView.swift   (nieuw)
  MainWindowController.swift, MainMenu.swift, AppDelegate.swift (gewijzigd)
Tests/ClaudeshellCoreTests/
  SubprocessTests.swift, GitStateTests.swift, LocalhostGuesserTests.swift,
  ProjectLinksTests.swift, WorkflowStepTests.swift, TranscriptReaderTests.swift,
  ProjectSummaryTests.swift, SummaryWriterTests.swift, SummaryQueueTests.swift,
  ProjectInfoStoreTests.swift   (nieuw)
```

### Aannames

- Het rechtsklikmenu van de linker kolom heeft vier items: 'Live-link…', 'Localhost-link…', 'Git-link…' en 'Links opnieuw zoeken'. Het laatste wist alle eigen waarden van dat project, zodat een leeggemaakte link weer gevonden kan worden. Dat vierde item staat niet in de requirements.
- Het rechtsklikmenu van de samenvatting heeft één item: 'Kopieer samenvatting'.
- Een ingevulde link mag zonder schema: `localhost` en `127.0.0.1` krijgen `http://`, al het andere `https://`. Tekst zonder geldige host wordt geweigerd met dezelfde melding als bij de website, en de oude waarde blijft staan.
- De samenvatting van een running project wordt niet vanzelf bijgewerkt terwijl HP erin werkt. De strook is er voor het terugkomen; de ververs-knop is er voor tussendoor.
- Bij de start loopt de app alleen de projecten in de balk na, niet de inactive.
- Staat er in de strook een foutmelding van een mislukte poging, dan verdwijnt die bij een herstart van de app.
- Een project dat naar inactive gaat terwijl het draaide, krijgt ook zijn samenvatting.

### Risico's

- **De gespreksbestanden zijn geen publiek formaat.** De opbouw is afgelezen van 345 bestanden van Claude Code 2.1.220 tot en met 2.1.319 en kan met een nieuwe versie veranderen. `TranscriptReader` slaat elke regel over die hij niet begrijpt; in het ergste geval steunt de samenvatting alleen op de repo. De map- en veldnamen staan op één plek.
- **De vlaggen van de aanroep horen bij Claude Code 2.1.319.** De documentatie kondigt aan dat `claude -p` in een latere versie standaard de inlog van het abonnement niet meer leest. Dat toont zich als een mislukte poging met een melding over inloggen in de log (KTD22); de strook houdt dan de oude samenvattingen.
- **De app-bundel uit het Dock.** De aanroep is gemeten met een kale omgeving, niet vanuit de gebouwde app. Of `claude` vanuit de bundel bij zijn inlog in de sleutelhanger komt, toont U8.
- **'Gebouwd' is een vuistregel.** Een plan dat gecommit is en daarna gevolgd wordt door een tweak aan iets anders, leest als gebouwd. Het label verdwijnt dan te vroeg. Het omgekeerde, een label dat blijft hangen, komt alleen voor bij een plan dat nooit gecommit wordt.
- **De live-link is bij een paar projecten niet de eigen site.** De `website` is soms ingevuld voor het icoon, en zes Django-projecten hebben geen domein in `ALLOWED_HOSTS`. HP zet die links bij het eerste gebruik goed via rechtsklik.
- **De terminals krijgen bij open- en dichtklikken drie of vier regels meer of minder.** Claude tekent zijn scherm dan opnieuw, zoals bij het verslepen van het window. U8 controleert dat dit midden in een beurt geen verminkte uitvoer geeft.
- **De samenvatting bij het stoppen kan het laatste bericht missen.** Stopt HP een project terwijl Claude midden in een beurt zit, dan is het gespreksbestand mogelijk nog niet compleet, ook na de twee seconden van KTD33. De controle bij het opnieuw starten van het project herstelt dat.
- **De inhoud van het gesprek gaat naar het model.** Dat is hetzelfde account en dezelfde dienst als het gesprek zelf. De samenvatting staat alleen in de support-folder.
- **Een trage `git status` in een heel grote repo.** De rondes lopen na elkaar, dus een trage repo geeft een strook die achterloopt, geen stapel processen.

---

## Implementation Units

| # | Task | Touches | Depends on |
|---|------|---------|------------|
| U1 | Projectmodel: eigen links, en het samenvattingsbestand | `Sources/ClaudeshellCore/Project.swift`, `Sources/ClaudeshellCore/ProjectStore.swift`, `Sources/ClaudeshellCore/ProjectSummary.swift`, `Tests/ClaudeshellCoreTests/ProjectTests.swift`, `Tests/ClaudeshellCoreTests/ProjectStoreTests.swift`, `Tests/ClaudeshellCoreTests/ProjectSummaryTests.swift` | - |
| U2 | Processen starten en de git-stand | `Sources/ClaudeshellCore/Subprocess.swift`, `Sources/ClaudeshellCore/GitState.swift`, `Tests/ClaudeshellCoreTests/SubprocessTests.swift`, `Tests/ClaudeshellCoreTests/GitStateTests.swift` | - |
| U3 | Het laatste gesprek lezen | `Sources/ClaudeshellCore/TranscriptReader.swift`, `Tests/ClaudeshellCoreTests/TranscriptReaderTests.swift` | - |
| U4 | Links: localhost raden en de drie links samenstellen | `Sources/ClaudeshellCore/LocalhostGuesser.swift`, `Sources/ClaudeshellCore/ProjectLinks.swift`, `Tests/ClaudeshellCoreTests/LocalhostGuesserTests.swift`, `Tests/ClaudeshellCoreTests/ProjectLinksTests.swift` | U1, U2 |
| U5 | De workflow-stap | `Sources/ClaudeshellCore/WorkflowStep.swift`, `Tests/ClaudeshellCoreTests/WorkflowStepTests.swift` | U2 |
| U6 | De samenvatting maken | `Sources/ClaudeshellCore/SummaryWriter.swift`, `Tests/ClaudeshellCoreTests/SummaryWriterTests.swift` | U1, U2, U3 |
| U7 | Het geheugen van de strook | `Sources/ClaudeshellCore/SummaryQueue.swift`, `Sources/ClaudeshellCore/ProjectInfoStore.swift`, `Tests/ClaudeshellCoreTests/SummaryQueueTests.swift`, `Tests/ClaudeshellCoreTests/ProjectInfoStoreTests.swift` | U4, U5, U6 |
| U8 | De strook in de app | `Sources/Claudeshell/ProjectStripView.swift`, `Sources/Claudeshell/MainWindowController.swift`, `Sources/Claudeshell/MainMenu.swift`, `Sources/Claudeshell/AppDelegate.swift`, `docs/architecture.md`, `docs/doel.md` | U7 |

U1, U2 en U3 raken geen gedeelde bestanden en kunnen parallel. Daarna kunnen U4, U5 en U6 parallel. U7 en U8 volgen na elkaar.

### U1. Projectmodel: eigen links, en het samenvattingsbestand

**Goal:** een project kan eigen links dragen, en een samenvatting is op te slaan en terug te lezen.

**Requirements:** R54, R57, R62. Covers AE24.

**Dependencies:** geen.

**Files:** `Sources/ClaudeshellCore/Project.swift`, `Sources/ClaudeshellCore/ProjectStore.swift`, `Sources/ClaudeshellCore/ProjectSummary.swift`, `Tests/ClaudeshellCoreTests/ProjectTests.swift`, `Tests/ClaudeshellCoreTests/ProjectStoreTests.swift`, `Tests/ClaudeshellCoreTests/ProjectSummaryTests.swift`

**Approach:**

- `Project` krijgt `linkOverrides` volgens KTD12, met een `LinkKind` van drie waarden.
- `ProjectStore` krijgt `setLink(_:kind:for:)` naar het patroon van `setWebsite`: normaliseren en valideren volgens de aannames, en melden of de waarde is geaccepteerd. Een lege tekst bewaart de lege waarde. `clearLinkOverrides(for:)` wist het veld.
- `ProjectSummary` is de tekst, het moment en de vingerafdruk (KTD29), met lezen, schrijven en verwijderen in `summaries/<project-id>.json` (KTD34). De map wordt aangemaakt als hij ontbreekt. Een onleesbaar bestand telt als geen samenvatting.

**Execution note:** test-first; pure logica en tijdelijke mappen.

**Test scenarios:**

- Een `Project` met `linkOverrides` gaat via JSON heen en terug zonder verlies.
- JSON zonder `linkOverrides` (het huidige bestandsformaat) laadt, met het veld leeg.
- `setLink` met `voorbeeld.nl` voor live bewaart `https://voorbeeld.nl`.
- `setLink` met `localhost:8003` voor localhost bewaart `http://localhost:8003`; met `127.0.0.1:9000` idem met `http://`.
- `setLink` met `http://voorbeeld.nl/pad` blijft zoals ingevoerd.
- Covers AE24. `setLink` met een lege tekst of alleen spaties bewaart een lege waarde voor die soort, en die overleeft opslaan en laden.
- `setLink` met `geen link` wordt geweigerd en de oude waarde blijft staan.
- `setLink` voor een onbekend project meldt onwaar en wijzigt niets.
- `clearLinkOverrides` wist alle drie; de andere velden van het project blijven.
- Een samenvatting schrijven en teruglezen geeft dezelfde tekst, hetzelfde moment en dezelfde vingerafdruk.
- Lezen zonder bestand geeft niets; lezen van een bestand met onzin geeft niets en geen crash.
- Schrijven terwijl de map `summaries` nog niet bestaat, maakt hem aan.
- Verwijderen van een samenvatting die er niet is, geeft geen fout.

**Verification:** alle scenario's slagen in `swift test`; de bestaande tests voor website en icoon blijven groen.

### U2. Processen starten en de git-stand

**Goal:** een proces starten en zijn uitvoer teruglezen, en daarmee de git-stand en de repo-link van een folder bepalen.

**Requirements:** R49, R61. Covers AE19, AE20.

**Dependencies:** geen.

**Files:** `Sources/ClaudeshellCore/Subprocess.swift`, `Sources/ClaudeshellCore/GitState.swift`, `Tests/ClaudeshellCoreTests/SubprocessTests.swift`, `Tests/ClaudeshellCoreTests/GitStateTests.swift`

**Approach:**

- `Subprocess.run` start een programma met argumenten, werkmap, optionele invoer en een time-out, en geeft de standaarduitvoer terug, volgens KTD7. Een exitcode ongelijk aan nul en een verlopen time-out zijn een fout; bij een time-out en bij annuleren wordt het proces beëindigd. De fout draagt de exitcode en de uitvoer, zodat de aanroeper een JSON-foutmelding nog kan lezen (KTD22).
- De uitvoer wordt gelezen terwijl de invoer geschreven wordt, en de invoer wordt daarna gesloten. Zo loopt een grote prompt niet vast op een volle pipe, en een programma dat antwoordt terwijl het leest ook niet. De foutuitvoer wordt op dezelfde manier weggelezen.
- Het type van de geïnjecteerde functie (KTD6) staat hier, zodat de andere onderdelen het delen.
- `GitState` heeft een parser voor de uitvoer van KTD8 en een functie die de stand van een folder ophaalt via de geïnjecteerde `run`. De stand kent: branch, aantal gewijzigde bestanden, aantal niet-gepushte commits of 'geen upstream', en de commit van `HEAD`.
- `GitState.browsableURL(fromRemote:)` zet een remote om volgens KTD13.

**Execution note:** test-first. De parser met vaste tekst; het ophalen met echte repo's die de test in een tijdelijke map aanmaakt met `git init`, met een eigen `user.name` en `user.email` per repo zodat de test niet afhangt van de instellingen van de machine.

**Test scenarios:**

- `Subprocess.run` van `/bin/echo hallo` geeft `hallo`.
- Invoer van 200 KB naar `/bin/cat` komt volledig terug.
- Een programma met exitcode 1 geeft een fout die de exitcode en de uitvoer draagt; een programma dat niet bestaat geeft ook een fout.
- `/bin/sleep 5` met een time-out van een halve seconde geeft binnen een seconde een fout.
- De taak annuleren terwijl `/bin/sleep 5` loopt: de aanroep eindigt binnen een seconde en het proces is weg.
- De werkmap wordt gebruikt: `/bin/pwd` geeft de opgegeven map.
- De parser op uitvoer met `# branch.head main`, `# branch.ab +2 -0` en drie regels zonder `#`: branch `main`, 3 gewijzigd, 2 niet gepusht.
- De parser zonder `# branch.ab`: 'geen upstream'.
- De parser met `# branch.head (detached)` geeft een losse HEAD als branch-tekst.
- De parser op een verse repo met `# branch.oid (initial)` geeft een stand zonder commit.
- Regels met de prefixen `1`, `2`, `u` en `?` tellen elk als één gewijzigd bestand.
- De aanroep van git die `run` krijgt, bevat `--no-optional-locks`.
- Covers AE19. Een map die geen repo is, geeft geen stand en geen crash.
- Covers AE20. Een echte repo met één commit en één nieuw bestand: 1 gewijzigd. Na `git add` en `git commit`: 0 gewijzigd.
- Een echte repo zonder remote: 'geen upstream'.
- Een echte repo met een kale tweede repo als `origin` en één lokale commit erbij: 1 niet gepusht.
- `git@github.com:gebruiker/repo.git` wordt `https://github.com/gebruiker/repo`.
- `https://naam:geheim@github.com/gebruiker/repo.git` wordt `https://github.com/gebruiker/repo`.
- `ssh://git@voorbeeld.nl:2222/gebruiker/repo.git` wordt `https://voorbeeld.nl/gebruiker/repo`.
- `https://git.heroku.com/app.git` en `dokku@voorbeeld.nl:app` geven geen link.
- Een lege tekst geeft geen link.

**Verification:** alle scenario's slagen in `swift test`, zonder netwerk.

### U3. Het laatste gesprek lezen

**Goal:** voor een projectfolder de laatste beurten van het laatste Claude-gesprek, met een kenmerk van het laatste echte bericht.

**Requirements:** R56, R60.

**Dependencies:** geen.

**Files:** `Sources/ClaudeshellCore/TranscriptReader.swift`, `Tests/ClaudeshellCoreTests/TranscriptReaderTests.swift`

**Approach:**

- De map van een project volgens KTD23. De hoofdmap van de gesprekken is een parameter met `~/.claude/projects` als standaard, zodat tests een tijdelijke map gebruiken.
- Het gesprek kiezen volgens KTD24, lezen volgens KTD27, filteren volgens KTD25 en het venster samenstellen volgens KTD26.
- De tekst van HP staat in `message.content` als tekst of als lijst met blokken van het type `text`; die van Claude in de blokken van het type `text`. De tussenstand staat in het veld `content` van de `system`-regel.
- Het resultaat: de beurten in volgorde (het bericht van HP en het slotantwoord van Claude), de tussenstand als die er is, de naam van het bestand en de `uuid` van het laatste echte bericht.
- Geen map, geen bestand of geen enkel echt bericht geeft een leeg resultaat.

**Execution note:** test-first. De tests schrijven hun eigen `.jsonl`-regels met verzonnen tekst; er gaat geen echt gesprek in de fixtures.

**Test scenarios:**

- `/Users/x/proj/voorbeeld` wordt `-Users-x-proj-voorbeeld`; `/Users/x/Sites/voorbeeld.nl` wordt `-Users-x-Sites-voorbeeld-nl`; `/Users/x/proj/a_b c` wordt `-Users-x-proj-a-b-c`; `/Users/x/.claude` wordt `-Users-x--claude`; hoofdletters blijven.
- Twee gesprekken met berichten: het gesprek met het laatste echte bericht wordt gelezen.
- Het nieuwste bestand bevat alleen `system`- en `cost-state`-regels: het oudere bestand met berichten wordt gelezen.
- Het nieuwste bestand bevat alleen de twee omhulsel-regels van `/clear`: het oudere bestand wordt gelezen.
- Het bestand met de nieuwste wijzigingstijd heeft een ouder laatste bericht dan het andere: het andere wordt gelezen.
- Het nieuwste gesprek heeft `entrypoint` `sdk-cli`: het wordt overgeslagen.
- Een `.jsonl` in een submap `subagents` wordt niet gekozen.
- Een bericht van HP met `content` als tekst en een met `content` als lijst van tekstblokken komen er allebei uit.
- Een bericht van Claude met een `thinking`-blok, een `text`-blok en een `tool_use`-blok levert alleen de tekst.
- Eén scenario per soort die niet telt: een `tool_result`, `isMeta`, `isCompactSummary`, `origin.kind` `task-notification`, en tekst die begint met `<task-notification>`, `<command-name>`, `<local-command-stdout>`, `<local-command-caveat>`, `<bash-input>`, `<bash-stdout>` en `[Request interrupted`.
- Een regel met `<command-message>` en argumenten telt als bericht van HP.
- Een bericht van Claude met model `<synthetic>` en een met `isApiErrorMessage` tellen niet.
- Een beurt met drie teksten van Claude tussen toolaanroepen: alleen de laatste komt mee.
- Twaalf beurten: de laatste acht komen terug, in volgorde.
- Een bericht van 5000 tekens komt terug als 2000 tekens.
- Een `away_summary` na het laatste echte bericht komt mee; een `away_summary` ervoor niet.
- De `uuid` in het resultaat is die van het laatste echte bericht, ook als er daarna nog een `system`-regel met een eigen `uuid` staat.
- Regels van andere types en een regel die geen JSON is, worden overgeslagen zonder fout.
- Een bestand van 20 MB waarvan de laatste acht beurten in de laatste 100 KB staan: de acht beurten komen terug en er is minder dan 2 MB van het bestand gelezen.
- Een toolresultaat-regel van 1 MB tussen twee beurten wordt overgeslagen zonder te decoderen, en beide beurten komen terug.
- Geen map voor het project: leeg resultaat.

**Verification:** alle scenario's slagen in `swift test`.

### U4. Links: localhost raden en de drie links samenstellen

**Goal:** voor een project de drie links zoals de strook ze toont.

**Requirements:** R48, R61, R62. Covers AE19, AE24.

**Dependencies:** U1, U2.

**Files:** `Sources/ClaudeshellCore/LocalhostGuesser.swift`, `Sources/ClaudeshellCore/ProjectLinks.swift`, `Tests/ClaudeshellCoreTests/LocalhostGuesserTests.swift`, `Tests/ClaudeshellCoreTests/ProjectLinksTests.swift`

**Approach:**

- `LocalhostGuesser` leest `runlocal.sh` in de projectroot en geeft `http://localhost:<poort>` volgens KTD14, of niets.
- `ProjectLinks.resolve` geeft per soort een URL of niets. Per soort: staat er een waarde in `linkOverrides`, dan geldt die, en een lege waarde betekent geen link. Anders de gevonden link volgens KTD13, met `DomainGuesser`, `LocalhostGuesser` en `GitState.browsableURL` via de geïnjecteerde `run`.

**Execution note:** test-first, met tijdelijke mappen en een `run` met vaste antwoorden.

**Test scenarios:**

- `python manage.py runserver 8082` geeft `http://localhost:8082`.
- `python manage.py runserver $PORT` met `PORT=9000` in `.env` geeft poort 9000.
- `runserver "$PORT"` met aanhalingstekens en `PORT=8086` in `.env` geeft 8086.
- `runserver ${LOCAL_PORT}` met `LOCAL_PORT=8091` en ook `EMAIL_PORT=587` in `.env` geeft 8091.
- `uvicorn app:app --port ${PORT:-8000}` zonder `.env` geeft 8000; met `PORT=8005` in `.env` geeft 8005.
- `FRONTEND_PORT=5173` in het script en verderop `http.server $FRONTEND_PORT` geeft 5173.
- `LOCAL_PORT=${ANDERS:-$LOCAL_PORT}` in het script, `runserver $LOCAL_PORT` en `LOCAL_PORT=8083` in `.env` geeft 8083.
- Een uitgecommentarieerde regel met `@localhost:5432` en verderop `runserver 8080` geeft 8080.
- Een script met `echo 'http://localhost:8000/pad/'` en geen ander spoor geeft `http://localhost:8000`.
- `runserver $PORT` zonder `.env` geeft niets.
- Een script zonder poort (`open build/Voorbeeld.app`) geeft niets; een folder zonder `runlocal.sh` ook.
- `PORT="9000"` en `PORT=9000 # commentaar` in `.env` geven allebei 9000; `PORT=abc` geeft niets.
- Covers AE19. Een project zonder repo, zonder website, zonder domein en zonder `runlocal.sh` geeft drie keer niets.
- Een project met `website` krijgt die als live-link; zonder `website` maar met een `CNAME` het domein daaruit met `https://`.
- `run` geeft voor `git remote get-url origin` een GitHub-remote: de git-link is de https-vorm.
- Een eigen live-link wint van de `website`.
- Covers AE24. Een leeggemaakte localhost-link geeft geen link, ook al levert `runlocal.sh` een poort.
- Een eigen git-link wint van de remote.

**Verification:** alle scenario's slagen in `swift test`.

### U5. De workflow-stap

**Goal:** voor een projectfolder één label met het document waar het uit volgt, of niets.

**Requirements:** R50, R64, R65. Covers AE25.

**Dependencies:** U2.

**Files:** `Sources/ClaudeshellCore/WorkflowStep.swift`, `Tests/ClaudeshellCoreTests/WorkflowStepTests.swift`

**Approach:**

- `WorkflowStep.detect` loopt de vier stappen van KTD16 af en stopt bij de eerste die past. Het resultaat is het soort stap en de naam volgens KTD18.
- Frontmatter lezen is: de regels tussen de eerste twee `---`, en daaruit `origin:` en `status:`. Geen YAML-bibliotheek.
- De takentabel van de handoff: de kolom met de kop `Status`, en per rij het eerste woord van die cel in kleine letters.
- 'Gebouwd' volgens KTD17, met git via de geïnjecteerde `run`.
- In `docs/plans` tellen alleen bestanden die op `-plan.md` eindigen; changelogs staan in dezelfde map.
- Een folder zonder `docs/` en zonder repo geeft niets.

**Execution note:** test-first, met echte repo's in een tijdelijke map zoals in U2. De namen van projecten, plannen en branches in de fixtures zijn verzonnen.

**Test scenarios:**

- Een lege folder, en een repo zonder `docs/`: geen label.
- Een `docs/brainstorms/2026-01-05-voorbeeld-requirements.md` zonder plan: 'requirements, nog geen plan' met die bestandsnaam.
- Hetzelfde met een plan waarvan `origin:` naar dat bestand wijst en dat niet gecommit is: 'plan, nog niet gebouwd' met de naam van het plan.
- Een plan waarvan `origin:` twee bestandsnamen met een komma ertussen bevat: beide requirementsdocumenten hebben een plan.
- Een plan zonder `origin:` maar met `voorbeeld` in de naam en dezelfde datum: het hoort bij de brainstorm.
- Een brainstorm met een ouder plan van een ander onderwerp: 'requirements, nog geen plan'.
- Twee brainstorms van dezelfde dag, `…-appel-requirements.md` zonder plan en `…-peer-requirements.md` met een gebouwd plan: het label wijst naar appel.
- Een brainstorm zonder plan van een eerdere dag en een nieuwere met een gebouwd plan: geen label.
- Een gecommit plan zonder commits erna: 'plan, nog niet gebouwd'.
- Een gecommit plan met daarna een commit die alleen `docs/architecture.md` raakt: nog niet gebouwd.
- Een gecommit plan met daarna een commit die `src/app.py` raakt: geen label.
- Een gecommit plan met daarna alleen een commit `publish ma 5 jan` die `pyproject.toml` raakt: nog niet gebouwd.
- Het plan en `src/app.py` in één commit, zonder commits erna: geen label.
- Een plan met `status: completed`, niet gecommit: geen label.
- Twee plannen: alleen het nieuwste telt. Is dat gebouwd en het oudere niet, dan geen label.
- Het plan met de oudere naam heeft de nieuwste wijzigingstijd: het plan met de nieuwere naam telt.
- Een bestand `2026-01-06-01-voorbeeld-dev-changelog.md` in `docs/plans` telt niet als plan.
- Een plan in een `docs/` die in `.gitignore` staat: geen label.
- Een plan in een folder zonder repo: geen label.
- Een tweede worktree op branch `feat/voorbeeld` met één eigen commit: 'build bezig' met de branchnaam. Op branch `fix/voorbeeld`: 'bugfix bezig'.
- Een tweede worktree waarvan de branch geen commits heeft die `HEAD` mist, en geen plan: geen label.
- Een verse tweede worktree zonder eigen commits en een niet-gebouwd plan: 'plan, nog niet gebouwd'.
- Een `docs/handoff/README.md` met een rij op `doing`: 'handoff open'. Met `doing: wacht op antwoord` ook. Met `blocked` en `todo` ook.
- Een handoff met een taak die 'todo-lijst opschonen' heet en status `done`: geen handoff-label.
- Een handoff met alleen rijen op `done`: geen handoff-label, en de volgende stappen worden bekeken.
- Covers AE25. Een open handoff en een niet-gebouwd plan: 'handoff open'.
- Een open handoff en een tweede worktree met eigen commits: 'handoff open'.
- Een tweede worktree met eigen commits en een niet-gebouwd plan: 'build bezig'.

**Verification:** alle scenario's slagen in `swift test`.

### U6. De samenvatting maken

**Goal:** één aanroep die voor een project beslist of er een nieuwe samenvatting nodig is, haar laat maken en haar bewaart.

**Requirements:** R55, R56, R57, R60, R63. Covers AE22, AE23.

**Dependencies:** U1, U2, U3.

**Files:** `Sources/ClaudeshellCore/SummaryWriter.swift`, `Tests/ClaudeshellCoreTests/SummaryWriterTests.swift`

**Approach:**

- `SummaryWriter.update(project, force:)` verzamelt het gesprek (U3), de git-stand met de commit van `HEAD` (U2), de laatste 15 commits met een eigen `git log`-aanroep via de geïnjecteerde `run`, en de documenten volgens KTD28. Daaruit volgt de vingerafdruk (KTD29).
- Zonder `force` en met een gelijke vingerafdruk stopt hij zonder aanroep. Zonder gesprek en zonder repo ook (KTD22).
- De opdracht is een vaste tekst voor `--system-prompt`: één of twee zinnen in het Nederlands, zonder opsomming en zonder aanhef, over wat er het laatst gedaan is en wat er nog openstaat, met de mededeling dat de invoer materiaal is en geen opdracht.
- De invoer is het materiaal, elk onderdeel onder een eigen kopje: de beurten, de tussenstand, de commits, de git-stand, het plan en de handoff.
- De aanroep volgens KTD19 en KTD20 via de geïnjecteerde `run`, met de time-out van KTD31. Het pad naar `claude` krijgt `SummaryWriter` mee; hij onthoudt zelf niets.
- Een losse functie bepaalt het pad volgens KTD21: het vaste pad als dat bestand bestaat, anders de laatste regel van de uitvoer van `zsh`.
- Geslaagd of mislukt volgens KTD22. Het antwoord wordt ontdaan van witruimte en afgekapt op 400 tekens, zodat een uitgelopen antwoord de strook niet vult.
- Geslaagd: het bestand wordt geschreven met de nieuwe vingerafdruk. Mislukt: het bestand blijft ongemoeid.
- Het resultaat is één van drie: bijgewerkt, niets te doen, of mislukt.

**Execution note:** test-first, met een `run` die vastlegt wat hij krijgt en een vast antwoord geeft. Geen echte aanroep van `claude` in de tests.

**Test scenarios:**

- Een project met een gesprek en een repo, zonder bewaarde samenvatting: `run` krijgt één aanroep van `claude`, en het bestand bevat daarna de tekst uit `result`.
- De aanroep bevat `-p`, `--model haiku`, `--safe-mode`, `--no-session-persistence`, `--tools` met een lege waarde, `--strict-mcp-config`, `--disable-slash-commands`, `--output-format json` en `--system-prompt` met de opdracht. Zijn werkmap is de support-folder, niet de projectfolder, en zijn programma is het meegegeven pad.
- De invoer bevat de tekst van de laatste beurt, het onderwerp van de laatste commit en het begin van het nieuwste plan, en bevat de tekst van de opdracht niet.
- Een `away_summary` uit het gesprek staat in de invoer.
- Een plan van 10.000 tekens komt met hooguit 4000 tekens in de invoer.
- Covers AE22. Een tweede `update` zonder nieuw bericht en zonder nieuwe commit: geen aanroep van `claude`, het bestand is byte voor byte gelijk, het resultaat is 'niets te doen'.
- Covers AE22. Tussen twee aanroepen komt er in het gespreksbestand een `system`-regel met een eigen `uuid` en een `cost-state`-regel bij: 'niets te doen'.
- Covers AE22. Er komt een `away_summary` bij: 'niets te doen'.
- Covers AE22. Er komt een nieuw gespreksbestand bij met alleen de omhulsel-regels van `/clear`: 'niets te doen'.
- Een nieuw bericht van HP in het gesprek: wel een aanroep. Een nieuwe commit zonder nieuw bericht: ook.
- `force` met een gelijke vingerafdruk: wel een aanroep.
- Covers AE23. `run` geeft een fout voor `claude`: het bestaande bestand is byte voor byte gelijk en het resultaat is 'mislukt'.
- Het antwoord heeft `is_error` op waar, `subtype` op `success` en een foutmelding in `result`: mislukt, bestand ongemoeid, en de foutmelding staat nergens in een samenvatting.
- Een exitcode ongelijk aan nul met geldige JSON in de uitvoer: mislukt.
- Het antwoord is geen JSON: mislukt. Een lege `result`: mislukt.
- Een `result` van 900 tekens wordt bewaard als 400 tekens.
- Een project zonder gesprek maar met een repo: er volgt een aanroep, met alleen de repo-onderdelen in de invoer.
- Een project zonder gesprek en zonder repo: geen aanroep, 'niets te doen'.
- Het pad bepalen: het vaste pad bestaat, dus geen aanroep van `zsh`.
- Het pad bepalen: het vaste pad bestaat niet, dus één aanroep van `zsh`, en de laatste regel van zijn uitvoer is het pad.
- Het pad bepalen: het vaste pad bestaat niet en `zsh` geeft niets: geen pad.

**Verification:**

- Alle scenario's slagen in `swift test`, zonder netwerk.
- Eén echte aanroep met de hand, met de vlaggen van KTD19 vanuit een lege map en het materiaal van een eigen project als invoer: het antwoord is één of twee Nederlandse zinnen die kloppen met het project. De tijd en de kosten uit de JSON staan in het commitbericht van deze unit. Wijkt de tijd sterk af van de gemeten 3 tot 6 seconden, dan is dat een bevinding om te melden, geen reden om de vlaggen op eigen gezag te wijzigen.

### U7. Het geheugen van de strook

**Goal:** één plek die per project de gegevens van de strook bijhoudt, de strook open en dicht houdt, en de samenvattingen op de juiste momenten laat maken.

**Requirements:** R51, R53, R57 tot en met R60, R63. Covers AE21, AE22, AE26, AE27.

**Dependencies:** U4, U5, U6.

**Files:** `Sources/ClaudeshellCore/SummaryQueue.swift`, `Sources/ClaudeshellCore/ProjectInfoStore.swift`, `Tests/ClaudeshellCoreTests/SummaryQueueTests.swift`, `Tests/ClaudeshellCoreTests/ProjectInfoStoreTests.swift`

**Approach:**

- `SummaryQueue` is een waarde zonder eigen werk: de wachtende project-id's op volgorde, elk met of het geforceerd is, en het project dat aan de beurt is. De regels staan in KTD31.
- `ProjectInfoStore` is `@MainActor @Observable` in `ClaudeshellCore`, zoals `ProjectStore` en `AttentionTracker`. Hij heeft geen AppKit nodig. Hij krijgt de `ProjectStore`, de support-folder en de `run` mee.
- Per project-id (KTD11): de links, de git-stand, de workflow-stap, de samenvatting, of er een samenvatting gemaakt wordt, en of de laatste poging mislukte.
- De set dichtgeklikte projecten van KTD2, met `isOpen` voor het geselecteerde project, `toggle`, en het heropenen bij een geslaagde start.
- `refresh(id)` haalt links, git-stand en workflow-stap op buiten de main actor en laadt de bewaarde samenvatting. `poll(id)` haalt alleen git-stand en workflow-stap op. Een pure functie zegt of de lus van KTD9 mag lopen: is er een selectie, is de strook open, staat de app vooraan. De lus zelf en het signaal 'app vooraan' horen bij U8.
- De wachtrij verwerken: één project tegelijk via `SummaryWriter.update`, en na afloop het resultaat verwerken. De momenten van KTD30 zijn vier ingangen: gestopt (na de wachttijd van KTD33), gestart (vooraan), ververs (vooraan en geforceerd), en de ronde bij de start van de app, die stopt bij de eerste mislukking (KTD32). De wachttijd is een parameter, zodat tests hem op nul zetten.
- Het pad naar `claude` wordt bij de eerste samenvatting bepaald en onthouden (KTD21). Geen pad is een mislukte poging.
- Van `IconStore` overnemen: de taken staan buiten de observatie, het project wordt vóór het wachten vastgelegd en daarna opnieuw opgezocht, en is het project intussen verwijderd, dan wordt het bestand verwijderd dat de aanroep net schreef.
- `forget(id)` wist het bestand, de gegevens en de plek in de wachtrij. `cancelAll()` breekt lopend werk af zonder te wachten (KTD35).
- Elke ingang is er in twee vormen: een die het werk afwacht, voor de tests, en een die een taak start, voor de app.

**Execution note:** test-first, met een `run` met vaste antwoorden en een tijdelijke support-folder.

**Test scenarios:**

- Wachtrij: een project dat er al in staat, komt er niet nog eens in.
- Wachtrij: een geforceerde aanvraag maakt een wachtende gewone aanvraag geforceerd.
- Wachtrij: een aanvraag 'vooraan' komt vóór de wachtenden.
- Wachtrij: `remove` haalt een wachtend project eruit.
- Wachtrij: een aanvraag voor het project dat aan de beurt is, geeft daarna precies één extra ronde.
- Wachtrij: er is nooit meer dan één project aan de beurt.
- Covers AE26. A dichtklikken: `isOpen` is onwaar met A geselecteerd en waar met B geselecteerd, en weer onwaar terug bij A.
- Covers AE27. A dichtklikken en daarna als gestart melden: `isOpen` is waar.
- Zonder selectie is `isOpen` onwaar.
- De lus mag lopen met selectie, open strook en app vooraan, en in geen van de drie andere gevallen.
- `refresh` voor A zet links, git-stand en workflow-stap onder A, en laadt de bewaarde samenvatting van A.
- `refresh` voor A terwijl B geselecteerd is: de gegevens staan onder A en die van B zijn ongemoeid.
- 'Gestopt' voor een project met een nieuw bericht: na verwerken bestaat het bestand en staat de samenvatting in de store.
- Covers AE22. 'Gestopt' zonder nieuw bericht of commit: geen aanroep van `claude`.
- 'Ververs' met een gelijke vingerafdruk: wel een aanroep.
- Tijdens het maken staat de bezig-vlag van dat project aan, daarna uit.
- Een mislukte poging zet de mislukt-vlag en laat de oude samenvatting staan; de volgende geslaagde poging haalt de vlag weg.
- Covers AE21. De ronde bij de start zet de projecten in de balk in de wachtrij en de inactive niet.
- De ronde bij de start met drie projecten waarvan de eerste mislukt: één aanroep van `claude`, de andere twee blijven zonder mislukt-vlag.
- Een mislukking bij 'gestopt' stopt de rest van de wachtrij niet.
- `forget` terwijl de aanroep voor dat project loopt: na afloop staat er geen bestand in `summaries/` en geen gegeven in de store.
- Het pad naar `claude` wordt één keer bepaald, ook bij drie samenvattingen achter elkaar.
- Geen pad naar `claude`: mislukt-vlag, geen bestand.

**Verification:** alle scenario's slagen in `swift test`, zonder netwerk en zonder echte aanroep van `claude`.

### U8. De strook in de app

**Goal:** de strook staat in het window, toont de gegevens van het gekozen project, gaat open en dicht, en de app meldt de momenten aan de store.

**Requirements:** R47 tot en met R54, R57 tot en met R59, R63. Covers F6, F7, F8, AE19 tot en met AE24, AE26, AE27.

**Dependencies:** U7.

**Files:** `Sources/Claudeshell/ProjectStripView.swift`, `Sources/Claudeshell/MainWindowController.swift`, `Sources/Claudeshell/MainMenu.swift`, `Sources/Claudeshell/AppDelegate.swift`, `docs/architecture.md`, `docs/doel.md`

**Approach:**

- `ProjectStripView` volgens 'Maten van de strook' en KTD5. Een link is de korte naam (`live`, `localhost`, `git`) met de volledige URL in de tooltip. Zonder samenvatting staat er 'Nog geen samenvatting'; na een mislukte poging 'Verversen lukte niet' naast de oude tekst; tijdens het maken een kleine bezig-indicator bij de ververs-knop.
- `MainWindowController`:
  - `buildLayout` plaatst de strook volgens KTD1.
  - Een eigen functie zet de strook zichtbaar of verborgen en wisselt de constraint. `refresh` roept haar aan vóór het plaatsen van de panes, in de volgorde van KTD4. `toggleStrip`, de knop en de link-dialogen roepen alleen die functie aan (KTD5).
  - `select` meldt een geslaagde start aan de store, binnen de tak waar `sessions.start` waar teruggeeft (KTD2, KTD30).
  - `stop` en `deactivate` gaan via één eigen functie die de sessies stopt en 'gestopt' meldt (KTD33). Dat is de enige plek waar een project van running naar active gaat.
  - `remove` roept `forget` aan, naast `icons.forget`.
  - De lus van KTD9 als één taak die bij elke aanleiding opnieuw begint. De controller volgt al wanneer de app de focus verliest; daar komt 'weer vooraan' bij.
  - De drie link-dialogen gebruiken het bestaande `ask`, met de huidige waarde ingevuld, en de melding van `editWebsite` bij een geweigerde waarde. Na een geaccepteerde waarde worden de links opnieuw bepaald.
- `MainMenu` krijgt het menu 'Beeld' met 'Projectstrook', Cmd+I (KTD3).
- `AppDelegate` maakt de `ProjectInfoStore` aan met de support-folder en `Subprocess.run`, geeft hem door, en start de ronde van KTD30. `applicationWillTerminate` en `restart` roepen `cancelAll` aan (KTD35) en wachten nergens op (R59).
- `docs/architecture.md`:
  - de inleiding, en de rijen van `MainWindowController.swift` en `AppDelegate.swift`;
  - de nieuwe bestanden in beide tabellen;
  - `summaries/` en `linkOverrides` onder 'Files on disk', en de logcategorie `Summary`;
  - een sectie 'Projectstrook': de bronnen per gegeven, de vier momenten voor de samenvatting, de aanroep van `claude` met zijn vlaggen, de vaste paden naar `claude` en git, en de regel dat gegevens per project-id staan met één lus en één samenvatting tegelijk;
  - een gedateerde notitie zoals bij de hooks: de opbouw van de gespreksbestanden zoals gezien met Claude Code 2.1.319;
  - bij 'Panes and sessions': stoppen zet twee seconden later een samenvatting in de wachtrij;
  - bij 'Resuming the last conversation': de aanroep voor de samenvatting laat geen gesprek achter.
- `docs/doel.md` krijgt een alinea over de strook.

**Execution note:** de logica is in U1 tot en met U7 getest; hier telt de controle met de hand in de gebouwde app, eerst met `CLAUDESHELL_SUPPORT` op een testfolder met een kopie van `projects.json`, daarna met de echte projecten.

**Test scenarios:** geen nieuwe unit tests; U1 tot en met U7 dekken de logica.

**Verification:**

- `swift build` en `swift test` slagen.
- Covers F6. Een active project starten: de strook staat open met links de links, de git-stand en zo nodig een label, en rechts de samenvatting of 'Nog geen samenvatting'.
- Zonder geselecteerd project, direct na de start van de app, is er geen strook.
- Covers AE19. Een folder zonder git, `docs/` en website: de linker kolom is leeg, de strook is even hoog als bij andere projecten, en er staat geen foutmelding.
- Een klik op elk van de drie links opent de juiste pagina in de browser.
- Een schone, gepushte repo oogt grijs; een repo met werk valt op.
- Covers AE20. `touch x` in de shell-pane: binnen vijf seconden staat er één gewijzigd bestand meer. `git add x && git commit -m x`: het aantal gewijzigd daalt en het aantal niet gepusht stijgt.
- Een commit maken in een andere app en met Cmd+Tab terugkomen: de strook klopt direct.
- Het label verschijnt binnen vijf seconden nadat er een requirementsdocument in `docs/brainstorms` is gezet, en de tooltip noemt het bestand.
- Na `git worktree add .worktrees/x -b feat/x` en een commit in die worktree staat er binnen vijf seconden 'build bezig'; na `git worktree remove` is dat label weer weg.
- Terwijl de strook open staat, lukt `git add` en `git commit` in de shell-pane tien keer achter elkaar zonder melding over `index.lock`.
- De sluitknop en Cmd+I sluiten de strook; de terminals worden hoger. Cmd+I en 'Beeld > Projectstrook' openen haar weer. Dit werkt ook met de focus in de shell-pane en in de Claude-pane.
- Na een klik op sluiten, verversen of een link, en na Cmd+I, komt wat HP typt in de pane die de focus had.
- Tien keer open en dicht terwijl Claude midden in een beurt zit: de uitvoer van Claude blijft leesbaar.
- Bij open en dicht en bij een window van 480 punten breed staan er geen constraint-waarschuwingen in de console.
- De positie van de scheidslijn tussen de panes is na open- en dichtklikken en een herstart dezelfde.
- Covers AE26. Dichtklikken in project A, naar B en terug: in B open, in A dicht, en de terminals verspringen bij elke wissel één keer.
- Covers AE27. A stoppen en opnieuw starten: de strook is open.
- Covers F7. Een project stoppen na een kort gesprek: binnen een minuut bestaat `summaries/<id>.json` met een samenvatting van één of twee Nederlandse zinnen, en de app bleef al die tijd bruikbaar.
- Covers AE22. Hetzelfde project starten en meteen weer stoppen: het bestand en zijn datum zijn onveranderd.
- De ververs-knop maakt een nieuwe samenvatting met de datum van nu. 'Kopieer samenvatting' zet de tekst op het klembord.
- Covers AE21. Vier projecten running, app afsluiten: de app is direct weg. Na het openen worden de samenvattingen op de achtergrond bijgewerkt; `log stream` toont ze één voor één.
- Tijdens die ronde een project starten: zijn samenvatting komt als eerstvolgende.
- Covers AE23. Wifi uit en een project stoppen: de oude samenvatting staat er nog. Dat project weer openen toont 'Verversen lukte niet'. De app starten zonder wifi geeft één mislukte poging in de log, geen negentien.
- Covers F8. Rechtsklik, 'Live-link…', een andere URL invullen: de link wijzigt direct en het icoon van de tile niet.
- Covers AE24. De localhost-link leegmaken en de app herstarten: geen localhost-link. 'Links opnieuw zoeken' brengt hem terug.
- Een ongeldige link invullen geeft de melding en laat de oude waarde staan.
- Na een samenvatting is er in `~/.claude/projects/` geen gespreksbestand bijgekomen voor de support-folder of voor het project, en `claude --continue` in de Claude-pane hervat het echte gesprek.
- De app gestart uit het Dock (`scripts/install-app.sh`) maakt ook een samenvatting; zo niet, dan staat de reden in `log stream`.
- Een project verwijderen: zijn bestand in `summaries/` is weg.

---

## Verification Contract

- `swift build` slaagt zonder waarschuwingen in eigen code.
- `swift test` slaagt, zonder netwerk en zonder een echte aanroep van `claude`. Alle nieuwe logica in `ClaudeshellCore` heeft tests.
- `./runlocal.sh` bouwt en opent `build/Claudeshell.app`.
- De Verification-lijst van U8 is met de hand doorlopen in de gebouwde app. Ze dekt AE19 tot en met AE24, AE26, AE27 en F6 tot en met F8. AE25 is gedekt door de tests van U5.
- De bestaande verificatie werkt nog: klik, Cmd+cijfer, Cmd+P, de spring-sneltoets, het geluid en de iconen.

## Definition of Done

- Elke requirement R47 tot en met R65 is terug te vinden in een geslaagde test of een afgevinkt verificatiepunt.
- Een bestaand `projects.json` laadt zonder handwerk.
- De gemeten tijd en kosten van een echte samenvatting staan in het commitbericht van U6.
- `docs/architecture.md` en `docs/doel.md` beschrijven de strook.
- Fixtures en documentatie bevatten geen echte klantnamen en geen tekst uit echte gesprekken.
- Er is niets gepusht.

## Uitgesteld

- De stap 'gebouwd, nog niet gepubliceerd'. De projecten laten geen eenduidig spoor achter: tags bestaan alleen bij de PyPI-pakketten, en veel projecten hebben geen `publish.sh`. Trigger: HP vergeet een publish in een project waar de strook 'schoon' toonde.
- De git-stand bijwerken op het moment dat er iets verandert in plaats van elke vijf seconden. Trigger: de vertraging van vijf seconden stoort, of `git status` duurt in een project langer dan een seconde.
- De samenvatting van een running project vanzelf bijwerken. Trigger: HP drukt in lopende projecten geregeld op de ververs-knop.
- Een snelle voorcontrole op wijzigingstijd en grootte van het gespreksbestand vóór het lezen. Trigger: de ronde bij de start duurt zonder één aanroep van `claude` langer dan vijf seconden; de ronde schrijft zijn duur in de log.
