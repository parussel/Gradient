# Gradient für FHEM

`Gradient` erkennt dynamische Änderungen in Messwerten mit linearer Regression. Damit lassen sich beispielsweise ein schneller Temperaturabfall, ein Feuchteanstieg oder die Erwärmung eines Zirkulationsrücklaufs erkennen.

> **Status und Risiko:** Unabhängiges Community-Modul, derzeit kein offizieller Bestandteil von FHEM. Automatisierte Tests und ein praktischer Betrieb mit mehreren Definitionen wurden geprüft; eine breite Erprobung in unterschiedlichen Anlagen steht noch aus. Nutzung in eigener Verantwortung.

Projektinformationen: [153er-netz.de – Entwicklung](https://153er-netz.de/seiten/entwicklung.html)

## Beispiele

- Zirkulationspumpe nach erkanntem Temperaturanstieg abschalten;
- schnellen Außentemperaturabfall erkennen;
- Feuchteanstieg beim Duschen feststellen;
- Erwärmung eines Heizkreises nach Ventilöffnung überwachen.

```text
define <Name> Gradient <Quellgerät> <Reading>
```

Beispiel:

```text
define TempCheck Gradient Thermometer temperature
```

Die vollständige deutsch- und englischsprachige Hilfe ist im Modul enthalten und in FHEM mit `help Gradient` erreichbar.

## Installation und Updates

Vor der Installation eine FHEM-Sicherung anlegen. Anschließend im FHEM-Kommandoeingabefeld:

```text
update add https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

Die Rückmeldung abwarten. Danach zunächst nur prüfen, welche Datei geändert würde:

```text
update check gradient
```

Erst wenn die Vorschau ausschließlich `FHEM/70_Gradient.pm` nennt, die Installation ausführen:

```text
update all gradient
```

Nach erfolgreichem Download das Modul neu laden:

```text
reload 70_Gradient
```

Nach `update add` wird diese Quelle bei einem normalen `update` berücksichtigt. `update list` zeigt die registrierten Quellen.

Die Steuerdatei enthält ausschließlich `FHEM/70_Gradient.pm`. Vorhandene Definitionen, Attribute, `fhem.cfg`, `fhem.save` und Nutzerdaten werden nicht überschrieben.

Automatische Updates lassen sich wieder abmelden mit:

```text
update delete https://raw.githubusercontent.com/parussel/Gradient/main/controls_gradient.txt
```

## Tests

Der Regressionstest prüft Definition, Versionskennung, lineare Regression, Schwellwert, Timer, Ausreißerfilter und Readingnamen mit Sonderzeichen wie einem Punkt.

```sh
sh tests/run-tests.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File tests/test-update-package.ps1
```

## Entwicklung und Lizenz

Initiator: Frank Parussel. Implementierung, Tests und Dokumentation entstanden mit KI-Unterstützung. Beiträge und eine mögliche spätere Übernahme durch die FHEM-Community sind willkommen.

Lizenz: GNU GPL Version 2 oder später (`GPL-2.0-or-later`). Siehe [LICENSE](LICENSE).

---

**English summary:** Independent FHEM community module for detecting trends in sensor readings by linear regression. Bilingual in-module help is included.
