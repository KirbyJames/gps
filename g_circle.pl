#!/usr/bin/perl
#
#

#    https://github.com/tingletech/moon-phase
#
#   http://stackoverflow.com/questions/18206361/svg-multiple-color-on-circle-stroke
#   http://jsfiddle.net/Weytu/
#


#=========================================================================
#       g_circle.pl
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
#   [2]     elevation (metres) of point                 elevation (metres) on track of point of closest approach
#
#   [3]     date-time (yyyy-mm-dd hh:mm:ss) at point    date-time on track of point of closest approach
#   [4]     segment (integer)                           segment (integer) in which point of closest approach falls
#   [5]     distance (km) of point along GPX track      distance (km) along GPX track of point of closest approach
#
#   [6]     ---                                         place-name (test) - passed through or close to
#   [7]     ---                                         distance (km) of closest approach to place-name
#   [8]     ---                                         longitude (deg) of place-name 
#   [9]     ---                                         latitude (deg) of place-name
#
#  

use     utility;
use     gps_lib;
use     os;
use     datum;
use     Getopt::Long;
use     File::Spec;
use     Image::Magick;
use     Cwd qw(abs_path);
use     Math::Trig;
use     Astro::MoonPhase;
use     Time::Local;
use     strict;
use     Carp;

my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
my ( $n, $gpx_data, $usage, $minimun, $maximum, $n_output_files, $path_output_gpx_file,  $path_input_gpx_file,  $path_output_json_file );
my ( $gpx_header, $file_modification_date_time );
my ( $lat_lon_tag ,$elevation_tag , $name_tag , $symbol_tag );
my ( $elevation , $elevation_tag, $name, $name_tag, $symbol, $symbol_tag, $elevation_tag, $date_time_tag );
my ( $lat, $lon, $all );           
my ( $start_east_km, $end_east_km, $start_north_km, $end_north_km );
my ( $border_km );
my ( $place, $x, $y, $radius, $fil_color, $color, $last_x, $last_y, $fill_colour, $font_size, $num_glossary_files );

my ( $k, $longitude_wgs84, $latitude_wgs84, $date_time, $distance, $altitude );
my ( $longitude_osgb36, $latitude_osgb36 );
my ( $east, $north, $string, $debug );
my ( $min_east, $max_east, $min_north, $max_north, $output_filename );
my ( $distance, $icon_radius );
my ( $x1, $y1, $x2, $y2 , $x3, $y3, $angle, $r1, $r2, $r3, $result, $pi);
my ( $start_index, $end_index, $max_distance, $max_deviation, $in, $count, $min_away, $max_away );
my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north);
my ( $place_name, $longitude, $latitude, $place_longitude_latitude_elevation, $text_angle );

my ( $output_file, $image_height, $y_height_pixels, $background_sky_colour, $x_offset, $y_offset, $width, $height, $fill_color);
my ( $x_width_pixels, $y_high );
my ( $highest_peak_height, $max_altitude, $y_low, $font_color  );
my ( $x_centre, $y_centre, $total_distance, $max_elevation, $text_example );
my ( $graphic_radius, $min_elevation_radius, $max_elevation_radius, $svg_gradient_profile, $min_text_radius, $max_text_radius );

my ( %distance_altitude, %place_distance, %principal_locations  );
my ( @principal_locations );

my ( @longitude, @latitude, @elevation, @date_time, @east, @north, @distance, @segment );
my ( @global_LoL, @gpx_LoL,  @place_loL, @xxx_global_LoL );
my ( @glossary_files );
my ( %place_longitude_latitude_elevation );


$debug = 0;
$|     = 1;     # autoflush after every print ... so can see progress

$usage = <<USAGE_TEXT;

USAGE: g_cicle.pl
            -i <input_gpx_file>
            -o <output_svg_file>
            -g <input_glossary_file_1> [<input_glossary_file_2> ...]
            
USAGE_TEXT


$pi = 3.14159;


##################################################################################
#	get, and check, file names from command line
##################################################################################

my $input_gpx_file      = '';
my $output_svg_file     = '';
my @glossary_files      = ();

