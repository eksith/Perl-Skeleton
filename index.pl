#!/usr/bin/perl -T

# Perl Skeleton is a simple web page starter for basic sites
# Includes:
#	- Simple URL router
#	- HTML templates
#	- Meta tag generation

use v5.20;						# Perl version
use strict;
use warnings;

use Digest::SHA qw( hmac_sha1 sha256_hex );		# Needed for pbkdf2 and checksums
use MIME::Base64 qw( encode_base64 decode_base64 );	# Needed for safe packaging

package PerlSkeleton;
{
	# Base variables
	my $app		= 'Perl Skeleton';		# App name
	my $version	= '0.1';			# App version
	
	my $store	= 'data';			# Storage folder (ideally outside web root)
	my $templates	= 'templates';			# Templates directory
	my $theme	= 'basic';			# Template name
	
	my $ssize	= 16;				# Password salt size
	my $passlen	= 48;				# Password hash length
	my $rounds	= 10000;			# Hash rounds
	my $robots	= "index, follow";		# Robots meta tag
	my $maxclen	= 50000;			# Maximum content length (bytes)
	my $rblock	= 1024;				# Read block size
	
	my $formexp	= 3600;				# Input form expiration (1 hour)
	my $cookiexp	= 604800;			# Cookie expiration (7 days)
	
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
		'lang'		=> 'HTTP_ACCEPT_LANGUAGE',	# Preferred language
		'ua'		=> 'HTTP_USER_AGENT',		# User agent string
		'enc'		=> 'HTTP_ACCEPT_ENCODING',	# Character encoding
		'dnt'		=> 'HTTP_DNT',			# Do not track token
		'addr'		=> 'REMOTE_ADDR',		# IP address
		'qs'		=> 'QUERY_STRING',		# Any querystrings
		'clen'		=> 'CONTENT_LENGTH',		# Content length
		'cookie'	=> 'HTTP_COOKIE'		# User cookie
	);
	
	# Application routes (add/edit as needed)
	# https://stackoverflow.com/questions/1915616/how-can-i-elegantly-call-a-perl-subroutine-whose-name-is-held-in-a-variable#1915709
	my %routes = (
		'/'					=> \&home,		# Home route
		'/posts'				=> \&home,
		'/page:page'				=> \&home,		# Home pagination
		
		# Browse the archives
		'/posts/:year'				=> \&archive,
		'/posts/:year/page:page'		=> \&archive,
		
		'/posts/:year/:month'			=> \&archive,
		'/posts/:year/:month/page:page'		=> \&archive,
		
		'/posts/:year/:month/:day'		=> \&archive,
		'/posts/:year/:month/:day/page:page'	=> \&archive,
		
		# Read a page
		'/posts/:year/:month/:day/:slug'	=> \&page,
		
		# Edit a page
		'/edit/:year/:month/:day/:slug'		=> \&edit_page,
		
		'/new'					=> \&new_page,		# Create a page
		'/save'					=> \&save_page,		# Save a page
		
		'/login'				=> \&login,		# User login
		'/logout'				=> \&logout,		# User logout
		'/changepass'				=> \&change_pass	# Change login password
	);
	
	
	
	####		Internal variables	####
	
	# Common meta tags
	my %common_meta = (
		
		# Mobile compatibility
		viewport	=> 'width=device-width, initial-scale=1',
		
		# Show application name (comment this out to hide)
		generator	=> "$app $version",
		
		# Robot follow/index
		robots		=> $robots
	);
	
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
	
	# Configuration settings
	my %settings;
	
	# Cookie data
	my %cookie;
	
	
	
	####		Page routes (per above)	####
	
	# Do homey things
	sub home {
		my ( $method, $path, %params ) = @_;
		
		# Meta tags
		my %mtags	= 
		( 
			%common_meta, (
				description	=> 'Achtung Baby',
				author		=> 'Bono'
			) 
		);
		
		my $test	= '<p>Hello world</p>';
		
		# Page template variables
		my %template	= (
			'title'		=> 'Home',
			'heading'	=> 'Welcome',
			'body'		=> $test,
			'meta'		=> meta_tags( %mtags )
		);
		
		# Send cookie values before rendering
		send_cookie();
		
		# Render a basic HTML page
		render( 'index', %template );
	}
	
	# Do post reading things
	sub page {
		my ( $method, $path, %params ) = @_;
		
		my %mtags	= 
		( 
			%common_meta, (
				description	=> 'Page description',
				author		=> 'Page author'
			) 
		);
		
		# Build reading page
		my %template	= (
			'title'		=> 'Reading a page',
			'heading'	=> 'Viewing a content page',
			'body'		=> '<p>Hello world</p>',
			'meta'		=> meta_tags( %mtags )
		);
		
		send_cookie();
		
		# Render page read
		render( 'post', %template );
	}
	
	# Do archive things
	sub archive {
		my ( $method, $path, %params ) = @_;
		my $out		= '';
		
		# Override description
		my %mtags	= 
		( 
			%common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Get posts by date
		my $archives = find_by_date( %params );
		
		my %template	= (
			'title'		=> 'Archive',
			'heading'	=> 'This is an archive page',
			'body'		=> $out,
			'meta'		=> meta_tags( %mtags )
		);
		
		send_cookie();
		render( 'archive', %template );
	}
	
	# Do new page things
	sub new_page {
		my ( $method, $path, %params ) = @_;
		
		# Override robots follow
		my %mtags	= 
		( 
			%common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Create anti-CSRF token
		my $csrf	= gen_csrf( 'editpage', '/save' );
		
		# Build new page
		my %template	= (
			'title'		=> 'Create a new page',
			'heading'	=> 'Creating a new page',
			'action'	=> '/save',
			'csrf'		=> $csrf,
			'meta'		=> meta_tags( %mtags )
		);
		
		send_cookie();
		render( 'new', %template );
	}
	
	# Do page editing things
	sub edit_page {
		my ( $method, $path, %params ) = @_;
		
		# Override robots follow
		my %mtags	= 
		( 
			%common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		my $csrf	= gen_csrf( 'editpage', '/save' );
		
		# TODO Find page to edit
		
		# Build edit page
		my %template	= (
			'title'		=> 'Edit a page',
			'heading'	=> 'Editing a created page',
			'page_title'	=> 'A test page',
			'page_body'	=> 'Test content',
			'page_pub'	=> '6/18/2016',
			'action'	=> '/save',
			'csrf'		=> $csrf,
			'meta'		=> meta_tags( %mtags )
		);
		
		send_cookie();
		render( 'edit', %template );
	}
	
	# Do save page things
	sub save_page {
		my ( $method, $path, %params ) = @_;
		
		# Post data was sent
		if ( $method eq "post" ) {
			my %data	= form_data( 'post' );
			
			# Check anti-CSRFtoken
			my $csrf	= field( 'csrf', %data );
			if ( !verify_csrf( 'editpage', $path, $csrf ) ) {
				redir( '/' );
			}
			
			my $content	= field( 'body', %data );
			my $title	= field( 'title', %data );
			
			# Merge any sent meta tags with default ones
			my %mtags = 
			( 
				%common_meta, 
				( robots => 'noindex, nofollow' ) 
			);
			
			my %template	= (
				'title'		=> 'Newly saved page',
				'heading'	=> $title,
				'meta'		=> meta_tags( %common_meta ),
				'body'		=> $content
			);
			
			send_cookie();
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
			
			# Process login
			my %data	= form_data( 'post' );
			my $csrf	= field( 'csrf', %data );
			
			# If anti-CSRF token failed, redirect to home
			if ( !verify_csrf( 'loginpage', $path, $csrf ) ) {
				redir( '/' );
			}
			
			# TODO check login
		}
	
		# Everything else,  display login form
		my %mtags	= 
		( 
			%common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Anti-CSRF token
		my $csrf	= gen_csrf( 'loginpage', '/login' );
		
		# TODO access login data
		
		# Build login page
		my %template	= (
			'title'		=> 'Login',
			'heading'	=> 'Site access',
			'action'	=> '/login',
			'csrf'		=> $csrf,
			'meta'		=> meta_tags( %mtags )
		);
				
		send_cookie();
		render( 'login', %template );
	}
	
	# Do logging out things
	sub logout {
		my ( $method, $path, %params ) = @_;
		
		send_cookie();
	}
	
	# Do password changing things
	sub change_pass {
		my ( $method, $path, %params ) = @_;
		
		# Data was sent
		if ( $method eq 'post' ) {
			
			# Process change password
			my %data	= form_data( 'post' );
			my $csrf	= field( 'csrf', %data );
			if ( !verify_csrf( 'loginpage', $path, $csrf ) ) {
				redir( '/' );
			}
			
			# TODO change password
		}
		
		my %mtags = 
		( 
			%common_meta, 
			( robots => 'noindex, nofollow' )
		);
		
		my $csrf	= gen_csrf( 'passpage', '/changepass' );
		
		my %template	= (
			'title'		=> 'Change password',
			'heading'	=> "Change your password",
			'action'	=> '/changepass',
			'csrf'		=> $csrf,
			'meta'		=> meta_tags( %mtags )
		);
		
		send_cookie();
		render( 'changepass', %template );
	}
	
	# Do saving new password things
	sub save_pass {
		my ( $method, $path, %params ) = @_;
		
		send_cookie();
		
		# After changing the password, redirect
		redir( '/' );
	}
	
	# Do not found things
	sub not_found {
		my ( $method, $path ) = @_;
		my %mtags = ( 
			%common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Build 404 page
		my %template	= (
			'title'		=> '404 Not found',
			'heading'	=> "Couldn't find the page you're looking for",
			'meta'		=> meta_tags( %mtags ),
			'body'		=> '<p>Return to <a href="/">index</a>.</p>'
		);
		
		render( '404', %template );
	}
	
	
	
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
		
		# Load any cookie data
		cookie_data();
		
		# Call router
		router( $uri );
	}
	
	# URL path router
	sub router {
		my $path	= shift;
		my $matches;
		
		# Iterate through given routes
		foreach my $route ( sort keys %routes ) {
			my $filter =  filter_route( $route );
			my %params;	# Placeholder vars
			
			# If we found this route has a handler
			if ( $path =~ m/^$filter(\/)?$/i ) {
				
				# Push named parameters into capture hash
				$params{$_} = $+{$_} for keys %+;
				
				# Call designated handler
				$routes{$route}->( 
					$method, $filter, %params 
				);
				
				# Break out of search
				return;
			}
		}
		
		# Fallback to not found
		not_found( $method, $path );
	}
	
	# Replace convenience placeholders with regex equivalents
	sub filter_route {
		my $route	= shift;
		$route =~ s/(\:\w+)/$routesubs{$1}/gi;
		return $route;
	}
	
	
	
	####		HTML Rendering		####
	
	# Print meta tags
	sub meta_tags {
		my ( %tags )	= @_;
		my $t = '';
		foreach my $k ( sort keys %tags ) {
			$t .= meta_tag( $k, $tags{$k} );
		}
		return $t;
	}
	
	# Print individual meta tag
	sub meta_tag {
		my ( $name, $value ) = @_;
		my %at = (
			name	=> $name,
			content	=> $value
		);
		return tag( 'meta', undef, 1, 1, %at );
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
				my %attr = 
				(  %attr, ( value => $value ) );
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
	
	# Create a selectbox with options and optional selected item
	# TODO
	sub select {
		my ( $name, $selected, %options, %attr ) = @_;
		foreach my $k ( keys %options ) {
			
		}
	}
	
	# Print attributes
	sub attr {
		my ( %attr )	= @_;
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
	
	
	
	
	####		File handling		####
	
	# Get a specific setting
	sub setting {
		my $name	= shift;
		if ( !%settings ) {
			%settings = load_settings();
		}
		
		return exists( $settings{$name} ) ? 
				$settings{$name} : '';
	}
	
	# Find posts by date
	sub find_by_date {
		my %params	= shift;
		
	}
	
	# Settings file
	sub load_settings {
		# TODO
	}
	
	# Browse for posts with a starting date
	sub browse {
		my ( %start, $limit, $page ) = @_;
		# TODO
	}
	
	# Look for posted comments on this post
	sub comments {
		my ( %path, $limit, $page ) = @_;
		# TODO
	}
	
	
	
	
	####		Form handling		####
	
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
				die( 'Content exceeded' );
			}
			$data	.= $raw;
			$len	+= $rblock;
		}
		
		return trim( $data );
	}
	
	# Form data
	sub form_data {
		my $method	= shift;
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
			die( 'Unknown method' );
		}
		
		return parse_form( $raw );
	}
	
	# Clean a parameter
	sub clean_param {
		my $value	= shift;
			
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
		my $value	= shift;
		
		# Strip non-printable chars including spaces
		$value =~ s/[[:^print:]\s]//g;
		
		return trim( $value );
	}
	
	# Generic clean
	sub scrub {
		my $value	= shift;
		
		if ( !$value ) {
			return '';
		}
			
		# Strip null bytes
		$value	=~ s/\x00$//;
		
		# Strip non-printable chars except spaces
		$value	=~ s/[[:^print:]]//g;
		
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
				my $size = scalar keys %{$parsed{$name}};
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
	
	
	
	# Get cookie data sent by the user (app specific)
	sub cookie_data {
		my $name	= shift;
		my @data	= raw_cookie();
		
		if ( !@data ) {
			return;
		}
		
		# Iterate through data
		foreach ( @data ) {
			# Each k/v pair
			my ( $name, $value ) = split( /=/, $_, 2 );
			
			# Scrub cookie data
			$name	= clean_name( $name );
			$value	= clean_param( $value );
			
			if ( !$name ) {
				next;
			}
			if ( !$value ) {
				$value = '';
			}
			
			$cookie{$name} = $value;
		}
	}
	
	# Get raw sent cookie 
	sub raw_cookie{
		my $c	= $opts{'cookie'};
		if ( !$c ) {
			return '';
		}
		
		# Basic clean
		$c	= scrub( $c );
		
		# Separate cookie data
		my @data = split( "[;,] ?", $c );
		chomp( @data );
		
		return @data;
	}
	
	# Set cookie data by name (key/value pairs)
	sub set_cookie {
		my ( $name, %data )	= @_;
		my $raw			= '';
		
		# Append key/value pairs marked by '=' separated by ';'
		foreach my $k ( keys %data ) {
			$raw .= join( '=',  $k, $data{$k} ) . ';';
		}
		
		# Get rid of last ';'
		chop( $raw );
		
		# Per key/value pair checksum with user signature
		my $check		= 
		Digest::SHA::sha256_hex( $raw . signature() ) ;
		
		$raw			= 
		MIME::Base64::encode_base64( $raw, '' );
		
		$cookie{$name}		= join( '|', $check, $raw );
	}
	
	# Get a specific cookie value
	sub get_cookie {
		my $name	= shift;
		my %data	= ();
		
		if ( exists( $cookie{$name} ) ) {
			
			# Checksum and encoded data
			my ( $check, $raw )	= 
				split( /\|/, $cookie{$name}, 2 );
			
			if ( !$check || !$raw ) {
				return %data;
			}
			
			$raw			= 
			MIME::Base64::decode_base64( $raw );
			
			# Verify checksum against current user signature
			my $verify		= 
			Digest::SHA::sha256_hex( $raw . signature() );
			
			# Check cookie checksum
			if ( $check ne $verify ) {
				return %data;
			}
			
			# Split key/value pairs by delimiter
			my @seg	= split( /;/, $raw );
			
			foreach ( @seg ) {
				
				# Extract key value pairs
				my ( $k, $v ) = split( /=/, $_ );
				$data{$k} = scrub( $v );
			}
		}
		return %data;
	}
	
	
	
	# Send cookie data to the user
	# http://www.comptechdoc.org/independent/web/cgi/perlmanual/perlcookie.html
	sub send_cookie {
		my $path	= shift;
		if ( !$path ) {
			$path = '/';
		}
		
		my $exp = gmtime( time() + $cookiexp );
		foreach my $k ( keys %cookie ) {
			print "Set-Cookie: $k=$cookie{$k}; path=$path; expires=$exp;\n";
		}
	}
	
	# Visitor signature
	sub signature {
		my $ua		= $opts{'ua'};		# User agent string
		my $addr	= $opts{'addr'};	# IP address
		my $lang	= $opts{'lang'};	# Accept language
		my $dnt		= $opts{'dnt'};		# Do Not Track
		
		my $hash = Digest::SHA::sha256_hex( $ua . $addr . $lang . $dnt );
		return unpack( "H*", $hash );
	}
	
	# Filter the request method to a small white list
	sub filter_method {
		my $method	= shift;
		my $out		= '';
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
	
	# Generate an anti-cross-site request forgery token
	sub gen_csrf {
		my ( $form, $path ) = @_;
		my $salt	= rnd( 6 );
		my %cdata	= (
			'nonce'	=> rnd( 6 ),
			'exp'	=> time() + $formexp
		);
		
		# Set the form nonce and expiration in the cookie
		set_cookie( $form . 'form', %cdata );
		
		my $token	= $form . $path . $cdata{'nonce'};
		
		return crypt( $token, $salt );		# 56 bit DES
	}
	
	# Verify anti-CSRF token
	sub verify_csrf {
		my ( $form, $path, $csrf ) = @_;
		
		# Get the form nonce and expiration from the cookie
		my %data	= get_cookie( $form . 'form' );
		if ( !%data ) {
			return 0;
		}
		
		# Empty values?
		if ( !$data{'nonce'} || !$data{'exp'} ) {
			return 1;
		}
		
		# Check for anti-CSRF token expiration
		my $exp = int( $data{'exp'} );
		if ( $exp < time() - $formexp ) {
			return 0;
		}
		
		my $salt	= substr( $csrf, 0, 2 );
		my $token	= $form . $path . $data{'nonce'};
		my $gen		= crypt( $token, $salt );
		
		# If generated token matches sent one, return true
		if ( $gen eq $csrf ) {
			return 1;
		}
		
		# Defaults to false
		return 0;
	}
	
	
	
	####		Helpers			####
	
	# Hash a password
	sub password {
		my ( $pass, $salt ) = @_;
		
		if ( !defined( $salt ) || $salt eq '' ) {
			$salt	= rnd( $ssize );
		}
		
		# Generate hash
		my $hash	= 
		pbkdf2( 
			\&Digest::SHA::hmac_sha1, $pass, $salt, 
			$rounds, $passlen 
		);
		
		# Convert to hex
		$hash		= unpack( "H*", $hash );
		
		# Package constituents
		return join( '$', $salt, $rounds, $passlen, $hash );
	}
	
	# Verify hashed password
	sub verify_pass {
		my ( $pass, $stored ) = @_;
		
		# Check stored components
		my $l		= length( $stored );
		
		# Too large or non-existent
		if ( !$l || $l > 500 ) {
			return 0;
		}
		
		# Break the package into constituents
		my @compile	= split( /\$/, $stored );
		
		# Check constituent size
		if ( scalar @compile != 4 ) {
			return 0;
		}
		
		# Break the components
		my ( $salt, $rounds, $passlen, $raw ) = @compile;
		$rounds		= int( $rounds );
		$passlen	= int( $passlen );
		
		# Create a hash with the given password
		my $hash	= 
		pbkdf2( 
			\&Digest::SHA::hmac_sha1, $pass, $salt, 
			$rounds, $passlen 
		);
		
		$hash		= unpack( "H*", $hash );
		
		# Sent password hash matches stored hash
		if ( $hash eq $raw ) {
			return 1;
		}
		
		# Defaults to false
		return 0;
	}
	
	# Password key derivation function
	# Initial function  Jochen Hoenicke <hoenicke@gmail.com> from the
	# Palm::Keyring perl module.  Found on the PerlMonks Forum
	# http://www.perlmonks.org/?node_id=631963
	sub pbkdf2 {
		my ( $prf, $pass, $salt, $iter, $len ) = @_;
		my ( $k, $t, $u, $ui, $i );
		
		$t = '';
		for ( $k = 1; length( $t ) <  $len; $k++ ) {
			$u = $ui = 
			&$prf( 
				$salt.pack( 'N', $k ), $pass 
			);
			
			for ( $i = 1; $i < $iter; $i++ ) {
				$ui	= &$prf( $ui, $pass );
				$u	^= $ui;
			}
			$t .= $u;
		}
		
		return substr( $t, 0, $len );
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
		
		$rand = substr( $rand, 0, $len );
		return unpack( 'H*', $rand );
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
