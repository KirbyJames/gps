#!/usr/bin/perlfstart_ceb
#
#
#=========================================================================
#       g_strip_map.pl
#=========================================================================
#
#   exploration of producing a strip map of a route defined by a GPX track.
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
use strict;
use Carp;

my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
my ( $n, $gpx_data, $usage, $minimun, $maximum, $n_output_files, $path_output_gpx_file,  $path_input_gpx_file,  $path_output_json_file );
my ( $gpx_header, $file_modification_date_time );
my ( $lat_lon_tag ,$elevation_tag , $name_tag , $symbol_tag );
my ( $elevation , $elevation_tag, $name, $name_tag, $symbol, $symbol_tag, $elevation_tag, $date_time_tag );
my ( $lat, $lon, $all );           
my ( $start_east_km, $end_east_km, $start_north_km, $end_north_km );
my ( $border_km );

my ( $k, $longitude_wgs84, $latitude_wgs84, $date_time, $distance, $altitude );
my ( $longitude_osgb36, $latitude_osgb36 );
my ( $east, $north, $string, $debug );
my ( $min_east, $max_east, $min_north, $max_north, $output_filename );
my ( $distance );
my ( $x1, $y1, $x2, $y2 , $angle, $result, $pi);
my ( $start_index, $end_index, $max_distance, $max_deviation, $in, $count, $min_away, $max_away );
my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north);


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
$n = @east;
$count = 0;
 
while ( $start_index < $n-1 ) {
     print "$count    ";
     ($end_index, $min_away, $max_away)  = determine_included_points ( $start_index, $max_distance, $max_deviation, \@east, \@north, \@distance );
     if ( $debug ) { print sprintf( "start_index: %d end_index: %d min departure: %.3f max departure: %.3f\n", $start_index, $end_index, $min_away, $max_away ); }
     #print "start: $start_index   end_index: $end_index\n";
     $angle = determine_angle ( @east[$start_index], @north[$start_index], @east[$end_index], @north[$end_index] );
     #--- angle is wrt west to east line with east = 0 degrees, north = 90 degrees, west = 180 degrees, south = 270 degrees
     
        
    $start_east_km  = @east[$start_index];
    $end_east_km    = @east[$end_index];
    
    $start_north_km = @north[$start_index];
    $end_north_km   = @north[$end_index];

    if ( $debug ) { print sprintf("track:: start: %.1f %.1f   end: %.1f %.1f  angle %.f degrees\n", $start_east_km, $start_north_km, $end_east_km, $end_north_km, $angle);  }
    
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
    my ( $red, $green, $blue, $black, $n_pts, $DPKM );
    my ( $x, $y, $r, $radius, $colour, $status );
    my ( $east1, $north1, $east2, $north2 );
    
 
    ####################################################################################
    #    draw track on map
    ####################################################################################

    open( PNG2, "<$map_only_filename" ) || die "unable to open $map_only_filename";
    $im = newFromPng GD::Image(\*PNG2) || die "unable to do newFromPng";
    close PNG2;

    my ($yellow, $orchid, $white, $thickness);
    
    $red    = $im->colorAllocate( 255, 128, 128 );
    $blue   = $im->colorAllocate( 128, 128, 255 );
    $green  = $im->colorAllocate( 128, 255, 128 );
    $black  = $im->colorAllocate( 0,   0,   0 );
    $yellow = $im->colorAllocate( 196, 196, 0 );
    $orchid = $im->colorAllocate( 218, 112, 240);
    $white  = $im->colorAllocate( 255, 255, 255);

   
    $n_pts = @east;
    $DPKM = 200;
    $thickness = 5;
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
            $im->line( $x1, $y1, $x2, $y2, $blue);  
        }
    }

    #---- plot first and last points as large circles ---- on non rotated map ----
    
    $x1 = $DPKM  * ($start_east_km - $map_min_east);    # start point coordinates
    $y1 = $DPKM  * ($map_max_north - $start_north_km);

    $x2 = $DPKM  * ($end_east_km - $map_min_east);      # end point coordinates
    $y2 = $DPKM  * ($map_max_north - $end_north_km);
    
    if ( $debug ) { print sprintf("\ntrack points:: first %.1f %.1f   last %.1f %.1f\n", $x1, $y1, $x2, $y2); }
    
    $radius = 60;
    for ( $r = 40 ; $r < $radius ; $r++ ) {
        $im->arc( $x1, $y1, $r, $r, 0, 360, $green );  # start point green = go
    }

    $radius = 60;
    for ( $r = 40 ; $r < $radius ; $r++ ) {
        $im->arc( $x2, $y2, $r, $r, 0, 360, $red );  # end point red = stop
    }

    $thickness = 10;
    $im->setThickness($thickness);
    if ( $debug ) {$im->line( $x1, $y1, $x2, $y2, $red); }  # line joining start and end points of this segment

    #---- calculate coordinates of centre line ---- symmetric w.r.t. deviations

    my ($delta);
    my ($min_centre_east, $min_centre_north, $max_centre_east, $max_centre_north);
    my ( $start_centre_east,  $start_centre_north, $end_centre_east, $end_centre_north );
    
    $delta = ( $max_away + $min_away) / 2.0; 
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
    
