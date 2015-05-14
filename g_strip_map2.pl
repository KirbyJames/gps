#!/usr/bin/perl
#
#
#=========================================================================
#       g_strip_map2.pl
#=========================================================================
#
#   exploration of producing a strip map of a route defined by a GPX track.
#
#    version 010 was used to produce first strip map for Cornwall - but only uses tracks aligned with long edge of paper
#    version 012 includes convex hull calculation to provide better fit
#
#
#   reads a GPX track file (-i) 
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
use gps_lib;
use os;
use datum;
use Getopt::Long;
use File::Spec;
use Image::Magick;
use Cwd qw(abs_path);
use Math::Trig;
use Data::Dumper;
use Math::ConvexHull qw/convex_hull/;
use strict;
use Carp;

my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
my ( $n, $gpx_data, $usage, $minimun, $maximum, $n_output_files, $path_output_gpx_file,  $path_input_gpx_file,  $path_output_json_file );
my ( $gpx_header, $file_modification_date_time );
my ( $lat_lon_tag ,$elevation_tag , $name_tag , $symbol_tag );
my ( $elevation , $elevation_tag, $name, $name_tag, $symbol, $symbol_tag, $elevation_tag, $date_time_tag );
my ( $lat, $lon, $all );           
my ( $start_east_km, $end_east_km, $start_north_km, $end_north_km );
my ( $border_km, $nok );
my ($delta);

my ( $k, $longitude_wgs84, $latitude_wgs84, $date_time, $distance, $altitude );
my ( $longitude_osgb36, $latitude_osgb36 );
my ( $east, $north, $string, $debug );
my ( $min_east, $max_east, $min_north, $max_north, $output_filename );
my ( $distance );
my ( $x1, $y1, $x2, $y2 , $angle, $result, $pi);
my ( $start_index, $end_index, $max_distance, $max_deviation, $in, $count, $min_away, $max_away );
my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north);
my ( $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );
my ( $a1, $a2, $a3, $a4 );


my ( @longitude, @latitude, @elevation, @date_time, @east, @north, @distance, @segment );
my ( @global_LoL, @gpx_LoL,  @place_loL, @xxx_global_LoL );
my ( @glossary_files );


$debug = 0;
$|     = 1;     # autoflush after every print ... so can see progress

$usage = <<USAGE_TEXT;

USAGE: g_strip_map.pl
            -i <input_gpx_file>
            -o <output_json_file>
            
USAGE_TEXT


$pi = 3.14159;



##################################################################################
#	get, and check, file names from command line
##################################################################################

my $input_gpx_file      = '';
#my @glossary_files      = ();

#GetOptions ("i=s" => \$input_gpx_file,   "o=s" => \$output_json_file,   "x=s" => \$output_gpx_file );  
GetOptions ("i=s" => \$input_gpx_file );  

if ( length($input_gpx_file) < 1 ){
    print "ERROR: input_gpx_file not specified\n";
    print $usage;
    exit;
}

#----    check that input file does exist

if ( !exists_and_is_non_zero_size($input_gpx_file) ) {
    print "\nFATAL: input file $input_gpx_file doesn't exist\n";
    print $usage;
    exit;
}
    
#################################################################################
# 	read and decode input GPX file 
#################################################################################

