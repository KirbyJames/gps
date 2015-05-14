#
#   os.pm
#

#=========================================================================
#       package os
#=========================================================================

package os;

use     strict;
use     datum;

$os::VERSION = 0.10;


my ($A, $B, $E0, $N0, $K0, $L0, $SC, $PI);
my ($deg_to_radian, $radian_to_deg);


my ($lon, $lat, $east, $north);
my (@ng, @ll);


#----------------------------------------------------------------------
#       os :: initialise
#----------------------------------------------------------------------

sub initialise {

    $PI = 3.141592654;

    $A = 6377563.396;                              # major semi axis in metres
    $B = 6356256.910;                              # minor semi axis in metres
    $E0 = 400000.0;                                # east grid coordinate of origin in metres
    $N0 = (-100000.0);                             # north grid coordinate of origin in metres
    $K0 = (49.00*$PI/180.0);                        # lat of origin in radians
    $L0 = ((-2.00*$PI)/180.0);                      # long of origin in radians
    $SC = 0.9996012717;                            #  scale on central axis

    $deg_to_radian = ($PI/180.0);
    $radian_to_deg = (180.0/$PI);
}



sub wgs84_to_os {
    my ( $longitude_wgs84, $latitude_wgs84 ) = @_;    # lat long in degrees
    my ( $longitude_osgb36, $latitude_osgb36, $osgb36_altitude, $east, $north );

    
    #print "DEBUG:: wgs84_to_os: $longitude_wgs84, $latitude_wgs84\n";
    
    ( $longitude_osgb36, $latitude_osgb36, $osgb36_altitude ) = datum::wgs84_to_osgb36($longitude_wgs84, $latitude_wgs84, 0.0);
    ( $east, $north ) = os::ll2m( $longitude_osgb36, $latitude_osgb36 );

     return ( $east, $north );    # easting and northing in km
}


sub os_to_wgs84 {
    my ( $east, $north ) = @_;    # easting and northing in km
    my ( $longitude_wgs84, $latitude_wgs84, $wgs84_altitude );
    my ( $longitude_osgb36, $latitude_osgb36 );
        
    ( $longitude_osgb36, $latitude_osgb36 ) = os::m2ll( $east, $north );
    ( $longitude_wgs84, $latitude_wgs84, $wgs84_altitude ) = datum::osgb36_to_wgs84( $longitude_osgb36, $latitude_osgb36, 0.0 );
    
    return ( $longitude_wgs84, $latitude_wgs84 );   # lat long in degrees
}


############################################################################
sub arcofmeridian
{
    my ($Q3, $Q4, $B1, $N1 ) = @_;

    my ($X3, $X4, $X5, $X6, $M);

#    print "arcofmeridian\n";
    initialise();
    $X3 = (1.0 + $N1 + (5.0/4.0) * $N1 * $N1 + (5.0/4.0) * $N1 * $N1 * $N1) * $Q3;
    $X4 = (3.0*$N1 + 3.0*$N1*$N1 + (21.0/8.0)*$N1*$N1*$N1)*sin($Q3)*cos($Q4);
    $X5 = ((15.0/8.0)*$N1*$N1 + (15.0/8.0)*$N1*$N1*$N1)*sin(2.0*$Q3)*cos(2.0*$Q4);
    $X6 = (35.0/24.0)*$N1*$N1*$N1*sin(3.0*$Q3)*cos(3.0*$Q4);
    $M = $B1*($X3-$X4+$X5-$X6);
    return($M);
}



############################################################################
sub ll2m        #01/21/03 6:44:PM
############################################################################
# inputs:
#       longitude (degrees)
#       latitude (degrees)
# outputs:
#       east of origin of NG  (km)
#       north of origin of NG (km)
############################################################################
{

    my ($lon, $lat) = @_;

    my ($K, $K3, $K4, $SK, $CK, $TK);
    my ($J3, $J4, $J5, $J6, $J7, $J8, $J9);
    my ($E, $L, $M, $N, $V, $H2, $P, $R);
    my ($A1, $B1, $N1, $E2);
    my (@ng);

#    print "ll2m\n";
    initialise();

    $N1 = (($A) - ($B)) / (($A) + ($B));
    $E2 = (($A)*($A) - ($B)*($B)) / (($A)*($A));
    $L = $lon * $deg_to_radian;
    $K = $lat * $deg_to_radian;
    $A1 = ($A) * ($SC);
    $B1 = ($B) * ($SC);
    $K3 = $K - ($K0);
    $K4 = $K + ($K0);
    $M = arcofmeridian($K3, $K4, $B1, $N1);
    $SK = sin($K);
    $CK = cos($K);
#    $TK = tan($K);
    $TK = $SK/$CK;
    $V = $A1/sqrt(1.0 - $E2*$SK*$SK);
    $R = $V*(1.0-$E2)/(1.0-$E2*$SK*$SK);
    $H2 = ($V/$R) - 1.0;
    $P = $L - $L0;
    $J3 = $M + $N0;
    $J4 = ($V/2.0)*$SK*$CK;
    $J5 = ($V/24.0)*$SK*$CK*$CK*$CK*(5.0-$TK*$TK+9.0*$H2);
    $J6 = ($V/720.0)*$SK*$CK*$CK*$CK*$CK*$CK*(61.0-58.0*$TK*$TK+$TK*$TK*$TK*$TK);
    $N = $J3 + $P*$P*$J4 + $P*$P*$P*$P*$J5 + $P*$P*$P*$P*$P*$P*$J6;
    $J7 = $V*$CK;
    $J8 = ($V/6.0)*$CK*$CK*$CK*($V/$R - $TK*$TK);
    $J9 = ($V/120.0)*$CK*$CK*$CK*$CK*$CK;
    $J9 = $J9*(5.0-18.0*$TK*$TK + $TK*$TK*$TK*$TK + 14.0*$H2 - 58.0*$TK*$TK*$H2);
    $E = ($E0) + $P*$J7 + $P*$P*$P*$J8 + $P*$P*$P*$P*$P*$J9;
    @ng = ($E/1000.0, $N/1000.0);

    if ( $ng[0] > 700.1 || $ng[0] < -0.1 || $ng[1] > 1300.1 || $ng[1] < -0.1 ) {
        print "m2ll: error: $ng[0], $ng[1] outside GB NG \n";
    }


    return @ng;
}


