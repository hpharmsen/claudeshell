---
title: Tiles met iconen - Requirements
type: feat
date: 2026-11-23
topic: tile-iconen
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-brainstorm
execution: code
input_source: prompt
input_text: |
  Ik zit erover te denken om de projectnamen in de tabs bovenin te vervangen door icons. Veel projecten hebben al een icon, websites hebben een favicon, en iets als Keep heeft een eigen icon voor het programma. En klanten hebben natuurlijk sowieso wel een favicon via hun website, bijvoorbeeld.

  Hoe zou dit werken? Is het mogelijk om zoveel mogelijk iconen alvast op te halen, automatisch? En wat met projecten die geen iconen hebben? Hoe tonen we dat dan? De kleurtjes zijn dan waarschijnlijk ook niet meer nodig. maar de indicator dat een tap bezig is, wel, en de indicator dat een tap aandacht nodig heeft, ook.
---

# Tiles met iconen - Requirements

## Goal Capsule

**Doel:** HP herkent een project in de balk aan zijn icoon in plaats van aan een gekleurd vlak met tekst, en de balk oogt rustiger.

**Middel:** elke tile toont een icoon met de projectnaam klein eronder. De app zoekt de iconen zelf, in de projectfolder en via de website van het project. De projectkleur blijft alleen over als achtergrond van de initialen bij een project zonder icoon.

**Product-autoriteit:** HP, enige gebruiker.

**Open blockers:** geen.

## Product Contract

### Summary

Een tile wordt een icoon met de naam eronder, zoals in het Dock met labels. De app zoekt voor elk project zelf een icoon: eerst in de projectfolder, daarna als favicon van een website die HP invult of die de app raadt. Een gevonden icoon staat direct op de tile en is via rechtsklik te corrigeren. Een project zonder icoon toont zijn initialen op de pastelkleur van het project. Draaiende projecten staan in kleur, gestopte in grijstinten en vervaagd. De indicatoren voor bezig en 'wacht op HP' blijven, als badge op het icoon.

### Problem Frame

De tiles zijn nu gekleurde vlakken met een naam. Het palet heeft 16 pasteltinten, dus kleuren komen dubbel voor en zeggen weinig over het project. Herkennen gaat via lezen. Ruimte is niet het probleem: de balk past. HP wil sneller zien welke tile welk project is, en een balk die er beter uitziet.

### Key Decisions

- **Icoon met de naam eronder.** (session-settled: user-directed, gekozen na een schets met drie varianten, boven 'alleen icoon' en 'icoon naast de naam'.) Governs R31, R32.
- **De balk wordt 20% hoger.** Iconen en indicatoren kunnen daardoor iets groter. (session-settled: user-directed.) Governs R33.
- **De pastelkleuren blijven, alleen voor initialen.** Zonder icoon toont de tile initialen op de projectkleur. (session-settled: user-directed, gekozen na een schets, boven 'initialen op neutraal grijs' en 'wit op donker voor draaiende projecten': op grijs leek een draaiend project zonder icoon gestopt.) Governs R34, R35.
- **De geselecteerde tile heeft een wit vlak met een donkere streep eronder.** (session-settled: user-approved, na een schets.) Governs R37.
- **Gestopt is grijstinten plus vervaagd, draaiend is volle kleur.** (session-settled: user-directed, gekozen boven 'alleen vervaagd' en 'volledig grijs zonder vervagen': een icoon dat zelf grijs is blijft zo ook te onderscheiden.) Governs R36.
- **Het sneltoetscijfer is alleen zichtbaar met Cmd ingedrukt.** (session-settled: user-directed, gekozen boven 'klein in een hoek' en 'niet tonen'.) Governs R38.
- **De app zoekt in de folder en raadt ook de website.** (session-settled: user-directed, gekozen boven 'niets raden' en 'geen netwerk': meer iconen zonder werk, met de kans op een verkeerd icoon.) Governs R39 tot en met R42.
- **Een gevonden icoon wordt direct toegepast.** Corrigeren gaat via rechtsklik. (session-settled: user-directed, gekozen boven een controlevenster vooraf en een markering op geraden iconen.) Governs R43, R44.

### Requirements

De nummering loopt door op `docs/brainstorms/2026-11-22-maestro-requirements.md`.

**De tile**