if ( 0 == 1 ) {    
#    if ( ($angle > 0.0 && $angle < 90.0)  ||  ($angle > 180.0 && $angle < 270.0)   ) {
#        $min_centre_east  = $min_east  + sin($angle*$pi/180.0) * $delta;
#        $max_centre_east  = $max_east  + sin($angle*$pi/180.0) * $delta;
#        $min_centre_north = $min_north - cos($angle*$pi/180.0) * $delta;
#        $max_centre_north = $max_north - cos($angle*$pi/180.0) * $delta;
#    } else {
#        $min_centre_east  = $min_east  + sin($angle*$pi/180.0) * $delta;
#        $max_centre_east  = $max_east  + sin($angle*$pi/180.0) * $delta;
#        $min_centre_north = $max_north - cos($angle*$pi/180.0) * $delta;
#        $max_centre_north = $min_north - cos($angle*$pi/180.0) * $delta;    
#    }
#
#    if ( $debug ) { 
#        print "------------------- centre line co-ordinates ---------------------\n";
#        print sprintf("min_centre_east/north: %.1f  %.1f\n",  $min_centre_east, $min_centre_north);
#        print sprintf("max_centre_east/north: %.1f  %.1f\n",  $max_centre_east, $max_centre_north);
#    }
}            
            
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
    
    $thickness = 20;
    $im->setThickness($thickness);

    if ( $debug ) {
        $im->line( $x1, $y1, $x2, $y2, $orchid );           
        $im->line( $x2, $y2, $x3, $y3, $orchid );           
        $im->line( $x3, $y3, $x4, $y4, $orchid );         
        $im->line( $x4, $y4, $x1, $y1, $orchid );
    
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 72, 0, $x1, $y1, "1" );  # label corners
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 72, 0, $x2, $y2, "2" ); 
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 72, 0, $x3, $y3, "3" ); 
        $im->stringFT( $black, "C:\\Windows\\fonts\\Arial.ttf", 72, 0, $x4, $y4, "4" ); 
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

    $image = Image::Magick->new;
    $im = $image->Read($map_plus_track_filename);
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "before rotation: width $width height $height\n"; }
    ##$im = $image->Resize(width=>"$THUMBNAIL_WIDTH", height=>"$THUMBNAIL_HEIGHT");
    $im = $image->Rotate(degrees=>"$angle", background=>"$background_color");  
    ($width, $height) = $image->Get('columns', 'rows');
    if ( $debug ) { print "after rotation: width $width height $height\n"; }

    $im = $image->Write($map_plus_track_rotated_filename);
    #undef $image;

   #---- now trim rotated image to final rectangular size ----
   
    my ($im_trim);
    
    open( PNG2, "<$map_plus_track_rotated_filename" ) || die "unable to open $map_plus_track_rotated_filename";
    $im = newFromPng GD::Image(\*PNG2) || die "unable to do newFromPng";
    close PNG2;

    my (  $final_filename );
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

    #--- ignore margin ---
    
#    $x = int($x);  # allow margin of 500 metres
#    $y = int($y);
    
#    $width = int(12.0*$DPKM);  # allow margin of 500 metres
#    $height = int(4.0*$DPKM);


    if ( $debug ) { print "copy instruction:  x: $x  y: $y  width: $width  height: $height\n"; }
    
    $final_filename = sprintf("strip_map_%3.3d.png", $count );
    
    $im_trim = new GD::Image( $width, $height );
    
 #   print "guess: \$im, 0, 0,   680, 1200, 2430, 830 );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object\n";
    
    $im_trim->copy( $im, 0, 0,  $x, $y, $width, $height );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object
    open( OUT, ">$final_filename" ) || croak("unable to open $final_filename");
    binmode OUT;
    $status = eval { print OUT $im_trim->png };
    close OUT;

    undef $im_trim;
    print "output in: $final_filename\n";
   
     print "----------------------------------------------------------------------------------------------------------------------\n";
    #print "-------------- DEBUG: exit -----------------\n";
    #exit;  

   
    
    undef $im;
    if ( !$debug ) {              # don't delete intermediate files if debugging
        `del $map_only_filename`;
        `del $map_plus_track_filename`;
        `del $map_plus_track_rotated_filename`;
    }
 

     $start_index = $end_index;
     $count++;
     
}
print "required $count segments\n";
    
    
#------------------------------------------------------------


exit;


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
sub determine_included_points {
##################################################################################
#   given arrays of x, y (easting, northing) points, determine the range of values which can be contained
#   in a rectangle of length $max_distance, and width $max_deviation
#
##################################################################################

    my ($start_index, $max_distance, $max_deviation, $ref_east, $ref_north, $ref_distance ) = @_;
    
    my ( $start_east, $start_north, $end_index, $east, $north, $e, $n, $deviation, $distance, $i, $index );
    my ( $min_away, $max_away, $away );
    
    
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
            
            if ( $deviation > $max_deviation ) {
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

