#
#   gps_lib.pm
#

#=========================================================================
#       package gps_lib
#=========================================================================

package gps_lib;

#use     Smart::Comments;
use     Image::Magick;
use     GD;
use     strict;
use     Carp;

$gps_lib::VERSION = 0.10;


#----------------------------------------------------------------------
#       gps_lib :: initialise
#----------------------------------------------------------------------

sub initialise {

    return;
}



############################################################################
sub generate_small_os_composite    # 12/02/2003 20:22
############################################################################
#
#       generates a composite at 1:200,000 scale
#
############################################################################
{
  my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north, $output_filename ) = @_;
  my ( $map_range_east, $map_range_north );
  my ( $filename,       $tmp, $im, $new_im, $new_image );
  my ( %details,        $height, $width, $index_filename, $base_directory, $detail_index_filename, $thumb_index_filename, $info_filename );
  my ( $image, $x,        $y,        $filename,         $dimensions );
  my ( $DPKM,  $OFFSET_X, $OFFSET_Y, $composite_size_x, $composite_size_y );
  my ( $x_offset, $y_offset );
  my ( $i,        $j );

     # print "generate_small_os_composite\n";
     # print "===========================\n";

  $DPKM = 25;    # dots per km

  $map_range_east  = $map_max_east - $map_min_east;     # units are metres
  $map_range_north = $map_max_north - $map_min_north;

  $composite_size_x = int(( $map_max_east - $map_min_east ) * $DPKM / 1000);     # units are
  $composite_size_y = int(( $map_max_north - $map_min_north ) * $DPKM / 1000);

    #  print "composite_size_x = $composite_size_x (pixels)\n";
    #  print "composite_size_y = $composite_size_y (pixels)\n";

    #  print "NEW   min/max/range east     $map_min_east  $map_max_east  $map_range_east (m)\n";
    #  print "NEW   min/max/range north    $map_min_north $map_max_north $map_range_north (m)\n";

  $new_image  = Image::Magick->new( size => '900x800' );
  $dimensions = "$composite_size_x" . "x" . "$composite_size_y";

  #    print "dimensions $dimensions\n";
  $new_image = Image::Magick->new( size => "$dimensions" );
  $new_image->ReadImage('xc:white');

  for ( $x = $map_min_east ; $x < $map_max_east ; $x = $x + 10000 ) {
   # print "*";
    for ( $y = $map_min_north ; $y < $map_max_north ; $y = $y + 10000 ) {

#      $i = int( ( $x + 1 ) / 1000 );
#      $j = int( ( $y + 1 ) / 1000 );
      $i = 10*int( ( $x + 1 ) / 10000 );        #---- must be multiple of 10 km
      $j = 10*int( ( $y + 1 ) / 10000 );
      $i = sprintf( "%3.3d", $i );
      $j = sprintf( "%3.3d", $j );

      $filename = sprintf( "\\map\\small\\map_%s_%s.gif", $i, $j );

      #     print " x $x  y $y  i $i  j $j  file $filename\n";
      # print "x $x y $y file $filename ";

      if ( ( -e $filename ) ) {

       #   print "$filename EXISTS ";

        $image = Image::Magick->new;
        $im    = $image->Read($filename);
        warn "$im" if "$im";
        ( $width, $height ) = $image->Get( 'columns', 'rows' );
        $x_offset = ( $x - $map_min_east ) * $DPKM / 1000;
        $y_offset = ( $map_max_north - 10000 - $y ) * $DPKM / 1000;

        #  print "\$x_offset $x_offset \$y_offset $y_offset (pixels)\n";
        #
        $new_im = $new_image->Composite( image => $image, compose => 'Over', x => "$x_offset", y => "$y_offset" );
        warn "$new_im" if "$new_im";
        undef $im;
        undef $image;
      } else {

        # print "$filename missing\n";
      }
    }
  }

  #    print "end of loops\n";

  warn "$new_im" if "$new_im";
  ( $width, $height ) = $new_image->Get( 'columns', 'rows' );

   #   print "---- NEW: width $width   height $height\n";

  $new_im = $new_image->Quantize( colors => 128 );
  warn "$new_im" if "$new_im";
  $new_im = $new_image->Write('png:' . $output_filename);
  warn "$new_im" if "$new_im";