#GetOptions ("i=s" => \$input_gpx_file,   "o=s" => \$output_json_file,   "x=s" => \$output_gpx_file );  
GetOptions ("i=s" => \$input_gpx_file,   "o=s" => \$output_svg_file,   "g=s{1,}"   => \@glossary_files   );  

my $num_glossary_files = @glossary_files;

if ( $num_glossary_files == 0 ) {
    print "ERROR: at least one glossary file must be specified\n";
    print $usage;
    exit;
}

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

if ( length($output_svg_file) < 1 ){
    print "ERROR: output_svg_file not specified\n";
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
print "number of GPX points: $n\n"; 

my $total_distance  = $gpx_LoL[$#gpx_LoL-1][5];
print"total distance = $total_distance km\n";

#################################################################################
# 	determine places passed through
#################################################################################

determine_route_text( \@gpx_LoL, \@glossary_files );    # result goes into @xxx_global_LoL for the moment
    
print "----- xxx brief summary ---------------\n";
$n = $#xxx_global_LoL;
print "number of places passed through = $n\n";
for $k ( 0 .. $#xxx_global_LoL ) {

    my $tmp_text;
    $longitude = sprintf("%.5f", $xxx_global_LoL[$k][0] );
    $latitude  = sprintf("%.5f", $xxx_global_LoL[$k][1] );
    $elevation = sprintf("%.1f", $xxx_global_LoL[$k][2] );
    $distance  = sprintf("%.3f", $xxx_global_LoL[$k][5] );
    $place_name = $xxx_global_LoL[$k][6];   


    $tmp_text  = sprintf( "%.5f,%.5f,%s", $longitude, $latitude, $place_name );   
    #print "$tmp_text\n";
    
    $place_longitude_latitude_elevation = $place_name . "\t" . $longitude . "\t" .  $latitude  . "\t" .  $elevation;
    $place_longitude_latitude_elevation{ $place_longitude_latitude_elevation } = $distance;
    
}
    
#   [0]     longitude (deg) of point                    longitude(deg) on track of point of closest approach
#   [1]     latitude (deg) of point                     latitude deg) on track of point of closest approach
#   [5]     distance (km) of point along GPX track      distance (km) along GPX track of point of closest approach
#   [6]     ---                                         place-name (test) - passed through or close to



##########################################################################
#	plot
##########################################################################


open(SVG, ">$output_svg_file") || die("unable to open $output_svg_file");

##########################################################################
#---- define major dimensions of diagram 
##########################################################################

$x_width_pixels         = 1700;
$y_height_pixels        = 1700;

$graphic_radius         =  800;

$min_elevation_radius   =  550;
$max_elevation_radius   =  700;

$min_text_radius        =  715;
$max_text_radius        =  800;

#---- calculate subsidiary ones ---

$x_centre = $x_width_pixels/2;
$y_centre = $y_height_pixels/2;


print SVG "<svg  xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n";
print SVG "   width=\"$x_width_pixels\" height=\"$y_height_pixels\">\n\n";

print SVG "\n<!-- ************ output produced by g_circle.pl ************ -->\n\n";
$background_sky_colour = "#ccccff";

##########################################################################
#   radial color elevation wash
##########################################################################

# figures represent the percentage of the distance between  $min_elevation_radius to $max_elevation_radius where stop points occur
# we need to convert them to the percentage of the distance between 0 (zero) and $max_elevation_radius

my ( @break_points );
my ( $num_break_poimts );


@break_points = (  
    0,  "#64C864",
    5,  "#A0C864",
    10, "#C8C878",
    20, "#C8C8B4",
    30, "#D2D2D2",
    40, "#E1E1E1",
    50, "#E6E6E6",
    60, "#EBEBEB",
    70, "#F0F0F0",
    80, "#F7F7F7",
    90, "#FFFFFF",
    100,"#FFFFFF"  );


$num_break_poimts = @break_points;
my $percentage; 

print SVG "\n<!-- **** radial colour altitude wash **** -->\n\n";
print SVG "<defs>\n    <radialGradient id=\"radial_gradient_profile3\">\n";

for ( $k = 0; $k < $num_break_poimts ; $k = $k + 2 ) {

    my $b  = $break_points[$k];
    my $c =  $break_points[$k+1];

    $percentage = 100.0 * ( $min_elevation_radius + ( $max_elevation_radius - $min_elevation_radius ) * $break_points[$k] / 100.0 ) / $max_elevation_radius;
    $percentage = sprintf("%.1f", $percentage );
    
    print "break $b   percentage: $percentage color: $c\n";
    print SVG "    <stop offset=\"$percentage%\"  style=\"stop-color: $c;\" />\n";
}

print SVG "</radialGradient>\n</defs>\n";

print SVG "<circle cx=\"$x_centre\" cy=\"$x_centre\" r=\"$max_elevation_radius\" fill=\"url(#radial_gradient_profile3)\"/>";




print SVG "\n<!-- ****** blank out centre of diagram - over-writing central altitude color wash ****** -->\n\n";
print SVG "<circle cx=\"$x_centre\" cy=\"$y_centre\" r=\"$min_elevation_radius\" fill=\"#99b\"/>\n";
print SVG "<circle cx=\"$x_centre\" cy=\"$y_centre\" r=\"$min_elevation_radius\" fill=\"#113\"/>\n";

$total_distance  = $gpx_LoL[$#gpx_LoL-1][5];
print"total distance = $total_distance km\n";    


##########################################################################
#---- calculate max elevation ----
##########################################################################
    
$n = $#gpx_LoL;
$max_distance = $gpx_LoL[$n-1][5] + 1.0;
$max_elevation = -99.9;

for $k ( 0 .. $#gpx_LoL ) {
    $elevation =  $gpx_LoL[$k][2];
    $distance  =  $gpx_LoL[$k][5];
    if ( $elevation > $max_elevation ) { $max_elevation = $elevation; }
}
print "max_distance  = $max_distance\n";
print "max_elevation = $max_elevation\n";

$max_elevation =   (int($max_elevation/50.0) + 1 ) * 50.0;
print "max_elevation (adjusted) = $max_elevation\n";

##########################################################################
#---- plot elevation profile
##########################################################################

print SVG "\n<!-- ****** elevation profile as a line ****** -->\n\n";

$last_x = -1;
$last_y = -1;

for $k ( 0 .. $#gpx_LoL ) {
    $elevation =  $gpx_LoL[$k][2];
    $distance  =  $gpx_LoL[$k][5];

    $angle = -360.0 * $distance / $max_distance;
    $radius = ($elevation/$max_elevation) * ($max_elevation_radius - $min_elevation_radius) + $min_elevation_radius;
    $x = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $radius);
    $y = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $radius);
    if ($last_x < 0) {
        $last_x = $x;
        $last_y = $y;
    }
    #if ( $k%200 == 0 ) {  print sprintf("k: %d  angle: %.1f  d: %.1f  el: %.1f radius: %.1f  x: %.1f  y: %.1f\n", $k, $angle, $distance, $elevation, $radius, $x, $y ); }
    
    $color = "#000"; 
    print SVG "<line x1=\"$last_x\" y1=\"$last_y\" x2=\"$x\" y2=\"$y\"  stroke-linecap=\"round\" style=\"stroke:$color; stroke-width: 2.5;\"\/>\n";  #  stroke-linecap="round"
    
    $last_x = $x;
    $last_y = $y;
    
}

print SVG "\n<!-- ****** add altitude scale ****** -->\n\n";

##########################################################################
#--- add elevation scale 
##########################################################################

for ( $elevation = 0 ; $elevation < $max_elevation + 50 ; $elevation = $elevation + 50  ) {

    $radius = ($elevation/$max_elevation) * ($max_elevation_radius - $min_elevation_radius) + $min_elevation_radius;
    $x = $x_centre;
    $y = $y_centre;
        
    $color = "#000"; 
    
    if ( $elevation%100 == 0 ){    
        print SVG "<circle cx=\"$x_centre\" cy=\"$y_centre\" r=\"$radius\" style=\"stroke:#00aaaa; stroke-dasharray: 1 1; stroke-width: 1.5; fill:none\"\/>\n";
    } else {
        print SVG "<circle cx=\"$x_centre\" cy=\"$y_centre\" r=\"$radius\" style=\"stroke:#00aaaa; stroke-dasharray: 1 3; stroke-width: 1.0; fill:none\"\/>\n";
    }
}

print SVG "\n<!-- ****** add altitude scale ****** -->\n\n";

##########################################################################
#--- add distance scale 
##########################################################################

for ( $distance = 0 ; $distance < $max_distance  ; $distance = $distance + 2  ) {

    $angle = -360.0 * $distance / $max_distance;

    $r1 = $min_elevation_radius;
    $x1 = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $r1);
    $y1 = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $r1);

    $r2 = $max_elevation_radius;
    $x2 = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $r2);
    $y2 = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $r2);
      
    if ( $distance%50 == 0 ){    
        print SVG "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" style=\"stroke:#00aaaa; stroke-dasharray: 2 1; stroke-width: 3.5;\"\/>\n";
    } elsif ( $distance%10 == 0 ){
        print SVG "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" style=\"stroke:#00aaaa; stroke-dasharray: 1 2; stroke-width: 2.0;\"\/>\n";
    } else {
        print SVG "<line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" style=\"stroke:#00aaaa; stroke-dasharray: 1 3; stroke-width: 1.0;\"\/>\n";
    }

    
    $angle = (-360.0 * $distance / $max_distance);  #  - 0.3;

    $r3 = $max_elevation_radius;   # -3
    $x3 = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $r3);
    $y3 = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $r3);
        
    $text_angle = 360.0 - $angle;
    $text_angle = $text_angle % 360.0;
    if ($text_angle < 180.0 ) { $text_angle = $text_angle + 180.0; }
    

    if ( $distance%10 == 0 ){    
        $font_size = 15;
    } else {
        $font_size = 1;  # 10
    }
    
    if ( $x3 < $x_centre ) {
        print SVG "<text x=\"$x3\" y=\"$y3\" transform=\"rotate($text_angle $x3,$y3)\" style=\"fill: #888; stroke: none; font-size: $font_size" . "px; text-anchor: start;   writing-mode: tb;\"> $distance<\/text>\n";
    } else {
        print SVG "<text x=\"$x3\" y=\"$y3\" transform=\"rotate($text_angle $x3,$y3)\" style=\"fill: #888; stroke: none; font-size: $font_size" . "px; text-anchor: end;   writing-mode: tb;\"> $distance<\/text>\n";
    }

    
    
}

