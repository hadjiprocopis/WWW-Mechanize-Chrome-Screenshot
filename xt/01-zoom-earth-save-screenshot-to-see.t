#!/usr/bin/env perl

use strict;
use warnings;

use lib 'blib/lib';

use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

use Test::More;

use File::Temp;
use Cwd;
use File::Basename;

use WWW::Mechanize::Chrome::Screenshot;

# sicily
my $URL = 'https://zoom.earth/#38.093577,13.444609,17z,sat';

my $num_tests = 0;

my $shot = WWW::Mechanize::Chrome::Screenshot->new({
	'settle-time' => 6,
	'verbosity' => 2,
	'remove-these-DOM-elements-first' => [
		{
			'element-classname' => 'share',
			'element-type' => 'button',
			'&&' => 1
		},
		# undef, # with an undef you stop here and forget the rest...
		{
			'element-classname' => 'panel controls',
			'element-type' => 'div',
			'&&' => 1
		},
		{
			'element-classname' => 'attribution',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'panel search',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'cookies',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'attribution',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'panel poi',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'panel ad',
			'element-type' => 'div',
			'&&' => 1
		},
		{	'element-classname' => 'about',
			'element-type' => 'button',
			'&&' => 1
		},
		{	'element-classname' => 'zoom in',
			'element-type' => 'button',
			'&&' => 1
		},
		{	'element-classname' => 'zoom out',
			'element-type' => 'button',
			'&&' => 1
		},
	],
}); # end of ->new(...)
ok(defined $shot, 'WWW::Mechanize::Chrome::Screenshot->new() : called') or BAIL_OUT("Call to ".'WWW::Mechanize::Chrome::Screenshot->new()'." has failed."); $num_tests++;

#my ($fh, $tmpfile) = File::Temp::tempfile(SUFFIX=>'.png'); close($fh);
my $tmpfile = 'shit.png';
$shot->screenshot({
	'outfile' => $tmpfile,
	'url' => $URL
});
ok(-s $tmpfile, "$tmpfile contains the screenshot") or BAIL_OUT("no screenshot was created, something seriously wrong."); $num_tests++;
#unlink($tmpfile);

# END
done_testing($num_tests);
