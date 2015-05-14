#!/usr/bin/perl
#
#
#=========================================================================
#       g.pl
#=========================================================================
#

#   results are stored in Perl list-of-lists (LoL)
#
#           GPX                                         PLACE/PASSAGE
#           ===                                         =============
#
#   [0]     longitude (deg) of point                    longitude(deg) on track of point of closest approach
#   [1]     latitude (deg) of point                     latitude deg) on track of point of closest approach
#   [2]     elevation (m) of point                      elevation (m) on track of point of closest approach

#   [3]     date-time (yyyy-mm-dd hh:mm:ss) at point    date-time on track of point of closest approach
#   [4]     segment (integer)                           segment (integer) in which point of closest approach falls
#   [5]     distance (km) of point along GPX track      distance (km) along GPX track of point of closest approach
#
#   [6]     ---                                         place-name (test) - passed through or close to
#   [7]     ---                                         distance (km) of closest approach to place-name
#   [8]     ---                                         longitude (deg) of place-name 
#   [9]     ---                                         latitude (deg) of place-name
 


use utility;
use Math::Trig;
use strict;
use Carp;

my ( $n, $gpx_data, $input_file, $usage, $minimun, $maximum );
my ( @longitude, @latitude, @elevation, @date_time, @distance, @segment );
my ( @global_LoL, @gpx_LoL,  @place_loL, @xxx_global_LoL );

$usage = "USAGE: g.pl <input_gpx_file>\n";

##################################################################################
#	get file names from command line
##################################################################################

$n = @ARGV;

if ( $n != 1) {
    print "ERROR: Incorrect number of command line arguments\n";
    print $usage;
    exit;
}

$input_file = $ARGV[0];
print "input file  = $input_file\n";

#################################################################################
# 	read and decode input GPX file 
#################################################################################

$gpx_data = read_file( $input_file );
print "file length = " . length($gpx_data) . " bytes\n";

decode_gpx_data( $gpx_data, \@gpx_LoL );

$n = $#gpx_LoL;
print "number of GPX points: $n\n";

determine_route_text( \@gpx_LoL );    # result goes into global_LoL for the moment

#################################################################################
#   output JSON file
#################################################################################

my $output_json_file = "/inetpub/wwwroot/leaflet/new.json";

open( OUT, ">$output_json_file" ) || die("unable to open $output_json_file");

print OUT "{ \"type\": \"FeatureCollection\", \"features\": [\n\n"; 

#----   output icon for PLACES passed through

$n = $#xxx_global_LoL;
print "n = $n\n";
if ( $n > -1  ) {               # are there any places identified?

    for my $k ( 0 .. $#xxx_global_LoL ) {
        #print "$xxx_global_LoL[$k][6]\n";
        my $place_name = $xxx_global_LoL[$k][6];
        my $distance = sprintf("%.1f", $xxx_global_LoL[$k][5] );
        my $time = substr( $xxx_global_LoL[$k][3], 11, 8 );
        my $longitude = $xxx_global_LoL[$k][8];     # PLACE co-ordinates
        my $latitude = $xxx_global_LoL[$k][9];
        #my $longitude = $xxx_global_LoL[$k][0];    # GPX place when nearest
        #my $latitude = $xxx_global_LoL[$k][1];
        my $elevation = 1.23;
        
        print OUT "{ \"type\": \"Feature\", \"properties\": { ";
        print OUT "\"name\": \"<b>$place_name</b><br>$distance km<br>$time\", \"color\": \"#ff00ff\" }, \"geometry\": { \"type\": \"Point\", \"coordinates\": ";
        print OUT "[ $longitude, $latitude, $elevation ] } },\n";
    }
    
    #---- output icon with summary information
    
    $n = $#xxx_global_LoL;
    my $total_distance  = sprintf("%.3f", $xxx_global_LoL[$n][5] ); 
    my $start_time      = substr( $xxx_global_LoL[0][3], 11, 8 );
    my $end_time        = substr( $xxx_global_LoL[$n][3], 11, 8 );
    my $date            = substr( $xxx_global_LoL[0][3], 0, 10 );
    
    $n = $#gpx_LoL;
    my $end_longitude   = $gpx_LoL[$n][0];
    my $end_latitude    = $gpx_LoL[$n][1];
        
    print OUT "{ \"type\": \"Feature\", \"properties\": { ";
    print OUT "\"name\": \"Date: $date<br>Start: $start_time<br>End: $end_time<br>Distance: $total_distance km\", \"color\": \"#008800\" }, \"geometry\": { \"type\": \"Point\", \"coordinates\": ";
    print OUT "[ $end_longitude, $end_latitude, 1.1 ] } },\n";
    
    print OUT "\n\n";

}

