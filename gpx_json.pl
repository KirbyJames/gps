#!/usr/bin/perl
#
#
#=========================================================================
#       gpx_json.pl
#=========================================================================
#
#
#   reads a GPX track file (-i) 
#   and outputs (-o) a JSON format file
#
#   The GPX format file may contain multiple segments and multiple waypoints 
#
#   The JSON format file contains the track segments (as "LineString" Features), and
#   the waypoints as a series of "Point" Features).
#
#
#   e.g.
#       { "type": "Feature", 
#           "properties": { "name": "Greenham", "color": "#ff00ff" }, 
#           "geometry": { "type": "Point", "coordinates": [ -3.314186, 50.974127, 1.23 ] } 
#       },
#
#       { "type": "Feature", 
#           "properties": { "id": 1,  "name": "GPX track", "color": "#aa00aa" }, 
#           "geometry": { "type": "LineString", "coordinates": [
#               [ -3.395082, 50.848671, -26.8, "2015-02-10 09:21:42Z" ],
#               [ -3.395064, 50.848664, -26.8, "2015-02-10 09:21:45Z" ],
#               etc.
#
#
#{ "type": "FeatureCollection", "features": [
#
#{ "type": "Feature", "properties": { "name": "Carbis Bay", "color": "#ff00ff" }, "geometry": { "type": "Point", "coordinates": [ -5.466250, 50.194016, 1.23 ] } },
#{ "type": "Feature", "properties": { "name": "Zennor", "color": "#ff00ff" }, "geometry": { "type": "Point", "coordinates": [ -5.567550, 50.191526, 1.23 ] } },
#{ "type": "Feature", "properties": { "name": "St Ives", "color": "#ff00ff" }, "geometry": { "type": "Point", "coordinates": [ -5.480773, 50.211431, 1.23 ] } },
#{ "type": "Feature", "properties": { "name": "Carbis Bay", "color": "#ff00ff" }, "geometry": { "type": "Point", "coordinates": [ -5.466250, 50.194016, 1.23 ] } },
#{ "type": "Feature", "properties": { "name": "Summary", "color": "#008800" }, "geometry": { "type": "Point", "coordinates": [ -5.465628, 50.194378, 1.1 ] } },
#
#
#{ "type": "Feature", "properties": { "id": 1,  "name": "GPX track", "color": "#aa00aa" }, "geometry": { "type": "LineString", "coordinates": [
# [ -5.466039, 50.194050, 91.9, "2015-04-03 20:36:13Z" ],
# [ -5.465638, 50.194346, 87.6, "2015-04-03 20:36:19Z" ],
# [ -5.465374, 50.194462, 87.6, "2015-04-03 20:36:22Z" ],
# [ -5.465204, 50.194722, 82.8, "2015-04-03 20:36:27Z" ],
# [ -5.465108, 50.194726, 82.8, "2015-04-03 20:36:28Z" ],
# [ -5.463688, 50.194522, 82.8, "2015-04-03 20:36:44Z" ],
# [ -5.463680, 50.194175, 85.2, "2015-04-03 20:36:49Z" ],
# [ -5.465996, 50.194082, 82.3, "2015-04-03 21:59:06Z" ],
# [ -5.465863, 50.194369, 78.5, "2015-04-03 21:59:11Z" ],
# [ -5.465646, 50.194459, 78.5, "2015-04-03 21:59:14Z" ],
# [ -5.465628, 50.194378, 78.5, "2015-04-03 21:59:15Z" ]
#
#] } } 
#
#] }
#

#
#   notes:
#   intermediate results are stored in Perl list-of-lists (LoL)
#
#           GPX                                         PLACE/PASSAGE
#           ===                                         =============
#
#   [0]     longitude (deg) of point                    longitude(deg) on track of point of closest approach
#   [1]     latitude (deg) of point                     latitude deg) on track of point of closest approach
#   [2]     elevation (m) of point                      elevation (m) on track of point of closest approach
#
#   [3]     date-time (yyyy-mm-dd hh:mm:ss) at point    date-time on track of point of closest approach
#   [4]     segment (integer)                           segment (integer) in which point of closest approach falls
#   [5]     distance (km) of point along GPX track      distance (km) along GPX track of point of closest approach
#
#   [6]     ---                                         place-name (test) - passed through or close to
#   [7]     ---                                         distance (km) of closest approach to place-name
#   [8]     ---                                         longitude (deg) of place-name 
#   [9]     ---                                         latitude (deg) of place-name
 

use utility;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);
use Math::Trig;
use strict;
use Carp;

my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
my ( $n, $gpx_data, $usage, $minimun, $maximum, $n_output_files, $path_output_gpx_file,  $path_input_gpx_file,  $path_output_json_file );
my ( $gpx_header, $file_modification_date_time );
my ( $lat_lon_tag ,$elevation_tag , $name_tag , $symbol_tag );
my ( $elevation , $elevation_tag, $name, $name_tag, $symbol, $symbol_tag, $elevation_tag, $date_time_tag );
my ( $lat, $lon, $all );           
my ( $n_wpts, $n_segs, $n_trkpts, $n_waypoints );

