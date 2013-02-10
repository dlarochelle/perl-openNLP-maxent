#!/usr/bin/perl -w

package MaxEntUtils;

use strict;

use 5.10.0;

use Text::CSV;
use Class::CSV;
use Readonly;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir /;
use Env qw(HOME);
use File::Path qw(make_path remove_tree);
use MaxEntModelFactory;

sub output_testing_and_training
{
    my( $out_data, my $leave_out_part, my $parts ) = @_;

    my @test_data = @ { $out_data };

    my $part_size =   my $parts_size = int ( scalar( @test_data ) /$parts ) + 1;

    my @leave_out_data = splice @test_data, ($part_size* $leave_out_part ), $part_size;

    my ( $leave_out_data_fh, $leave_out_data_file_name ) = tempfile("/tmp/leave_out_tmpfileXXXXXX",  SUFFIX => '.dat');

    print $leave_out_data_fh @leave_out_data;

    close( $leave_out_data_fh);

    my ( $train_data_fh, $train_data_file_name ) = tempfile( "/tmp/train_tmpfileeXXXXXX", SUFFIX => '.dat');

    print $train_data_fh @test_data;

    say STDERR $leave_out_data_file_name;
    say STDERR $train_data_file_name;

    close( $train_data_fh);

    return { 
	leave_out_file =>  $leave_out_data_file_name,
	train_data_file => $train_data_file_name
    };
}


sub generate_output_fhs
{
    my ( $output_dir ) = @_;

    my $ret= {};
    my $probabilities_file_name = "$output_dir/probabilities.txt";
    open my $probabilities_fh, '>',  $probabilities_file_name or die "Failed to open file $@";

    $ret->{ probabilities_fh } = $probabilities_fh;

    my $predictions_file_name =  "$output_dir/predictions.txt";;
    open my $predictions_fh, '>', $predictions_file_name or die "Failed to open file $@";

    $ret->{ predictions_fh } = $predictions_fh;

    my $expected_results_file_name =  "$output_dir/expected.txt";
    open my $expected_results_fh, '>', $expected_results_file_name or die "Failed to open file $@";

    $ret->{ expected_results_fh } = $expected_results_fh;

    return $ret;
}

my $gaussian = $ENV{ MAX_ENT_GUASSIAN };

sub create_model
{
    my ( $training_data_file, $iterations ) = @_;

    say STDERR "creating model";

    my $create_model_script_path;

    if ( $gaussian )
    {
	$create_model_script_path = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_create_model_gaussian.sh";
    }
    else
    {
	$create_model_script_path = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_create_model.sh";
    }

    #say STDERR "running $create_model_script_path " .  "-$iterations " . $training_data_file;
    #exit;

    system( $create_model_script_path, "-$iterations", $training_data_file );

    my $model_file_name = $training_data_file;
    
    $model_file_name =~ s/\.dat$/Model\.txt/;

    return $model_file_name;
}

sub create_model_inline_java
{
    my ( $training_data_file, $iterations ) = @_;

    say STDERR "creating model";

    my $create_model_script_path;

    if ( $gaussian )
    {
	$create_model_script_path = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_create_model_gaussian.sh";
    }
    else
    {
	$create_model_script_path = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_create_model.sh";
    }

    #say STDERR "running $create_model_script_path " .  "-$iterations " . $training_data_file;
    #exit;

    my $model = MaxEntModelFactory::create_model( $training_data_file, $iterations );

    #system( $create_model_script_path, "-$iterations", $training_data_file );

    my $model_file_name = $training_data_file;
    
    $model_file_name =~ s/\.dat$/Model_inline_java\.txt/;

    MaxEntModelFactory::save_model( $model, $model_file_name ) ;

    return $model_file_name;
}

sub create_model_at_location
{
    my ( $training_data_file, $iterations, $model_file_location ) = @_;
    
    use File::Copy;

    my ( $tmp_data_fh, $tmp_data_file_name ) = tempfile("/tmp/data_file_tmpfileXXXXXX",  SUFFIX => '.dat');

    copy ( $training_data_file, $tmp_data_fh );

    close( $tmp_data_fh );

    my $model_tmp_file_name = create_model( $tmp_data_file_name, $iterations );

    copy ( $model_tmp_file_name, $model_file_location );

    return $model_file_location;
}

sub run_model_arff_file
{
    my ( $model_file_name, $test_arff_file_name, $output_fhs ) = @_;

    my $dat_file_name = _dat_file_name_from_arff_file_name( $test_arff_file_name );

    arff_file_to_dat_file( $test_arff_file_name, $dat_file_name );

    run_model ( $model_file_name, $dat_file_name, $output_fhs ) 
}

