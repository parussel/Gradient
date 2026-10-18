# 70_Gradient.pm
# Version 1.0.0.6 (2026-10-16)
#
# Independent FHEM community module initiated by Frank Parussel.
# Contributions and possible future adoption by the FHEM community are welcome.
# This is currently not an official FHEM module.
#
# Copyright (C) 2026 Frank Parussel.
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Project information: https://153er-netz.de/seiten/entwicklung.html

=for comment
####################################################################################################
#
#       70_Gradient.pm
#       The Gradient device is a trend monitor, used to detect dynamic changes 
#       (e.g. temperature drops or humidity rises) using linear regression.
#
#       The module was developed for practical use in FHEM by Frank Parussel.
#
#       This file is part of fhem.
#
#       Fhem is free software: you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation, either version 2 of the License, or
#       (at your option) any later version.
#
#       Fhem is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with fhem. If not, see <http://www.gnu.org/licenses/>.
#
####################################################################################################
#
# V 1.0.0.1
#  10.05.2026 - Initial version: Linear regression and basic gradient detection.
# V 1.0.0.2
#  10.05.2026 - Feature: added NOTIFYDEV and notifyRegexpChanged for better FHEM integration.
# V 1.0.0.3
#  10.05.2026 - Feature: added gradientHysteresis to prevent toggling of state.
# V 1.0.0.4
#  10.05.2026 - Feature: added gradientMaxDelta as plausibility filter for sensor errors.
# V 1.0.0.5
#  10.05.2026 - Feature: automatic attribute initialization on define.
# V 1.0.0.6
#  16.10.2026 - Fix: reading names are matched literally, including dots.
#               Project attribution, version internal, bilingual documentation
#               and project link reviewed.
#
####################################################################################################
=cut

package main;

use strict;
use warnings;
use POSIX;

my $Gradient_Version = "1.0.0.6";

sub Gradient_Initialize {
    my ($hash) = @_;
    $hash->{DefFn}    = "Gradient_Define";
    $hash->{NotifyFn} = "Gradient_Notify";
    $hash->{AttrList} = "gradientMode:rise,fall,both " .
                        "gradientThreshold " . 
                        "gradientHysteresis " . 
                        "gradientTime " .      
                        "gradientResetTime " . 
                        "gradientMinPoints " .
                        "gradientMaxDelta " . 
                        $readingFnAttributes;
}

sub Gradient_Reset {
    my ($hash) = @_;
    readingsSingleUpdate($hash, "state", "off", 1);
}

sub Gradient_Calculate {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $hist_ref = $hash->{HISTORY};
    
    my $minPoints = AttrVal($name, "gradientMinPoints", 4);
    return if (!$hist_ref || scalar(@{$hist_ref}) < $minPoints);

    my @hist = @{$hist_ref};
    my $n = scalar(@hist);
    my $span = $hist[-1]->{t} - $hist[0]->{t};
    return if ($span < 45); 

    my ($sum_t, $sum_v, $sum_tv, $sum_t2) = (0, 0, 0, 0);
    my $t0 = $hist[0]->{t}; 
    
    foreach my $p (@hist) {
        my $t_rel = $p->{t} - $t0; 
        $sum_t  += $t_rel;
        $sum_v  += $p->{v};
        $sum_tv += ($t_rel * $p->{v});
        $sum_t2 += ($t_rel**2);
    }

    my $denom = ($n * $sum_t2 - $sum_t**2);
    return if ($denom == 0);

    my $slope_per_sec = ($n * $sum_tv - $sum_t * $sum_v) / $denom;
    my $total_time = AttrVal($name, "gradientTime", 300);
    my $total_gradient = $slope_per_sec * $total_time;
    
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "currentGradient", sprintf("%.3f", $total_gradient));
    
    my $threshold  = AttrVal($name, "gradientThreshold", 1.0);
    my $hysteresis = AttrVal($name, "gradientHysteresis", 0.1);
    my $mode       = AttrVal($name, "gradientMode", "rise");
    
    my $is_on    = (ReadingsVal($name, "state", "off") eq "on");
    my $detected = 0;
    my $keep_on  = 0;

    if ($mode eq "rise" || $mode eq "both") {
        $detected = 1 if ($total_gradient >= $threshold);
        $keep_on  = 1 if ($is_on && $total_gradient >= ($threshold - $hysteresis));
    }
    if ($mode eq "fall" || $mode eq "both") {
        $detected = 1 if ($total_gradient <= -$threshold);
        $keep_on  = 1 if ($is_on && $total_gradient <= -($threshold - $hysteresis));
    }

    if ($detected || $keep_on) {
        readingsBulkUpdate($hash, "state", "on") if (!$is_on);
        RemoveInternalTimer($hash);
        my $reset = AttrVal($name, "gradientResetTime", 300);
        InternalTimer(time() + $reset, "Gradient_Reset", $hash);
    }
    
    readingsEndUpdate($hash, 1);
}