#print "\$output_filename $output_filename\n";

  undef $new_im;
  undef $new_image;

}    ##generate_small_os_composite


############################################################################
sub generate_exact_small_os_composite    #12/02/2003 20:22
############################################################################
#
#       generates a composite over the area indicated in the input coordinates
#       the output composite is centred on the mean of the east and north input
#       coordinates
#       the base data is 250x250 pixel images representing 10x10 km map squares
#
#       input coordinates are in metres
#
############################################################################
{
  my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north, $output_filename ) = @_;
  my ( $map_range_east, $map_range_north );
  my ( $filename,       $tmp, $im, $new_im, $new_image );
  my ( %details,        $height, $width, $index_filename, $base_directory, $detail_index_filename, $thumb_index_filename, $info_filename );
  my ( $image, $x,        $y,        $filename,         $dimensions );
  my ( $DPKM,  $OFFSET_X, $OFFSET_Y, $composite_size_x, $composite_size_y );
  my ( $x_offset, $y_offset );
  my ( $i,        $j, $temp_filename );
  my ($red, $green, $blue, $black, $white);
  my ($r, $large_composite_min_east,  $large_composite_min_north, $map_centre_east, $map_centre_north, $large_composite_max_north);
  my ($map_width_pixels, $map_height_pixels, $start_east, $start_north, $status, $im_trim);


  $temp_filename        =  '___temp_small_rubbish_delete_me.png';
  $DPKM                 = 25;                                  # dots per km: 250 pixels = 10 km

  #------------------------------------------------------------------------
  #---- first generate a larger composite - big enough to cover area required ----
  #------------------------------------------------------------------------

#print "----------------------------------------------------------------------------------------------------------------------------\n";
 # print "\$map_min_east $map_min_east, \$map_max_east $map_max_east, \$map_min_north $map_min_north, \$map_max_north $map_max_north\n";

  generate_small_os_composite( $map_min_east, $map_max_east + 10000.0, $map_min_north, $map_max_north + 10000.0, $temp_filename );

  #------------------------------------------------------------------------
  #---- read in oversize composite ----
  #------------------------------------------------------------------------

#return;

  open( PNG, "<$temp_filename" ) || die "generate_exact_os_composite: unable to open $temp_filename";
  $im = newFromPng GD::Image(\*PNG) || die "generate_exact_os_composite: unable to do newFromPng";
  close (PNG);

  $red   = $im->colorAllocate( 196, 0,   0 );
  $blue  = $im->colorAllocate( 0,   0,   196 );
  $green = $im->colorAllocate( 0,   196, 0 );
  $black = $im->colorAllocate( 0,   0,   0 );

  #------------------------------------------------------------------------
  #------ draw red circle at centre
  #------------------------------------------------------------------------

  $large_composite_min_east  =          10000 * int( ( $map_min_east + 1 ) / 10000 );    # units are metres
  $large_composite_min_north =          10000 * int( ( $map_min_north + 1 ) / 10000 );
#  $large_composite_max_north =  10000 + 10000 * int( ( $map_max_north + 1 ) / 10000 );
  $large_composite_max_north =   $large_composite_min_north + ($map_max_north - $map_min_north);

 # print "\$large_composite_min_east $large_composite_min_east \$large_composite_min_north $large_composite_min_north\n";

  $map_centre_east  = ($map_max_east  + $map_min_east) / 2.0;   # units are metres
  $map_centre_north = ($map_max_north + $map_min_north) / 2.0;

 #print "map centre: \$map_centre_east $map_centre_east \$map_centre_north $map_centre_north\n";

  $x = int($DPKM * ($map_centre_east - $large_composite_min_east)/1000.0);      # units are pixels
  $y = int($DPKM * (10000.0 + $large_composite_max_north - $map_centre_north)/1000.0);

  #print "circle: \$x $x  \$y $y\n";