sub run_model
{
    my ( $model_file_name, $test_data_file, $output_fhs ) = @_;
    
    my $probabilities_fh = $output_fhs->{ probabilities_fh };

    my $predictions_fh = $output_fhs->{ predictions_fh };

    my $expected_results_fh = $output_fhs->{ expected_results_fh };
    
    say STDERR "generating probabilities";
    
    my $model_results_command = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_predict.sh  $test_data_file $model_file_name";
    #say STDERR $model_results_command;
    
    my $model_results = `$model_results_command`;
    print $probabilities_fh $model_results;
    
    say STDERR "generating predictions";
    
    my $model_prediction_command = "$HOME/Dropbox/SCOTUS_Data2/apache-opennlp-1.5.2-incubating-src/opennlp-maxent/samples/sports/run_eval.sh  $test_data_file $model_file_name";
    
    #say STDERR "$model_prediction_command";
    
    my $model_predictions = `$model_prediction_command`;
    print $predictions_fh $model_predictions;

    open my $in_fh,  $test_data_file or die "Failed to open file $@";

    my @test_data = <$in_fh>;   

    my @expected_results = map { $_ =~ s/.* //; $_ } @test_data;

    print $expected_results_fh @expected_results;    
}

sub train_and_test
{
    my ($files, $output_fhs, $iterations ) = @_;

    my $model_file_name = create_model( $files->{ train_data_file }, $iterations );

    run_model( $model_file_name, $files->{ leave_out_file }, $output_fhs );
}


#TODO DRY out this code

sub purge_false_features_and_references
{
    my ( $data_array ) = @_;

    my $updated_data =  [ map { $_ =~ s/(\S*\=false)\s+//g; $_ =~ s/(\s+reference_\S+\.html=(true)|(false))\s+/ /g; $_; } @{ $data_array } ];

    return $updated_data;
}

sub purge_false_features
{
    my ( $data_array ) = @_;

    my $updated_data =  [ map { $_ =~ s/(\S*\=false)\s+//g; $_; } @{ $data_array } ];

    return $updated_data;
}

sub dat_file_purge_false_features_and_references
{
    my ( $input_file_name, $output_file_name ) = @_;

    open my $in_fh, '<', $input_file_name or die "Failed to open file: $@";

    my @data = <$in_fh>;

    my $updated_data = purge_false_features_references( \@data );

    open my $out_fh, '>', $output_file_name;

    print $out_fh @{ $updated_data };
    #print @updated_data;
}

sub dat_file_purge_false_features
{
    my ( $input_file_name, $output_file_name ) = @_;

    open my $in_fh, '<', $input_file_name or die "Failed to open file: $@";

    my @data = <$in_fh>;

    my $updated_data = purge_false_features( \@data );

    open my $out_fh, '>', $output_file_name;

    print $out_fh @{ $updated_data };
    #print @updated_data;
}

sub csv_file_to_dat_file
{
    my ( $csv_file_name, $dat_file_name ) = @_;

    my $text_csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

    open my $fh, "<:encoding(utf8)", $csv_file_name or die "$csv_file_name: $!";
    open my $out_fh, ">:encoding(utf8)", $dat_file_name or die "$dat_file_name: $!";
    my $fields = $text_csv->getline( $fh );

#say STDERR Dumper($fields);
    
    $text_csv = 0;
    close( $fh );
    
    say STDERR "starting csv parse";
    
    my $csv = Class::CSV->parse(
	filename => $csv_file_name,
	fields   => $fields
	);
    
    say STDERR "finished csv parse";
    
    my @lines = @{$csv->lines()};
    
    shift @lines;
    
    $csv->lines( \@lines );
    
    my $indep_var_fields = [ @ { $fields } ];
    
    pop @ { $ indep_var_fields };
    
    for my $line ( @ { $csv->lines() } )
    {
	for my $indep_var_field ( @ { $indep_var_fields } )
	{
	    
	    my $field_val = $line->get( $indep_var_field ) ;
	    ## Don't include false features.
	    
	    next if ( $field_val == 0 );
	    
	    print $out_fh "$indep_var_field=";
	    die unless defined( $field_val );
	    
	    if ( $field_val == 1 )
	    {
		print $out_fh "true";
	    }
	    else
	    {
		die unless $field_val == 0;
		print $out_fh "false";
	    }
	    
	    print $out_fh " ";
	}
	
	say $out_fh $line->get( 'class' );
    }
    
    say STDERR "closing handle for the file:  $dat_file_name";
}


sub arff_file_to_csv_file
{
    my ($arff_file_name, $csv_file_name ) = @_;

    my $cmd = "java -cp /usr/share/java/weka.jar weka.core.converters.CSVSaver -i  $arff_file_name -o $csv_file_name";

    system( $cmd ) and
	die "failed command: '$cmd' to create csv file $csv_file_name from $arff_file_name: $@";
}

sub arff_file_to_dat_file
{
    my ($arff_file_name, $dat_file_name ) = @_;

   my ( $tmp_csv_fh, $tmp_csv_file_name ) = tempfile("/tmp/leave_out_tmpfileXXXXXX",  SUFFIX => '.csv');
    
    arff_file_to_csv_file( $arff_file_name, $tmp_csv_file_name );

    csv_file_to_dat_file( $tmp_csv_file_name, $dat_file_name );
}

sub _dat_file_name_from_arff_file_name
{
    my ( $arff_file_name ) = @_;

    my $dat_file_name = $arff_file_name;
    $dat_file_name =~ s/\.arff$/\.dat/;
   
    die $dat_file_name if $arff_file_name eq $dat_file_name;

    say STDERR "Dat file: $dat_file_name";

    return $dat_file_name;
}

sub create_model_from_arff_file
{
    my ( $arff_file_name, $iterations ) = @_;

    my $dat_file_name = _dat_file_name_from_arff_file_name( $arff_file_name );

    arff_file_to_dat_file( $arff_file_name, $dat_file_name );

    return create_model( $dat_file_name , $iterations );
}

sub create_model_and_test_from_arff_files
{
    my ( $arff_train_file_name, $arff_test_file_name, $iterations, $output_dir ) = @_;

    unless ( -d $output_dir ) 
    {
	make_path( $output_dir ) or die "$@";
    }

    my $output_fhs = MaxEntUtils::generate_output_fhs( $output_dir );

    my $dat_train_file_name =  _dat_file_name_from_arff_file_name( $arff_train_file_name );

    my $model_file_name = create_model_from_arff_file( $arff_train_file_name , $iterations );

    run_model_arff_file( $model_file_name, $arff_test_file_name, $output_fhs );
}

1;