##########################################################################
#----   add place names
##########################################################################

print SVG "\n<!-- ****** plot place names ****** -->\n\n";    

foreach $place_longitude_latitude_elevation ( sort keys %place_longitude_latitude_elevation ) {

    ( $place_name, $longitude, $latitude, $elevation ) = split "\t", $place_longitude_latitude_elevation;

    $distance = 0.1 + $place_longitude_latitude_elevation{ $place_longitude_latitude_elevation };
    $angle = sprintf("%.3f", -360.0 * $distance / $max_distance );
    $text_angle = 360.0 - $angle;
    $text_angle = $text_angle % 360.0;
    if ($text_angle < 180.0 ) { $text_angle = $text_angle + 180.0; }
    
    $radius = $min_text_radius;
    $x = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $radius);
    $y = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $radius);

    
    @principal_locations = (                                            # these are plotted with a larger font size
        "Carbis Bay", "Newquay", "Port Quin", "Bude", "Okehampton" );
    
    # convert array to a hash with the array elements as the hash keys and the values are simply 1
    %principal_locations = map {$_ => 1} @principal_locations;

    # check if the hash contains $place
    if (defined $principal_locations{$place_name}) {
        print "found $place_name  angle: $angle\n";
        $icon_radius = 12;
        $fill_color = "#ffaaaa";
        $font_size = 20;
        $font_color = "111";
    } else {
        $icon_radius = 8;
        $fill_color = "#ffff00";
        $font_size = 15;
        $font_color = "666";
    }


    #print "$distance km  \t$text_angle deg  \t$place_name\n";
   
    if ( $x < $x_centre ) {
        print SVG "<text x=\"$x\" y=\"$y\" transform=\"rotate($text_angle $x,$y)\" style=\"fill: #$font_color; stroke: none; font-size: $font_size" . "px; text-anchor: end;   writing-mode: tb;\">$place_name<\/text>\n";
    } else {
        print SVG "<text x=\"$x\" y=\"$y\" transform=\"rotate($text_angle $x,$y)\" style=\"fill: #$font_color; stroke: none; font-size: $font_size" . "px; text-anchor: start;   writing-mode: tb;\">$place_name<\/text>\n";
    }
    
    #---- plot place names outside

    $radius = $min_elevation_radius - 10;
    $x = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $radius);
    $y = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $radius);
    
    #print "$distance km  \t$text_angle deg  \t$place_name\n";

   #---- plot place names inside
   
    $font_color = "aaa";

    
    if ( $x < $x_centre ) {
        print SVG "<text x=\"$x\" y=\"$y\" transform=\"rotate($text_angle $x,$y)\" style=\"fill: #$font_color; stroke: none; font-size: $font_size" . "px; text-anchor: start;   writing-mode: tb;\">$place_name<\/text>\n";
    } else {
        print SVG "<text x=\"$x\" y=\"$y\" transform=\"rotate($text_angle $x,$y)\" style=\"fill: #$font_color; stroke: none; font-size: $font_size" . "px; text-anchor: end;   writing-mode: tb;\">$place_name<\/text>\n";
    }
       
    $radius = ($elevation/$max_elevation) * ($max_elevation_radius - $min_elevation_radius) + $min_elevation_radius;
    $x = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $radius);
    $y = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $radius);

    print SVG "<circle cx=\"$x\" cy=\"$y\" r=\"$icon_radius\" style=\"stroke:#000000; fill:$fill_color\"\/>\n";
    
}

