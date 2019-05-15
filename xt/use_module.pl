#!/usr/bin/env perl

use 5.018;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use FASTX::Abi;
use Data::Dumper;
my $test = "$Bin/../data/hetero.ab1";

$test = $ARGV[0] if (defined $ARGV[0] and -e "$ARGV[0]");
say STDERR " - Reading: $test";

my $fastq_abi = FASTX::Abi->new({
  filename  => "$test",
  trim_ends => 1,
});



say $fastq_abi->{raw_quality};

say  $fastq_abi->{diff}, ' ambiguities at position: ', join(',', @{ $fastq_abi->{diff_array} });

say $fastq_abi->get_fastq('seqname');