#---- add circle ----

  for ( $r = 240 ; $r < 244 ; $r++ ) {
    $im->arc( $x, $y, $r, $r, 0, 360, $red );
  }

#---- add cross ----

  $im->line( $x+5, $y+5, $x-5, $y-5, $red);
  $im->line( $x+4, $y+5, $x-6, $y-5, $red);
  $im->line( $x+5, $y-5, $x-5, $y+5, $red);
  $im->line( $x+4, $y-5, $x-6, $y+5, $red);


  #------------------------------------------------------------------------
  #------ trim and shift composite to size required
  #------------------------------------------------------------------------

#print "trim_composite\n";

  $map_width_pixels = ($map_max_east  - $map_min_east) * $DPKM / 1000.0;
  $map_height_pixels = ($map_max_north - $map_min_north) * $DPKM / 1000.0;

#print "\$map_width_pixels $map_width_pixels \$map_height_pixels $map_height_pixels\n";



  $start_east = int( $DPKM*0.001* (( $map_min_east + 1 ) % 10000) );              # units in pixels
  $start_north = (10.0 * $DPKM) - int( $DPKM*0.001* (( $map_min_north + 1 ) % 10000) );

#print "PIXELS: \$start_east $start_east \$start_north $start_north\n";

  #---- make new blank image of correct size ----

  $im_trim = new GD::Image( $map_width_pixels, $map_height_pixels );

  $im_trim->copy( $im, 0, 0, $start_east, $start_north, $map_width_pixels, $map_height_pixels );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object


  undef $im;

  ##open( OUT, ">$output_directory" . "small_map.png" ) || croak("unable to open small_map.png");

  open( OUT, ">$output_filename" ) || croak("unable to open $output_filename");
  binmode OUT;
  $status = eval { print OUT $im_trim->png };
  close OUT;

  #print "written $output_filename\n";

  undef $im_trim;

#print "DEBUG EXIT";
#exit;
  return;
}



############################################################################
sub generate_os_composite    #12/02/2003 20:22
############################################################################
#
#       generates composite at 1:50,000 scale
#
#       generates a composite over the area indicated in the input coordinates
#       the output composite contains an integral number of whole 1x1 km squares
#       in both the east and north directions
#       the base data is 200x200 pixel images representing 1x1 km map squares
#
#       input coordinates are in metres
#
############################################################################
{
  my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north, $output_filename ) = @_;
  my ( $map_range_east, $map_range_north );
  my ( $filename,       $tmp, $im, $new_im, $new_image );
  my ( %details,        $height, $width, $index_filename, $base_directory, $detail_index_filename, $thumb_index_filename, $info_filename );
  my ( $image, $x,        $y,        $filename,         $dimensions );
  my ( $DPKM,  $OFFSET_X, $OFFSET_Y, $composite_size_x, $composite_size_y );
  my ( $x_offset, $y_offset );
  my ( $i,        $j );

