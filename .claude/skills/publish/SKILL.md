---
name: publish
description: Commit alles, push naar GitHub, bouw de app, installeer hem in /Applications en controleer de nieuwe binary.
disable-model-invocation: true
---

# /publish

Brengt de stand van `main` naar GitHub en naar `/Applications/Claudeshell.app`.
Draai elke stap pas als de vorige gelukt is. Mislukt er iets, stop dan en meld de
werkelijke uitvoer. Probeer niets te forceren.

Deze skill is de enige plek waar gepusht wordt. HP roept hem zelf aan, en dat is de
toestemming om te pushen.

## 1. Voorwaarden

- `git branch --show-current` moet `main` geven. Anders: stop en vraag HP wat hij wil.
- Noteer het begintijdstip met `date +%s`; stap 5 heeft het nodig.

## 2. Tests

`swift test 2>&1 | tail -5`. Faalt er een test, stop dan vóór de commit.

## 3. Committen

Alleen als `git status --short` iets toont.

- Lees `git diff` en de nieuwe bestanden door. De repo is openbaar: stop bij een `.env`,
  een sleutel, een wachtwoord of een echte klantnaam en vraag HP wat ermee moet.
- `git add -A`, en commit met een bericht in de stijl van `git log --oneline -10`
  (`fix:`, `feat:`, `docs:`, Engels, gericht op wat het oplevert).
- Hoort de wijziging duidelijk uit elkaar in losse onderwerpen, maak dan per onderwerp
  een commit.

## 4. Pushen

`git push origin main`. Wordt de push geweigerd omdat de remote verder is, stop dan en
meld dat. Nooit `--force`. Controleer daarna dat `git rev-parse HEAD` gelijk is aan
`git rev-parse origin/main`.

## 5. Bouwen, installeren en controleren

`scripts/install-app.sh`. Controleer daarna alle vier:

| Check | Commando |
|---|---|
| Geïnstalleerd is gelijk aan de build | `cmp build/Claudeshell.app/Contents/MacOS/Claudeshell /Applications/Claudeshell.app/Contents/MacOS/Claudeshell` |
| De binary is van deze run | `stat -f %m /Applications/Claudeshell.app/Contents/MacOS/Claudeshell` is minstens het begintijdstip |
| De handtekening klopt | `codesign --verify /Applications/Claudeshell.app` |
| Geen ongecommitte wijzigingen bij het bouwen | `git status --short` is leeg |

## 6. Melden

Kort: de commits (hash en onderwerp), dat `origin/main` op dezelfde commit staat, en
de tijd van de nieuwe binary. Herstart Claudeshell niet zelf: deze sessie draait er
misschien in. Zeg dat HP de app moet herstarten, en dat macOS daarna opnieuw om toegang
tot mappen vraagt.