$gpx_data = read_file( $input_gpx_file );
( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($input_gpx_file);
$file_modification_date_time = localtime $mtime;
if ( $debug ) { print "file length = " . length($gpx_data) . " bytes\n"; }

decode_gpx_data( $gpx_data, \@gpx_LoL );

$n = $#gpx_LoL;
if ( $debug ) { print "number of GPX points: $n\n"; }

#################################################################################
# 	convert long/lat to OS NG eastings/northings
#################################################################################

for ( $k = 0 ; $k < $#gpx_LoL ; $k++ ) {
    $longitude_wgs84  = $gpx_LoL[$k][0];
    $latitude_wgs84  = $gpx_LoL[$k][1];
    $distance  = $gpx_LoL[$k][5];

    ($east, $north) = os::wgs84_to_os( $longitude_wgs84, $latitude_wgs84 );
    @east[$k] = $east;
    @north[$k] = $north;
    @distance[$k] = $distance;    
}

#############################################################################################
#   divide track into chunks each of which can be displayed on one page
#############################################################################################

$max_distance  = 12.0;  # km
$max_deviation =  4.0;   # km
$start_index    = 0;  # 200;
$end_index = 0;
$n = @east;
$count = 0;
 
while ( $start_index < $n-4 ) {  # to ensure finishes!!!
    print "---------------------------------- generating image number $count ----------------------------------\n";
    print "START LOOP: start_index: $start_index  end_index: $end_index      ";

     ($end_index, $min_away, $max_away)  = determine_included_points ( $start_index, $max_distance, $max_deviation, \@east, \@north, \@distance );
     if ( $debug ) { print sprintf( "start_index: %d end_index: %d min departure: %.3f max departure: %.3f\n", $start_index, $end_index, $min_away, $max_away ); }
     if ( $debug ) { print "after determine_included_points: start: $start_index   end_index: $end_index\n"; }
     $angle = determine_angle ( @east[$start_index], @north[$start_index], @east[$end_index], @north[$end_index] );
     #--- angle is wrt west to east line with east = 0 degrees, north = 90 degrees, west = 180 degrees, south = 270 degrees
     
     if ( $debug ) { print sprintf("end_index: %d  min_away: %.3f  max_away: %.3f  total_away %.3f  angle: %.1f\n", $end_index, $min_away, $max_away, ($max_away - $min_away), $angle );  }

    $start_east_km  = @east[$start_index];
    $end_east_km    = @east[$end_index];
    
    $start_north_km = @north[$start_index];
    $end_north_km   = @north[$end_index];


    $delta = ( $max_away + $min_away) / 2.0; 
    if ( $debug ) { print sprintf("\nmax_away: %.3f   min_away: %.3f   angle: %.1f  delta: %.3f\n",  $max_away , $min_away,  $angle , $delta ); }

    $start_centre_east  = $start_east_km  + sin($angle*$pi/180.0) * $delta ;
    $start_centre_north = $start_north_km - cos($angle*$pi/180.0) * $delta;
    $end_centre_east    = $end_east_km    + sin($angle*$pi/180.0) * $delta;
    $end_centre_north   = $end_north_km   - cos($angle*$pi/180.0) * $delta; 
     
      #($end_index, $min_away, $max_away)  =     calculate_convex_hull ( $start_index, $end_index, $max_distance, $max_deviation, \@east, \@north, \@distance );
  
    if ( $debug ) { print "Before convex_hull: start_index: $start_index  end_index: $end_index\n"; }
    
    $nok = 1;
    while ( $nok > 0 && $end_index < $n-1) {
          ( $nok, $a1, $a2, $a3, $a4  ) = calculate_convex_hull ( $start_index, $end_index, $max_distance, $max_deviation, \@east, \@north, \@distance );
          if ( $nok > 0 ) { 
              ( $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north ) = ( $a1, $a2, $a3, $a4 );
              $end_index++; 
          }
    }
    $end_index--;
    if ( $debug ) { 
        print "after convex hull: start: $start_index   end_index: $end_index\n";
        print sprintf("+++++++ start_centre: %.1f %.1f end_centre %.1f %.1f  ++++++++++++\n", $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );
    }
    
    #---- new ----
    $start_east_km  = $start_centre_east;
    $end_east_km    = $end_centre_east;
    
    $start_north_km = $start_centre_north;
    $end_north_km   = $end_centre_north;
    
     $angle = determine_angle ( $start_east_km, $start_north_km, $end_east_km, $end_north_km );
     if ( $debug ) { print sprintf("angle: %.1f\n", $angle ); }
    
    

    if ( $debug ) { print sprintf("track:: start: %.1f %.1f   end: %.1f %.1f  angle %.f degrees\n", $start_east_km, $start_north_km, $end_east_km, $end_north_km, $angle);  }
    
    #---- work out co-ordinates of a rectangle bigger than required area - to allow for rotation
    
    $min_east   = min( $start_east_km, $end_east_km );   # lowest and highest map edges
    $max_east   = max( $start_east_km, $end_east_km );
    $min_north  = min( $start_north_km, $end_north_km );
    $max_north  = max( $start_north_km, $end_north_km );

    $border_km = 5.0;

    $map_min_east  =  int($min_east  - $border_km);     # round to whole 1 x 1 km square
    $map_max_east  =  int($max_east  + $border_km);
    $map_min_north =  int($min_north - $border_km); 
    $map_max_north =  int($max_north + $border_km); 
     
    if ( $debug ) { 
        print "-------------  composite map dimensions (km) -------------\n";
        print sprintf("     exact:      \$min_east: %.3f      \$max_east: %.3f     \$min_north: %.3f      \$max_north: %.3f \n", $min_east, $max_east, $min_north, $max_north); 
        print sprintf("plus border: \$map_min_east: %.3f  \$map_max_east: %.3f \$map_min_north: %.3f  \$map_max_north: %.3f \n", $map_min_east, $map_max_east, $map_min_north, $map_max_north); 
    }
    
    ####################################################################################
    #    generate map covering required area
    ####################################################################################
    
    my $map_only_filename;
    $map_only_filename = sprintf("strip_map_%3.3d_map_only.png", $count );
    
    if ( $debug ) { print "................. generate composite map .................\n"; }
    #print "$output_filename\n";    
     
    gps_lib::generate_os_composite( 1000.0*$map_min_east, 1000.0*$map_max_east, 1000.0*$map_min_north, 1000.0*$map_max_north, $map_only_filename ) ;
    print "\n";
 
    my ( $input_filename, $im, $image, $width, $height );    
    my ( $red, $green, $blue, $black, $purple, $magenta, $n_pts, $DPKM );
    my ( $x, $y, $r, $radius, $colour, $status );
    my ( $east1, $north1, $east2, $north2 );
    
 
    ####################################################################################
    #    draw track on map
    ####################################################################################

    open( PNG2, "<$map_only_filename" ) || die "unable to open $map_only_filename";
    $im = newFromPng GD::Image(\*PNG2) || die "unable to do newFromPng";
    close PNG2;

    my ($yellow, $orchid, $white, $thickness, $darkblue);
    
    $red    = $im->colorAllocate( 255, 128, 128 );
    $blue   = $im->colorAllocate( 128, 128, 255 );
    $darkblue   = $im->colorAllocate(  64,  64, 128 );
    $green  = $im->colorAllocate( 128, 255, 128 );
    $black  = $im->colorAllocate( 0,   0,   0 );
    $yellow = $im->colorAllocate( 196, 196, 0 );
    $orchid = $im->colorAllocate( 218, 112, 240);
    $white  = $im->colorAllocate( 255, 255, 255);
    $purple = $im->colorAllocate( 128,   0, 128);
    $magenta= $im->colorAllocate( 255,   0, 255);

   
    $n_pts = @east;
    $DPKM = 200;
    $thickness = 35;  # 45;   # 7;    # 5;
    $im->setThickness($thickness);

    #---- plot track on map ---- map is not rotated at this stage ----
    
    for ( $k = 1 ; $k < $n_pts ; $k++ ) {
        $east1  = @east[$k];
        $north1 = @north[$k];
        $east2  = @east[$k-1];
        $north2 = @north[$k-1];
        $x1 = $DPKM  * ($east1 - $map_min_east);
        $y1 = $DPKM  * ($map_max_north - $north1);   # y is measured down from top of map
        $x2 = $DPKM  * ($east2 - $map_min_east);
        $y2 = $DPKM  * ($map_max_north - $north2);
        if ( $east1 > $map_min_east && $east1 < $map_max_east && $north1 > $map_min_north && $north1 < $map_max_north ){  # check it's on map!
            #$im->line( $x1, $y1, $x2, $y2, $blue);  # $blue
            plw( $x1, $y1, $x2, $y2, $thickness, $magenta, $im);
            plotFilledCircle( $x2, $y2, $thickness/2, $magenta, $im);  # to round off ends of line1
        }
    }

    #---- plot first and last points as large circles ---- on non rotated map ----
 
    #---- new ----    

    $x1 = $DPKM  * (@east[$start_index] - $map_min_east);    # start point coordinates
    $y1 = $DPKM  * ($map_max_north - @north[$start_index]);

    $x2 = $DPKM  * (@east[$end_index] - $map_min_east);      # end point coordinates
    $y2 = $DPKM  * ($map_max_north - @north[$end_index]);
    
    if ( $debug ) { print sprintf("track start/end: first %.1f %.1f   last %.1f %.1f\n", @east[$start_index], @north[$start_index], @east[$end_index], @north[$end_index]  ); }
    if ( $debug ) { print sprintf("track points:: first %.1f %.1f   last %.1f %.1f\n", $x1, $y1, $x2, $y2); }
    
    $thickness = 2;   # 7;    # 5;
    $im->setThickness($thickness);
 
    $radius = 90;
    for ( $r = 80 ; $r < $radius ; $r++ ) {
        $im->arc( $x1, $y1, $r, $r, 0, 360, $green );  # start point green = go
    }

    $radius = 90;
    for ( $r = 80 ; $r < $radius ; $r++ ) {
        $im->arc( $x2, $y2, $r, $r, 0, 360, $red );  # end point red = stop
    }

    $thickness = 8;
    $im->setThickness($thickness);
    if ( $debug ) {$im->line( $x1, $y1, $x2, $y2, $red); }  # line joining start and end points of this segment

    #---- calculate coordinates of centre line ---- symmetric w.r.t. deviations

    my ($min_centre_east, $min_centre_north, $max_centre_east, $max_centre_north);
    my ( $start_centre_east,  $start_centre_north, $end_centre_east, $end_centre_north );
    
    $delta = 0;
    if ( $debug ) { print sprintf("\nmax_away: %.3f   min_away: %.3f   angle: %.1f  delta: %.3f\n",  $max_away , $min_away,  $angle , $delta ); }

    $start_centre_east  = $start_east_km  + sin($angle*$pi/180.0) * $delta ;
    $start_centre_north = $start_north_km - cos($angle*$pi/180.0) * $delta;
    $end_centre_east    = $end_east_km    + sin($angle*$pi/180.0) * $delta;
    $end_centre_north   = $end_north_km   - cos($angle*$pi/180.0) * $delta;

    if ( $debug ) {
        print "------------------- centre line co-ordinates ---------------------\n";
        print sprintf("start_centre_east/north: %.1f  %.1f\n",  $start_centre_east, $start_centre_north);
        print sprintf("  end_centre_east/north: %.1f  %.1f\n",  $end_centre_east, $end_centre_north);
    }
#}            
            
    $x1 = $DPKM  * ($start_centre_east - $map_min_east);
    $y1 = $DPKM  * ($map_max_north - $start_centre_north);

    $x2 = $DPKM  * ($end_centre_east - $map_min_east);
    $y2 = $DPKM  * ($map_max_north - $end_centre_north);
          
    if ( $debug ) { $im->line( $x1, $y1, $x2, $y2, $green); }   #--- plot centreline of rectangle

    #---- calculate coordinates of rectangle bounding the track ---- on un-rotated map ----    
    
    my ($half_width);
    my ($east3, $east4, $north3, $north4, $x3, $x4, $y3, $y4);
    
    $half_width = $max_deviation / 2.0;
    
    my ($e1, $e2, $e3, $e4, $n1, $n2, $n3, $n4 );

    $e1  = $start_centre_east  + sin($angle*$pi/180.0) * $half_width ;
    $n1  = $start_centre_north - cos($angle*$pi/180.0) * $half_width ;
    
    $e2  = $start_centre_east  - sin($angle*$pi/180.0) *  $half_width;
    $n2  = $start_centre_north + cos($angle*$pi/180.0) *  $half_width;
        
    $e3  = $end_centre_east    - sin($angle*$pi/180.0) *  $half_width;
    $n3  = $end_centre_north   + cos($angle*$pi/180.0) *  $half_width;
    
    $e4  = $end_centre_east    + sin($angle*$pi/180.0) * $half_width;
    $n4  = $end_centre_north   - cos($angle*$pi/180.0) * $half_width;


    if ( $debug ) { 
        print "************** coordinates of corner of rectangle **************\n";
        print sprintf("east1/north1 %.1f   %.1f\n", $e1, $n1);
        print sprintf("east2/north2 %.1f   %.1f\n", $e2, $n2);
        print sprintf("east3/north3 %.1f   %.1f\n", $e3, $n3);
        print sprintf("east4/north4 %.1f   %.1f\n", $e4, $n4);
    }

    $x1 = int( $DPKM  * ($e1 - $map_min_east));
    $y1 = int( $DPKM  * ($map_max_north - $n1));

    $x2 = int( $DPKM  * ($e2 - $map_min_east));
    $y2 = int( $DPKM  * ($map_max_north - $n2));

    $x3 = int( $DPKM  * ($e3 - $map_min_east));
    $y3 = int( $DPKM  * ($map_max_north - $n3));

    $x4 = int( $DPKM  * ($e4 - $map_min_east));
    $y4 = int( $DPKM  * ($map_max_north - $n4));

    if ( $debug ) { print "(1) $x1 $y1   (2) $x2 $y2   (3) $x3 $y3   (4) $x4 $y4\n"; }
    
    #---- draw rectangle bounding the track --- on un-rotated map ----    
    
    $thickness = 8;
    $im->setThickness($thickness);

    if ( $debug ) {
        $im->line( $x1, $y1, $x2, $y2, $orchid );           
        $im->line( $x2, $y2, $x3, $y3, $orchid );           
        $im->line( $x3, $y3, $x4, $y4, $orchid );         
        $im->line( $x4, $y4, $x1, $y1, $orchid );
    
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 48, 0, $x1, $y1, "1" );  # label corners
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 48, 0, $x2, $y2, "2" ); 
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 48, 0, $x3, $y3, "3" ); 
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 48, 0, $x4, $y4, "4" ); 
    }
    
    my $map_plus_track_filename;
    $map_plus_track_filename = sprintf("strip_map_%3.3d_map_plus_track.png", $count );
    if ( $debug ) { print "$map_plus_track_filename\n";  }

    open( OUT, ">$map_plus_track_filename" ) || croak("unable to open $map_plus_track_filename");
    binmode OUT;
    $status = eval { print OUT $im->png };
    close OUT;

    undef $im;
 
    #---- rotate image ---- so track is horizontal ----

    my $map_plus_track_rotated_filename;
    #$input_filename = $output_filename;
    $map_plus_track_rotated_filename = sprintf("strip_map_%3.3d_map_plus_track_rotated.png", $count );
    
    my $background_color = "#d8f8ff";   # "#d1f4ff"; # "#d1eeee";  # "white";

    if ( $debug ) { print sprintf("angle: %.1f degrees\n", $angle ); }
    
    $image = Image::Magick->new;
    $im = $image->Read($map_plus_track_filename);
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "before rotation: width $width height $height\n"; }
    $im = $image->Rotate(degrees=>"$angle", background=>"$background_color");  
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "after rotation: width $width height $height\n"; }
    $im = $image->Write($map_plus_track_rotated_filename);


   #---- now trim rotated image to final rectangular size ----
   
    my ($im_trim);
    
    open( PNG2, "<$map_plus_track_rotated_filename" ) || die "unable to open $map_plus_track_rotated_filename";
    $im = newFromPng GD::Image(\*PNG2) || die "unable to do newFromPng";
    close PNG2;

    my (  $final_filename, $trimmed_filename );
    my ( $d_unrotated_east, $d_unrotated_north, $d_rotated_east, $d_rotated_north , $d_rotated_east_pixels, $d_rotated_north_pixels );    
    #my ($d);

        
    if ( $angle >= 0.0 && $angle < 90.0 ) {
        $x =  int($DPKM  * ( ($e2 - $map_min_east)*cos($angle*$pi/180.0) + ($n2 - $map_min_north)*sin($angle*$pi/180.0)));
        $y =  int($DPKM  * ( ($e2 - $map_min_east)*sin($angle*$pi/180.0) + ($map_max_north - $n2)*cos($angle*$pi/180.0)));
    } elsif ( $angle >= 90.0 && $angle < 180.0 ) {   
        $x =  int($DPKM  * (-($map_max_east - $e2)*cos($angle*$pi/180.0) + ($n2 - $map_min_north)*sin($angle*$pi/180.0)));
        $y =  int($DPKM  * ( ($e2 - $map_min_east)*sin($angle*$pi/180.0) - ($n2 - $map_min_north)*cos($angle*$pi/180.0)));
    } elsif ( $angle >= 180.0 && $angle < 270.0 ) {
        $x =  int($DPKM  * ( ($e2 - $map_max_east)*cos($angle*$pi/180.0) + ($n2 - $map_max_north)*sin($angle*$pi/180.0)));
        $y =  int($DPKM  * ( ($e2 - $map_max_east)*sin($angle*$pi/180.0) + ($map_min_north - $n2)*cos($angle*$pi/180.0)));
    } elsif ( $angle >= 270.0 && $angle < 360.0 ) {
        $x =  int($DPKM  * ( ($e2 - $map_min_east)*cos($angle*$pi/180.0) + ($n2 - $map_max_north)*sin($angle*$pi/180.0)));
        $y =  int($DPKM  * (-($map_max_east - $e2)*sin($angle*$pi/180.0) + ($map_max_north - $n2)*cos($angle*$pi/180.0)));
    } else {
        print "Error: angle = $angle\n";
        exit;
    }
        
    if ( $debug ) {
        my ( $cc, $ss );
        
        $cc = cos($angle*$pi/180.0);
        $ss = sin($angle*$pi/180.0);
        print sprintf("angle: %.1f  cos: %.5f   sin: %.5f \n", $angle, $cc, $ss);
        
        print sprintf("\$e2 - \$map_min_east   %.1f\n", $DPKM  * ($e2 - $map_min_east ));
        print sprintf("\$map_max_east - \$e2   %.1f\n", $DPKM  * ($map_max_east - $e2 ));
        print sprintf("\$n2 - \$map_min_north  %.1f\n", $DPKM  * ($n2 - $map_min_north ));
        print sprintf("\$map_max_north - \$n2  %.1f\n", $DPKM  * ($map_max_north - $n2 ));
    }    
        
        
        
        
    if ( $debug ) { print "\$x: $x  \$y: $y\n"; }
    
    #---- add margin and calculate width/height
   
    $x = int($x - (1.0 * $DPKM));           # allow margin of 1.0 km lengthways
    $y = int($y - (0.5 * $DPKM));           # allow margin of 0.5 km sideways
    
    $width = int((12.0 + 2.0)*$DPKM);       # allow margin of 1.0 km lengthways
    $height = int((4.0 + 1.0)*$DPKM);       # allow margin of 0.5 km sideways


    if ( $debug ) { print "copy instruction:  x: $x  y: $y  width: $width  height: $height\n"; }
    
    $final_filename = sprintf("strip_map_%3.3d.png", $count );
    
    $im_trim = new GD::Image( $width, $height );
 #   print "guess: \$im, 0, 0,   680, 1200, 2430, 830 );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object\n";    
    $im_trim->copy( $im, 0, 0,  $x, $y, $width, $height );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object
 
    $trimmed_filename = sprintf("strip_map_trimmed_%3.3d.png", $count );
  
      
    open( OUT, ">$trimmed_filename" ) || croak("unable to open $trimmed_filename");
    binmode OUT;
    $status = eval { print OUT $im_trim->png };
    close OUT;

    undef $im_trim;

    
    $final_filename = sprintf("strip_map_%3.3d.png", $count );

    $image = Image::Magick->new;
    $im = $image->Read($trimmed_filename);
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "before rotation: width $width height $height\n"; }
    
    if ( $angle > 90.0 && $angle < 270.0 ) { 
        $angle = 180.0;
        $image->Rotate(degrees=>"$angle", background=>"$background_color");  
        if ( $debug ) { print "rotating 180\n"; }
    }

    my $count_text = sprintf("%d", $count + 1 );    
    $x1 = 30;
    $y1 = 30;    
    $r  = 25;
    $image->Draw(fill=>'lightgrey', primitive=>'rectangle', points=>'10,10 70,70');
    $image->Annotate(font=>"C:\\Windows\\fonts\\Arial.ttf", pointsize=>40, fill=>'black', align=>'Center',text=>$count_text, x=>40, y=>55);
    
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "after rotation: width $width height $height\n"; }

    $im = $image->Write($final_filename);
    #undef $image;



    print "output in: $final_filename\n";
    
    
    undef $im;
    if ( !$debug ) {              # don't delete intermediate files if debugging
        `del $map_only_filename`;
        `del $map_plus_track_filename`;
        `del $map_plus_track_rotated_filename`;
        `del $trimmed_filename`;
        
  
    }
 
    if ( $debug ) { print "END LOOP: start_index: $start_index  end_index: $end_index\n"; }
    #if ( $count >= 1 ) { 
    #    print "EXIT: exit early for debuggig\n";
    #    exit; 
    #}

     $start_index = $end_index;
     $count++;

     
    #print "----------------------------------------------------------------------------------------------------------------------\n";
    #print "----------------------------------------------------------------------------------------------------------------------\n";
    #print "----------------------------------------------------------------------------------------------------------------------\n";

     
}
print "required $count segments\n";
    
    
#------------------------------------------------------------