my (  $pathName1, $pathName2, $pathName3, $pathName4, $centerX, $centerY, $radius, $startangleInDegrees, $endangleInDegrees, $def1, $def2, $def3, $def4, $font_name, $font_size, $text );


$font_name = "Verdana";
$font_size = 30;
$text = "Monday 1 December 2015";
$centerX = $x_centre;
$centerY = $y_centre;
$radius = 400;

$startangleInDegrees = 0.0;
$endangleInDegrees =   45.0;
$pathName1 = "newpath1";
$text = "Monday 1 December 2015";
$def1  = svg_write_text_on_circle ( $pathName1, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) ;
        
$startangleInDegrees =   90.0;
$endangleInDegrees   =  135.0;
$pathName2            = "newpath2";
$text                = "90 to 135 degrees";
$def2  = svg_write_text_on_circle ( $pathName2, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) ;
    
$startangleInDegrees =  180.0;
$endangleInDegrees   =  225.0;
$pathName3            = "newpath3";
$text                = "180 to 225 degrees";
$def3  = svg_write_text_on_circle ( $pathName3, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) ;
    
$startangleInDegrees =  270.0;
$endangleInDegrees   =  315.0;
$pathName4            = "newpath4";
$text                = "270 to 315 degrees";
$def4  = svg_write_text_on_circle ( $pathName4, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) ;
    
