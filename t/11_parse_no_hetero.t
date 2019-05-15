use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;

use_ok 'FASTX::Abi';
my $chromatogram = "$Bin/../data/mt.ab1";

if (-e "$chromatogram") {
    my $data = FASTX::Abi->new({ filename => "$chromatogram" });
    ok(length($data->{raw_sequence}) == length($data->{raw_quality}), "raw quality and rawr sequence length matches" );

    ok(length($data->{sequence}) == length($data->{quality}), "quality and sequence length matches" );


    ok(length($data->{raw_sequence}) >= length($data->{seq1}), "Raw sequence length >= filtered sequence length" );
  }




done_testing();
