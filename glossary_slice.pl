#
#   glossary_001.pl
#
#   takes trimmed down version of OS 1:50,000 Glossary and outputs
#
#   (1)     sequence number
#   (2)     definitive name
#   (3)     latitude (degrees)
#   (4)     longitude (degrees
#   (5)     feature code
#
#


use Carp;
use strict;

my ($lon, $lat, $east, $north, $text, $string, $alt );
my ( $usgae, $type, $name, $usage, $other );
my ($n, $input_file, $output_file );
my ( $sequence_number, $definitive_name, $latitude, $longitude, $feature_code, $gmt_code);
my ($start_longitude, $end_longitude, $longitude_increment);
 
my @array;

##################################################################################
#	get file names from command line
##################################################################################

$input_file  = 'new_glossary.csv';

$longitude_increment = 0.1;

for ( $start_longitude =  -4.0001 ; $start_longitude < -3.0 ; $start_longitude = $start_longitude + $longitude_increment ) {

    $end_longitude =  $start_longitude + $longitude_increment;

    $output_file = sprintf("uk4_%d_%d.csv", int(-$start_longitude*10), int(-$end_longitude*10) );
    print "start $start_longitude   end $end_longitude   file $output_file\n";

    open (IN,  "<$input_file")  || die("unable to open $input_file");
    open (OUT, ">$output_file") || die("unable to open $output_file");

    while ( $text = <IN> ) {

#   (1)     sequence number
#   (2)     definitive name
#   (3)     latitude (degrees)
#   (4)     longitude (degrees
#   (5)     feature code

        chomp($text);

        @array = split( /\,/, $text );
   
        $sequence_number = @array[0];
        $definitive_name = @array[1];
        $latitude = @array[2];
        $longitude = @array[3];
        $feature_code = @array[4];
        
#        $definitive_name =~ s!\,! !m;
        $sequence_number  = sprintf("%6.6d", $sequence_number);

#        print "$sequence_number  $definitive_name  $latitude  $longitude  $feature_code\n";

        
        my @selected_features = qw(A C O H R T X Z);  # loose F = forest/wood, FM = farm; W = water feature

        if ( $latitude > 49.75 && $latitude < 51.25 && $longitude > $start_longitude && $longitude < $end_longitude ) {
            if (  grep { /$feature_code/ } @selected_features ) {

#            print OUT "$sequence_number\t$definitive_name\t$latitude\t$longitude\t$feature_code\n";

                print OUT "$longitude,$latitude,$definitive_name\_$feature_code\_$sequence_number\n";
            } 
        }
    }
    close(IN);
    close(OUT);    
}
    
exit;



#-----------------------------------------


