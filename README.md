# Gradient für FHEM

`Gradient` erkennt dynamische Änderungen von Messwerten mithilfe linearer
Regression. Damit lassen sich beispielsweise ein schneller Temperaturabfall,
ein Feuchteanstieg oder die Erwärmung eines Zirkulationsrücklaufs erkennen.

> **Status und Hinweis:** Eigenständiges Community-Modul, kein offizieller
> Bestandteil von FHEM. Das Modul wurde automatisiert und im praktischen
> FHEM-Betrieb geprüft. Vor der Installation eine Sicherung erstellen und die
> Schwellwerte an die eigene Anlage anpassen. Nutzung in eigener Verantwortung.

Projektinformationen: [153er-netz.de – Entwicklung](https://153er-netz.de/seiten/entwicklung.html)

## Typische Anwendungen

- Zirkulationspumpe nach erkanntem Temperaturanstieg abschalten;
- schnellen Abfall der Außentemperatur erkennen;
- Feuchteanstieg beim Duschen feststellen;
- Erwärmung eines Heizkreises nach Ventilöffnung überwachen.

Grunddefinition:

```text
define <Name> Gradient <Quellgerät> <Reading>
```

Beispiel:

```text
define TempCheck Gradient Thermometer temperature
```

Die vollständige deutsche und englische Hilfe ist im Modul enthalten und in
FHEM mit `help Gradient` erreichbar.

## Installation und Updates

Vorher eine aktuelle FHEM-Sicherung anlegen. Die folgenden Befehle einzeln im
FHEM-Kommandoeingabefeld ausführen und jeweils die Rückmeldung abwarten.

```text
update add https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

Vorschau prüfen:

```text
update check https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

Nur wenn die Vorschau ausschließlich `FHEM/70_Gradient.pm` aufführt, das Update
ausführen:

```text
update all https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

Danach das Modul neu laden:

```text
reload 70_Gradient
```

Die Steuerdatei enthält nur die Moduldatei. Definitionen, Attribute,
`fhem.cfg`, `fhem.save` und andere Nutzerdaten sind nicht Teil des Updates.
Nach `update add` wird diese Quelle auch bei einem normalen FHEM-Update
berücksichtigt. Mit `update list` lassen sich eingetragene Quellen anzeigen.

Quelle abmelden, ohne die installierte Moduldatei zu löschen:

```text
update delete https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

## Lizenz

GNU General Public License, Version 2 oder – nach eigener Wahl – eine spätere
Version (`GPL-2.0-or-later`). Siehe [LICENSE](LICENSE).
