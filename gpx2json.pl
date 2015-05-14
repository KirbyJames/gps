#!/usr/bin/perl
#
#
#=========================================================================
#       gpx2json.pl
#=========================================================================
#
#   reads a GPX file and converts it to a JSON file
#

use utility;
use Math::Trig;
use strict;
use Carp;

my ( $input_gpx_file, $output_json_file, $usage );
my ( $data, $k, $j, $n, $segment, $n_segment, $n_points, $point, $count, $count_1, $count_2, $n_pts_in_seg );
my ( $a, $b, $c );
my ( $latitude, $longitude, $elevation, $date_time, $distance, $seconds, $speed );
my ( $start, $n_remove );
my ( $year, $month, $day, $hour, $minute, $second, $elevation_feet );

my ( @latitude, @longitude, @elevation, @date_time );


##################################################################################
#	initialise constants
##################################################################################


$usage = 'USAGE: gpx2json.pl <input_gpx_file> <output_json_file>';


##################################################################################
#	get file names from command line
##################################################################################

$n = @ARGV;

if ( $n != 2) {
    print "ERROR: Incorrect number of command line arguments\n";
    print $usage;
    exit;
}

$input_gpx_file = $ARGV[0];
$output_json_file = $ARGV[1];


print "input file  = $input_gpx_file\n";
print "output file = $output_json_file\n";

#---- 	read entire input GPX file

$data = read_file( $input_gpx_file );

print "file length = " . length($data) . "\n";

#######################################################################################################
#	open output JSON file and write header stuff
#######################################################################################################

my $start_string = q|
{
 "type": "FeatureCollection",
 "features": [
 {
 "type": "Feature",
 "properties": {
 "name": "ACTIVE LOG",
 "time": "DATETIME"
 },
 "geometry": {
 "type": "LineString",
 "coordinates": [
 
|;
 
 
 my $end_string = q|
  ]
 }
 }
 ]
}

|;


open (JSON, ">$output_json_file") || die("unable to open $output_json_file");

 
##################################################################################
#	work through input GPX data - and extract longitude, latitude, elevation and date-time
##################################################################################

@latitude = ();			# zero arrays used to hold coordinates
@longitude = ();
@elevation = ();
@date_time = ();

$n_segment = 0;
$n_points = 0;				# number of points in total

while ( $data =~ m!<trkseg>(.*?)</trkseg>!sg ) {        # find each segment
    $segment = $1;
    print "segment\t$n_segment\n";
    	
	############################################################
    # in this segment work through trkpts and extract long, lat, elevation and date-time
	############################################################
    
	$n_pts_in_seg = 0;			# just number of points in this segment

    while ( $segment =~ m!<trkpt\s(.*?)</trkpt>!sg ) {       # find all data points within this segment

		$point = $1;

		# example - <trkpt lat="50.6161519792" lon="-3.4078547638"><ele>3.50</ele><time>2013-11-25T13:39:01Z</time></trkpt>
        
        $point =~ m!lat\=[\"\'](.*?)[\"\']!s;
        $latitude = sprintf("%.6f", $1);        # retain 0.1 m resolution
        
        $point =~ m!lon\=[\"\'](.*?)[\"\']!s;
        $longitude = sprintf("%.6f", $1);       # retain 0.1 m resolution
        
        $point =~ m!<ele>(.*?)</ele>!s;
        $elevation = sprintf("%.1f", $1);       # retain 0.1 m resolution
        
        $point =~ m!<time>(.*?)</time>!s;
        $date_time = $1;
        
        if ( $n_points == 0 ) {
            print "time(0) = $date_time\n";
            $start_string =~ s!DATETIME!$date_time!;
            print JSON $start_string;
            print "start = $start_string\n";
            
            
        }
        

		push @latitude, $latitude;
		push @longitude, $longitude;
		push @elevation, $elevation;
		push @date_time, $date_time;
		$n_points++;
		$n_pts_in_seg++;

    }   # for each data point
	$n_segment++;
}
    
	############################################################
    # we now have all the data points in GPX file
	############################################################
    
print "number of points\t$n_points\n";
for ( $k = 0 ; $k < $n_points-1 ; $k++ ) {
#    print "$k  @latitude[$k]  @longitude[$k]  @elevation[$k]  @date_time[$k]\n";
    print JSON "[@longitude[$k],@latitude[$k]],\n";
        
}
print JSON "[@longitude[$n_points-1],@latitude[$n_points-1]]\n";  # no comma on last one

print JSON $end_string;
print "end = $end_string\n";

close (JSON);

exit;



############################################################################
sub exists_and_is_non_zero_size {
############################################################################
  # returns 1 if file exists and is of non-zero size
  # returns 0 otherwise

  my ($file) = @_;

  if ( !( -e $file ) ) {
    return 0;    # doesn't even exist
  }

  my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat $file;

  if ( $size == 0 ) {
    return 0;
  }
  return 1;
}


############################################################################
sub read_file    #05/03/2003 21:18 - slurps a complete text file
############################################################################
{
  my ($file) = @_;
  my ($text);

  undef $/;

  open( IN, "<$file" ) || die("unable to open $file");
  $text = <IN>;
  close(IN);

  $/ = "\n";

  return $text;

}    ##read_file

#------------------------------ end -----------------------------

