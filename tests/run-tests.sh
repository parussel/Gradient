#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
perl tests/test-gradient.pl ./FHEM/70_Gradient.pm
perl -e '
  open my $fh, "<", "controls_gradient.txt" or die $!;
  my @lines = grep { /\S/ } <$fh>;
  close $fh;
  die "controls file must contain exactly one module entry\n" unless @lines == 1;
  my @f = split /\s+/, $lines[0];
  my $size = -s "FHEM/70_Gradient.pm";
  die "wrong controls entry\n" unless $f[0] eq "UPD" && $f[2] == $size && $f[3] eq "FHEM/70_Gradient.pm";
  print "GRADIENT_CONTROLS_OK: size $size bytes\n";
'