exit;




############################################################################
sub round {
############################################################################
    my ( $float ) = @_;
    my $rounded = sprintf "%.0f", $float;
    
    return $rounded;
}

############################################################################
sub setPixelAA{
############################################################################
    my ($x, $y, $color, $im ) = @_;
    return setPixel( $x, $y, $color, $im );
}

############################################################################
sub setPixel{
############################################################################
    my ($x, $y, $color, $im ) = @_;
    $x = int($x);
    $y = int($y);
    
    if (  $x%2 != 0 || $y%2 != 0 ) { return; }
    
    $im->setPixel($x, $y, $color);
    return;
}

############################################################################
sub plotFilledCircle {
############################################################################
    my ($x0, $y0, $r, $color, $im) = @_;
    my ($dx, $dy, $rsquared);
    
    $x0 = int($x0);
    $y0 = int($y0);
    $r = int($r);
    $rsquared = $r * $r;
    
    for ( $dx = -$r ; $dx <= $r ; $dx++ ) {
        for ( $dy = -$r ; $dy <= $r ; $dy++ ) {
            if ( ($dx*$dx + $dy*$dy) <= $rsquared ) {
                setPixel($x0+$dx, $y0+$dy, $color, $im );    
            }
        }
    }
    return;
}
    

## http://members.chello.at/~easyfilter/bresenham.js
#function plotLineWidth(x0, y0, x1, y1, th)
#{                              /* plot an anti-aliased line of width th pixel */
#   var dx = Math.abs(x1-x0), sx = x0 < x1 ? 1 : -1; 
#   var dy = Math.abs(y1-y0), sy = y0 < y1 ? 1 : -1; 
#   var err, e2 = Math.sqrt(dx*dx+dy*dy);                            /* length */#

