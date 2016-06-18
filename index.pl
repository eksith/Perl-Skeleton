#!/usr/bin/perl -T

# Perl Skeleton is a simple web page starter for basic sites
# Includes:
#	- Simple URL router
#	- HTML input field generation
#	- Meta tag generation

use v5.20;						# Perl version
use strict;
use warnings;
package PerlSkeleton;
{
	# Base variables
	my $app		= 'Perl Skeleton';		# App name
	my $version	= '0.1';			# App version
	
	my $store	= 'data';			# Storage folder
	my $templates	= 'templates';			# Templates directory
	my $theme	= 'default';			# Template name
	
	my $ssize	= 16;				# Password salt size
	my $robots	= "index, follow";		# Robots meta tag
	my $maxclen	= 50000;			# Maximum content length (bytes)
	my $rblock	= 1024;				# Read block size
	
	# Common vars (always sent)
	my ( $uri, $scheme, $method ) = (
		$ENV{'REQUEST_URI'},			# Visitor path
		$ENV{'REQUEST_SCHEME'},			# http or https
		$ENV{'REQUEST_METHOD'}			# GET, POST etc...
	);
	
	# Filter request method
	$method	= filter_method( $method );
	
	# Common options (usually sent, sometimes broken)
	my %opts = (
		lang	=> 'HTTP_ACCEPT_LANGUAGE',	# Preferred language
		ua	=> 'HTTP_USER_AGENT',		# User agent string
		enc	=> 'HTTP_ACCEPT_ENCODING',	# Character encoding
		dnt	=> 'HTTP_DNT',			# Do not track token
		addr	=> 'REMOTE_ADDR',		# IP address
		qs	=> 'QUERY_STRING',		# Any querystrings
		clen	=> 'CONTENT_LENGTH',		# Content length
		cookie	=> 'HTTP_COOKIE'		# User cookie
	);
	
	# Application routes (add/edit as needed)
	# https://stackoverflow.com/questions/1915616/how-can-i-elegantly-call-a-perl-subroutine-whose-name-is-held-in-a-variable#1915709
	my %routes = (
		'/'			=> \&home,		# Home route
		'/(?<page>\d+)'		=> \&home,		# Home pagination
		
		# Browse the archives
		'/posts'								=> \&archive,
		'/posts/(?<year>\d{4})'							=> \&archive,
		'/posts/(?<year>\d{4})/(?<month>\d{2})'					=> \&archive,
		'/posts/(?<year>\d{4})/(?<month>\d{2})/(?<day>\d{2})'			=> \&archive,
		
		# Read a page
		'/posts/(?<year>\d{4})/(?<month>\d{2})/(?<day>\d{2})/(?<slug>\w+)'	=> \&page,
		
		# Edit a page
		'/edit/(?<year>\d{4})/(?<month>\d{2})/(?<day>\d{2})/(?<slug>\w+)'	=> \&edit_page,
		
		'/new'				=> \&new_page,		# Create a page
		'/save'				=> \&save_page,		# Save a page
		
		'/login'			=> \&login,		# User login
		'/logout'			=> \&logout,		# User logout
		'/changepass'			=> \&change_pass	# Change login password
	);
	
	# Common meta tags
	my %common_meta = (
		
		# Mobile compatibility
		viewport	=> 'width=device-width, initial-scale=1',
		
		# Show application name (comment this out to hide)
		generator	=> "$app $version",
		
		# Robot follow/index
		robots		=> $robots
			
	);
	
	
	####		Page routes (per above)	####
	
	# Do homey things
	sub home {
		my ( $method, $path, %params ) = @_;
		
		# Meta tags
		my %mtags = ( 
			%common_meta, (
				description	=> 'Achtung Baby',
				author		=> 'Bono'
			) 
		);
		
		# Render a basic HTML page
		html( 'Home', 'Welcome ' . $path, %mtags );
	}
	
	# Do post reading things
	sub page {
		my ( $method, $path, %params ) = @_;
		my %mtags = (
			description	=> 'Page description',
			author		=> 'Page author'
		);
		
		# Reading a page
		html( 'This is a test page', 'Hello World' . $path, %mtags );
	}
	
	# Do archive things
	sub archive {
		my ( $method, $path, %params ) = @_;
		my $out		= '';
		
		# Override description
		my %mtags = ( 
			%common_meta, (
				description	=> 'Content archive'
			) 
		);
		
		foreach my $p ( keys %params ) {
			$out .= ' '. $params{$p};
		}
		
		html( 'Archive', 'This is an archive page' . $out, %mtags );
	}
	
	# Do new page things
	sub new_page {
		my ( $method, $path, %params ) = @_;
		
		
		# Override robots follow
		my %mtags = ( 
			%common_meta, (
				robots	=> 'noindex, nofollow'
			) 
		);
		
		# Build new page
		my %template	= (
			'title'		=> 'Create a new page',
			'heading'	=> 'Creating a new page',
			'action'	=> '/save',
			'meta'		=> meta_tags( %mtags )
		);
			
		render( 'new', %template );
	}
	
	# Do page editing things
	sub edit_page {
		my ( $method, $path, %params ) = @_;
		
		# Override robots follow
		my %mtags = ( 
			%common_meta, (
				robots	=> 'noindex, nofollow'
			) 
		);
		
		# TODO Find page
		
		# Build edit page
		my %template	= (
			'title'		=> 'Edit a page',
			'heading'	=> 'Editing a created page',
			'page_title'	=> 'A test page',
			'page_body'	=> 'Test content',
			'page_pub'	=> '6/18/2016',
			'action'	=> '/save',
			'meta'		=> meta_tags( %mtags )
		);
			
		render( 'edit', %template );
	}
	
	# Do save page things
	sub save_page {
		my ( $method, $path, %params ) = @_;
		
		# Post data was sent
		if ( $method eq "post" ) {
			my %data	= form_data( 'post' );
			
			# Merge any sent meta tags with default ones
			my %mtags = ( 
				%common_meta, (
					robots	=> 'noindex, nofollow'
				) );
			
			my %template	= (
				'title'	=> 'Newly saved page',
				'meta'	=> meta_tags( %common_meta ),
				'body'	=> field( 'body', %data )
			);
			
			render( 'post', %template );
		}
		
		# After saving the page, redirect
		redir( '/' );
	}
	
	# Do logging in things
	sub login {
		my ( $method, $path, %params ) = @_;
		
		# Login info was sent
		if ( $method eq "post" ) {
			# Process login (TODO)
			my %data = form_data( 'post' );
			
			redir( '/' );
		}
	
		# Everything else,  display login form
		my %mtags	= (
					robots	=> 'noindex, nofollow'
				);
		
		my $user	= input( 'username', 'text', '', 
					( placeholder=> 'Username' ) 
				);
		my $pass	= input( 'password', 'password', '', 
					( placeholder=> 'Password' ) 
				);
		my $submit	= input( 'login', 'submit', 'Login' );
		my $ht		= h( 'User login', 1 ) . 
					p( $user ) . 
					p( $pass ) . 
					p( $submit );
					
		html( 'Login user', $ht, %mtags );
	}
	
	# Do logging out things
	sub logout {
		my ( $method, $path, %params ) = @_;
		
	}
	
	# Do password changing things
	sub change_pass {
		my ( $method, $path, %params ) = @_;
		
		# Data was sent
		if ( $method eq 'post' ) {
			# Process change password (TODO)
			my %data = form_data( 'post' );
			
			redir( '/' );
		}
		
		my %mtags	= (
					robots	=> 'noindex, nofollow'
				);
		
		my $oldpass	= input( 'oldpassword', 'password', '', 
					( placeholder=> 'Old Password' ) 
				);
		my $newpass	= input( 'oldpassword', 'password', '', 
					( placeholder=> 'New Password' ) 
				);
		my $submit	= input( 'changepass', 'submit', 'Change' );
		my $ht		= h( 'Change login password', 1 ) . 
					p( $oldpass ) . 
					p( $newpass ) . 
					p( $submit );
					
		html( 'Change password', $ht, %mtags );
		
	}
	
	# Do saving new password things
	sub save_pass {
		my ( $method, $path, %params ) = @_;
		
		# After changing the password, redirect
		redir( '/' );
	}
	
	# Do not found things
	sub not_found {
		my ( $method, $path ) = @_;
		my %mtags	= (
					robots	=> 'noindex, nofollow'
				);
		
		html( '404 Not found', "Couldn't find the page you're looking for", %mtags );
	}
	
	
	
	####		Internal variables	####
	
	# https://doc.perl6.org/language/regexes#Subrules
	
	# Routing substitutions for brevity
	my %routesubs = (
		# Calendar markers
		':year'		=> '(?<year>\d{4})',	
		':month'	=> '(?<month>\d{2})',
		':day'		=> '(?<day>\d{2})',
		
		# Page slug (search engine friendly string)
		':slug'		=> '(?<slug>\w{1,80})',
		
		# Pagination number
		':page'		=> '(?<page>\d+)'
	);
	
	
	
	####		Let's begin		####
	
	
	start( $uri, $scheme, $method );
	
	
	
	####		Core functions		####
	
	# Initialization
	sub start {
		my ( $uri, $scheme, $method ) = @_;
		
		# Find which common vars are set in the options
		foreach my $okey ( keys %opts ) {
			
			# If the environment variable is defined...
			if ( defined $ENV{$opts{$okey}} ) {
				$opts{$okey} = $ENV{$opts{$okey}};
			} else {
				$opts{$okey} = undef;
			}
		}
		
		# Call router
		router( $uri );
	}
	
	# URL path router
	sub router {
		my ( $path ) = @_;
		my $matches;
		
		# Iterate through given routes
		foreach my $route ( sort keys %routes ) {
			
			# If we found this route has a handler
			if ( $path =~ s/^$route(\/)?$//i ) {
				
				# Pass matches into parameters
				my %params = parse_url( $route );
				
				# Call designated handler
				$routes{$route}->( $method, $path, %params );
				
				# Break out of search
				return;
			}
		}
		
		# Fallback to not found
		not_found( $method, $path );
	}
	
	# URL parameters
	# Map the named captures into a key => value hash
	# https://doc.perl6.org/language/regexes#Subrules
	sub parse_url {
		my $route	= shift;
		my %params;
		# Hacking the match object into a hash
		# https://doc.perl6.org/language/regexes#Named_captures
		#if ( $uri ~~ m/^$route(\/)?$/i ) {
			#my %params = $/.hash;
			#return %params;
		#}
		return %params;
	}
	
	
	
	####		HTML Rendering		####
	
	# Content type, DOCTYPE, and opening <html> tag pre-render
	sub preamble {
		print "Content-type: text/html\n\n";
		print "<!DOCTYPE html>\n<html>\n";
	}
	
	# Print header tag, title, and meta tags
	sub heading {
		my ( $title, %tags ) = @_;
		my $html = "<head>\n<meta charset=\"utf-8\" />\n";
		
		# Header content
		$html .= title( $title );
		$html .= meta_tags( %tags );
		
		return $html . "</head>\n";
	}
	
	# Print page title
	sub title {
		my $title = shift;
		return tag( 'title', "$title", 0, 1 );
	}
	
	# Print meta tags
	sub meta_tags {
		my ( %tags ) = @_;
		my $t = '';
		foreach my $k ( sort keys %tags ) {
			$t .= meta_tag( $k, $tags{$k} );
		}
		return $t;
	}
	
	# Print individual meta tag
	sub meta_tag {
		my ( $name, $value ) = @_;
		return "<meta name=\"$name\" content=\"$value\" />\n";
	}
	
	# Content page body
	sub body {
		my $body	= shift;
		return tag( 'body', "\n$body\n", 0, 1 );
	}
	
	# Close HTML and end execution
	sub ending() {
		print "</html>";
		exit ( 0 );
	}
	
	# Render a complete HTML page
	sub html {
		my ( $title, $body, %sent_meta ) = @_;
		
		# Merge any sent meta tags with default ones
		my %mtags = ( %common_meta, %sent_meta );
		
		# Put together the HTML page
		preamble();
		print heading( $title, %mtags );
		print body( $body );
		
		ending();
	}
	
	# Create heading tag
	sub h {
		my ( $value, $n, %attr ) = @_;
		return tag( "h$n", $value, 0, 1, %attr );
	}
	
	# Paragraph tag
	sub p {
		my ( $value, %attr ) = @_;
		return tag( 'p', $value, 0, 1, %attr );
	}
	
	# Anchor tag
	sub a {
		my ( $value, $title, %attr ) = @_;
		if ( !defined( $title ) ) {
			$title = '';
		}
		my %at = ( %attr, (
			href	=> $value,
			title	=> $title
		) );
		return tag( 'a', undef, 1, 0, %at );
	}
	
	# Image tag
	sub img {
		my ( $value, $alt, %attr ) = @_;
		if ( !defined( $alt ) ) {
			$alt = '';
		}
		my %at = ( %attr, (
			src	=> $value,
			alt	=> $alt
		) );
		
		return tag( 'img', undef, 1, 0, %at );
	}
	
	# Create a generic HTML tag
	sub tag {
		my ( $name, $value, $close, $br, %attr ) = @_;
		my $out = "";
		
		if ( $close ) { # Self closing
			
			# Merge the value with attributes, if it's there
			if ( defined( $value ) ) {
				my %attr = ( %attr, (
					value => $value
				) );
			}
			
			my $at = attr( %attr );
			$out = "<$name$at/>";
			
		} else {
			my $at = attr( %attr );
			$out = "<$name$at>$value</$name>";
		}
		
		if ( $br ) {
			return "$out\n";
		}
		return $out;
	}
	
	# Create an HTML input box (text, password, submit etc...)
	sub input {
		my ( $name, $type, $value, %attr ) = @_;
		my $at = attr( %attr ); # Append any attributes
		my $out = "<input name=\"$name\" type=\"$type\" " . 
				"value=\"$value\"$at />";
		
		return $out;
	}
	
	# Create a textarea
	sub text {
		my ( $name, $value, $rows, $cols, %attr ) = @_;
		my %st = (
			rows	=> $rows,
			cols	=> $cols
		);
		my $at = attr( %attr ); # Append any attributes
		my $out = "<textarea name=\"$name\" rows=\"$rows\" " 
				. "cols=\"$cols\"$at>";
		
		if ( !defined( $value ) || $value eq '' ) {
			return ( $out . '</textarea>' );
		}
		
		return ( $out . $value . '</textarea>' );
		
	}
	
	# Create a selectbox with options and optional selected item
	# TODO
	sub select {
		my ( $name, $selected, %options, %attr ) = @_;
		foreach my $k ( keys %options ) {
			
		}
	}
	
	# Print attributes
	sub attr {
		my ( %attr ) = @_;
		if  ( !%attr ) {
			return '';
		}
		
		my $out = "";
		
		foreach my $k ( sort keys %attr ) {
			if ( 'required' eq $k ) {
				$out .= " required";
				next;
			}
			$out .= " $k=\"$attr{$k}\"";
		}
		
		return $out;
	}
	
	
	
	
	####		Helpers			####
	
	
	# Raw data sent by the user
	# http://www.perlmonks.org/?node_id=135323
	sub raw_content {
		
		# Require content length
		if ( !$opts{'clen'} ) {
			%opts = ( %opts, ( clen => $maxclen ) );
		}
		
		if ( $opts{'clen'} > $maxclen ) {
			return '';
		}
		
		my $data	= '';
		my $len		= 0;
		my $raw;
		
		# Read user input in chunks up to maximum content length
		while( read( STDIN, $raw, $rblock ) ) {
			if ( 
				$len > $opts{'clen'} || 
				( $len + $rblock ) > $maxclen 
			) {
				exit ( 0 );
			}
			$data	.= $raw;
			$len	+= $rblock;
		}
		
		return trim( $data );
	}
	
	# Form data
	sub form_data {
		my $method = shift;
		my $raw;
		my @sent;
		
		for ( $method ) {
			/get/ and do { 
				# Check for empty query string
				if ( !defined( $opts{'qs'} ) ) {
				}
				
				# Get sent values from the query string
				$raw	= $opts{'qs'};
				last; 
			};
			
			/post/ and do {
				# Check for empty content length
				if ( !defined( $opts{'clen'} ) ) {
					return undef;
				}
				
				# Get sent data from raw content
				$raw	= raw_content();
				last;
			};
			
			# Form shouldn't have been used
			exit ( 0 );
		}
		
		return parse_form( $raw );
	}
	
	# Clean a parameter
	sub clean_param {
		my $value = shift;
			
		# Strip null bytes
		$value	=~ s/\x00$//;
		
		# Replace '+' with space
		$value	=~ tr/+/ /;
		
		# Hex decode
		$value	=~ s/%(..)/pack("C", hex($1))/eg;
		
		# Strip non-printable chars except spaces
		$value	=~ s/[[:^print:]]//g;
		
		return trim( $value );
	}
	
	# Clean a parameter name
	sub clean_name {
		my $value = shift;
		
		# Strip non-printable chars including spaces
		$value =~ s/[[:^print:]\s]//g;
		
		return trim( $value );
	}
	
	# Process form data
	sub parse_form {
		my $raw		= shift;
		my @sent	= split( /&/, $raw );
		my %parsed;
		
		foreach my $data ( @sent ) {
			my ( $name, $value ) = split( /=/, $data );
			
			# Scrub
			$name	= clean_name( $name );
			$value	= clean_param( $value );
			
			# Take care of possible duplicate values
			if ( exists( $parsed{$name} ) ) {
				
				# Use the size to increment the key
				my $size = scalar keys $parsed{$name};
				$parsed{$name}{$size} = $value;
			} else {
				# No duplicates yet, use zero as the key
				$parsed{$name} = ( { 0 => $value } );
			}
		}
		
		return %parsed;
	}
	
	# Form field from processed data
	sub field {
		my ( $field, %data, $i ) = @_;
		
		# First index for this field if none were specified
		if ( !defined( $i ) ) {
			$i = 0;
		}
		if ( exists( $data{$field} ) ) {
			# Specific index only?
			if ( exists( $data{$field}->{$i} ) ) {
				return $data{$field}->{$i};
			
			# All fields?
			} elsif ( $i == -1 ) {
				return $data{$field};
			}
		}
		
		# Field wasn't sent
		return undef;
	}
	
	
	
	# Get cookie data sent by the user
	sub cookie_data {
		my $name	= shift;
		my @data	= raw_cookie();
		foreach my $cookie ( @data ) {
			# TODO
		}
	}
	
	# Get raw sent cookie 
	sub raw_cookie{
		my $cookie = $opts{'cookie'};
		if ( !$cookie ) {
			return '';
		}
		
		my @data = split( "[;,] ?", $cookie );
		chomp( @data );
		
		return @data;
	}
	
	# Set cookie data by name
	sub set_cookie {
		my ( $name, %data  ) = @_;
		
		# TODO
	}
	
	# Send cookie data
	sub send_cookie {
		# TODO
	}
	
	sub parse_cookie {
		my @sent = shift;
		my %parsed;
		
		# TODO
		
		return %parsed;
	}
	
	# Filter the request method to a small white list
	sub filter_method {
		my ( $method ) = @_;
		my $out = '';
		for ( $method ) {
			/HEAD/		and do { $out = 'head';		last; };
			/POST/		and do { $out = 'post';		last; };
			/DELETE/	and do { $out = 'delete';	last; };
			/PUT/		and do { $out = 'put';		last; };
			/PATCH/		and do { $out = 'patch';	last; };
			
			# Use get if all else failed
			$out = 'get';
		}
		return ( $out );
	}
	
	# Hash a password
	sub password {
		my ( $pass, $salt ) = @_;
		
		if ( !defined( $salt ) || $salt eq '' ) {
			$salt	= rnd( $ssize );
		}
		
		return crypt( $pass, $salt );
	}
	
	# Verify hashed password
	sub verify_pass {
		my ( $pass, $stored ) = @_;
		
		my $salt	= substr( $pass, 0, 2 );
		my $gen		= crypt( $pass, $salt );
		if ( $gen eq $stored ) {
			return 1;
		}
		return 0;
	}
	
	# Generate random data
	sub rnd {
		my $len	= shift;
		my $os	= $^O;
		
		if ( $os eq 'MSWin32' ) {
			return win_rnd( $len );
		}
		
		return nix_rnd( $len );
	}
	
	# Random data on a *nix machine
	# http://rosettacode.org/wiki/Random_number_generator_(device)
	sub nix_rnd {
		my $len = shift;
		my $dev = '/dev/urandom'; # Read from random device
		
		# Always fail when entropy source cannot be found
		open my $in, "<:raw", $dev
			or die "Can't open random device";
		
		sysread $in, my $rand, 4 * $len;
		return unpack( 'H*', $rand );
	}
	
	# Random data on Windows
	sub win_rnd {
		my $len = shift;
		# Workaround for lack of random device access
		# http://stackoverflow.com/a/10336772
		my $rand = sprintf( "%08X", 
				( rand( 0x8000 ) << 17 ) + 
				( rand( 0x8000 ) << 2 ) + 
				rand( 0b100 )
			);
		
		return substr( $rand, 0, $len );
	}
	
	# Redirect and end script execution
	sub redir {
		my $url = shift;
		print "Status: 302 Moved\n";
		print "Location: $url\n\n";
		exit ( 0 );
	}
	
	# Trim text
	sub trim {
		my $data = shift;
		$data	=~ s/^\s+//;
		$data	=~ s/\s+$//;
		
		return $data;
	}
	
	####		Templates		####
	
	# Render a given template
	sub render {
		my ( $name, %data, $ctheme ) = @_;
		my $tpl		= load_template( $name, $ctheme );
		my $html	= placeholders( $tpl, %data );
		print "Content-type: text/html\n\n";
		print $html;
		
		exit( 0 );
	}
	
	# Substitute placeholders with sent data
	sub placeholders {
		my ( $tpl, %data ) = @_;
		
		# Swap {label} markers with label => values from $data
		$tpl =~ s/\{([\w]+)\}/$data{$1}/g;
		return $tpl;
	}
	
	# Load a template file
	sub load_template {
		my ( $name, $ctheme )	= @_;
		my $ltheme		= $ctheme ? $ctheme : $theme;
		my $file		= $templates . '/' . 
						$ltheme . '/' . 
						$name . '.html';
		my $tpl			= '';
		
		open( my $fh, '<:encoding(UTF-8)', $file )
			or die ( 'Unable to find template' );
		
		while ( my $row = <$fh> ) {
			chomp( $row );
			$tpl .= "$row\n";
		}
		close $fh;
		return $tpl;
	}
}

__END__