sub Gradient_Define {
    my ($hash, $def) = @_;
    my @a = split("[ \t]+", $def);
    return "Usage: define <name> Gradient <sourceDev> <reading>" if (@a != 4);
    
    my $name = $a[0];
    $hash->{NAME} = $name; 
    $hash->{VERSION} = $Gradient_Version;
    $hash->{SOURCE} = $a[2]; 
    $hash->{READING} = $a[3];
    $hash->{HISTORY} = []; 
    $hash->{NOTIFYDEV} = $a[2];
    
    if ($init_done) { 
        $attr{$name}{gradientMode}       = "rise"  if (!defined($attr{$name}{gradientMode}));
        $attr{$name}{gradientThreshold}  = "1.0"   if (!defined($attr{$name}{gradientThreshold}));
        $attr{$name}{gradientHysteresis} = "0.1"   if (!defined($attr{$name}{gradientHysteresis}));
        $attr{$name}{gradientTime}       = "300"   if (!defined($attr{$name}{gradientTime}));
        $attr{$name}{gradientResetTime}  = "300"   if (!defined($attr{$name}{gradientResetTime}));
        $attr{$name}{gradientMinPoints}  = "4"     if (!defined($attr{$name}{gradientMinPoints}));
        $attr{$name}{gradientMaxDelta}   = "0"     if (!defined($attr{$name}{gradientMaxDelta}));
        $attr{$name}{devStateIcon}       = "on:10px-kreis-rot off:lamp_on\@green" if (!defined($attr{$name}{devStateIcon}));
    }

    notifyRegexpChanged($hash, $a[2]);
    readingsSingleUpdate($hash, "state", "off", 1);
    return undef;
}

sub Gradient_Notify {
    my ($hash, $source) = @_;
    return if ($source->{NAME} ne $hash->{SOURCE});
    my $reading = $hash->{READING};
    my $events = deviceEvents($source, 1);
    return if (!$events);
    my $val = undef;
    foreach my $e (@{$events}) {
        if ($e =~ /^\Q$reading\E:\s*([-+]?[\d\.]+)/) { $val = $1; last; }
    }
    $val = ReadingsVal($source->{NAME}, $reading, undef) if (!defined($val));
    return if (!defined($val));

    my $now = time();
    my $maxDelta = AttrVal($hash->{NAME}, "gradientMaxDelta", 0);
    if ($maxDelta > 0 && scalar(@{$hash->{HISTORY}}) > 0) {
        my $lastVal = $hash->{HISTORY}->[-1]->{v};
        if (abs($val - $lastVal) > $maxDelta) {
            Log3 $hash->{NAME}, 3, "Gradient $hash->{NAME}: Ignored outlier $val (last: $lastVal)";
            return undef;
        }
    }
    my $max_age = AttrVal($hash->{NAME}, "gradientTime", 300);
    push(@{$hash->{HISTORY}}, { t => $now, v => $val });
    @{$hash->{HISTORY}} = grep { $_->{t} > ($now - $max_age) } @{$hash->{HISTORY}};
    $hash->{HELPER}{history_list} = join(" | ", map { $_->{v} } @{$hash->{HISTORY}});
    Gradient_Calculate($hash);
    return undef;
}

1;

=pod
=item helper
=item summary    detects dynamic changes (gradients) using linear regression
=item summary_DE erkennt dynamische Änderungen (Gradienten) mittels linearer Regression
=begin html

