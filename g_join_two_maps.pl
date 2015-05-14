#!/usr/bin/perlfstart_ceb
#
#
#=========================================================================
#       g_join_two_maps.pl
#=========================================================================
#
#   join two 2800 x 1000 images
#
#                                    latitude (deg) of place-name
 
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

#my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
#my ( $n, $gpx_data, $usage, $minimun, $maximum, $n_output_files, $path_output_gpx_file,  $path_input_gpx_file,  $path_output_json_file );
#my ( $gpx_header, $file_modification_date_time );
#my ( $lat_lon_tag ,$elevation_tag , $name_tag , $symbol_tag );
#my ( $elevation , $elevation_tag, $name, $name_tag, $symbol, $symbol_tag, $elevation_tag, $date_time_tag );
#my ( $lat, $lon, $all );           
#my ( $start_east_km, $end_east_km, $start_north_km, $end_north_km );
#my ( $border_km );

#my ( $k, $longitude_wgs84, $latitude_wgs84, $date_time, $distance, $altitude );
#my ( $longitude_osgb36, $latitude_osgb36 );
#my ( $east, $north, $string, $debug );
#my ( $min_east, $max_east, $min_north, $max_north, $output_filename );
#my ( $distance );
#my ( $x1, $y1, $x2, $y2 , $angle, $result, $pi);
#my ( $start_index, $end_index, $max_distance, $max_deviation, $in, $count, $min_away, $max_away );
#my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north);


#my ( @longitude, @latitude, @elevation, @date_time, @east, @north, @distance, @segment );
#my ( @global_LoL, @gpx_LoL,  @place_loL, @xxx_global_LoL );
#my ( @glossary_files );


my ( $file1, $file2, $output_file );
my ( $im1, $im2, $im_out );
my ( $width, $height );
my ( $k, $status, $white );

for ( $k = 0 ; $k < 14 ; $k = $k + 2 ) {

    $file1 = sprintf("strip_map_%3.3d.png", $k );
    $file2 = sprintf("strip_map_%3.3d.png", $k+1 );
    $output_file = sprintf("strip_map_%3.3d_%3.3d.png", $k, $k+1 );
    print "$file1 plus $file2 = $output_file\n";
    
    
    open( PNG1, "<$file1" ) || die "unable to open $file1";
    $im1 = newFromPng GD::Image(\*PNG1) || die "unable to do newFromPng";
    close PNG1;

    open( PNG2, "<$file2" ) || die "unable to open $file2";
    $im2 = newFromPng GD::Image(\*PNG2) || die "unable to do newFromPng";
    close PNG2;

    $width = 2870;
    $height = 2 * 990 + 10;
     
    $im_out = new GD::Image( $width, $height );
    $white = $im_out->colorAllocate(255,255,255);
    $im_out->transparent($white);
    
   
    $im_out->copy( $im1, 0, 0,  0, 0, 2870, 990 );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object
    
    $im_out->copy( $im2, 0, 1000,  0, 0, 2870, 990 );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object
    
    open( OUT, ">$output_file" ) || croak("unable to open $output_file");
    binmode OUT;
    $status = eval { print OUT $im_out->png };
    close OUT;

    undef $im_out;
    print "output in: $output_file\n";
   
     print "----------------------------------------------------------------------------------------------------------------------\n";
     
}
    

exit;
    
#------------------------------------------------------------

