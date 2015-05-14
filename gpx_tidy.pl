#!/usr/bin/perl
#
#
#=========================================================================
#       gpx_tidy.pl
#=========================================================================
#
#   reads a GPX file and generates fresh times for each point
#   allows 'rough' gpx files to be tidied up
#   optionally allows points to be thinned
#   simply by selecting every Nth point
#

use utility;
use Math::Trig;
use strict;
use Carp;

my ( $input_file, $output_gpx_file, $output_csv_file, $usage );
my ( $data, $k, $j, $n, $segment, $n_segment, $n_points, $point, $count, $count_1, $count_2, $n_pts_in_seg );
my ( $a, $b, $c );
my ( $latitude, $longitude, $elevation, $date_time, $distance, $seconds, $speed );
my ( $distance_ab, $distance_bc, $seconds_ab, $seconds_bc );
my ( $abc_distance_threshold, $abc_min_speed_threshold, $abc_max_speed_threshold, $cluster_threshold, $min_num_cluster_points, $half_max_cluster_points );
my ( $speed_ab, $speed_bc );
my ( $start, $n_remove );
my ( $year, $month, $day, $hour, $minute, $second, $elevation_feet );

my ( @latitude, @longitude, @elevation, @date_time );


##################################################################################
#	initialise constants
##################################################################################

$abc_distance_threshold 	= 15.0;    	# in metres (remove points closer than this)
$abc_min_speed_threshold	= 0.45;		# in metres/sec  ~ 1.0 mph
$abc_max_speed_threshold	= 20.0;		# in metres/sec	~ 45 mph

$cluster_threshold  		= 30.0;     # in metres (distance to be in cluster)
$min_num_cluster_points 	= 7;		# minimum number of points required in a cluster
$half_max_cluster_points	= 40;  		# i.e. max number of track points to search either side of current point when building cluster


$usage = 'USAGE: gpx_tidy.pl <input_file> <output_gpx_file>';


##################################################################################
#	get file names from command line
##################################################################################

$n = @ARGV;

if ( $n != 2) {
    print "ERROR: Incorrect number of command line arguments\n";
    print $usage;
    exit;
}

$input_file = $ARGV[0];
$output_gpx_file = $ARGV[1];

#print "input file  = $input_file\n";
#print "output file = $output_gpx_file\n";

#---- 	read entire input GPX file

$data = read_file( $input_file );

print "file length = " . length($data) . "\n";

#######################################################################################################
#	open output GPX and CSV files and write header stuff
#######################################################################################################

open (GPX, ">$output_gpx_file") || die("unable to open $output_gpx_file");

print GPX "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n\n";
print GPX "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\">\n";
print GPX "<trk>\n\n";
print GPX "  <trkseg>\n";



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

		if ( $n_pts_in_seg >= 1 ) {  		# skip first two points in each new segment
			push @latitude, $latitude;
			push @longitude, $longitude;
			push @elevation, $elevation;
			push @date_time, $date_time;
			$n_points++;
		}
        
		$n_pts_in_seg++;

    }   # for each data point
	$n_segment++;
}
    
	############################################################
    # we now have all the data points in GPX file
	############################################################
    
#    print "number of points\t$n_points\n";
#    for ( $k = 0 ; $k < 4 ; $k++ ) {
#        print "$k  @latitude[$k]  @longitude[$k]  @elevation[$k]  @date_time[$k]\n";
#    }

if ( 0 == 1 ) {
    print "before thinning\n";    
    print "seg\tnum\tnum\tdist\ttime\tspeed\tdt1\tdt2\n";
    
    for ( $k = 0 ; $k < $n_points-1 ; $k++ ){
    
		$j = $k + 1;
        $distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
        $distance = sprintf("%.1f", $distance);
        
        $seconds = utility::IsoSecondsDifference( @date_time[$k], @date_time[$j] );
        $speed = $distance / $seconds;      # m/s
        $speed = sprintf("%.2f", $speed);
           
        print "$n_segment\t$k\t$j\t$distance\t$seconds\t$speed\t@date_time[$k]\t@date_time[$k+1]\n";
    }
}    
    

#######################################################################################################
#	A(B)C algorithm
#   	examines each set of 3 consecutive points - A, B and C 
#######################################################################################################
	
	$a = 0;			# index of first of three points A, B, C

	print "A(B)C algorithm\n";