<a id="Gradient"></a>
<h3>Gradient</h3>
<ul>
    <a id="Gradient-define"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; Gradient &lt;sourceDevice&gt; &lt;reading&gt;</code>
        <br><br>
        Example: <code>define TempCheck Gradient Thermometer temperature</code>
    </ul>
    <br>

    <a id="Gradient-usecases"></a>
    <b>Use Cases / Examples</b>
    <ul>
        <li><b>Bath Fan:</b> Detects humidity rise while showering (Threshold: ~5.0).</li>
        <li><b>Window Check:</b> Detects rapid temperature drop (Mode: fall, Threshold: ~0.8).</li>
        <li><b>Circulation Pump:</b> Detects hot water usage at return pipe.</li>
        <li><b>Heating Control:</b> Checks if radiator gets warm after opening valve.</li>
    </ul>
    <br>
    <b>Project information</b>
    <ul>
        <a href="https://153er-netz.de/seiten/entwicklung.html">153er-netz.de / Development</a><br>
        Independent community module; currently not an official FHEM module.
    </ul>
    <br>

    <a id="Gradient-attr"></a>
    <b>Attributes</b>
    <ul>
        <li><b>gradientMode</b><br>
            rise: reacts to rising values.<br>
            fall: reacts to falling values.<br>
            both: reacts to both directions.<br>
            Default: rise</li><br>
        <li><b>gradientThreshold</b><br>
            Threshold to be reached within the defined time period.<br>
            Default: 1.0</li><br>
        <li><b>gradientHysteresis</b><br>
            Difference to threshold before state returns to 'off'. Prevents toggling. <br>
            Example: Threshold 0.25, Hysteresis 0.1 -> stays 'on' until gradient drops below 0.15.</li><br>
        <li><b>gradientTime</b><br>
            Time period in seconds for trend calculation.<br>
            Default: 300</li><br>
        <li><b>gradientResetTime</b><br>
            Seconds after which the state returns to 'off' if trend is lost. <br>
            Default: 300</li><br>
        <li><b>gradientMinPoints</b><br>
            Minimum data points required before switching.<br>
            Default: 4</li><br>
        <li><b>gradientMaxDelta</b><br>
            Plausibility filter to ignore outliers (Sensor errors). 0 = disabled.</li>
    </ul>
</ul>
=end html

=begin html_DE

<a id="Gradient"></a>
<h3>Gradient</h3>
<ul>
    <a id="Gradient-define"></a>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; Gradient &lt;sourceDevice&gt; &lt;reading&gt;</code>
        <br><br>
        Beispiel: <code>define TempCheck Gradient Thermometer temperature</code>
    </ul>
    <br>

    <a id="Gradient-usecases-de"></a>
    <b>Anwendungsbeispiele</b>
    <ul>
        <li><b>Bad-Lüfter:</b> Erkennt Feuchteanstieg beim Duschen (Threshold: ~5.0).</li>
        <li><b>Fenster-Check:</b> Erkennt schnellen Temperatursturz (Mode: fall, Threshold: ~0.8).</li>
        <li><b>Zirkulationspumpe:</b> Erkennt Zapfvorgang am Rücklauf.</li>
        <li><b>Heizungskontrolle:</b> Prüft ob Heizkörper nach Ventilöffnung warm wird.</li>
    </ul>
    <br>
    <b>Projektinformationen</b>
    <ul>
        <a href="https://153er-netz.de/seiten/entwicklung.html">153er-netz.de / Entwicklung</a><br>
        Unabhängiges Community-Modul; derzeit kein offizielles FHEM-Modul.
    </ul>
    <br>

    <a id="Gradient-attr-de"></a>
    <b>Attribute</b>
    <ul>
        <li><b>gradientMode</b><br>
            rise: Reagiert auf Anstieg.<br>
            fall: Reagiert auf Abfall.<br>
            both: Reagiert auf beides.<br>
            Default: rise</li><br>
        <li><b>gradientThreshold</b><br>
            Schwellenwert, der innerhalb des Zeitraums erreicht werden muss.<br>
            Default: 1.0</li><br>
        <li><b>gradientHysteresis</b><br>
            Differenz zum Schwellenwert, bevor der Status auf 'off' geht. Verhindert schnelles Hin- und Herschalten.<br>
            Beispiel: Threshold 0.25, Hysteresis 0.1 -> bleibt 'on' bis Gradient unter 0.15 sinkt.</li><br>
        <li><b>gradientTime</b><br>
            Zeitraum in Sekunden, über den der Trend berechnet wird.<br>
            Default: 300</li><br>
        <li><b>gradientResetTime</b><br>
            Zeit in Sekunden, nach der der Status wieder auf 'off' geht.<br>
            Default: 300</li><br>
        <li><b>gradientMinPoints</b><br>
            Mindestanzahl an Messwerten, bevor geschaltet wird.<br>
            Default: 4</li><br>
        <li><b>gradientMaxDelta</b><br>
            Plausibilitätsfilter zum Ignorieren von Ausreißern (Sensorfehler). 0 = deaktiviert.</li>
    </ul>
</ul>
=end html_DE
=cut
