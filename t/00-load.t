#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WWW::Mechanize::Chrome::Screenshot' ) || print "Bail out!\n";
}

diag( "Testing WWW::Mechanize::Chrome::Screenshot $WWW::Mechanize::Chrome::Screenshot::VERSION, Perl $], $^X" );
