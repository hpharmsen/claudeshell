# Doel: Mac terminal app om makkelijk met Claude projecten te werken

## Opzet
De basis-eenheid in de applicatie is het project. Een project heeft een folder, een kleur en een status. De projecten staan op alfabetische volgorde in de balk. Status kan zijn: running, active of inactive. 

## Interface
De applicatie besstaat uit 1 window, resizable. Standaard is deze gecentreerd en neemt 3/4 van de hoogte en 3/4 van de breedte van het scherm in.
De bovenste balk is 2 em hoog en heeft tiles voor de verschillende projecten. Deze staan altijd in beeld. Een tile is het icoon van het project met de naam klein eronder. De applicatie zoekt het icoon zelf, in de folder van het project of als favicon van zijn website. Een project zonder icoon toont zijn initialen op de kleur van het project; alleen daar is de kleur nog te zien. De meest rechter tile is een + om een nieuw project toe te voegen. Als de tiles niet meer passen, worden ze smaller.
De rest van het window bestaat uit 2 delen. De linker 1/3 is een zsh terminal opgestart in de folder van het gekozen project. De rechter 2/3 draait claude --dangerously-skip-permissions in diezelfde folder.
De lijn tussen die twee moet vershuifbaar zijn zodat links of rechts groter gemaakt kan worden.

## Projectstatus
Running - Dit project is nu bezig. De claude sessie en .zsh zijn actief.
Active - Dit is een actief onderhouden project maar op dit moment doen we er niks mee. Er draait ook geen claude. Klikken op de tab van een actief project zet hem op running (start zsh en claude). 
Inactive - Dit project wordt niet meer actief onderhouden. Het staat niet in de tiles bar maar kan wel weer aan de tiles bar toegevoegd worden via een dropdown met alle inactieve projecten.
In de tiles bar moet duidelijk zijn of een project actief of inactief is. 
Ook moet er een optie zijn om een project van running naar active te zetten en van active naar inactive.

## Needs attention
Als eeen project een nieuw bericht van claude code heeft, dan moet dit duidelijk worden in de tiles bar.

## De terminal
Liefs zo veel mogelijk als mijn huidige setup via Oh My Zshell. Dus inclusief de prompt. Liefst leest het uit mijn oh my zshell settings.

## De claude sessie
URL's moeten klikbaar zijn zodat de browser hiermee opstart.