#   if (th <= 1 || e2 == 0) return plotLineAA(x0,y0, x1,y1);         /* assert */
#   dx *= 255/e2; dy *= 255/e2; th = 255*(th-1);               /* scale values */
#
#   if (dx < dy) {                                               /* steep line */
#      x1 = Math.round((e2+th/2)/dy);                          /* start offset */
#      err = x1*dy-th/2;                  /* shift error value to offset width */
#      for (x0 -= x1*sx; ; y0 += sy) {
#         setPixelAA(x1 = x0, y0, err);                  /* aliasing pre-pixel */
#         for (e2 = dy-err-th; e2+dy < 255; e2 += dy)  
#            setPixel(x1 += sx, y0);                      /* pixel on the line */
#         setPixelAA(x1+sx, y0, e2);                    /* aliasing post-pixel */
#         if (y0 == y1) break;
#         err += dx;                                                 /* y-step */
#         if (err > 255) { err -= dy; x0 += sx; }                    /* x-step */ 
#      }
#   } else {                                                      /* flat line */
#      y1 = Math.round((e2+th/2)/dx);                          /* start offset */
#      err = y1*dx-th/2;                  /* shift error value to offset width */
#      for (y0 -= y1*sy; ; x0 += sx) {
#         setPixelAA(x0, y1 = y0, err);                  /* aliasing pre-pixel */
#         for (e2 = dx-err-th; e2+dx < 255; e2 += dx) 
#            setPixel(x0, y1 += sy);                      /* pixel on the line */
#         setPixelAA(x0, y1+sy, e2);                    /* aliasing post-pixel */
#         if (x0 == x1) break;
#         err += dy;                                                 /* x-step */ 
#         if (err > 255) { err -= dx; y0 += sy; }                    /* y-step */
#      } 
#   }
#}