$n_segs = 0;             

my ( @longitude, @latitude, @elevation, @date_time, @distance, @segment );
my ( @global_LoL, @gpx_LoL,  @place_loL, @xxx_global_LoL );
my ( @glossary_files );

$| = 1;     # autoflush after every print ... so can see progress

$usage = <<USAGE_TEXT;

USAGE: gpx_json.pl
            -i <input_gpx_file>
            -o <output_json_file>
            
USAGE_TEXT


##################################################################################
#	get, and check, file names from command line
##################################################################################

my $input_gpx_file      = '';
my $output_json_file    = '';

GetOptions ("i=s" => \$input_gpx_file,   "o=s" => \$output_json_file  );  


if ( length($input_gpx_file) < 1 ){
    print "ERROR: input_gpx_file not specified\n";
    print $usage;
    exit;
}

if ( length($output_json_file) < 1 ){                         #--- check we've got an output file
    print "ERROR: output_json_file not specified\n";
    print $usage;
    exit;
}

if ( !exists_and_is_non_zero_size($input_gpx_file) ) {        #----    check that input file does exist
    print "\nFATAL: input file $input_gpx_file doesn't exist\n";
    print $usage;
    exit;
}
    
if ( exists_and_is_non_zero_size($output_json_file) ) {        #---- check that the requested JSON output file (if it exists) is not the input file
    $path_output_json_file = File::Spec->canonpath( abs_path($output_json_file) );  # use cannonical path to resolve \ and / issues
    $path_input_gpx_file = File::Spec->canonpath( abs_path($input_gpx_file) );
    
    if ( $path_input_gpx_file eq $path_output_json_file ) {
        print "\nFATAL: input and output files are identical:  $path_input_gpx_file\n";
        print $usage;
        exit;
    }
}

#################################################################################
# 	read input GPX file and count waypoints and segments
#################################################################################

$gpx_data = read_file( $input_gpx_file );

$n_wpts = 0;             
while ( $gpx_data =~ m!<wpt.*?</wpt>!gs) {     # count segments
    $n_wpts++;
}

$n_segs = 0;             
while ( $gpx_data =~ m!<trkseg>.*?</trkseg>!gs) {     # count segments
    $n_segs++;
}

$n_trkpts = 0;             
while ( $gpx_data =~ m!<trkpt.*?</trkpt>!gs) {     # count segments
    $n_trkpts++;
}

print "   number of waypoints: $n_wpts\n";
print "    number of segments: $n_segs\n";
print "number of track points: $n_trkpts\n";

if ( ( $n_segs == 0 || $n_trkpts == 0 ) &&  $n_wpts == 0 ) {
    print "FATAL: input file $input_gpx_file doesn't contain any waypoints or segments\n";
    exit;
}


#################################################################################
#   open output JSON file
#################################################################################

open( JSON, ">$output_json_file" ) || die("unable to open $output_json_file");
print JSON "{ \"type\": \"FeatureCollection\", \"features\": [\n\n"; 

#################################################################################
#   work through waypoints in input file
#################################################################################

$n_waypoints = 0;
while ( $gpx_data =~ m!(<wpt.*?</wpt>)!sg ) {        # find each waypoint
    my $wpt_data = $1;
    chomp ( $wpt_data );
    
    # <wpt lat="51.71" lon="-4.04"><ele>1.23</ele><name>Old Place</name><sym>OSi Star</sym></wpt>
    
    $wpt_data =~ m!<ele>(.*?)</ele>!s;
    $elevation = $1;
    if ( $elevation ) {
        $elevation = sprintf("%.1f", $elevation );
    } else {
         $elevation = "0.0";
    }
    
    $wpt_data =~ m!<name>(.*?)</name>!s;
    $name = $1;
    if ( !$name ) {
         $name = "--blank--";
    }

    #  lat="47.011523" lon="4.842947">
        
    $wpt_data =~ m!\slat=\"(.*?)\"\slon=\"(.*?)\"\>!s;
    $lat = $1;
    $lon = $2;
    $lat = sprintf("%.6f", $lat );
    $lon = sprintf("%.6f", $lon );
                  
    print JSON "{ \"type\": \"Feature\", \"properties\": { ";
    print JSON "\"name\": \"$name\", \"color\": \"#ff00ff\" }, \"geometry\": { \"type\": \"Point\", \"coordinates\": ";
    $n_waypoints++;
    if ( $n_waypoints == $n_wpts ) {
        if ( $n_segs == 0 ) {
            print JSON "[ $lon, $lat, $elevation ] } }\n";
        } else {
            print JSON "[ $lon, $lat, $elevation ] } },\n\n";
        }
    } else {
        print JSON "[ $lon, $lat, $elevation ] } },\n";
    }
}  # find each waypoint

