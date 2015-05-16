#!/usr/bin/perl
#
#
#=========================================================================
#       gpx_join.pl
#=========================================================================
#
#   join two or more GPX files together
#    -t     removes <time> (date-time) tags
#    -e     removes <ele> (elevation) tags
#

use Getopt::Long;
#use strict;
use Carp;

my ( $k, $input_gpx_file, $output_gpx_file, $name );
my ( $n, $gpx_data, $usage, $wpt_data, $n_segment, $segment_data, $trk_pnt, $elevation, $elevation_tag, $all, $lat, $lon );
my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks );
my ( $file_modification_date_time );
my ( @input_gpx_files );

$usage = << 'USAGE_TEXT';
USAGE: gpx_join.pl 
            [-elevation]                                    [removes elevation tags; default = retain]
            [-time]                                         [removes date-time tags; default = retain]
            -i <input_gpx_file_1> <input_gpx_file_2> ....   [multiple input files to join]
            -o <output_gpx_file>                            [output file]
USAGE_TEXT

##################################################################################
#	get, and check, file names from command line
##################################################################################

my $remove_date_time = '';   # default FLASE = retain
my $remove_elevation = '';   # default FALSE = retain

GetOptions ("o=s" => \$output_gpx_file,   "i=s{1,}"   => \@input_gpx_files,  "time"  => \$remove_date_time,  "elevation"  => \$remove_elevation  );  

if ( @input_gpx_files < 1 ) {
    print "ERROR: at least one input_gpx_file must be specified\n";
    print $usage;
    exit;
}

if ( length($output_gpx_file) < 1 ){
    print "ERROR: output_gpx_file not specified\n";
    print $usage;
    exit;
}

if ( !$remove_date_time ) {
    print "retaining date_time tags in tracks\n";
} else {
    print "removing date_time tags from tracks\n";
}

if ( !$remove_elevation ) {
    print "retaining elevation tags in waypoints and tracks\n";
} else {
    print "removing elevation tags from waypoints and tracks\n";
}


#for ( $k = 0 ; $k < @input_gpx_files ; $k++ ) {
#    $input_gpx_file = @input_gpx_files[$k];
#    print "$k: $input_gpx_file\n";
#}

##################################################################################
#	open output file
##################################################################################

open (OUT, ">$output_gpx_file") || die("unable to open $output_gpx_file");
print OUT "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n";
print OUT "<gpx xmlns=\"http://www.topografix.com/GPX/1/1\">\n";
print OUT "\n<!--\n";
print OUT "    **************************************************************\n";
print OUT "         output produced by gpx_join.pl\n";
print OUT "    **************************************************************\n";
print OUT "-->\n";

###########################################################################################
#---- run through input files twice - first time extracting way points - second time extracting tracks
###########################################################################################

#---- first - extract waypoints ----

for ( $k = 0 ; $k < @input_gpx_files ; $k++ ) {
    $input_gpx_file = @input_gpx_files[$k];
    print "extract waypoints from $input_gpx_file \n";
    
    $gpx_data = read_file( $input_gpx_file );
     ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($input_gpx_file);
    $file_modification_date_time = localtime $mtime;
     
    print OUT "\n<!-- waypoints: $input_gpx_file: $size bytes [$file_modification_date_time] -->\n\n";
    
    while ( $gpx_data =~ m!(<wpt.*?</wpt>)!sg ) {                               # find each waypoint
        $wpt_data = $1;
        if ( $remove_elevation ) {  
            $wpt_data =~ s!<ele>.*?</ele>!!sg;                                  # remove elevation info
        } else {
            if ( $wpt_data =~ m!(<ele>(.*?)</ele>)!s ) {                        # is elevation present?
                $elevation = $2;
                $all = $1;
                #print "all: $all  elevation: $elevation\n";
                $elevation_tag = sprintf("<ele>%.1f</ele>", $elevation );       # retain 0.1 m resolution
                $wpt_data =~ s!$all!$elevation_tag!s;
            }
        }
        
        #  lat="47.011523" lon="4.842947">
        
        $wpt_data =~ m!(\slat=\"(.*?)\"\slon=\"(.*?)\"\>)!s;
        my $lat = $2;
        my $lon = $3;
        my $all = $1;
        #print "$lat $lon $all\n";
        
        my $sub = sprintf(" lat=\"%.6f\" lon=\"%.6f\"\>", $lat, $lon );         # 0.1 metre accuracy
        $wpt_data =~ s!$all!$sub!s;
                
        print OUT "$wpt_data\n";
    }
}

#---- second - extract tracks ----

print OUT "\n\n<trk>\n";
print OUT "  <name>-</name>\n";  # Q: what do we call it?


for ( $k = 0 ; $k < @input_gpx_files ; $k++ ) {
    $input_gpx_file = @input_gpx_files[$k];
    print "extract track/segments from $input_gpx_file: segment: ";
    
    $gpx_data = read_file( $input_gpx_file );      ## NO need to do this as have read file already!!!!!!!!!!!!!!
     ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat($input_gpx_file);
    $file_modification_date_time = localtime $mtime;
    
    print OUT "\n  <!-- tracks/segment: $input_gpx_file: $size bytes [$file_modification_date_time] -->\n";

    $n_segment = 0;

    $name = $input_gpx_file;
        
    while ( $gpx_data =~ m!<trkseg>(.*?)</trkseg>!sg ) {                        # find each segment
        $segment_data = $1;
        print " $n_segment";
        print OUT "\n  <!-- start segement $n_segment: $input_gpx_file: -->\n\n";
        
        print OUT "  <trkseg>\n";
    	
        #----   in this segment work through all trkpts 
    
        while ( $segment_data =~ m!(<trkpt.*?</trkpt>)!sg ) {                       # find all data points within this segment
            $trk_pnt = $1;  
            $trk_pnt =~ s!>\s*<!><!sg;                                              # force onto single line - ie remove newlines, tabs and spaces
            if ( $remove_date_time ) {  $trk_pnt =~ s!<time>.*?</time>!!sg; }       # remove date-time info
            if ( $remove_elevation ) {  
                $trk_pnt =~ s!<ele>.*?</ele>!!sg;                                   # remove elevation info
            } else {
                if ( $trk_pnt =~ m!(<ele>(.*?)</ele>)!s ) {                         # is elevation present?
                    $elevation = $2;
                    $all = $1;
                    $elevation_tag = sprintf("<ele>%.1f</ele>", $elevation );       # retain 0.1 m resolution
                    $trk_pnt =~ s!$all!$elevation_tag!s;
                }
            }
                    
            #  lat="47.011523" lon="4.842947">
        
            $trk_pnt =~ m!(\slat=\"(.*?)\"\slon=\"(.*?)\"\>)!s;
            $lat = $2;
            $lon = $3;
            $all = $1;
            #print "$lat $lon $all\n";
        
            my $sub = sprintf(" lat=\"%.6f\" lon=\"%.6f\"\>", $lat, $lon );         # 0.1 metre accuracy
            $trk_pnt =~ s!$all!$sub!s;

            print OUT "    $trk_pnt\n";
        }        
    
        print OUT "  </trkseg>\n";
        print OUT "\n  <!-- end segement $n_segment: $input_gpx_file: -->\n\n";
        $n_segment++;
    }
    print "\n";
}

print OUT "</trk>\n\n";

print OUT "</gpx>\n\n";


print "output in $output_gpx_file \n";


exit;




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

