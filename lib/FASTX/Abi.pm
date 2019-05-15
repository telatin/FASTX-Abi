package FASTX::Abi;
use 5.018;
use warnings;
use Carp qw(confess);
use Bio::Trace::ABIF;
use Data::Dumper;
use File::Basename;
$FASTX::Abi::VERSION = '0.02';
#ABSTRACT: Read Sanger trace file (chromatograms) in FASTQ format. For traces called with I<hetero> option, the ambiguities will be split into two sequences to allow usage from NGS tools that usually do not understand IUPAC ambiguities.

our @valid_new_attributes = ('filename', 'trim_ends', 'wnd', 'min_qual', 'bad_bases', 'keep_abi');

=pod

=encoding UTF-8

=head1 SYNOPSIS

  use FASTX::Abi;
  my $filepath = '/path/to/trace.ab1';

  my $trace_fastq = FASTX::Abi->new({ filename => "$filepath" });

  # Print chromatogram as FASTQ (will print two sequences if there are ambiguities)
  print $trace_fastq->get_fastq();

=head1 TEST

=for html <a href="https://travis-ci.org/telatin/FASTX-Abi"><img src="https://travis-ci.org/telatin/FASTX-Abi.svg?branch=master"></a>

=head1 HETERO CALLING (IUPAC AMBIGUITIES)

When sequencing with Sanger a mix of molecules (i.e. PCR product from heterozigous genome) containing a single-base polimorphisms,
B<if> the I<.ab1> file is called using the I<hetero modality> the sequence stored in the file will contain ambiguous bases (i.e. using DNA IUPAC characters).

This module is designed to produce NGS-compatible FASTQ, so when ambiguous bases are detected the two "alleles" will be split into two sequences
(of course, if more SNPs are present in the same trace, the output I<cannot> be phased).

=head1 METHODS

=cut

our %iupac = (
 'R' => 'AG',
 'Y' => 'CT',
 'M' => 'CA',
 'K' => 'TG',
 'W' => 'TA',
 'S' => 'CG'
);


=head2 new()

When creating a new object the only B<required> argument is I<filename>.

  # Trimming is based on Bio::Trace::ABIF->clear_range()
  my $trace_fastq = FASTX::Abi->new({
    filename   => "$filepath",
    min_qual   => 22,
    wnd        => 16,
    bad_bases  => 2,
    keep_abi   => 1,      # keep Bio::Trace::ABIF object in $self->{chromas} after use
  });

  # Raw sequence and quality:
  print "Raw seq/qual: ", $trace_fastq->{raw_sequence}, ", ", $trace_fastq->{raw_quality}, "\n";
  # Trimmed sequence and quality:
  print "Seq/qual: ", $trace_fastq->{sequence}, ", ", $trace_fastq->{quality}, "\n";

  # If there are ambiguities (hetero bases, IUPAC):
  if ($trace_fastq->{diff} > 0 ) {
    print "Differences: ", join(',', @{ $trace_fastq->{diffs} }), "\n";
    print "Seq 'A': ", $trace_fastq->{seq1}, "\n";
    print "Seq 'B': ", $trace_fastq->{seq2}, "\n";
  }

Input parameters:

=over 4

=item I<filename>, path

Name of the trace file (AB1 format)

=item I<trim_ends>, bool

Trim low quality ends (true by default, highly recommended)

=item I<min_qual>, int

Minimum quality value for trimming

=item I<wnd>, int

Window size for end trimming

=item I<bad_bases>, int

Maximum number of bad bases per window

=back
=cut
sub new {
    # Instantiate object
    my ($class, $args) = @_;

    my $self = {
        filename  => $args->{filename},   # Chromatogram file name
        trim_ends => $args->{trim_ends},  # Trim low quality ends (bool)
        min_qual  => $args->{min_qual},   # Minimum quality
        wnd       => $args->{wnd},        # Window for end trimming
        bad_bases => $args->{bad_bases},  # Number of low qual bases per $window_width
        keep_abi  => $args->{keep_abi},   # Do not destroy $self->{chromas} after use
    };

    #check valid inputs:
    for my $input (sort keys $args) {
      if ( ! grep( /^$input$/, @valid_new_attributes ) ) {
        confess("Method new() does not accept \"$input\" attribute. Valid attributes are:\n", join(', ', @valid_new_attributes));
      }
    }



    # CHECK INPUT FILE
    # -----------------------------------
    if (not defined $self->{filename}) {
      confess("ABI file must be provided when creating new object");
    }

    if (not -e $self->{filename}) {
      confess("ABI file not found: ", $self->{filename});
    }
    my $abif;
    my $try = eval
    {
      $abif = Bio::Trace::ABIF->new();
      $abif->open_abif($self->{filename}) or confess "Error in file: ", $self->{filename};
      1;
    };

    if (not $try) {
      confess("Bio::Trace::ABIF was unable to read: ", $self->{filename});
    }
    my $object = bless $self, $class;
    $object->{chromas} = $abif;

    my @ext = ('.abi','.ab1','.ABI','.abI','.AB1','.ab');
    my ($seqname) = basename($self->{filename}, @ext);
    $object->{sequence_name} = $seqname;

    # DEFAULTS
    # -----------------------------------
    $object->{trim_ends} = 1  unless defined $object->{trim_ends};
    $object->{wnd}       = 10 unless defined $object->{wnd};
    $object->{min_qual}  = 20 unless defined $object->{min_qual};
    $object->{bad_bases} = 4  unless defined $object->{bad_bases};
    # GET SEQUENCE FROM AB1 FILE
    # -----------------------------------
    my $seq = _get_sequence($self);
    if (! $self->{keep_abi}) {
      $self->{chromas} = undef;
    }
    return $object;
}

