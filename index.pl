#!/usr/bin/perl

# Perl Skeleton is a simple web page starter for basic sites
# Includes:
#	- Simple URL router
#	- HTML input field generation
#	- Meta tag generation

use v5.20;						# Perl version
use strict;
use warnings;

{
	# Base variables
	my $app		= 'Perl Skeleton';		# App name
	my $version	= '0.1';			# App version
	
	
	my $ssize	= 16;				# Password salt size
	my $robots	= "index, follow";		# Robots meta tag
	
	# Common vars (always sent)
	my ( $uri, $scheme, $method ) = (
		$ENV{'REQUEST_URI'},			# Visitor path
		$ENV{'REQUEST_SCHEME'},			# http or https
		$ENV{'REQUEST_METHOD'}			# GET, POST etc...
	);
	
	# Common options (usually sent, sometimes broken)
	my %opts = (
		lang	=> 'HTTP_ACCEPT_LANGUAGE',	# Preferred language
		ua	=> 'HTTP_USER_AGENT',		# User agent string
		enc	=> 'HTTP_ACCEPT_ENCODING',	# Character encoding
		dnt	=> 'HTTP_DNT',			# Do not track token
		addr	=> 'REMOTE_ADDR',		# IP address
		qs	=> 'QUERY_STRING'		# Any querystrings
	);
	
	# Application routes (add/edit as needed)
	# https://stackoverflow.com/questions/1915616/how-can-i-elegantly-call-a-perl-subroutine-whose-name-is-held-in-a-variable#1915709
	my %routes = (
		'/'		=> \&home,		# Home route
		'/(\d+)'	=> \&home,		# Home pagination
		
		'/post/(\w+)'	=> \&page,		# Read a page
		
		'/new'		=> \&new_page,		# Create a page
		'/edit/(\w+)'	=> \&edit_page,		# Edit a page
		'/save'		=> \&save_page,		# Save a page
		
		'/login'	=> \&login,		# User login
		'/logout'	=> \&logout		# User logout
	);
	
	
	
	
	####		Page routes (per above)	####
	
	# Do homey things
	sub home {
		my ( $method, $path, %tags ) = @_;
		
		# Merge default meta tags with our own
		%tags = ( %tags, (
			description	=> 'Achtung Baby',
			author		=> 'Bono'
		) );
		
		# Render a basic HTML page
		html( 'Home', 'Welcome ' . $path, %tags );
	}
	
	# Do post reading things
	sub page {
		my ( $method, $path, %tags ) = @_;
		
		# Reading a page
		html( 'This is a test page', 'Hello World' . $path, %tags );
	}
	
	# Do new page things
	sub new_page {
		my ( $method, $path, %tags ) = @_;
		
		my $title	= input( 'title', 'text', '' );
		my %tattr	= (
			placeholder	=> 'Content'
		);
		my $out		= text( 'body', '', 6, 60, %tattr );
		
		
		my $ht		= "<p>$title</p><p>$out</p>";
		
		html( 'New page', $ht, %tags );
	}
	
	# Do save page things
	sub save_page {
		my ( $method, $path, %tags ) = @_;
		
		# After saving the page, redirect
		redir( '/' );
	}
	
	# Do page editing things
	sub edit_page {
		my ( $method, $path, %tags ) = @_;
		
		html( 'Editing', 'Edit existing page', %tags );
	}
	
	# Do logging in things
	sub login {
		my ( $method, $path, %tags ) = @_;
		
		given ( $method ) {
			when( 'post' ) {
				
			}
			
			# Everything else display login form
			default {
				html( 'Login', 'Login user', %tags );
			}
		}
	}
	
	# Do logging out things
	sub logout {
		my ( $method, $path, %tags ) = @_;
		
	}
	
	# Do not found things
	sub not_found {
		my ( $method, $path, %tags ) = @_;
		
		html( '404 Not found', "Couldn't find the page you're looking for$path", %tags );
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
		
		# Generator meta tag gets added first
		# Comment this part out if you don't want it shown
		my %tags = (
			generator	=> "$app $version"
		);
		
		# Call router
		router( $uri, %tags );
	}
	
	# URL path router
	sub router {
		my ( $path, %tags ) = @_;
		
		# Iterate through given routes
		foreach my $route ( keys %routes ) {
			
			# If we found this route has a handler
			if ( $path =~  s/^$route$//i ) {
				# Call designated handler
				$routes{$route}->( $method, $path, %tags );
				
				# Break out of search
				return;
			}
		}
		
		# Fallback to not found
		not_found( $method, $path, %tags );
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
		print "<head>\n<meta charset=\"utf-8\" />\n";
		
		# Header content
		title( $title );
		meta_tags( %tags );
		
		print "</head>\n";
	}
	
	# Print page title
	sub title {
		my $title = shift;
		print tag( 'title', "$title", 0, 1 );
	}
	
	# Print meta tags
	sub meta_tags {
		my ( %tags ) = @_;
		
		foreach my $k ( sort keys %tags ) {
			meta_tag( $k, $tags{$k} );
		}
	}
	
	# Print individual meta tag
	sub meta_tag {
		my ( $name, $value ) = @_;
		print "<meta name=\"$name\" content=\"$value\" />\n";
	}
	
	# Content page body
	sub body {
		my $body	= shift;
		print tag( 'body', "\n$body\n", 0, 1 );
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
		my %mtags = ( (
			viewport	=> 'width=device-width, initial-scale=1',
			robots		=> $robots
		), %sent_meta );
		
		# Put together the HTML page
		preamble();
		heading( $title, %mtags );
		body( $body );
		
		ending();
	}
	
	# Create a generic HTML tag
	sub tag {
		my ( $name, $value, $close, $br, %attr ) = @_;
		my $out = "";
		
		# Fix empty values
		if ( !defined( $value ) ) {
			$value = '';
		}
		
		if ( $close ) { # Self closing
			my %sat = ( %attr, (
				value => $value
			) );
			my $at = attr( %sat );
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
		
		return ( $out );
	}
	
	
	
	
	####		Helpers			####
	
	
	# Filter the request method to a small white list
	sub filter_method {
		my ( $method ) = @_;
		my $out = '';
		
		given( $method ) {
			$out = 'head'	when 'HEAD';
			$out = 'post'	when 'POST';
			$out = 'delete'	when 'DELETE';
			$out = 'put'	when 'PUT';
			$out = 'patch'	when 'PATCH';
			
			# Use get if all else failed
			default { $out = 'get'; }
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
		unpack( 'H*', $rand );
		return $rand;
		
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
	
	
	####		Templates		####
	# TODO
}