### enter_generate_os_composite

  $DPKM = 200;    # dots per km

  $map_range_east  = $map_max_east - $map_min_east;     # units are metres
  $map_range_north = $map_max_north - $map_min_north;

  $composite_size_x = ( $map_max_east - $map_min_east ) * $DPKM / 1000;     # units are pixels
  $composite_size_y = ( $map_max_north - $map_min_north ) * $DPKM / 1000;

 #     print "composite_size_x = $composite_size_x\n";
 #     print "composite_size_y = $composite_size_y\n";

      $map_range_east = $map_max_east - $map_min_east;
      $map_range_north = $map_max_north - $map_min_north;

 print "NEW   min/max/range east     $map_min_east  $map_max_east  $map_range_east\n";
 print "NEW   min/max/range north    $map_min_north $map_max_north $map_range_north\n";

 #     print "output filename = $output_filename\n";

  $new_image  = Image::Magick->new( size => '900x800' );
  $dimensions = "$composite_size_x" . "x" . "$composite_size_y";

  #    print "dimensions $dimensions\n";
  $new_image = Image::Magick->new( size => "$dimensions" );
  $new_image->ReadImage('xc:white');

  for ( $x = $map_min_east ; $x < $map_max_east ; $x = $x + 1000 ) {       ### Map [===|   ]     % done 
    print " $x";
    for ( $y = $map_min_north ; $y < $map_max_north ; $y = $y + 1000 ) {

      $i = int( ( $x + 1 ) / 1000 );
      $j = int( ( $y + 1 ) / 1000 );
      $i = sprintf( "%3.3d", $i );
      $j = sprintf( "%3.3d", $j );

      #$filename = sprintf( "\\map\\%s%s\\%s%s\\map_%s_%s.gif",  substr( $i, 0, 1 ), substr( $j, 0, 1 ), substr( $i, 1, 1 ), substr( $j, 1, 1 ), $i, $j );
      $filename = sprintf( "D:\\map\\%s%s\\%s%s\\map_%s_%s.gif",  substr( $i, 0, 1 ), substr( $j, 0, 1 ), substr( $i, 1, 1 ), substr( $j, 1, 1 ), $i, $j );

 #     print "$x  $y $i $j $filename\n";
 #     print "x $x y $y filename $filename ";

      if ( !( -e $filename ) ) {
          $filename = "D:\\map\\10\\32\\map_133_022.gif";  # a blank square
      }
 
 
        $image = Image::Magick->new;
        $im    = $image->Read($filename);
        warn "$im" if "$im";
        ( $width, $height ) = $image->Get( 'columns', 'rows' );
        $x_offset = ( $x - $map_min_east ) * $DPKM / 1000;
        $y_offset = ( $map_max_north - 1000 - $y ) * $DPKM / 1000;

        #     print "\$x_offset $x_offset  \$y_offset $y_offset\n";
        #
        $new_im = $new_image->Composite( image => $image, compose => 'Over', x => "$x_offset", y => "$y_offset" );
        warn "$new_im" if "$new_im";
        undef $im;
        undef $image;
 #     } else {

 #            print "missing\n";
#      }
      
      
    }
  }

  #    print "end of loops\n";
### End of loops


  warn "$new_im" if "$new_im";
  ( $width, $height ) = $new_image->Get( 'columns', 'rows' );

#  print "NEW: width $width   height $height\n";
### Quantise
  $new_im = $new_image->Quantize( colors => 128 );
### Write image file
  $new_im = $new_image->Write($output_filename);

#  print "\$new_im = $new_im\n";

  undef $new_im;
  undef $new_image;

### exit_generate_os_composite

}    ##generate_os_composite



