#!/usr/bin/perl -w

use strict;

#use 5.14.0;
use 5.10.0;

use Text::CSV;
use Class::CSV;
use Readonly;
use Data::Dumper;
use MaxEntUtils;

#get_fields
my $text_csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();
 
my $usage = 'perl csv_to_dat.pl CSV_FILE' ;
die "$usage" unless scalar (@ARGV) >= 1;

my $csv_file_name = $ARGV[0];

MaxEntUtils::csv_file_to_dat_file( $csv_file_name, '/tmp/file.dat' );
