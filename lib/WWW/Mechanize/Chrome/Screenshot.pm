package WWW::Mechanize::Chrome::Screenshot;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.01';

use WWW::Mechanize::Chrome;
use WWW::Mechanize::Chrome::DOMdel qw/remove_element_from_DOM VERBOSE_DOMdel/;

use Data::Dumper;

sub	new {
	my $class = $_[0];
	my $params = $_[1]; # a hash of params, see below

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my $self = {
		'mech-obj' => undef,
		'mech-params' => undef,
		'remove-these-DOM-elements-first' => undef,
		'settle-time' => 2, # seconds to wait after hitting a page in order to settle browser contents
		'verbosity' => 0,
	};
	bless $self, $class;

	# input param 'settle-time' (>=0 seconds)
	if( defined $params->{'settle-time'} ){
		$self->settle_time($params->{'settle-time'});
	} else { $self->settle_time($self->{'settle-time'}); }

	# input param 'remove-these-DOM-elements-first' as an array of hashrefs to be passed as params
	# to WWW::Mechanize::Chrome::DOMdel::remove_element_from_DOM (see that for what keys to use)
	# NOTE: place an undef in this array in order to skip all the following entries.
	$self->{'remove-these-DOM-elements-first'} = [ @{$params->{'remove-these-DOM-elements-first'}} ] if defined $params->{'remove-these-DOM-elements-first'};

	# input param 'verbosity' (0 or 1 or 2)
	if( defined $params->{'verbosity'} ){
		$self->verbosity($params->{'verbosity'});
	} else { $self->verbosity($self->{'verbosity'}); }

	# save the mech-params for later, we may need them if crash
	if( defined $params->{'mech-params'} ){
		$self->mech_params($params->{'mech-params'});
	} else { $self->mech_params($self->{'mech-params'}); }

	# launch a chrome now or when first screenshot is taken?
	if( ! exists $params->{'launch-mech-on-demand'} or $params->{'launch-mech-on-demand'} == 0 ){
		$self->{'mech-obj'} = $self->launch_mech_obj($params->{'mech-params'});
		if( ! defined $self->{'mech-obj'} ){ print STDERR "$whoami (via $parent) : call to ".'launch_mech_obj()'." with parameters:\n".Dumper($params->{'mech-params'})."\n--- end mech launch parameters\n     has failed.\n"; return undef }
	}
	return $self
}
# blank the browser
sub	blank_browser { $_[0]->{'mech-obj'}->get('about:blank') }

