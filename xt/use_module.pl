#!/usr/bin/env perl

use 5.018;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use FASTX::Abi;
use Data::Dumper;
use Term::ANSIColor;
my $test_het = "$Bin/../data/hetero.ab1";
my $test_omo = "$Bin/../data/mt.ab1";

#$test = $ARGV[0] if (defined $ARGV[0] and -e "$ARGV[0]");



my $fastq_h = FASTX::Abi->new({
  filename  => "$test_het",
  trim_ends => 1,
});

my $fastq_o = FASTX::Abi->new({
  filename  => "$test_omo",
  trim_ends => 1,
});

for my $o ($fastq_h, $fastq_o) {
  say color('bold'), "Name   :\t",   $o->{filename}, color('reset');
  say "Iso_seq:\t",$o->{iso_seq};
  say "Diffs  :\t",  $o->{diff};
  my $info = $o->get_trace_info();
  print color('blue'), Dumper $info;
  say color('yellow'),substr($o->get_fastq(), 0, 44), color('reset'),'...';
}

say color('bold'),  "NOW TESTING ERROR", color('reset');
my $test_abi;
my $eval = eval {
 $test_abi = FASTX::Abi->new({   filename  => "$test_het",   asdbad_attribute => 1});
 1;
};
if (defined $eval) {
  die "Error: passing wrong attribute should confess\n";
} else {
  say color('green'), 'ok: ', color('reset'), "Failed loading bad attribute";
}
