#!/usr/bin/env perl

use strict; 
use GD;

my $res = 1600;
my $outres = 1000;
my $format = 2.0;

for my $z(0..2) {
    my ($c1, $c2, $c3, $c4);
    my $img = new GD::Image($res, $res);
    $img->fill($res, $res => $img->colorAllocate(0, 0, 0));

    for (0..120) {
        $c1 = $img->colorAllocate(rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32);
        $c2 = $img->colorAllocate(rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32);
        $c3 = $img->colorAllocate(rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32);
        $c4 = $img->colorAllocate(rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32, rand(0xFF-0x32)+0x32);
        
        $c1 = $img->colorAllocate(    0,   0, 255);
        $c2 = $img->colorAllocate(  255,   0,   0);
        $c3 = $img->colorAllocate(    0, 255,   0);
        $c4 = $img->colorAllocate(  255, 255, 255);
        
            my $thickness = 4;
       $img->setThickness($thickness);

        $img->setStyle($c1, $c1, $c1, $c1, $c3, $c3, $c4, $c4, gdTransparent, gdTransparent, gdTransparent, gdTransparent);
        (rand(10)>2) ? ($img->line(rand($res), rand($res), rand($res), rand($res), gdStyled)):
        ((rand(10)>2) ? $img->rectangle(rand($res), rand($res), rand($res), rand($res), gdStyled):
        $img->ellipse(rand($res), rand($res), rand($res), rand($res), gdStyled)) if (rand(10)>2);
        
        
        
        
    }

    $img->setStyle($c1, $c2, $c3, gdTransparent, gdTransparent, gdTransparent, gdTransparent);
    my $thickness = 24;
    $img->setThickness($thickness);
    $img->line( 1, 1, 800, 800, gdStyled);
    $img->line( 1, 41, 800, 841, $c2);

    
    print "processing $z.png...\n";
#    my $m = new GD::Image($outres*$format, $outres);
#    $m->copyResized($img, 0, 0, 0, 0, $outres*$format, $outres, $res, $res);

    open F => '>'.$z.'.png';
    binmode F;
 #   print F $m->png;
    print F $img->png;
    close F;
}

