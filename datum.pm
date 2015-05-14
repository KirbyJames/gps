#
#   datum.pm
#

#=========================================================================
#       package datum
#
#       used for some common geodetic coordinate transformations
#       NOTE:
#               N +ive
#               S -ive
#               E +ive
#               W -ive
#
#
#=========================================================================

package datum;


use     Math::MatrixReal;
use     Math::Trig;
use     warnings;
use     strict;

$datum::VERSION = 0.10;


my ( $A_OSGB36, $B_OSGB36, $A_WGS84, $B_WGS84 );
my ($PI, $Tx, $Ty, $Tz, $s, $Rx, $Ry, $Rz);
my ($deg_to_radian, $radian_to_deg);



#----------------------------------------------------------------------
#       datum :: initialise
#----------------------------------------------------------------------

sub initialise {

    $PI = 3.141592654;

    $A_OSGB36 = 6377563.396;           # major semi axis in metres
    $B_OSGB36 = 6356256.910;           # minor semi axis in metres

    $A_WGS84 = 6378137.000;           # major semi axis in metres
    $B_WGS84 = 6356752.314;           # minor semi axis in metres

    $Tx = -446.448;             # metres
    $Ty =  125.157;             # metres
    $Tz = -542.060;             # metres
    $s  =   20.4895;            # ppm
    $Rx = -0.1502;              # sec of degree
    $Ry = -0.2470;              # sec of degree
    $Rz = -0.8421;              # sec of degree

        #---- convert to metres and radians ----

    $s = $s / 1000000.0;
    $Rx = ($Rx / 3600.0) * $PI/180.0;   # radians
    $Ry = ($Ry / 3600.0) * $PI/180.0;   # radians
    $Rz = ($Rz / 3600.0) * $PI/180.0;   # radians

    $deg_to_radian = ($PI/180.0);
    $radian_to_deg = (180.0/$PI);
}


############################################################################
sub osgb36_to_wgs84
#
#       inputs:  degree, degree, metres
#       outputs: degree, degree, metres
#
############################################################################
{

    my ($lon, $lat, $alt) = @_;   ## these should be called east and north!!!
    my ($x, $y, $z);
    my ($a, $m, $t, $sp1, $ma, $xyz);
    my ($mRx,  $mRy, $mRz);

    my (@wgs84);

    initialise();

    ($x, $y, $z) =  lon_lat_alt_to_xyz($lon, $lat, $alt, 'OSGB36');


    $a = Math::MatrixReal->new_from_string( "[ $x ] \n [ $y ] \n [ $z ]\n" );
#    print "matrix A\n";
#    print $a;

    $sp1 = $s + 1.0;

    $a = Math::MatrixReal->new_from_string( "[ $x ] \n [ $y ] \n [ $z ]\n" );


    $mRx = -$Rx;
    $mRy = -$Ry;
    $mRz = -$Rz;

# change the sign of everything

#print "\$sp1 $sp1\n";

    $Tx  = -$Tx;
    $Ty  = -$Ty;
    $Tz  = -$Tz;
    $sp1 =  2.0 - $sp1;
    $Rx  = -$Rx;
    $Ry  = -$Ry;
    $Rz  = -$Rz;
    $mRx = -$mRx;
    $mRy = -$mRy;
    $mRz = -$mRz;

#print "\$sp1 $sp1\n";



    $m = Math::MatrixReal->new_from_string(  "[  $sp1     $mRz     $Ry   ] \n  [  $Rz       $sp1    $mRx  ] \n  [  $mRy      $Rx    $sp1   ]\n" );

#    print "\nmatrix m\n";
#    print $m;




    $t = Math::MatrixReal->new_from_string(  "[ $Tx ] \n [ $Ty ] \n [ $Tz ] \n" );
#    print "\nmatrix t\n";
#    print $t;


    $ma = $m * $a;

#    print "\nmatrix ma\n";
#    print $ma;

    $xyz = $t + $ma;

#    print "\nmatrix xyz\n";
#    print $xyz;

    my ($rows, $cols) = dim $xyz;
#    print "\$rows $rows \$cols $cols\n";


    $x = element $xyz (1, 1);
    $y = element $xyz (2, 1);
    $z = element $xyz (3, 1);


#    print "  END: \$x $x, \$y $y, \$z $z\n";
    ($lon, $lat, $alt) =  xyz_to_lon_lat_alt($x, $y, $z, 'WGS84');

#    print "  END:\$lon $lon, \$lat $lat, \$alt $alt\n";

#print "DEBUG - reverse tesr\n";
#exit;


    @wgs84 = ($lon, $lat, $alt);
    return @wgs84;
}