print "def1:\n$def1\n\n";    
print "def2:\n$def2\n\n";    
print "def3:\n$def3\n\n";    
print "def4:\n$def4\n\n";    

print SVG "$def1\n";    
print SVG "$def2\n";    
print SVG "$def3\n";    
print SVG "$def4\n";    


print SVG "<use xlink:href=\"#$pathName1\" fill=\"none\" stroke=\"green\"  />\n";



for ( $k = 0 ; $k < 360 ; $k = $k+10 ) {

    $radius = $max_text_radius;

    $startangleInDegrees =  $k;
    $endangleInDegrees   =  $k + 10;
    $pathName4           = sprintf("newpath%3.3d", $k);
    $text                = sprintf("%3.3d", $k);
    $def4  = svg_write_text_on_circle ( $pathName4, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) ;
    print SVG "$def4\n";
}

###################################################################
#   text on a curved path
###################################################################

$text_example = <<TEXT_EXAMPLE;
    
<defs>
  <path id="MyPath"
   d="M 100 200 
      C 200 100 300   0 400 100
      C 500 200 600 300 700 200
      C 800 100 900 100 900 100" />
</defs>

<use xlink:href="#MyPath" fill="none" stroke="green"  />

<text font-family="Verdana" font-size="42.5">
    <textPath xlink:href="#MyPath">We go up, then we go down, then up again</textPath>