# hits the page, waits for some settle-time, removes some elements from the DOM,
# if asked, that obstruct the shot, e.g. banners and dumps the browser's window
# to a PNG file (whose filename must be supplied as input param).
# returns 0 on failure
# returns 1 on success
sub	screenshot {
	my $self = $_[0];
	my $params = $_[1]; # a hashref of 'outfile', 'url' etc.

	my $outfile = $params->{'outfile'};
	my $URL = $params->{'url'};

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	if( ! defined $outfile ){ print STDERR "$whoami (via $parent) : 'outfile' parameter was not specified.\n"; return 0 }
	if( ! defined $URL ){ print STDERR "$whoami (via $parent) : 'URL' parameter was not specified.\n"; return 0 }

	my $mech = $self->{'mech-obj'};
	if( ! defined $mech ){
		# launch a chrome on demand
		$self->{'mech-obj'} = $self->launch_mech_obj($self->mech_params());
		if( ! defined $self->{'mech-obj'} ){ print STDERR "$whoami (via $parent) : call to ".'launch_mech_obj()'." with parameters:\n".Dumper($self->mech_params())."\n--- end mech launch parameters\n     has failed.\n"; return undef }
		$mech = $self->{'mech-obj'};
	}

	# if 2 consecutive urls have the same path (except the params) then we get stuck
	# with error  Page.navigatedWithinDocument
	# see https://perlmonks.org/?node_id=1219646
	$self->blank_browser();

	# and then get the page
	if( ! $mech->get($URL) ){ print STDERR "$whoami (via $parent) : call to ".'get()'." has failed for url: $URL\n"; return 0 }

	# move by nothing in order to load images
	$self->scroll(0);

	# sleep a second or two till it gets settled
	if( $self->verbosity() > 0 ){ print "$whoami (via $parent) : allowing settle time of ".$self->{'settle-time'}." seconds.\n"; }
	sleep($self->settle_time());

	# move by nothing in order to load images
	$self->scroll(0);

	# do we have any elements to remove?
	if( defined $self->{'remove-these-DOM-elements-first'} ){
		foreach my $anentry (@{$self->{'remove-these-DOM-elements-first'}}){
			if( ! defined $anentry ){ last } # any undef in the array is a signal to skip the rest
			my %delparms = (
				%$anentry,
				'mech-obj' => $mech
			);
			if( WWW::Mechanize::Chrome::DOMdel::remove_element_from_DOM(\%delparms) < 0 ){
				print STDERR "$whoami (via $parent) : call to ".'WWW::Mechanize::Chrome::DOMdel::remove_element_from_DOM()'." has failed for these parameters:\n".Dumper($anentry)."\n---end of parameters.\n";
				return 0 # do not continue if error!
			}
			if( $self->verbosity() > 1 ){ print "Done entry : ".Dumper($anentry)."\n" }
		}
	}

	sleep(1);

	# smile!!!
	my $fh;
	if( ! open $fh, '>:raw', $outfile ){ print STDERR "$whoami (via $parent) : error, failed to open file '$outfile' for writing, $!\n"; return 0 }
	print $fh $mech->content_as_png();
	close $fh;

	return 1 # success
}
# launches a mech obj given optional parameters which
# may overwrite some defaults we have
sub	launch_mech_obj {
	my $self = $_[0];
	my $params = $_[1];

	# the above params have the same structure as the default below
	# we overwrite defaults with params (if any)

	$params = {} unless defined $params; 

	my $parent = ( caller(1) )[3] || "N/A";
	my $whoami = ( caller(0) )[3];

	my %default_mech_params = (
		headless => 1,
#		log => $mylogger,
		launch_arg => [
			'--window-size=800x600', # this is the default size of the shot
			'--password-store=basic', # do not ask me for stupid chrome account password
#			'--remote-debugging-port=9223',
#			'--enable-logging', # see also log above
			'--disable-gpu',
			'--no-sandbox',
			'--ignore-certificate-errors',
			'--disable-background-networking',
			'--disable-client-side-phishing-detection',
			'--disable-component-update',
			'--disable-hang-monitor',
			'--disable-save-password-bubble',
			'--disable-default-apps',
			'--disable-infobars',
			'--disable-popup-blocking',
		],
	);

	# input param 'mech-params' : specify params to launching chrome as a hashref
	# 'launch_arg' is a hashref though (unlike its counterpart in defaults above)
	# if it has a value like '--window-size' => '1600x1200' it will be converted to '--window-size=1600x1200'
	# and overwrite previous setting if any in the defaults.
	# if it starts with a /^no\s*/i then the defaults will have this option removed from it.
	my $m;
	if( ref $params eq 'HASH' ){
		foreach my $k (keys %$params){
			my $v = $params->{$k};
			if( ref($v) eq '' ){
				# overwrite all the scalars of the default params
				$default_mech_params{$k} = $params->{$k};
			}
		}
		if( exists $params->{'launch_arg'} && ref($m=$params->{'launch_arg'}) eq 'ARRAY' ){
			my %la = map { /=/ ? split/=/,$_ : ($_=>undef) } @$m;
			my %dla = map { /=/ ? split/=/,$_ : ($_=>undef) } @{$default_mech_params{'launch_arg'}};

			foreach my $k (keys %la){
				# it was an option starting with 'no', e.g. 'no --disable-infobars'
				if( $k =~ s/^no\s*//i ){ delete $dla{$k} }
				else { $dla{$k} = $la{$k} } # else set the option or option with value
			}
			$default_mech_params{'launch_arg'} = [ map { defined($dla{$_}) ? $_.'='.$dla{$_} : $_ } keys %dla ];
		}
	}

	my $mech = WWW::Mechanize::Chrome->new(%default_mech_params);
	if( ! defined $mech ){ print STDERR "_create_mech_obj() : call to ".'WWW::Mechanize::Chrome->new()'." with params:\n".Dumper(%default_mech_params)."\n---end mech launch params\n    has failed, parameters to this sub (launch_mech_obj) are:\n".Dumper($params)."\n---- end of sub parameters.\n"; return undef }

	# now that we have a mech we need to re-do the verbosity thing to fix the mech obj too
	$self->verbosity($self->{'verbosity'});

	if( $self->verbosity() > 0 ){ print "$whoami (via $parent) : launched WWW::Mechanize::Chrome with the following parameters:\n".Dumper(\%default_mech_params)."\n--- end mech launch parameters\n"; }

	return $mech
}
sub	scroll { $_[0]->{'mech-obj'}->eval('window.scrollBy('.$_[1].', window.innerHeight);') }
sub	verbosity {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'verbosity'} unless defined $m;
	$self->{'verbosity'} = $m;
	# this is >= 0
	$WWW::Mechanize::Chrome::DOMdel::VERBOSE_DOMdel = $m;
	# make a mech console for showing js output (and other things)
	$self->{'mech-console'} =
		$m > 0 and defined $self->{'mech-obj'} ?
			$self->{'mech-obj'}->add_listener('Runtime.consoleAPICalled', sub {
			  warn join ", ",
			      map { $_->{value} // $_->{description} }
			      @{ $_[0]->{params}->{args} };
			})
		:
			undef # console goes away, all gone
	;
	return $m
}
sub	mech_obj {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'mech-obj'} unless defined $m;
	$self->{'mec-obj'} = $m;
	return $m
}
sub	mech_params {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'mech-params'} unless defined $m;
	$self->{'mech-params'} = $m;
	return $m
}
sub	settle_time {
	my $self = $_[0];
	my $m = $_[1];
	return $self->{'settle-time'} unless defined $m;
	$self->{'settle-time'} = $m;
	return $m
}

## POD starts here

=head1 NAME

WWW::Mechanize::Chrome::Screenshot - The great new WWW::Mechanize::Chrome::Screenshot!

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use WWW::Mechanize::Chrome::Screenshot;

    my $foo = WWW::Mechanize::Chrome::Screenshot->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head1 AUTHOR

Andreas Hadjiprocopis, C<< <bliako at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-mechanize-chrome-screenshot at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mechanize-Chrome-Screenshot>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mechanize::Chrome::Screenshot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mechanize-Chrome-Screenshot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Mechanize-Chrome-Screenshot>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/WWW-Mechanize-Chrome-Screenshot>

=item * Search CPAN

L<https://metacpan.org/release/WWW-Mechanize-Chrome-Screenshot>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2019 Andreas Hadjiprocopis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of WWW::Mechanize::Chrome::Screenshot