############################################################################
sub generate_exact_os_composite    #12/02/2003 20:22
############################################################################
#
#       generates a composite over the area indicated in the input coordinates
#       the output composite is centred on the mean of the east and north input
#       coordinates
#       the base data is 200x200 pixel images representing 1x1 km map squares
#
#       input coordinates are in metres
#
############################################################################
{
  my ( $map_min_east, $map_max_east, $map_min_north, $map_max_north, $output_filename ) = @_;
  my ( $map_range_east, $map_range_north );
  my ( $filename,       $tmp, $im, $new_im, $new_image );
  my ( %details,        $height, $width, $index_filename, $base_directory, $detail_index_filename, $thumb_index_filename, $info_filename );
  my ( $image, $x,        $y,        $filename,         $dimensions );
  my ( $DPKM,  $OFFSET_X, $OFFSET_Y, $composite_size_x, $composite_size_y );
  my ( $x_offset, $y_offset );
  my ( $i,        $j, $temp_filename );
  my ($red, $green, $blue, $black, $white);
  my ($r, $large_composite_min_east,  $large_composite_min_north, $map_centre_east, $map_centre_north, $large_composite_max_north);
  my ($map_width_pixels, $map_height_pixels, $start_east, $start_north, $status, $im_trim);

### generate_exact_os_composite

  $temp_filename        =  '___temp_rubbish_delete_me.png';
  $DPKM                 = 200;                                  # dots per km

  #------------------------------------------------------------------------
  #---- first generate a larger composite - big enough to cover area required ----
  #------------------------------------------------------------------------

  generate_os_composite( $map_min_east, $map_max_east + 1000.0, $map_min_north, $map_max_north + 1000.0, $temp_filename );

  #------------------------------------------------------------------------
  #---- read in oversize composite ----
  #------------------------------------------------------------------------

  open( PNG, "<$temp_filename" ) || die "generate_exact_os_composite: unable to open $temp_filename";
  $im = newFromPng GD::Image(\*PNG) || die "generate_exact_os_composite: unable to do newFromPng";
  close (PNG);

  $red   = $im->colorAllocate( 196, 0,   0 );
  $blue  = $im->colorAllocate( 0,   0,   196 );
  $green = $im->colorAllocate( 0,   196, 0 );
  $black = $im->colorAllocate( 0,   0,   0 );

  #------------------------------------------------------------------------
  #------ draw red circle at centre
  #------------------------------------------------------------------------

  $large_composite_min_east  =  1000 * int( ( $map_min_east + 1 ) / 1000 );    # units are metres
  $large_composite_min_north =  1000 * int( ( $map_min_north + 1 ) / 1000 );
  $large_composite_max_north =  1000 + 1000 * int( ( $map_max_north + 1 ) / 1000 );

#  print "\$large_composite_min_east $large_composite_min_east \$large_composite_min_north $large_composite_min_north\n";

  $map_centre_east  = ($map_max_east  + $map_min_east) / 2.0;   # units are metres
  $map_centre_north = ($map_max_north + $map_min_north) / 2.0;

# print "map centre: \$map_centre_east $map_centre_east \$map_centre_north $map_centre_north\n";

  $x = int($DPKM * ($map_centre_east - $large_composite_min_east)/1000.0);      # units are pixels
  #$y = int($DPKM * ($map_centre_north - $large_composite_min_north)/1000.0);
  $y = int($DPKM * ($large_composite_max_north - $map_centre_north)/1000.0);

#  print "circle: \$x $x  \$y $y\n";
#---- add circle ----

  for ( $r = 240 ; $r < 244 ; $r++ ) {
    $im->arc( $x, $y, $r, $r, 0, 360, $red );
  }

#---- add cross ----

  $im->line( $x+5, $y+5, $x-5, $y-5, $red);
  $im->line( $x+4, $y+5, $x-6, $y-5, $red);
  $im->line( $x+5, $y-5, $x-5, $y+5, $red);
  $im->line( $x+4, $y-5, $x-6, $y+5, $red);


  #------------------------------------------------------------------------
  #------ trim compoiste to size required
  #------------------------------------------------------------------------

#print "trim_composite\n";

  $map_width_pixels = ($map_max_east  - $map_min_east) * $DPKM / 1000.0;
  $map_height_pixels = ($map_max_north - $map_min_north) * $DPKM / 1000.0;

#print "\$map_width_pixels $map_width_pixels \$map_height_pixels $map_height_pixels\n";



  $start_east = int( $DPKM*0.001* (( $map_min_east + 1 ) % 1000) );              # units in pixels
  $start_north = $DPKM - int( $DPKM*0.001* (( $map_min_north + 1 ) % 1000) );

#print "\$start_east $start_east \$start_north $start_north\n";

  #---- make new blank image of correct size ----

  $im_trim = new GD::Image( $map_width_pixels, $map_height_pixels );

  $im_trim->copy( $im, 0, 0, $start_east, $start_north, $map_width_pixels, $map_height_pixels );    ## copy(sourceImage, dstX, dstY, srcX, srcY, width, height) object


  undef $im;

  ##open( OUT, ">$output_directory" . "small_map.png" ) || croak("unable to open small_map.png");

  open( OUT, ">$output_filename" ) || croak("unable to open $output_filename");
  binmode OUT;
  $status = eval { print OUT $im_trim->png };
  close OUT;

  #print "written $output_filename\n";

  undef $im_trim;

  return;
}

#------------------------------ end -----------------------------

return 1;