</text>
    
    
    
TEXT_EXAMPLE

print SVG $text_example;


######################################################################
#  plot moons
#####################################################################

my ( $phase, $moon_radius, $svg_text );


for ( $angle = 0; $angle < 360 ; $angle = $angle + 20.0 ) {


    $radius = $min_elevation_radius - 100;
    $x = sprintf("%.3f", $x_centre + sin($angle*$pi/180.0) * $radius);
    $y = sprintf("%.3f", $y_centre + cos($angle*$pi/180.0) * $radius);

   $phase = $angle / 360;
   $moon_radius = 25;

   $svg_text = svg_moon( $x, $y, $moon_radius, $phase );
   print SVG "    $svg_text\n";
}



print SVG "<\/svg>\n\n";

close( SVG );

exit;



##########################################################################
#	svg_moon
##########################################################################

sub svg_moon {
    my ( $x, $y, $r, $phase ) = @_;
    my ( $mag, $svg, $d, $s1, $s2 );
    my ( $a, $b, $c );
        
    if ( $phase < 0.0 || $phase > 1.0 ) {  $phase = 0.0; }
    #print "phase: $phase\n";
    
    if ( $phase <= 0.25 ) {
        $s1 = 1;
        $s2 = 0;
        $mag = 20 - 20 * $phase * 4;
    } elsif ( $phase <= 0.50 ) { 
        $s1 = 0;
        $s2 = 0;
        $mag = 20 * ($phase - 0.25) * 4;
    } elsif ( $phase <= 0.75 ) {
        $s1 = 1;
        $s2 = 1;        
        $mag = 20 - 20 * ($phase - 0.50) * 4;
    } elsif ( $phase <= 1 ) {
        $s1 = 0;
        $s2 = 1;
        $mag = 20 * ($phase - 0.75) * 4;
    } else { 
        print "ERROR: phase: $phase\n";
        exit; 
    }
    
    $a = $y - $r;
    $b = 2*$r;
    $c = -$r*2;

    $svg = "<!-- moon centred at x,y: $x, $y radius: $r phase: $phase -->\n" .
            "<circle cx=\"$x\" cy=\"$y\" r=\"$r\" stroke=\"#888\" stroke-width=\"0.5\" fill=\"#110\" />" .  
            "<path d=\"M$x,$a a$mag,20 0 1,$s1 0,$b a20,20 0 1,$s2 0,$c\" fill=\"#ffe\" />"; 
           
    #print "svg: $svg\n";    
    
    return ( $svg );
}


##########################################################################
#	svg_write_text_on_circle
##########################################################################

sub svg_write_text_on_circle {

    my ( $pathName, $centerX, $centerY, $radius, $startangleInDegrees , $endangleInDegrees, $font_name, $font_size, $text ) = @_;
    my ( $startangleInRadians, $endangleInRadians, $x1, $y1, $x2, $y2, $def, $path, $svg_circle );

    $startangleInRadians = $startangleInDegrees * $pi / 180.0;
    $endangleInRadians = $endangleInDegrees * $pi / 180.0;
    
    $x1 = $centerX + $radius * cos($startangleInRadians);
    $y1 = $centerY + $radius * sin($startangleInRadians);
    
    $x2 = $centerX + $radius * cos($endangleInRadians);
    $y2 = $centerY + $radius * sin($endangleInRadians);
        
    $path = sprintf("M %.1f, %.1f A %.1f, %.1f 0 0,1 %.1f, %.1f", $x1, $y1, $radius, $radius, $x2, $y2);

    $def = "<defs><path id=\"$pathName\" d=\"$path\" /></defs>";
    
    $svg_circle =   "<!-- circle centre: $centerX, $centerY radius: $radius -->\n" . 
                    "$def\n" .
                    "<text font-family=\"$font_name\" font-size=\"$font_size\">" .
                    "<textPath xlink:href=\"#$pathName\">$text</textPath>" . 
                    "</text>\n";

    #print "$svg_circle\n\n";    
    return($svg_circle);
}    
    