#################################################################################
#   work through segments in input file
#################################################################################

$gpx_data = read_file( $input_gpx_file );

my ( $longitude, $latitude, $elevation,  $date_time );
my ( $segment_data, $n_segment, $trk_pnt );


my $segment_color;
$n_segment = 0;
while ( $gpx_data =~ m!<trkseg>(.*?)</trkseg>!sg ) {        # find each segment

    $segment_color = "#000000";
    if ( $n_segment % 3 == 0 ) { $segment_color = "#ffff00"; }
    if ( $n_segment % 3 == 1 ) { $segment_color = "#ff00ff"; }
    if ( $n_segment % 3 == 2 ) { $segment_color = "#00ffff"; }
    
#    if ( $n_segment == 0 && $n_waypoints > 0 ) {
#        print JSON ",";
#    }
    print JSON "{ \"type\": \"Feature\", \"properties\": { \"id\": $n_segment,  \"name\": \"GPX track\", \"color\": \"$segment_color\" }, \"geometry\": { \"type\": \"LineString\", \"coordinates\": [\n";  

    $segment_data = $1;
    #print " $n_segment";
    	        
    #----   in this segment work through all trkpts 
    my $trk_pnt_count = 0;    
    while ( $segment_data =~ m!(<trkpt.*?</trkpt>)!sg ) {       # find all data points within this segment

        $trk_pnt = $1;
        
        #  lat="47.011523" lon="4.842947">
        
        $trk_pnt =~ m!\slat=\"(.*?)\"\slon=\"(.*?)\"\>!s;
        $latitude = $1;
        $longitude = $2;
        $longitude = sprintf("%.6f", $longitude );
        $latitude = sprintf("%.6f", $latitude );
        #print "$lat $lon $all\n";
            
        $trk_pnt =~ m!<ele>(.*?)</ele>!s;
        $elevation = $1;
        if ( $elevation ) {
            $elevation = sprintf("%.1f", $elevation );
        } else {
            $elevation = "0.0";
        }
            
        $trk_pnt =~ m!<time>(.*?)</time>!s;
        $date_time = $1;
        if ( !$date_time ) {
            $date_time = "1980-01-01 00:00:00";
        }
 
        if ($trk_pnt_count == 0) {
            print JSON " [ $longitude, $latitude, $elevation, \"$date_time\" ]";
        } else {
            print JSON ",\n [ $longitude, $latitude, $elevation, \"$date_time\" ]";
        }
        $trk_pnt_count++;
    }   # each segment

    $n_segment++;
        
    if ( $n_segment == $n_segs ) {   # add comma if not last one
        print JSON  "\n]}}\n";
    } else {
        print JSON  "\n]}},\n\n";
    }
}

print JSON "\n] }\n\n";
close JSON;

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
    my ( $ref_gpx_LoL, $ref_glossary_files ) = @_;

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
#----   open and read all glossary files specified; format is "longitude,latitude,name" 
#----   find all places within min/max rectangle surrounding route and save them in $longitude_latitude_place_hash
##########################################################################
    
    
    $n_match_places = 0;

    for ( $k=0 ; $k < @$ref_glossary_files ; $k++ ) {
        $glossary_filename = @$ref_glossary_files[$k];
        #print "$k: $glossary_filename\n";
        
        open( PLACES, "<$glossary_filename" ) || die("unable to open $glossary_filename");

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
    }
    
    #print "FOUND: $n_match_places places within rectangle surrounding track\n";
        
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
        
        #if ( $k%1000 == 0 ) { print " $k "; }        
        foreach $longitude_latitude_place (keys %longitude_latitude_place_hash) {    # for each place in glossary ....
            #print "$longitude_latitude_place\n";
            ( $place_longitude, $place_latitude, $place_name) = split( "\,", $longitude_latitude_place );
  
            #print "PLACE: $place_longitude, $place_latitude, $place_name\n";
            if ( abs($gpx_longitude - $place_longitude) > 0.02 || abs($gpx_latitude - $place_latitude) > 0.02 ) {
                $d = 2.0;
            } else {
                $d = approx_haversine_distance ( $gpx_longitude, $gpx_latitude, $place_longitude, $place_latitude );
            }
            $d = sprintf("%.3f", $d);
            #$d = 99.0;

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
        #print "PUSH: $longitude_latitude_place:\n";
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

    
    #print "----- xxx brief summary ---------------\n";
    for $k ( 0 .. $#xxx_global_LoL ) {
        my $tmp_text = sprintf( "%s   %.1f   %s ", substr($xxx_global_LoL[$k][3],11) , $xxx_global_LoL[$k][5] , $xxx_global_LoL[$k][6] );
        #print "$k:  $tmp_text\n";
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

