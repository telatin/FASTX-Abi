#!/usr/bin/env perl
use 5.012;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use FASTX::Abi;
use File::Basename;

say "Usage: ", basename($0), " FILE1.ab1 FILE2.ab1 .. > reads.fq" unless defined $ARGV[0];
foreach my $file (@ARGV) {
	if (! -e "$file") {
		say STDERR " * Skipping '$file': not found";
		next;
	}
	my $trace = FASTX::Abi->new({ filename => $file });
	say $trace->get_fastq("a b", 92);
}