##########################################################################
#	plot colour shaded altitude profile upwards - which will later be overwritten sky downwards
##########################################################################

my $svg_gradient_profile = q|

<defs>
  <radialGradient id="radial_gradient_profile">
    <stop offset="0%" style="stop-color: #64C864;" />
    <stop offset="5%" style="stop-color: #A0C864;" />
    <stop offset="10%" style="stop-color: #C8C878;" />
    <stop offset="20%" style="stop-color: #C8C8B4;" />
    <stop offset="30%" style="stop-color: #D2D2D2;" />
    <stop offset="40%" style="stop-color: #E1E1E1;" />
    <stop offset="50%" style="stop-color: #E6E6E6;" />
    <stop offset="60%" style="stop-color: #EBEBEB;" />
    <stop offset="70%" style="stop-color: #F0F0F0;" />
    <stop offset="80%" style="stop-color: #F7F7F7;" />
    <stop offset="90%" style="stop-color: #FFFFFF;" />
    <stop offset="100%" style="stop-color: #FFFFFF;" />
  </radialGradient>
</defs>


<!-- define gradient profile -->

<defs>
  <linearGradient id="gradient_profile">
    <stop offset="0%" style="stop-color: #64C864;" />
    <stop offset="5%" style="stop-color: #A0C864;" />
    <stop offset="10%" style="stop-color: #C8C878;" />
    <stop offset="20%" style="stop-color: #C8C8B4;" />
    <stop offset="30%" style="stop-color: #D2D2D2;" />
    <stop offset="40%" style="stop-color: #E1E1E1;" />
    <stop offset="50%" style="stop-color: #E6E6E6;" />
    <stop offset="60%" style="stop-color: #EBEBEB;" />
    <stop offset="70%" style="stop-color: #F0F0F0;" />
    <stop offset="80%" style="stop-color: #F7F7F7;" />
    <stop offset="90%" style="stop-color: #FFFFFF;" />
    <stop offset="100%" style="stop-color: #FFFFFF;" />
  </linearGradient>
</defs>

<linearGradient id="up" xlink:href="#gradient_profile"  x1="0%" y1="100%" x2="0%" y2="0%" />
    
|;     # end of ... $svg_gradient_profile

print SVG $svg_gradient_profile;

$x1 = $x_offset  + int( $x_width_pixels * 0.0 / $max_distance );
$y2 = $y_height_pixels - $y_offset - int( $y_height_pixels * 0.0 / $max_altitude );    
$x2 = $x_offset  + int( $x_width_pixels * $max_distance / $max_distance );
$y1 = $y_height_pixels - $y_offset - int( $y_height_pixels * $highest_peak_height / $max_altitude );
print "SVG: x1 $x1  y1 $y1  x2 $x2  y2  $y2\n";

$width  = $x2 - $x1;
$height =  $y2 - $y1;
print "SVG: width $width  height $height\n";

print SVG "\n<!-- plot altitude profile -->\n\n";    
print SVG "<rect x=\"$x1\" y=\"$y1\" width=\"$width\" height=\"$height\" style=\"fill: url(#up); stroke: white;\" />\n\n";

##########################################################################
#   plot the sky downwards to over-write the altitude profile
##########################################################################

$last_x = -1;
$last_y = -1;

print SVG "\n<!-- plot sky downwards -->\n\n";    