############################################################################
sub plw {
############################################################################
    my ( $x0, $y0, $x1, $y1, $th, $color, $im) = @_;

    
    my ( $dx, $dy, $e2, $ed, $err, $sx, $sy, $x2, $y2 );
                             ## /* plot an anti-aliased line of width th pixel */
    $x0 = int($x0);
    $y0 = int($y0);
    $x1 = int($x1);
    $y1 = int($y1);
    #print "plot line from [$x0, $y0] to [$x1, $y1] of width $th\n";
   
    $dx = (abs($x1-$x0));
    $sx = $x0 < $x1 ? 1 : -1; 
    $dy = (abs($y1-$y0));
    $sy = $y0 < $y1 ? 1 : -1; 
    $e2 = sqrt($dx*$dx+$dy*$dy);                          #  # /* length */

   if ($th <= 1 || $e2 == 0) {
       return plotLineAA($x0,$y0, $x1,$y1, $color, $im);         ## /* assert */   
   }
   $dx *= 255/$e2; 
   $dy *= 255/$e2; 
   $th = 255*($th-1);               # /* scale values */

   if ($dx < $dy) {                                               # /* steep line */
      $x1 = round(($e2+$th/2)/$dy);                          # /* start offset */
      $err = $x1*$dy-$th/2;                  # /* shift error value to offset width */
      for ($x0 -= $x1*$sx; ; $y0 += $sy) {
         setPixelAA($x1 = $x0, $y0, $color, $im);                  # /* aliasing pre-pixel */
         for ($e2 = $dy-$err-$th; $e2+$dy < 255; $e2 += $dy) { 
            setPixel($x1 += $sx, $y0, $color, $im);                      # /* pixel on the line */
         }
         setPixelAA($x1+$sx, $y0, $color, $im);                    # /* aliasing post-pixel */
         #print "y0: $y0 y1: $y1\n";
         if ($y0 == $y1) { last; }
         $err += $dx;                                                 # /* y-step */
         if ($err > 255) { $err -= $dy; $x0 += $sx; }                    # /* x-step */ 
      }
   } else {                                                      # /* flat line */
      $y1 = round(($e2+$th/2)/$dx);                          # /* start offset */
      $err = $y1*$dx-$th/2;                  # /* shift error value to offset width */
      for ($y0 -= $y1*$sy; ; $x0 += $sx) {
         setPixelAA($x0, $y1 = $y0, $color, $im);                  # /* aliasing pre-pixel */
         for ($e2 = $dx-$err-$th; $e2+$dx < 255; $e2 += $dx) {
            setPixel($x0, $y1 += $sy, $color, $im);                      # /* pixel on the line */
         }
         setPixelAA($x0, $y1+$sy, $color, $im);                    # /* aliasing post-pixel */
         #print "x0: $x0 x1: $x1\n";
         if ($x0 == $x1) { last; }
         $err += $dy;                                                 # /* x-step */ 
         if ($err > 255) { $err -= $dx; $y0 += $sy; }                    # /* y-step */
      } 
   }
}


############################################################################
sub plotLineAA{
############################################################################
    my ($x0,$y0, $x1,$y1, $color, $im) = @_;
    #print "plot simple line from $x0,$y0, $x1,$y1 \n";
    plotLine( $x0,$y0, $x1,$y1, $color, $im );
}

############################################################################
sub plotLine {
############################################################################
    my ($x0, $y0, $x1, $y1, $color, $im) =@_;
    my ($dx, $dy, $sx, $sy, $err, $e2);

   $x0 = int($x0);
   $y0 = int($y0);
   $x1 = int($x1);
   $y1 = int($y1);

   $dx =  abs($x1-$x0);
   $sx = $x0<$x1 ? 1 : -1;
   $dy = -abs($y1-$y0);
   $sy = $y0<$y1 ? 1 : -1;
   $err = $dx+$dy;
   $e2;                                   #/* error value e_xy */

   for (;;){                                                          #/* loop */
      #setPixel(x0,y0);
      $im->setPixel($x0, $y0, $color);
      if ($x0 == $x1 && $y0 == $y1) { last; }
      $e2 = 2*$err;
      if ($e2 >= $dy) { $err += $dy; $x0 += $sx; }                        #/* x step */
      if ($e2 <= $dx) { $err += $dx; $y0 += $sy; }                        #/* y step */
   }
}
 
############################################################################
############################################################################
############################################################################


