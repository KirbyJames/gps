


use Data::Dumper;
use Math::ConvexHull qw/convex_hull/;

$Data::Dumper::Indent = 0;




print "---------- refs ------------\n";

$input =   [   [0,0],     [1,0],     [0.2,0.9], [0.2,0.5],     [0,1],     [1,1]   ];

$hull_array_ref = convex_hull($input); 


print "Input points: " . Dumper $input;  
print "\n";

print "       Hull?: " . Dumper   $hull_array_ref;
print "\n";




 # another one
my $from = [[0,0], [1,0],[0.2,0.9], [0.2,0.5], [0.2,0.5], [0,1], [1,1],]; 
my $to   = [[0,0], [1,0], [1,1], [0,1]];
my $res = convex_hull($from);

print "\n\n";

print "        From: " . Dumper $from;
print "\n";

print "          To: " . Dumper $to;
print "\n";

print "         Res: " . Dumper $res;
print "\n";

print "        From: " . Dumper $from;
print "\n";

print "=========================================================\n";

# convex_hull() expects an array reference to an array of points and returns an array reference to an array#  of points in the convex hull.
# In this context, a point is considered to be a reference to an array containing an x and a y coordinate. 
  
print " Convex hull: " . Dumper convex_hull(
  [
    [0,0],     [1,0],
    [0.2,0.9], [0.2,0.5],
    [0,1],     [1,1],
  ]
);
print "\n";
  
  # Prints out the points [0,0], [1,0], [0,1], [1,1].


@points =   (   [0,0],     [1,0],     [0.2,0.9], [0.2,0.5],     [0,1],     [1,1]   );

print "Input points: " . Dumper @points;  
print "\n";

  
$hull_array_ref = convex_hull(\@points); 

print "       Hull?: " . Dumper   $hull_array_ref;
print "\n";

print "Input points: " . Dumper @points;  
print "\n";



my @AoA; # an array of arrays to represent the points.

while(<DATA>) {
    push @AoA, [ split ];
}
$x = 0.111;
$y = 0.123456;

push @AoA, [ 0.11, 0.12 ];
push @AoA, [ $x, $y ];

my @sorted = sort { $a->[1] <=> $b->[1] } @AoA; # thanks moritz!


for my $aref ( @sorted ) {
    print "\t [ @$aref ],\n";
}
#exit;

$hull_array_ref = convex_hull(\@sorted);
$hull_array_ref = convex_hull(\@AoA);
 
print "Input points: " . Dumper \@sorted;  
print "\n";

print "Input points: " . Dumper \@AoA;  
print "\n";

print "       Hull?: " . Dumper   $hull_array_ref;
print "\n";


__DATA__
0 0
1 0
0.2 0.9
0.2 0.5
0 1
1 1