=head2 B<get_fastq($sequence_name)>

Return a string with the FASTQ formatted sequence (if no ambiguities) or two
sequences (if at least one ambiguity is found).
If no I<$sequence_name> is provided, the header will be made from the AB1 filename.

=cut

sub get_fastq {
  my ($self, $name) = @_;

  if (not defined $name) {
    $name = $self->{sequence_name};
  }

  my $output = '';
  if ( $self->{iso_seq} ) {
    $output .= '@' . $name . "\n" .
                $self->{seq1} . "\n+\n" .
                $self->{quality} . "\n";
  } else {
    $output .= '@' . $name . "_1\n" .
                $self->{seq1} . "\n+\n" .
                $self->{quality} . "\n";
    $output .= '@' . $name . "_2\n" .
                $self->{seq2} . "\n+\n" .
                $self->{quality} . "\n";
  }
  return $output;
}

=head2 get_trace_info()

Returns an object with trace information:

  my $info = FASTX::Abi->get_trace_info();

  print "Instrument:            ", $info->{instrument}, "\n";
  print "Version:               ", $info->{version}, "\n";
  print "Average peak distance: ", $info->{avg_peak_spacing}, "\n";

=cut

sub get_trace_info {
  my $self   = shift;
  my $data;
  $data->{instrument} = $self->{instrument};
  $data->{version}    = $self->{version};
  $data->{avg_peak_spacing} = $self->{avg_peak_spacing};

  return $data;
}

=head2 _get_sequence()

Internal routine (called by B<new()>) to populate sequence and quality.
See new()

=cut

sub _get_sequence {
    my $self   = shift;
    my $abif = $self->{chromas};

    $self->{raw_sequence}  = $abif->sequence();

    # Get quality values
    my @qv       = $abif->quality_values();
    # Encode quality in FASTQ chars
    my @fqv      = map {chr(int(($_<=93? $_ : 93)*4/6) + 33)} @qv;

    # FASTQ
    my $q = join('', @fqv);


    $self->{raw_quality} = $q;

    $self->{sequence} = $self->{raw_sequence};
    $self->{quality}  = $self->{raw_quality};

    # Trim
    if ($self->{trim_ends}) {
        #The Sequencing Analysis program determines the clear range of the sequence by trimming bases from the 5' to 3'
        #ends until fewer than 4 bases out of 20 have a quality value less than 20.
        #You can change these parameters by explicitly passing arguments to this method
        #(the default values are $window_width = 20, $bad_bases_threshold = 4, $quality_threshold = 20).
        # Note that Sequencing Analysis counts the bases starting from one, so you have to add one to the return values to get consistent results.
        my ($b, $e) = $abif->clear_range(
                                    $self->{wnd},
                                    $self->{bad_bases},
                                    $self->{min_qual},
                                   );
             if ($b>0 and $e>0) {
                my $l = $e-$b+1;
                $self->{sequence} = substr($self->{sequence}, $b, $l);
                $self->{quality}  = substr($self->{quality} , $b, $l);
             } else {
                $self->{discard} = 1;
             }
    }

    # Check hetero bases
    if ($self->{sequence}!~/[ACGT][RYMKWS]+[ACGT]/i) {
        $self->{hetero} = 0;
    } else {
        $self->{hetero} = 1;
    }

    # Check
    $self->{diff_array} = ();
    $self->{diff} = 0;
    my $seq1 = '';
    my $seq2 = '';
    for (my $i = 0; $i<length($self->{sequence}); $i++) {
      my $q0 = substr($self->{quality}, $i, 1);
      my $s0 = substr($self->{sequence}, $i,1);

      # Ambiguity detected:
      if ($iupac{$s0}) {
        my ($base1, $base2) = split //, $iupac{$s0};
        $seq1.=$base1;
        $seq2.=$base2;
        $self->{diff}++;
        push(@{ $self->{diff_array} }, $i);
      } else {
        $seq1.=$s0;
        $seq2.=$s0;

      }
    }
    $self->{seq1} = $seq1;
    $self->{seq2} = $seq2;

    if ($seq1 eq $seq2) {
       $self->{iso_seq} = 1
     } else {
       $self->{iso_seq} = 0;
     }


     $self->{instrument} = $self->{chromas}->official_instrument_name();
     $self->{version}    = $self->{chromas}->abif_version();
     $self->{avg_peak_spacing} = $self->{chromas}->avg_peak_spacing();

}

=head1 SEE ALSO

This module is a wrapper around L<Bio::Trace::ABIF> by Nicola Vitacolonna.

=cut
1;