- R31. Een tile toont het icoon van het project met de projectnaam klein eronder, op één regel. Past de naam niet, dan wordt hij afgekapt. De volledige naam staat in de tooltip.
- R32. Alle tiles zijn even breed. Passen ze niet meer in de balk, dan worden ze smaller; het icoon blijft even groot en de naam wordt verder afgekapt.
- R33. De balk is 20% hoger dan nu. Icoon, bezig-indicator en wacht-indicator zijn groter dan in de huidige tile.
- R34. Een project zonder icoon toont zijn initialen op een vlak in de projectkleur, met dezelfde vorm en maat als een icoon. Twee woorden in de naam geven de eerste letter van elk woord, één woord geeft de eerste twee letters.
- R35. Een project houdt zijn kleur uit het bestaande pastelpalet, en die is via rechtsklik te wijzigen zolang het project geen icoon heeft; bij een project met een icoon staat het menu 'Kleur' er niet. De kleur is alleen zichtbaar achter de initialen; de tile zelf heeft geen gekleurde achtergrond meer en een project met een icoon toont zijn kleur nergens.
- R36. Het icoon of de initialen van een draaiend project staan in volle kleur en op volle sterkte. Die van een gestopt project staan in grijstinten en vervaagd, net als de naam eronder.
- R37. De bezig-indicator en de wacht-indicator staan als badge rechtsboven op het icoon. De geselecteerde tile heeft een wit vlak met een donkere streep eronder, en zijn naam staat vet.
- R38. Het sneltoetscijfer van een tile is normaal niet zichtbaar. Zolang HP Cmd ingedrukt houdt, staan de cijfers over de iconen. De sneltoetsen zelf veranderen niet.

**Iconen vinden**

- R39. De app zoekt voor een project eerst een icoon in de projectfolder: een favicon, een app-icoon of een logo.
- R40. Een project kan een website hebben. Is die ingevuld, dan gebruikt de app het favicon van die website.
- R41. Is er geen website ingevuld en levert de folder niets op, dan probeert de app zelf een website te vinden, bijvoorbeeld uit een foldernaam die een domein is of uit een domein in de projectconfiguratie, en gebruikt het favicon daarvan.
- R42. Een afbeelding die veel breder is dan hoog, zoals een woordmerk, telt bij het automatisch zoeken niet als icoon. Een favicon van de website gaat dan voor.
- R43. Het zoeken gebeurt bij het toevoegen van een project en één keer voor alle bestaande projecten bij de eerste start met deze versie. Wat gevonden is staat direct op de tile, zonder bevestiging. Het zoeken houdt de app niet op: een tile toont initialen tot zijn icoon er is.
- R44. Via rechtsklik op een tile kan HP: een eigen afbeelding kiezen, een website invullen of wijzigen, het icoon opnieuw laten zoeken, en het icoon weghalen. Na weghalen toont de tile initialen en zoekt de app niet opnieuw uit zichzelf.
- R45. Een door HP gekozen afbeelding of ingevulde website wint altijd van wat de app zelf vindt, ook na opnieuw zoeken.
- R46. Het icoon van een project blijft bewaard tussen sessies van de app en werkt zonder netwerk. Verdwijnt het bronbestand of is de website onbereikbaar, dan blijft het laatst gevonden icoon staan.

**Wat hiermee vervalt uit de eerste requirements**

- R2: de balk van 2 em hoog. R33 geldt.
- R5: herkenbaar aan de projectnaam. R31 en R32 gelden.
- 'Aan zijn kleur te onderscheiden' in AE8: een tile met een icoon toont geen kleur. De kleur in R6, R19, R20 en R23 blijft bestaan, met de beperking uit R35.

### Key Flows

- F4. Een project toevoegen
  - **Trigger:** HP voegt via + een folder toe.
  - **Stappen:** de tile verschijnt achteraan met initialen. De app zoekt in de folder en zo nodig via een geraden website. Is er een icoon, dan vervangt het de initialen. Vindt de app niets, dan blijven de initialen staan.
  - **Covers R34, R39, R41, R43.**
- F5. Een verkeerd of ontbrekend icoon herstellen
  - **Trigger:** een tile toont initialen of een icoon dat niet bij het project hoort.
  - **Stappen:** HP rechtsklikt op de tile en vult de website van het project in, of kiest een afbeelding. De tile toont het nieuwe icoon en houdt dat, ook na opnieuw zoeken.
  - **Covers R40, R44, R45.**

