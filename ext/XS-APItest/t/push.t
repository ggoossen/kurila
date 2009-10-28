use TestInit
use Config

use Test::More tests => 9

BEGIN { (use_ok: 'XS::APItest') };

#########################

my @mpushp = @:  (mpushp: ) 
my @mpushn = @:  (mpushn: ) 
my @mpushi = @:  (mpushi: ) 
my @mpushu = @:  (mpushu: ) 
ok: (eq_array: \@mpushp, \qw(three)), 'mPUSHp()'
ok: (eq_array: \@mpushn, \(@: 0.125)), 'mPUSHn()'
ok: (eq_array: \@mpushi, \(@: -3)),         'mPUSHi()'
ok: (eq_array: \@mpushu, \(@: 3)),           'mPUSHu()'

my @mxpushp = @:  (mxpushp: ) 
my @mxpushn = @:  (mxpushn: ) 
my @mxpushi = @:  (mxpushi: ) 
my @mxpushu = @:  (mxpushu: ) 
ok: (eq_array: \@mxpushp, \(@: 'three')), 'mXPUSHp()'
ok: (eq_array: \@mxpushn, \(@: 0.125)), 'mXPUSHn()'
ok: (eq_array: \@mxpushi, \(@: -3)),         'mXPUSHi()'
ok: (eq_array: \@mxpushu, \(@: 3)),           'mXPUSHu()'