#	print "time\tmax_dist\tmax_speed\ttime\n";
	
    while ( $a < $n_points-2  ){			# note that $n_points and $a are adjusted in loop!
	
	    $b = $a + 1;	# indexes of three consecutive points A, B, C
		$c = $a + 2;	
#		print "a: $a  b: $b  c: $c\n";
    
        $distance_ab = great_circle_distance( @longitude[$a], @latitude[$a], @longitude[$b], @latitude[$b] ); 
        $distance_bc = great_circle_distance( @longitude[$b], @latitude[$b], @longitude[$c], @latitude[$c] ); 
        
        $seconds_ab = utility::IsoSecondsDifference( @date_time[$a], @date_time[$b] );
        $seconds_bc = utility::IsoSecondsDifference( @date_time[$b], @date_time[$c] );
				
        $speed_ab = $distance_ab / ($seconds_ab+0.01);      # m/s
        $speed_bc = $distance_bc / ($seconds_bc+0.01);      # m/s
           
		if (    max($speed_ab, $speed_bc) > $abc_max_speed_threshold ) {			# 20 m/s approx 45 mph
			print "a = $a  speed = " . max($speed_ab, $speed_bc) . "\n";
		}
		   
		   
##		print sprintf("%s\t%8.1f\t%6.1f\t%5d\t", @date_time[$b], max($distance_ab, $distance_bc), max($speed_ab, $speed_bc), max($seconds_ab, $seconds_bc) );
						
		if ( max($distance_ab, $distance_bc) < $abc_distance_threshold  ||  
				max($speed_ab, $speed_bc) < $abc_min_speed_threshold   ||
				max($speed_ab, $speed_bc) > $abc_max_speed_threshold )  {    # we need to remove point B

			$n_points--;
##			print "REMOVE b:\t$b";
			splice @longitude, $b, 1;
			splice @latitude, $b, 1;
			splice @elevation, $b, 1;
			splice @date_time, $b, 1;
						# we don't increment $a in here as we want to try again after having removed one point B
		} else {	   
			$a++;		# move onto next
		}
##		print "\n";
    }
    
#///////////////////////////////////////////////////////////////////////////////////////

if ( 0 == 1 ) {
    print "work out how many CLOSE neighbours a point has\n";    

    print "segment\ttime\tbefore\tafter\n";
	print "\t \t \t$cluster_threshold\t$cluster_threshold\n";
    
    for ( $k = 0 ; $k < $n_points-1 ; $k++ ){
	
		# how many points are near to $k ?
		
		$count_1 = 0;
		$count_2 = 0;
		
		for ( $j = $k - 1 ; $j > $k - $half_max_cluster_points ; $j-- ){		# how many before?
			if ( $j >= 0 ) {  # don't go below 0
				$distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
				if ( $distance < $cluster_threshold ) {
					$count_1++;
				} else {
				    last;  # demand that all points within cluster are consecutive in time
				}
			}
		}
		for ( $j = $k + 1 ; $j <= $k + $half_max_cluster_points ; $j++ ){		# how many after?
			if ( $j <  $n_points-1 ) {  # don't go over end
				$distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
				if ( $distance < $cluster_threshold ) {
					$count_2++;
				} else {
				    last;   # demand that all points within cluster are consecutive in time
				}
			}
		}
		$count = $count_1 + $count_2;
#        print "$n_segment\t@date_time[$k]\t$count_1\t$count_2\t$count\n";
		
    }
}

#######################################################################################################
#	Clustering algorithm
#		points are examined to see how many points other are 'close' to it
#		if more than (say) 7 points are within a radius of (say) 30 m of one point
#		then all the points 'within' the cluster are removed - but not the first and last points
#######################################################################################################


#    print "try to delete CLOSE neighbours!!!\n";    
	print "Cluster algorithm\n";

#    print "segment\ttime\tbefore\tafter\n";
#	print "\t \t \t$cluster_threshold\t$cluster_threshold\n";
    
	$k = 0;
	
    while ( $k < $n_points-1 ){
	
		# how many points are near to $k ?
		
		$count_1 = 0;
		$count_2 = 0;
		
		for ( $j = $k ; $j > $k - $half_max_cluster_points ; $j-- ){		# how many at and before?
			if ( $j >= 0 ) {  # don't go below 0
				$distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
				if ( $distance < $cluster_threshold ) {
					$count_1++;
				} else {
				    last;  # demand that all points within cluster are consecutive in time
				}
			}
		}
		for ( $j = $k + 1 ; $j <= $k + $half_max_cluster_points ; $j++ ){		# how many after?
			if ( $j <  $n_points-1 ) {  # don't go over end
				$distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
				if ( $distance < $cluster_threshold ) {
					$count_2++;
				} else {
				    last;   # demand that all points within cluster are consecutive in time
				}
			}
		}
		$count = $count_1 + $count_2;
#        print "$n_segment\t@date_time[$k]\t$count_1\t$count_2\t$count\n";
		if ( $count >= $min_num_cluster_points  ) {			# we need a minimum number of points near together to consider it a cluster
		
				# we need to delete everything from $k - $count_1 + 1 to $k + $count_2 - 1
		
			$start = $k - $count_1 + 2;			# adjust indexes so that we retain first and last point
			$n_remove = $count - 2;
		
			$n_points = $n_points - $n_remove;
			print "REMOVE STUFF at k = $k, c1 = $count_1  c2 = $count_2  count = $count  start = $start  n_remove = $n_remove\n";
			
			splice @longitude, $start, $n_remove;
			splice @latitude,  $start, $n_remove;
			splice @elevation, $start, $n_remove;
			splice @date_time, $start, $n_remove;
						# we don't increment $k in here as we want to try again after having removed one cluster
		} else {
			$k++;
		}
    }
			
