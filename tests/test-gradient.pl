use strict;
use warnings;

our $readingFnAttributes = '';
our $init_done = 1;
our %attr;
our %TEST_READINGS;
our @TEST_TIMERS;
our @TEST_FAILURES;

sub AttrVal {
    my ($name, $attribute, $default) = @_;
    return exists $attr{$name}{$attribute} ? $attr{$name}{$attribute} : $default;
}

sub ReadingsVal {
    my ($device, $reading, $default) = @_;
    return exists $TEST_READINGS{$device}{$reading}
      ? $TEST_READINGS{$device}{$reading}
      : $default;
}

sub readingsSingleUpdate {
    my ($hash, $reading, $value) = @_;
    $hash->{READINGS}{$reading}{VAL} = $value;
}

sub readingsBeginUpdate { return undef; }
sub readingsEndUpdate { return undef; }

sub readingsBulkUpdate {
    my ($hash, $reading, $value) = @_;
    $hash->{READINGS}{$reading}{VAL} = $value;
}

sub InternalTimer {
    my ($when, $function, $argument) = @_;
    push @TEST_TIMERS, { when => $when, function => $function, argument => $argument };
}

sub RemoveInternalTimer {
    my ($argument) = @_;
    @TEST_TIMERS = grep { $_->{argument} != $argument } @TEST_TIMERS;
}

sub notifyRegexpChanged { return undef; }
sub Log3 { return undef; }
sub deviceEvents { return $_[0]{CHANGED}; }

sub check {
    my ($condition, $message) = @_;
    push @TEST_FAILURES, $message unless $condition;
}

sub approx {
    my ($actual, $expected) = @_;
    return abs($actual - $expected) < 0.01;
}

my $module_path = shift @ARGV
  or die "Usage: perl test-gradient.pl /path/to/70_Gradient.pm\n";

open my $module_fh, '<', $module_path
  or die "Could not open $module_path: $!\n";
local $/;
my $module_source = <$module_fh>;
close $module_fh;
eval $module_source;
die "Could not load $module_path: $@ $!\n" if $@;

my $type = {};
Gradient_Initialize($type);
check($type->{AttrList} =~ /gradientMode:rise,fall,both/, 'mode attribute is missing');

my $defined = { READINGS => {} };
my $define_error = Gradient_Define($defined, 'gradientTest Gradient dummySensor temperature.avg');
check(!defined($define_error), 'valid definition should be accepted');
check(($defined->{VERSION} // '') eq '1.0.0.6', 'VERSION internal should identify 1.0.0.6');

# Linear regression: 10, 11 and 12 over 120 seconds means +5 over 300 seconds.
my $calc = {
    NAME => 'gradientTest',
    HISTORY => [
        { t => 1_000, v => 10 },
        { t => 1_060, v => 11 },
        { t => 1_120, v => 12 },
    ],
    READINGS => { state => { VAL => 'off' } },
};
$attr{gradientTest} = {
    gradientMinPoints => 3,
    gradientTime => 300,
    gradientThreshold => 4,
    gradientHysteresis => 1,
    gradientMode => 'rise',
    gradientResetTime => 300,
};
Gradient_Calculate($calc);
check(approx($calc->{READINGS}{currentGradient}{VAL}, 5), 'rise gradient should equal 5.000');
check($calc->{READINGS}{state}{VAL} eq 'on', 'rise above threshold should switch on');
check(@TEST_TIMERS == 1, 'detected gradient should schedule one reset');

# A configured reading name is literal. A dot must not match an arbitrary character.
my $literal = {
    NAME => 'literalTest',
    SOURCE => 'dummySensor',
    READING => 'temperature.avg',
    HISTORY => [],
    HELPER => {},
    READINGS => { state => { VAL => 'off' } },
};
$attr{literalTest} = {
    gradientMinPoints => 2,
    gradientTime => 300,
    gradientThreshold => 1,
    gradientHysteresis => 0.1,
    gradientMode => 'rise',
    gradientResetTime => 300,
    gradientMaxDelta => 0,
};
$TEST_READINGS{dummySensor}{'temperature.avg'} = 20;
my $source = { NAME => 'dummySensor', CHANGED => ['temperatureXavg: 99'] };
Gradient_Notify($literal, $source);
check(
    @{$literal->{HISTORY}} == 1 && $literal->{HISTORY}[0]{v} == 20,
    'reading names containing a dot must be matched literally'
);

# The plausibility filter must reject a jump larger than gradientMaxDelta.
$literal->{HISTORY} = [{ t => time() - 60, v => 20 }];
$attr{literalTest}{gradientMaxDelta} = 5;
$source->{CHANGED} = ['temperature.avg: 50'];
$TEST_READINGS{dummySensor}{'temperature.avg'} = 50;
Gradient_Notify($literal, $source);
check(@{$literal->{HISTORY}} == 1, 'outlier should not be added to history');

if (@TEST_FAILURES) {
    print "FAIL: $_\n" for @TEST_FAILURES;
    exit 1;
}

print "GRADIENT_TESTS_OK\n";