for ( my $d = 0.0 ; $d < $max_distance ; $d = $d + 0.5 ) {
    $distance = sprintf("%.1f", $d); 

    $altitude = $distance_altitude{$distance};
	
    $x = $x_offset  + int( $x_width_pixels * $distance / $max_distance );
    $y = $y_height_pixels - $y_offset - int( $y_height_pixels * $altitude / $max_altitude );
    
    if ($last_x > 0 ){

        $y_low = $y_height_pixels - $y_offset - int( $y_height_pixels * $altitude / $max_altitude );
        $y_high = $y_height_pixels - $y_offset - int( $y_height_pixels * $max_altitude / $max_altitude );

        $height = $y_low - $y_high;
        $width = $x - $last_x;
    
        print SVG "<rect x=\"$last_x\" y=\"$y_high\" height=\"$height\" width=\"$width\" style=\"stroke: $background_sky_colour; fill: $background_sky_colour\"/>\n";            
    }    
    
    $last_x = $x;
    $last_y = $y;
}

##########################################################################
#   plot the altitude profile as a line
##########################################################################

print SVG "\n<!-- plot route profile as line -->\n\n";    

$last_x = -1;
$last_y = -1;

for ( my $d = 0.0 ; $d < $max_distance ; $d = $d + 0.5 ) {
    $distance = sprintf("%.1f", $d); 

    $altitude = $distance_altitude{$distance};
    $altitude = $altitude + 0.0;
    #print "distance $distance \taltitude $altitude\n";
	
    $x = $x_offset  + int( $x_width_pixels * $distance / $max_distance );
    $y = $y_height_pixels - $y_offset - int( $y_height_pixels * $altitude / $max_altitude );
    
 #   print SVG "<circle cx=\"$x\" cy=\"$y\" r=\"1\" style=\"stroke:#00aaaa; fill:#00aaaa\"\/>\n";
    
    if ($last_x > 0 && $altitude > 0.0){
        $color = "#00aaaa";
        print SVG "<line x1=\"$last_x\" y1=\"$last_y\" x2=\"$x\" y2=\"$y\" style=\"stroke:$color; stroke-width: 4.5;\"\/>\n";
#        print "line $last_x $last_y $x $y\n";
    }
    
    $last_x = $x;
    $last_y = $y;
        
}

##########################################################################
#	plot place names
##########################################################################

print SVG "\n<!-- plot place names -->\n\n";    

foreach $place ( sort keys %place_distance ) {
	$distance = $place_distance{ $place };
    $altitude = $distance_altitude{$distance};
	$altitude = $altitude;
	
#    print sprintf("%6.1f %s\n", $distance, $place);

#    $x = $x_width_pixels - 50;
    $x = $x_offset  + int( $x_width_pixels * $distance / $max_distance );
    $y = $y_height_pixels - $y_offset - int( $y_height_pixels * $altitude / $max_altitude );
    $y1 = $y - 18;  # offset label a nudge
    
    $radius = 8;
    $fill_color = "#ffff00";
    $font_size = 15;
    
    @principal_locations = (                                            # these are plotted with a larger font size
        "Beaune", "Dijon", "Pesmes", "Besancon", "Arbois", "Nozeroy",
        "Malbuisson", "Sant-Maurice-Crillat", "Sante-Claude", "Bellegarde-sur-Valserine",
        "Chamberry", "Grenoble", "Pont-en-Royans", "Valence" );
    
    # convert array to a hash with the array elements as the hash keys and the values are simply 1
    %principal_locations = map {$_ => 1} @principal_locations;

    # check if the hash contains $place
    if (defined $principal_locations{$place}) {
        print "found $place\n";
        $radius = 12;
        $fill_color = "#ffaaaa";
        $font_size = 20;
    }
	
    print SVG "<text x=\"$x\" y=\"$y1\" style=\"fill: #444444; stroke: none; font-size: $font_size" . "px; text-anchor: end;   writing-mode: tb;\">$place<\/text>\n";
    print SVG "<circle cx=\"$x\" cy=\"$y\" r=\"$radius\" style=\"stroke:#000000; fill:$fill_color\"\/>\n";
    
}

##########################################################################
#	plot axes
##########################################################################


    
    
#------------------------------------------------------------


exit;



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
    
    print "EXACT:  longitude: $minimum_longitude, $maximum_longitude  latitude: $minimum_latitude, $maximum_latitude\n";
    
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
        print "$k: $glossary_filename\n";
        
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