#///////////////////////////////////////////////////////////////////////////////////////
			
			
			
			
			
if ( 0 == 1 ) {		   
    print "after thinning\n";    

    print "seg\tnum\tnum\tdist\ttime\tspeed\tdt1\tdt2\n";
    
    for ( $k = 0 ; $k < $n_points-1 ; $k++ ){
    
		$j = $k + 1;
        $distance = great_circle_distance( @longitude[$k], @latitude[$k], @longitude[$j], @latitude[$j] ); 
        $distance = sprintf("%.1f", $distance);
        
        $seconds = utility::IsoSecondsDifference( @date_time[$k], @date_time[$j] );
        $speed = $distance / $seconds;      # m/s
        $speed = sprintf("%.2f", $speed);
           
        print "$n_segment\t$k\t$j\t$distance\t$seconds\t$speed\t@date_time[$k]\t@date_time[$k+1]\n";
    }
}
	
#######################################################################################################
#	write out this segment in GPX and CSV formats
#######################################################################################################


    $date_time = "2014-10-01 08:00:00";
	
	$count = 0;
    for ( $k = 0 ; $k < $n_points ; $k++ ){

        $latitude  = sprintf("%.6f", @latitude[$k]);        # 0.1 m resolution
        $longitude = sprintf("%.6f", @longitude[$k]);       # 0.1 m resolution
        $elevation = sprintf("%.1f", @elevation[$k]);       # 0.1 m resolution
#        $date_time = @date_time[$k];

#		<trkpt lat="28.26885" lon="-16.7452168744"><ele>10.0</ele><time>2013-12-25T10:49:43Z</time></trkpt>

        if ($count%4 == 0 ) {
 		    print GPX "    <trkpt lat=\"$latitude\" lon=\"$longitude\"><ele>$elevation</ele><time>$date_time</time></trkpt>\n";
		}
		
		$year 	= substr($date_time, 0, 4);
		$month 	= substr($date_time, 5, 2);
		$day 	= substr($date_time, 8, 2);
		$hour 	= substr($date_time, 11, 2);
		$minute = substr($date_time, 14, 2);
		$second = substr($date_time, 17, 2);

        $date_time = utility::IsoDateTimePlusSeconds($date_time, 10);
        $count++;
			
    }
	

#######################################################################################################
#	write out tails of GPX and CSV files
#######################################################################################################

print GPX "  </trkseg>\n\n";
print GPX "</trk>\n";
print GPX "</gpx>\n";
close (GPX);


exit;


############################################################################
sub great_circle_distance {
############################################################################
#
#   great_circle_distance( lon1, lat1, lon2, lat2 ) 
#   using haversine formulae
#   assumes the earth is spherical
#   input angles in degrees
#   output result in metres
#
    my ( $lon1, $lat1, $lon2, $lat2 ) = @_;
    my ( $deg2rad , $pi, $earth_radius );
    my ( $a, $b, $h, $theta, $distance );
    
    $pi = 3.14159;
    $deg2rad = $pi / 180.0;
    $earth_radius = 6372797.6;      # metres

    $lon1 = $deg2rad * $lon1;
    $lat1 = $deg2rad * $lat1;
    $lon2 = $deg2rad * $lon2;
    $lat2 = $deg2rad * $lat2;
    
# $lat1 and $lon1 are the coordinates of the first point in radians
# $lat2 and $lon2 are the coordinates of the second point in radians

    $a = sin(($lat2 - $lat1)/2.0);
    $b = sin(($lon2 - $lon1)/2.0);
    $h = ($a*$a) + cos($lat1) * cos($lat2) * ($b*$b);
    $theta = 2 * asin(sqrt($h)); # distance in radians
    # in order to find the distance, multiply $theta by the radius of the earth, e.g.

    $distance = $theta * $earth_radius;
    return ($distance );
}

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
sub max
############################################################################
{
	my ($a, $b) = @_;
  
	if ( $a > $b ) {
		return ( $a );
	} else {
		return ( $b );
	}
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