############################################################################
sub m2ll        #01/21/03 6:51:PM
############################################################################
# inputs:
#       east of origin of NG  (km)
#       north of origin of NG (km)
# outputs:
#       longitude (degrees)
#       latitude (degrees)
############################################################################
{
    my ($east, $north) = @_;

    my ($lat, $lon);
    my ($K, $K3, $K4, $K9, $SK, $CK, $TK);
    my ($J3, $J4, $J5, $J6, $J7, $J8, $J9);
    my ($E, $L, $M, $N, $V, $H2, $R);
    my ($Y1, $TMP, $A1, $B1, $N1, $E2);
    my (@ll);
    my ($count);

#    print "m2ll\n";
    initialise();

#----- check input values are within grid ----

    if ( $east > 700.1-2 || $east < -0.1 || $north > 1300.1 || $north < -0.1 ) {
        print "m2ll: error: $east, $north outside GB NG \n";
    }

    $N1 = (($A) - ($B)) / (($A) + ($B));
    $E2 = (($A)*($A) - ($B)*($B)) / (($A)*($A));
    $A1 = $A*$SC;
    $B1 = $B*$SC;
    $N = $north * 1000.0;
    $E = $east * 1000.0;
    $K = ($N-$N0)/$A1 + $K0;
    $count = 0;
    while (1 && $count++ < 5) {
        $K3 = $K - $K0;
        $K4 = $K + $K0;
        $M = arcofmeridian($K3, $K4, $B1, $N1);
        $TMP = $N - $N0 - $M;
        if ($TMP < 0.0) {$TMP = (-$TMP);}
        if ($TMP < 0.001) {last};
        $K = $K + ($N - $N0 - $M)/$A1;
#        print "\n\$TMP $TMP ";
    }
    $SK = sin($K);
    $CK = cos($K);
#    $TK = tan($K);
    $TK = $SK/$CK;
    $V = $A1/sqrt(1.0 - $E2*$SK*$SK);
    $R = $V*(1.0-$E2)/(1.0-$E2*$SK*$SK);
    $H2 = ($V/$R) - 1.0;
    $Y1 = $E - $E0;
    $J3 = $TK/(2.0*$R*$V);
    $J4 = ($TK/(24.0*$R*$V*$V*$V)) * (5.0 + 3.0*$TK*$TK + $H2 - 9.0*$TK*$TK*$H2);
    $J5 = ($TK/(720.0*$R*$V*$V*$V*$V*$V)) *(61.0 + 90.0*$TK*$TK + 45.0*$TK*$TK*$TK*$TK);
    $K9 = $K - $Y1*$Y1*$J3 + $Y1*$Y1*$Y1*$Y1*$J4 - $Y1*$Y1*$Y1*$Y1*$Y1*$Y1*$J5;
    $J6 = 1.0/($CK*$V);
    $J7 = (1.0/($CK*6.0*$V*$V*$V)) * ($V/$R + 2.0*$TK*$TK);
    $J8 = (1.0/($CK*120.0*$V*$V*$V*$V*$V)) * (5.0 + 28.0*$TK*$TK + 24.0*$TK*$TK*$TK*$TK);
    $J9 = (1.0/($CK*5040.0*$V*$V*$V*$V*$V*$V*$V));
    $J9 = $J9 * (61.0 + 662*$TK*$TK +1320.0*$TK*$TK*$TK*$TK +  720.0*$TK*$TK*$TK*$TK*$TK*$TK);
    $L = $L0 +$Y1*$J6 - $Y1*$Y1*$Y1*$J7 + $Y1*$Y1*$Y1*$Y1*$Y1*$J8 -  $Y1*$Y1*$Y1*$Y1*$Y1*$Y1*$Y1*$J9;
    $K = $K9;
    $lat = $K*$radian_to_deg;
    $lon = $L*$radian_to_deg;
    @ll = ($lon, $lat);
    return @ll;
}

#------------------------------ end -----------------------------

return 1;