#----   output GPX track

print OUT "{ \"type\": \"Feature\", \"properties\": { \"id\": 1,  \"name\": \"GPX track\", \"color\": \"#aa00aa\" }, \"geometry\": { \"type\": \"LineString\", \"coordinates\": [\n";  


my ($longitude, $latitude, $elevation,  $date_time );

$n = $#gpx_LoL;

for my $k ( 0 .. $#gpx_LoL ) {

    #print "$k: @gpx_LoL[$k], @latitude[$k], @elevation[$k], @date_time[$k], @distance[$k], @segment[$k]\n";
    
    $longitude  = $gpx_LoL[$k][0];
    $latitude   = $gpx_LoL[$k][1];
    $elevation  = $gpx_LoL[$k][2];
    $date_time  = $gpx_LoL[$k][3];
    
    if ($k == 0) {
        print OUT "[ $longitude, $latitude, $elevation, \"$date_time\" ]";
    } else {
        print OUT ",\n[ $longitude, $latitude, $elevation, \"$date_time\" ]";
    }
}

print OUT "\n\n] } } \n\n] }\n\n";
close OUT;

exit;

##################################################################################
sub decode_gpx_data() {
##################################################################################
#   work through input GPX data - and extract longitude, latitude, elevation, date-time and segment number
##################################################################################
    my ( $gpx_data, $ref_gpx_LoL ) = @_;

    my ( $segment_data, $point, $last_latitude, $last_longitude, $latitude, $longitude, $date_time, $elevation, $n_pts_in_seg, $last_date_time );
        
    @$ref_gpx_LoL       = ();

    my $n_segment = 0;
    my $n_points = 0;				# number of points in total
    my $total_distance = 0.0;

    my $last_date_time = "ba7652n5";  # nonsensical value

    while ( $gpx_data =~ m!<trkseg>(.*?)</trkseg>!sg ) {        # find each segment
        $segment_data = $1;
        #print "segment number\t$n_segment\n";
    	
        #----   in this segment work through all trkpts and extract long, lat, elevation and date-time
    
        $n_pts_in_seg = 0;			# just number of points in this segment

        while ( $segment_data =~ m!<trkpt\s(.*?)</trkpt>!sg ) {       # find all data points within this segment

            $point = $1;       # example - <trkpt lat="50.6161519792" lon="-3.4078547638"><ele>3.50</ele><time>2013-11-25T13:39:01Z</time></trkpt>
        
            $point =~ m!lat\=[\"\'](.*?)[\"\']!s;
            $latitude = sprintf("%.6f", $1);        # retain 0.1 m resolution
        
            $point =~ m!lon\=[\"\'](.*?)[\"\']!s;
            $longitude = sprintf("%.6f", $1);       # retain 0.1 m resolution
        
            $point =~ m!<ele>(.*?)</ele>!s;
            $elevation = sprintf("%.1f", $1);       # retain 0.1 m resolution
        
            $point =~ m!<time>(.*?)</time>!s;
            $date_time = $1;
            $date_time =~ s!T! !;

            if ( $date_time ne $last_date_time ) {   # skip if date-time is repeated ...
                
                $$ref_gpx_LoL[$n_points][0]      = $longitude;
                $$ref_gpx_LoL[$n_points][1]      = $latitude;
                $$ref_gpx_LoL[$n_points][2]      = $elevation;
                $$ref_gpx_LoL[$n_points][3]      = $date_time;
                $$ref_gpx_LoL[$n_points][4]      = $n_segment;
                                
                if ( $n_points == 0 ) {
                    $total_distance = 0.0;
                } else {
                    $total_distance = $total_distance + haversine_distance ( $last_longitude, $last_latitude, $longitude, $latitude );
                }
                
                $$ref_gpx_LoL[$n_points][5] = sprintf( "%.4f", $total_distance );     # to nearest 0.1 m
                
                $last_date_time = $date_time;
                $last_latitude = $latitude;
                $last_longitude = $longitude;
                
			    $n_points++;
            }
        
            $n_pts_in_seg++;

        }   # for each data point
        $n_segment++;
    }
    
    #---- we now have all the data points in GPX file
    
    return;   # results are in @gpx_LoL
}


#############################################################################
sub calculate_ref_array_min_max    #04/02/2003 19:35
#############################################################################
#   given references to an array determines min and max values
#############################################################################
{
    my ($ref_array) = @_;
    my ( $min, $max, $n_pts, $big_number, $val );

    $n_pts = @$ref_array;
  
    $big_number = 9999999999.9;
    $min        = $big_number;
    $max        = -$big_number;

    for ( my $k = 0 ; $k < $n_pts ; $k++ ) {    
        $val = @$ref_array[$k];
        if ( $val > $max ) { $max = $val };
        if ( $val < $min ) { $min = $val };
    }
    
    return ( $min, $max );      
}  
  

#############################################################################
sub determine_route_text   
#############################################################################
#   given references to arrays of longitude, latitude east, north, date_time and distance, and
#   a database of the longitude and latitude of places, determines
#    -- which locations are 'passed through'
#    -- at what distance from the start, and
#    -- the place's longitude and latitude 
#############################################################################
{
    my ( $ref_gpx_LoL ) = @_;

    my ( $arrive_threshold, $depart_threshold );
    my ( $minimum_longitude, $maximum_longitude, $minimum_latitude, $maximum_latitude, $border );
    my ( $longitude, $latitude, $date_time, $name, $n_match_places, $glossary_filename, $line, $longitude_latitude_place, $j, $k, $d, $dd );
    my ( $n_gpx_points, $gpx_latitude, $gpx_longitude, $gpx_date_time, $gpx_distance, $gpx_elevation );
    my ( $place_longitude, $place_latitude, $place_name);
    my ( $tmp_gpx_distance, $tmp_gpx_date_time, $tmp_gpx_longitude, $tmp_gpx_latitude, $tmp_gpx_elevation );
    my ( %longitude_latitude_place_hash, %passage );
    my ( %passage_distance, %passage_date_time, %passage_longitude, %passage_latitude, %passage_metadata );
    my ( @LoL, @xxx_LoL );
 
    $arrive_threshold = 0.6;                        # km to point
    $depart_threshold = 2.0 * $arrive_threshold;
    $border = 0.01;                                 # border to add to search area in degrees lat/long; 0.01 degrees is ~1.0 km

    #---- limit area/places to search ----
    
    $minimum_longitude = +180.0;
    $maximum_longitude = -180.0;
    $minimum_latitude  =  +90.0;
    $maximum_latitude  =  -90.0;
    
    for $k ( 0 .. $#gpx_LoL ) {
        $longitude = $$ref_gpx_LoL[$k][0];
        $latitude = $$ref_gpx_LoL[$k][1];
        if ( $latitude > $maximum_latitude ) { $maximum_latitude = $latitude };
        if ( $latitude < $minimum_latitude ) { $minimum_latitude = $latitude };
        if ( $longitude > $maximum_longitude ) { $maximum_longitude = $longitude };
        if ( $longitude < $minimum_longitude ) { $minimum_longitude = $longitude };
    }
    
    #print "EXACT:  longitude: $minimum_longitude, $maximum_longitude  latitude: $minimum_latitude, $maximum_latitude\n";
    
    $minimum_longitude = $minimum_longitude - $border;
    $maximum_longitude = $maximum_longitude + $border;
    $minimum_latitude = $minimum_latitude - $border;
    $maximum_latitude = $maximum_latitude + $border;

##########################################################################
#-----  FIRST
#----   'os_glossary.csv' data file holds UK places in longitude,latitude,name format
#----   find all places within min/max rectangle surrounding route and save them in $longitude_latitude_place_hash
##########################################################################
    
    $glossary_filename = 'os_glossary.csv';
    open( PLACES, "<$glossary_filename" ) || croak("unable to open $glossary_filename");

    $n_match_places = 0;
    while ( ( $line = <PLACES> ) ) {     # read each place
        chomp($line);
        ( $longitude, $latitude, $name ) = split( "\,", $line );
        
        if ( $longitude > $minimum_longitude && $longitude < $maximum_longitude && $latitude > $minimum_latitude && $latitude < $maximum_latitude ) {        
            #print "FOUND: $longitude $latitude $name\n"; 
            $longitude_latitude_place_hash{$line} = $line;        
            $n_match_places++;
        }
    }        # read each place
    close(PLACES);
    
    print "FOUND: $n_match_places places within rectangle surrounding track\n";
        
##########################################################################
#---- SECOND
#---- we now have a list of places within the rectangle surrounding the route
#---- we now go through the route seeing which places the route 'passes through'
##########################################################################

    for $k ( 0 .. $#gpx_LoL ) {                 # for each consecutive point on track ....

        $gpx_longitude = $$ref_gpx_LoL[$k][0];
        $gpx_latitude  = $$ref_gpx_LoL[$k][1];
        $gpx_elevation = $$ref_gpx_LoL[$k][2];
        $gpx_date_time = $$ref_gpx_LoL[$k][3];
        $gpx_distance  = $$ref_gpx_LoL[$k][5];
                
        foreach $longitude_latitude_place (keys %longitude_latitude_place_hash) {    # for each place in glossary ....
            #print "$longitude_latitude_place\n";
            ( $place_longitude, $place_latitude, $place_name) = split( "\,", $longitude_latitude_place );
            
            #print "PLACE: $place_longitude, $place_latitude, $place_name\n";
            $d = haversine_distance ( $gpx_longitude, $gpx_latitude, $place_longitude, $place_latitude );
            $d = sprintf("%.3f", $d);

            if ( !defined( $passage{$longitude_latitude_place} ) ) {                    # are we currently passing close to this place (are we 'in passage')?
                #print "$longitude_latitude_place is not in passage\n";
                if ( $d < $arrive_threshold ) {    # so should be in passage
                    #print "$k ARRIVING: $longitude_latitude_place at $gpx_date_time - \n";
                    $passage{$longitude_latitude_place}           = $d;                 # record distance (from place-name)
                    $passage_metadata{$longitude_latitude_place}  = "$d\t$gpx_distance\t$gpx_date_time\t$gpx_longitude\t$gpx_latitude\t$gpx_elevation";      # 
                }
            } else {    # already in passage
                if ( $d < $passage{$longitude_latitude_place} ) {                       # is it closer than best previous closest?
                    $passage{$longitude_latitude_place}           = $d;                 # record distance (from place-name)
                    $passage_metadata{$longitude_latitude_place}  = "$d\t$gpx_distance\t$gpx_date_time\t$gpx_longitude\t$gpx_latitude\t$gpx_elevation";      # 
                }
                        # next bit needed as we might approach place more than once !!!!
                if ( $d > $depart_threshold  ) {                                        # exiting passage
                    #my $x = $passage{$longitude_latitude_place};
                    #my $meta = $passage_metadata{$longitude_latitude_place};
                    #print "$k LEAVING: $place_name: dist: $gpx_distance  \$d $d $longitude_latitude_place meta: $meta\n";
                    
                    ( $dd, $tmp_gpx_distance, $tmp_gpx_date_time, $tmp_gpx_longitude, $tmp_gpx_latitude, $tmp_gpx_elevation ) = split( "\t", $passage_metadata{$longitude_latitude_place} );
                    push @xxx_LoL, [    
                        $tmp_gpx_longitude,                 # ... longitude, and
                        $tmp_gpx_latitude,                  # ... latitude of point of closest approach !
                        $tmp_gpx_elevation,
                        $tmp_gpx_date_time,                 # ... time
                        99,                                 # ... segment
                        $tmp_gpx_distance,                  # ... distance (along GPX track)            
                        $place_name,                        # place name
                        $dd,                                # record distance (from place)
                        $place_longitude,                   # longitude of place 
                        $place_latitude                     # latitude of place
                    ];        
                    
                    delete $passage{$longitude_latitude_place};
                    delete $passage_metadata{$longitude_latitude_place};
                }
            }
        }      # for each place in glossary ....
    }      # go through each GPX point in track
        
    #---- deal with any left overs ----

    #print "################ LEFT OVERS #######################\n";
    
    foreach $longitude_latitude_place (keys %passage) {   
        print "PUSH: $longitude_latitude_place:\n";
        ( $place_longitude, $place_latitude, $place_name) = split( "\,", $longitude_latitude_place );
        ( $dd, $tmp_gpx_distance, $tmp_gpx_date_time, $tmp_gpx_longitude, $tmp_gpx_latitude, $tmp_gpx_elevation ) = split( "\t", $passage_metadata{$longitude_latitude_place} );
        push @xxx_LoL, [    
            $tmp_gpx_longitude,                 # ... longitude, and
            $tmp_gpx_latitude,                  # ... latitude of point of closest approach !
            $tmp_gpx_elevation,
            $tmp_gpx_date_time,                 # ... time
            99,                                 # ... segement
            $tmp_gpx_distance,                  # ... distance (along GPX track)            
            $place_name,                        # place name
            $dd,                                # record distance (from place)
            $place_longitude,                   # longitude of place 
            $place_latitude                     # latitude of place
        ];        
    }
    
    @xxx_global_LoL = sort { $a->[5] <=> $b->[5] } @xxx_LoL;    

    
    print "----- xxx brief summary ---------------\n";
    for $k ( 0 .. $#xxx_global_LoL ) {
        my $tmp_text = sprintf( "%s   %.1f   %s ", substr($xxx_global_LoL[$k][3],11) , $xxx_global_LoL[$k][5] , $xxx_global_LoL[$k][6] );
        print "$k:  $tmp_text\n";
    }
    
    return;
}    ##determine_route_text


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



############################################################################
#   haversine_distance - returns distance (km) between 
#   two longitude/latitude (degrees) points on the earth
############################################################################

sub haversine_distance ( ) {
    my ( $lon1, $lat1, $lon2, $lat2 ) = @_;
    
    my ( $d );
    my $pi = 3.14159;
    my $earth_radius = 6372.7976;        # mean earth radius (km)
    my $radian_ratio = $pi / 180.0;
    
    if ( $lat1 > 90.0 || $lat2 > 90.0 || $lat1 < -90.0 || $lat2 < -90.0 ||
        $lon1 > 360.0 || $lon2 > 360.0 || $lon1 < -360.0 || $lon2 < -360.0 ) {   # sanity check
        
        print "ERROR: haversine_distance: input out of range: $lon1, $lat1, $lon2, $lat2\n";
        $d = 0.0;        
        return ( $d ); 
    }
 
    $lat1 = $lat1 * $radian_ratio;
    $lon1 = $lon1 * $radian_ratio;
    $lat2 = $lat2 * $radian_ratio;
    $lon2 = $lon2 * $radian_ratio;

    my $a = sin(($lat2 - $lat1)/2.0);
    my $b = sin(($lon2 - $lon1)/2.0);
    my $h = ($a*$a) + cos($lat1) * cos($lat2) * ($b*$b);
    my $theta = 2 * asin(sqrt($h)); # distance in radians
    #print "theta = $theta radians \n";    
    my $d = $theta * $earth_radius;  # km
    return ( $d ); 
}        

############################################################################
#   approx_haversine_distance - returns distance (km) between 
#   two longitude/latitude (degrees) points on the earth
############################################################################

sub approx_haversine_distance ( ) {
    my ( $lon1, $lat1, $lon2, $lat2 ) = @_;
    my ( $R, $pi, $x, $y, $d);

    $R  = 6374.0;       # approx radius of earth in km
    $pi = 3.14159;

#---- convert to 'simple' polar stereographic projection centred on $lon1, $lat1

    $x = ( ($lon2 - $lon1) * $pi/180.0 ) * cos ( $lat1 * $pi / 180.0 ) * $R;
    $y = ( ($lat2 - $lat1) * $pi/180.0 ) * $R;
    
    $d = sqrt( $x**2 + $y**2 );
    return $d;
}



#------------------------------ end -----------------------------