############################################################################
sub wgs84_to_osgb36
#
#       inputs:  degree, degree, metres
#       outputs: degree, degree, metres
#
############################################################################
{

    my ($lon, $lat, $alt) = @_;
    my ($x, $y, $z);
    my ($a, $m, $t, $sp1, $ma, $xyz);
    my ($mRx,  $mRy, $mRz);

    my (@osgb36);

#    print "**** wgs84_to_osgb36 ****\n";

    initialise();

#    print "START: \$lon $lon, \$lat $lat, \$alt $alt\n";
    ($x, $y, $z) =  lon_lat_alt_to_xyz($lon, $lat, $alt, 'WGS84');
#    print "START: \$x $x, \$y $y, \$z $z\n";


# exit;
#    goto jump;


    $a = Math::MatrixReal->new_from_string( "[ $x ] \n [ $y ] \n [ $z ]\n" );
#    print "matrix A\n";
#    print $a;

    $sp1 = $s + 1.0;

    $a = Math::MatrixReal->new_from_string( "[ $x ] \n [ $y ] \n [ $z ]\n" );


    $mRx = -$Rx;
    $mRy = -$Ry;
    $mRz = -$Rz;

    $m = Math::MatrixReal->new_from_string(  "[  $sp1     $mRz     $Ry   ] \n  [  $Rz       $sp1    $mRx  ] \n  [  $mRy      $Rx    $sp1   ]\n" );

#    print "\nmatrix m\n";
#    print $m;




    $t = Math::MatrixReal->new_from_string(  "[ $Tx ] \n [ $Ty ] \n [ $Tz ] \n" );
#    print "\nmatrix t\n";
#    print $t;


    $ma = $m * $a;

#    print "\nmatrix ma\n";
#    print $ma;

    $xyz = $t + $ma;

#    print "\nmatrix xyz\n";
#    print $xyz;

    my ($rows, $cols) = dim $xyz;
#    print "\$rows $rows \$cols $cols\n";


    $x = element $xyz (1, 1);
    $y = element $xyz (2, 1);
    $z = element $xyz (3, 1);


#jump:

#    print "  END: \$x $x, \$y $y, \$z $z\n";
    ($lon, $lat, $alt) =  xyz_to_lon_lat_alt($x, $y, $z, 'OSGB36');

#    print "  END:\$lon $lon, \$lat $lat, \$alt $alt\n";

#print "DEBUG - reverse tesr\n";
#exit;


    @osgb36 = ($lon, $lat, $alt);
    return @osgb36;
}


############################################################################
sub lon_lat_alt_to_xyz
#
#       inputs:
#               longitude       degrees
#               latitude        degrees
#               altitude        metres
#               datum           'WGS84' or 'OSGB36'
#
#       outputs:
#               x               metres
#               y               metres
#               z               metres
#
############################################################################
{
    my ($lon, $lat, $alt, $datum) = @_;
    my ($x, $y, $z);
    my ($A, $B, $E2, $V);

    initialise();

    if ( $datum eq 'WGS84' ) {
        $A = $A_WGS84;
        $B = $B_WGS84;
    } elsif ( $datum eq 'OSGB36') {
        $A = $A_OSGB36;
        $B = $B_OSGB36;
    } else {
        die("invalid datum->$datum<-\n");
    }

    $E2 = ($A*$A - $B*$B) / ($A*$A);
    $V = $A / sqrt(1.0 - $E2 *  sin( $lat * $deg_to_radian ) * sin( $lat * $deg_to_radian ));
#    print "\$V = $V\n";


    $x = ($V + $alt) * cos( $lat * $deg_to_radian ) * cos( $lon * $deg_to_radian );
    $y = ($V + $alt) * cos( $lat * $deg_to_radian ) * sin( $lon * $deg_to_radian );
    $z = ((1.0-$E2)*$V + $alt) * sin( $lat * $deg_to_radian );

    return ( ($x, $y, $z) );
}


############################################################################
sub xyz_to_lon_lat_alt
#
#       inputs:
#               x               metres
#               y               metres
#               z               metres
#               datum           'WGS84' or 'OSGB36'
#
#       outputs:
#               longitude       degrees
#               latitude        degrees
#               altitude        metres
#
############################################################################
{
    my ($x, $y, $z, $datum) = @_;
    my ($lon, $lat, $alt);
    my ($radius, $i, $last_lat);
    my ($A, $B, $E2, $V, $p);

    initialise();

    if ( $datum eq 'WGS84' ) {
        $A = $A_WGS84;
        $B = $B_WGS84;
    } elsif ( $datum eq 'OSGB36') {
        $A = $A_OSGB36;
        $B = $B_OSGB36;
    } else {
        die("invalid datum->$datum<-\n");
    }

    $E2 = ($A*$A - $B*$B) / ($A*$A);

 #   print "\$x $x, \$y $y, \$z $z\n";


    $lon = atan( $y / $x );

     $p = sqrt($x*$x + $y*$y);
     $lat = atan( $z / ($p * (1.0-$E2) ) );


     do {

        $last_lat = $lat;
        $V = $A / sqrt(1.0 - $E2 *  sin( $lat ) * sin( $lat ));
        $lat = atan( ($z + $E2 * $V * sin ($lat)) / $p );
#        print "\$lat $lat\n";
     } while (abs($lat-$last_lat) > 1.0E-13);

     $alt = ($p / cos($lat)) - $V;

    $lon =  $radian_to_deg * $lon;
    $lat =  $radian_to_deg * $lat;

#    print "\$lon $lon, \$lat $lat, \$alt $alt\n";


    return ( ($lon, $lat, $alt) );
}




############################################################################



#------------------------------ end -----------------------------

return 1;