##################################################################################
sub determine_angle {
##################################################################################
#   determine angle (in degrees) to the x axis of the direction x1, y1 to x2, y2
#   east is 0 degrees 
#   north east is +45 degrees
##################################################################################

    my ( $x1, $y1, $x2, $y2 ) = @_;
    my ( $dx, $dy, $pi, $x, $y, $angle );
    
    $pi = 3.14159;

    $dx = $x2 - $x1;
    $dy = $y2 - $y1;
    
    if ( $dx > 0 && $dy > 0 ) {  # 0 - 90
        $angle = atan($dy/$dx);
        
    } elsif ( $dx < 0 && $dy > 0 ){  #90 - 180
        $angle = $pi + atan($dy/$dx);
        
    } elsif ( $dx < 0 && $dy < 0 ){  # 180 - 270    
        $angle = atan($dy/$dx) + $pi;
        
    } elsif ( $dx > 0 && $dy < 0 ){  # 270 - 360
        $angle = 2*$pi- atan(-$dy/$dx);
    } else {
        print "divide by zero\n";
    }
    
    $angle = $angle * 180.0 / $pi;
    return $angle;
    
}


##################################################################################
sub calculate_convex_hull {
##################################################################################
#
##################################################################################

    my ( $start_index, $end_index, $max_distance, $max_deviation, $ref_east, $ref_north, $ref_distance ) = @_;
    my ( $east, $north, $index, $aref, $array_ref, $n, $k, $from, $along, $nok );
    my ( $min_from, $max_from, $min_along, $max_along, $k0, $k1, $k2, $e0, $e1, $e2, $n0, $n1, $n2, $j, $m );
    my ( $lengthwise, $e1_start, $n1_start, $e2_end, $n2_end, $hyp, $x2, $y2, $x3, $y3  );  
    my ( $save_min_along, $save_max_along, $save_min_from, $save_max_from, $delta );
    my ( $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );


    my ( @AoA );
    
    if ( $debug  && 1 == 0 ) { print "-------- calculate_convex_hull --------\n"; }
    if ( $debug  && 1 == 0 ) { print sprintf("start_index: %d  end_index %d  max_distance: %.3f  max_devation: %.3f\n", $start_index, $end_index, $max_distance, $max_deviation);   }
    
    for ( $index = $start_index ; $index < $end_index ; $index++ ) {
        #print "INDEX  $index ";
        $east  = $$ref_east[$index];
        $north = $$ref_north[$index];
        push @AoA, [ $east, $north ];
    }
    # my @sorted = sort { $a->[1] <=> $b->[1] } @AoA; # 

    #for my $aref ( @AoA ) {
    #    print "\t [ @$aref ],\n";
    #}
    $array_ref = convex_hull(\@AoA);
 
    #print "       Hull?: " . Dumper   $array_ref;
    #print "\n";
    
    $n = @$array_ref;
    
    
    for ( $k=0 ; $k < $n ; $k++ ) {
        $east  = $array_ref->[$k][0];
        $north = $array_ref->[$k][1];
        #if ( $debug ) { print sprintf("k: %d  \t%.3f \t%.3f\n", $k, $east, $north ); }
    }
    
    #---- now calculate width and length of convex hull relative to each side
    
    $nok = 0;
    for ( $k=0 ; $k < $n ; $k++ ) {
    
        $k1 = $k;
        $k2 = ($k1 + 1) % $n;
        
        $e1 = $array_ref->[$k1][0];     #--- co-ordinates of two adjacent points on outside of hull
        $n1 = $array_ref->[$k1][1];

        $e2 = $array_ref->[$k2][0];
        $n2 = $array_ref->[$k2][1];
        
        #print "k1/2 $k1 $k2  ";
        
        $max_along = -100;
        $min_along = +100;
        $max_from  = -100;
        $min_from   = +100;
    
        for ( $j=0 ; $j < $n ; $j++ ) {   
            $e0 = $array_ref->[$j][0];     #--- co-ordinate of successive points on hull - including two edge points above
            $n0 = $array_ref->[$j][1];

            $from  = -distance_of_point_from_line ( $e1, $n1, $e2, $n2, $e0, $n0 );  # minus because convex hull is traversed clockwise and points on right are negative
            $along = distance_of_point_along_line ( $e1, $n1, $e2, $n2, $e0, $n0 );
            #print sprintf("f %.1f ", $from );
            if ( $from > $max_from ) { $max_from = $from; }
            if ( $from < $min_from ) { $min_from = $from; }
            if ( $along > $max_along ) { $max_along = $along; }
            if ( $along < $min_along ) { $min_along = $along; }
        }
        #print sprintf(" %.1f %.1f %.1f %.1f ", $e1, $n1, $e2, $n2 ); 
        #print sprintf("\tfrom %.1f %.1f (%.1f) \talong %.1f %.1f (%.1f)\t", $min_from, $max_from, ($max_from-$min_from), $min_along, $max_along, ($max_along-$min_along));

        
        if ( ($max_distance > ($max_from-$min_from) &&  $max_deviation > ($max_along-$min_along)) ){    
            if ( $debug && 1 == 0 ) { 
                print "k1/2 $k1 $k2  ";
                print sprintf(" (1) %.1f %.1f (2) %.1f %.1f ", $e1, $n1, $e2, $n2 ); 
                print sprintf("\tfrom %.1f %.1f (%.1f) \talong %.1f %.1f (%.1f)\t", $min_from, $max_from, ($max_from-$min_from), $min_along, $max_along, ($max_along-$min_along));
                print sprintf( "*** IT FITS sideways   ***  %.1f %.1f %.3f\n", ($max_from-$min_from), ($max_along-$min_along), ($max_from-$min_from) + ($max_along-$min_along) );
            }
            $nok++;
            $lengthwise = 0;        # i.e. sideways
            $e1_start = $e1;  $n1_start = $n1;  $e2_end = $e2;  $n2_end = $n2;  
            $save_min_along = $min_along;  $save_max_along = $max_along;
            $save_min_from = $min_from;  $save_max_from = $max_from;
            if ( $debug && 1 == 0  ) {  print sprintf("save            start: %.1f %.1f  end: %.1f %.1f \n", $e1_start, $n1_start, $e2_end, $n2_end ); }
            
        } elsif ( ($max_deviation > ($max_from-$min_from) &&  $max_distance > ($max_along-$min_along)) ){    
            if ( $debug && 1 == 0  ) { 
                print "k1/2 $k1 $k2  ";
                print sprintf(" (1) %.1f %.1f (2) %.1f %.1f ", $e1, $n1, $e2, $n2 ); 
                print sprintf("\tfrom %.1f %.1f (%.1f) \talong %.1f %.1f (%.1f)\t", $min_from, $max_from, ($max_from-$min_from), $min_along, $max_along, ($max_along-$min_along));
                print sprintf( "*** IT FITS lengthwise ***  %.1f %.1f %.3f\n", ($max_from-$min_from), ($max_along-$min_along), ($max_from-$min_from) + ($max_along-$min_along) );
            }
            $nok++;
            $lengthwise = 1;
            $e1_start = $e1;  $n1_start = $n1;  $e2_end = $e2;  $n2_end = $n2;  
            $save_min_along = $min_along;  $save_max_along = $max_along;
            $save_min_from = $min_from;  $save_max_from = $max_from;
            if ( $debug && 1 == 0  ) {  print sprintf("save            start: %.1f %.1f  end: %.1f %.1f \n", $e1_start, $n1_start, $e2_end, $n2_end ); }

        } else {
            #print "too big";
            #print "\n";
        }
        #print "\n";    
        
    }
    if ( $nok == 0 ) { 
        if ( $debug ) { print "---- no fit this time ----\n"; }
    }
    
    #---- calculate edge along which convex hull lies - then centre points
    if ( $nok > 0  &&  $lengthwise) {
    
        if ( $debug && 1 == 0  ) { 
            print "\n";
            print "============================= LENGTHWISE =========================\n";
            print sprintf("lengthwise with  start: %.1f %.1f  end: %.1f %.1f \n", $e1_start, $n1_start, $e2_end, $n2_end );
            print sprintf("save_min_along: %.1f  save_max_from %.1f\n", $save_min_along, $save_max_from );
        }
        
    
        $hyp = sqrt(  ($e2_end - $e1_start)**2  +  ($n2_end - $n1_start)**2 );   #??????????????????????????????/
        
        $x2 = $e1_start + $save_min_along * ( $e2_end - $e1_start) / $hyp;
        $y2 = $n1_start + $save_min_along * ( $n2_end - $n1_start) / $hyp;
    
        $x3 = $x2       + $max_distance * ( $e2_end - $e1_start) / $hyp;
        $y3 = $y2       + $max_distance * ( $n2_end - $n1_start) / $hyp;
    
        if ( $debug  && 1 == 0 ) { print sprintf("corners: [2] %.1f %.1f  [3] %.1f %.1f hyp: %.3f\n", $x2, $y2, $x3, $y3, $hyp ); }
        
        #---- determine start and end centre points
        
        $angle = determine_angle ( $x3, $y3, $x2, $y2  );
        
        $delta = ($max_deviation)/2.0  - ($max_deviation - ($max_from-$min_from))/2.0;
        if ( $debug  && 1 == 0 ) { print sprintf("max_deviation/2: %.1f  delta: %.1f\n", $max_deviation/2.0, $delta); }

        $delta = ($save_max_from-$save_min_from)/2.0;
        if ( $debug  && 1 == 0 ) { print sprintf("max_deviation/2: %.1f  delta: %.1f\n", $max_deviation/2.0, $delta); }

        #$start_centre_east  = $x2  + sin($angle*$pi/180.0) * $max_deviation / 2.0;
        #$start_centre_north = $y2  - cos($angle*$pi/180.0) * $max_deviation / 2.0;
        #$end_centre_east    = $x3  + sin($angle*$pi/180.0) * $max_deviation / 2.0;
        #$end_centre_north   = $y3  - cos($angle*$pi/180.0) * $max_deviation / 2.0;

        $start_centre_east  = $x2  + sin($angle*$pi/180.0) * $delta;
        $start_centre_north = $y2  - cos($angle*$pi/180.0) * $delta;
        $end_centre_east    = $x3  + sin($angle*$pi/180.0) * $delta;
        $end_centre_north   = $y3  - cos($angle*$pi/180.0) * $delta;

          #print "X              angle: $angle\n";
          #print "X  start_centre_east: $start_centre_east\n";
          #print "X start_centre_north: $start_centre_north\n";
          #print "X    end_centre_east: $end_centre_east\n";
          #print "X   end_centre_north: $end_centre_north\n";

        if ( $debug  && 1 == 0 ) {     
            print sprintf("centre line: %.1f %.1f   %.1f %.1f\n", $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );
            print "============================= LENGTHWISE =========================\n";
        }

     }   



    #---- calculate edge along which convex hull lies - then centre points
    if ( $nok > 0  &&  !$lengthwise) {    # i.e. sideways
       
        if ( $debug  && 1 == 0 ) { 
            print "\n";
            print "============================= SIDEWAYS =========================\n";
            print sprintf("sideways  start: %.1f %.1f  end: %.1f %.1f \n", $e1_start, $n1_start, $e2_end, $n2_end );
            print sprintf("sidways  inputs: %.1f %.1f  end: %.1f %.1f \n", $e1_start, $n1_start, $e2_end, $n2_end );
            print sprintf("save_min_along: %.1f  save_max_along %.1f\n", $save_min_along, $save_max_along );
        }

        $angle = determine_angle ( $e1_start, $n1_start, $e2_end, $n2_end  );
        $hyp = sqrt(  ($e2_end - $e1_start)**2  +  ($n2_end - $n1_start)**2 );  

        if ( $debug  && 1 == 0 ) { 
            print sprintf("angle: %.1f  hyp: %.4f\n", $angle, $hyp);
            print sprintf("save_max_along: %.1f  save_min_along %.1f\n",  $save_max_along, $save_min_along );
        }
               
        $x2 = $e1_start + 0.5 * ($save_max_along + $save_min_along) * ( $e2_end - $e1_start) / $hyp;
        $y2 = $n1_start + 0.5 * ($save_max_along + $save_min_along) * ( $n2_end - $n1_start) / $hyp;
    
        if ( $debug  && 1 == 0 ) { print sprintf("centre point of side: %.1f %.1f\n", $x2, $y2 ); }
        
        
        #---- determine end centre points
        
        $angle = $angle + 90.0;
        if ( $angle > 360.0 ) { $angle = $angle - 360.0; }
        
        $delta = $max_distance;
        if ( $debug && 1 == 0  ) { print sprintf("************* max_distance: %.1f angle (rot): %.1f  delta: %.1f *********\n", $max_distance, $angle, $delta); }

        $start_centre_east  = $x2;
        $start_centre_north = $y2;
        $end_centre_east    = $x2  + cos($angle*$pi/180.0) * $delta;
        $end_centre_north   = $y2  + sin($angle*$pi/180.0) * $delta;   # + to -
        
        if ( $debug  && 1 == 0 ) { 
            print sprintf("cos(angle*pi/180.0) * delta: %.1f\n",   cos($angle*$pi/180.0) * $delta );
            print sprintf("sin(angle*pi/180.0) * delta: %.1f\n",   sin($angle*$pi/180.0) * $delta );
            print sprintf("centre line: %.1f %.1f   %.1f %.1f\n", $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );
            print "============================= SIDEWAYS =========================\n";
        }

        #print "EXIT: sideways being worked on\n";
        #exit;
    }   
 
    #print "SUB: start_centre_east: $start_centre_east\n";
   
    #print "EXIT: working here ----------------------\n";
    #exit;
    return( $nok, $start_centre_east, $start_centre_north, $end_centre_east, $end_centre_north );
}