### Acceptance Examples

- AE9. **Covers R39, R43.** Een bestaand project met een favicon in zijn folder toont na de eerste start met deze versie dat favicon, zonder dat HP iets doet.
- AE10. **Covers R34.** De projecten 'Golf meester' en 'Research' hebben geen icoon. De tiles tonen 'GM' en 'Re', elk op de eigen projectkleur, met de naam eronder.
- AE11. **Covers R34, R31.** 'Justai' en 'Justlog' hebben geen icoon en tonen allebei 'Ju'. Ze zijn te onderscheiden aan de naam onder de initialen.
- AE12. **Covers R42.** In de folder van een klantproject staat alleen een breed woordmerk als `logo.png`. De app gebruikt dat niet. Is er een website bekend of geraden, dan toont de tile het favicon daarvan; anders initialen.
- AE13. **Covers R41, R44, R45.** De app raadt voor een project een website en toont een favicon dat niet klopt. HP vult via rechtsklik de juiste website in. De tile toont het juiste favicon, ook na 'opnieuw zoeken'.
- AE14. **Covers R44.** HP haalt het icoon van een project weg. De tile toont initialen, ook na een herstart van de app.
- AE18. **Covers R34, R36.** Een draaiend project zonder icoon toont zijn initialen op de volle pastelkleur, met de wacht-badge erop. HP stopt het project: het vlak wordt grijs en vervaagd.
- AE15. **Covers R36, R37.** Een gestopt project met een kleurig icoon staat in grijstinten en vervaagd. HP klikt erop: het icoon krijgt kleur. Claude gaat aan het werk en de bezig-badge staat rechtsboven op het icoon. Claude is klaar en de wacht-badge staat op dezelfde plek.
- AE16. **Covers R38.** HP houdt Cmd ingedrukt. Over de eerste tien iconen staan 1 tot en met 0, over de volgende tien ⌥1 tot en met ⌥0. HP laat Cmd los en de cijfers verdwijnen.
- AE17. **Covers R46.** HP start de app zonder netwerk. Alle eerder gevonden iconen staan op hun tile.

### Scope Boundaries

Uitgesteld:

- Iconen in de Cmd+P zoeker en in de dropdown met inactive projecten. Trigger: HP zoekt in een van die lijsten naar een project dat hij in de balk wel aan zijn icoon herkent.
- Iconen automatisch verversen. Trigger: een project krijgt een nieuw icoon en HP merkt dat de tile het oude blijft tonen terwijl hij 'opnieuw zoeken' te veel werk vindt.

Buiten scope:

- Een icoon tekenen of genereren voor een project dat er geen heeft. Initialen zijn de fallback.
- De projectkleur tonen bij een project dat een icoon heeft.
- Een controlevenster of markering voor geraden iconen.

### Dependencies / Assumptions

- Van de 19 projecten in de balk hebben er 8 een bruikbaar icoon of logo in hun folder (gemeten op 2026-11-23, tot vijf niveaus diep, zonder `node_modules`, `.venv` en build-folders). Bij 2 daarvan is het een breed woordmerk. De andere 11 hebben niets en zijn aangewezen op een website of initialen.
- De app weet nu van geen enkel project een website. R40 voegt dat gegeven toe.
- Een favicon ophalen bij een geraden domein vraagt alleen een openbaar bestand op; er gaat geen projectinhoud het netwerk op.
- Twee aannames, niet met HP besproken: R42 (woordmerk telt niet als icoon) en de vorm van de initialen in R34.

### Outstanding Questions

Deferred to Planning:

- Welke bestandsnamen en mappen doorzoekt R39, in welke volgorde, en hoe diep? Bij meerdere treffers: welke wint (grootste, vierkantste, dichtst bij de root)?
- Uit welke bronnen raadt R41 een domein, en wanneer is een gok betrouwbaar genoeg om te gebruiken?
- Welke favicon-variant haalt de app op (apple-touch-icon, `link rel=icon`, `/favicon.ico`) om op een Retina-scherm scherp te blijven?
- Waar bewaart de app de iconen en de website per project, en hoe onthoudt hij dat HP een icoon bewust heeft weggehaald?
- Hoe volgt de balk het indrukken en loslaten van Cmd voor R38, ook als de focus in een terminal-pane ligt?
- Hoe breed is een tile?