##################################################################################
sub determine_included_points {
##################################################################################
#   given arrays of x, y (easting, northing) points, determine the range of values which can be contained
#   in a rectangle of length $max_distance, and width $max_deviation
#
##################################################################################

    my ($start_index, $max_distance, $max_deviation, $ref_east, $ref_north, $ref_distance ) = @_;
    
    my ( $start_east, $start_north, $end_index, $east, $north, $e, $n, $deviation, $distance, $i, $index );
    my ( $min_away, $max_away, $away );
    my ( $along, $deviation_along, $max_along, $min_along);
    
    
    $end_index =  @$ref_east;
    #print "start_index: $start_index   end_index: $end_index    max_distance: $max_distance    max_deviation $max_deviation\n";
        
    #print "east: " .$$ref_east[$start_index] . "\n";
    #print "north: " . $$ref_north[$start_index] . "\n";
    #print "distance: ". $$ref_distance[$start_index] . "\n";
    #print "length array = " . @$ref_east . "\n";
    #print "end_index: " . $end_index . "\n";
        
    my ($last_valid_min_away, $last_valid_max_away );
   
    $start_east  = $$ref_east[$start_index];
    $start_north = $$ref_north[$start_index];
    
    $last_valid_min_away = 0.0;
    $last_valid_max_away = 0.0;

    for ( $index = $start_index ; $index < $end_index ; $index++ ) {
        #print "INDEX  $index ";
        $min_away = 0.0;
        $max_away = 0.0;
        $min_along = 0.0;
        $max_along = 0.0;
     
        $east  = $$ref_east[$index];
        $north = $$ref_north[$index];
    
        $distance = sqrt(  ($start_east-$east)**2  + ($start_north-$north)**2 );
        if ( $distance > $max_distance  ) {
                print sprintf("INT: MAX DIST EXCEDED d: %.3f max_d %.3f\n", $distance, $max_distance );
                return ($index-1, $last_valid_min_away, $last_valid_max_away);
        }
        
        for ( $i = $start_index ; $i < $index ; $i++ ) {
        
            $e  = $$ref_east[$i];
            $n  = $$ref_north[$i];
            
            $away = distance_of_point_from_line ( $start_east, $start_north, $east, $north, $e, $n );
            if ( $away < $min_away ) { $min_away = $away; }
            if ( $away > $max_away ) { $max_away = $away; }
            $deviation = $max_away - $min_away;

            $along = distance_of_point_along_line ( $start_east, $start_north, $east, $north, $e, $n );
            if ( $along < $min_along ) { $min_along = $along; }
            if ( $along > $max_along ) { $max_along = $along; }
            $deviation_along = $max_along - $min_along;
            
            if ( $deviation_along > $max_deviation ) {
                print sprintf("INT: MAX DEVIATION EXCEEDED  d: %.3f max_d %.3f dev: %.3f max_dev: %.3f\n",  $distance, $max_distance, $deviation, $max_deviation );
                return ($index-1, $min_away, $max_away);
            }
        }
        $last_valid_max_away = $max_away;
        $last_valid_min_away = $min_away;
        #print sprintf( "INDEX: %d  d: %.3f  dev: %.3f\n",  $index , $distance, $deviation );
        
    }
    
    print sprintf("END: OF LOOP d: %.3f max_d %.3f dev: %.3f max_dev: %.3f\n", $distance, $max_distance, $deviation, $max_deviation );  
    return ($index-1, $min_away, $max_away);
}

##################################################################################
sub clockwise {
##################################################################################
    my ($x0, $y0, $x1, $y1, $x2, $y2 ) = @_;
    my $d;
    
    $d = ( $x2-$x0) * ($y1-$y0) - ($x1-$x0) * ($y2-$y0);
    
    if ($d > 0){
        return(1);
    } elsif ($d < 0) {
        return(-1);
    } else {
        return(0);
    }        
}

##################################################################################
sub distance_of_point_from_line {
#   given line between x1,y1 and x2,y2; determines how far point x0,y0 is from line
#   the sign of the answer indicates which side of line point is on
#   http://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Proofs
#   http://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Another_formula
##################################################################################
    my ( $x1, $y1, $x2, $y2, $x0, $y0 ) = @_;
    
    my ( $distance, $s );
    
    $s = sqrt( ($y2-$y1)**2 + ($x2-$x1)**2 );
    $distance = ( ($y2-$y1)*$x0 - ($x2-$x1)*$y0 + $x2*$y1 - $y2*$x1 ) / $s;
    #$distance = sprintf("%.4f", $distance);
    #print " $distance ";
    #$distance = abs( ($y2-$y1)*$x0 - ($x2-$x1)*$y0 + $x2*$y1 - $y2*$x1 ) / $s;
    #$distance = $distance * clockwise( $x1, $y1, $x2, $y2, $x0, $y0 );  # give it a sign depending on which side of line
    
    return $distance;    # sign indicates which side of line point lies
}    

##################################################################################
sub distance_of_point_along_line {
#   given line between x1,y1 and x2,y2; determines how far point x0,y0 is along line
#   starting from x1,y1; sign of answer indicates direction of point 
#   http://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Proofs
#   http://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Another_formula
##################################################################################
    my ( $x1, $y1, $x2, $y2, $x0, $y0 ) = @_;
    
    my ( $distance, $k, $m, $xp, $yp, $sign );

    #---- determine m and k in y = mx + k

    $m = ($y1-$y2)/($x1-$x2);
    $k = ($x1*$y2 - $y1*$x2) / ($x1-$x2);
    #print "m: $m  k: $k\n";    
    
    #---- determine point on line closest to x0, y0

    $xp = ($x0 + $m*$y0 - $m*$k) / ($m*$m + 1);
    $yp = $m*$xp + $k;
    #print "xp: $xp  yp: $yp\n";
    
    #---- distance from x1,y1
    
    $distance = sqrt( ($yp-$y1)**2 + ($xp-$x1)**2 );
    #print "distance: $distance\n";
    
    $sign = ($xp-$x1)/($x2-$x1);
    if ( $sign > 0 ) {
        $sign = +1;
    } else {
        $sign = -1;
    }
    $distance = $sign * $distance;    
    return $distance;    # sign indicates which direction closest point resides
}    

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
sub min
############################################################################
{
	my ($a, $b) = @_;
  
	if ( $a < $b ) {
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

#------------------------------ end -----------------------------

