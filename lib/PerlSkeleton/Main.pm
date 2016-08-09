#!/usr/bin/perl -T

use strict;
use warnings;

# Unicode handling
use utf8;

# Required modules
use Time::Local qw( timelocal );			# Needed for calendar and timestamps
use Encode qw ( encode decode );			# Needed for character encoding

BEGIN {

use lib '.';

use PerlSkeleton::Config;
use PerlSkeleton::Html;
use PerlSkeleton::Routes;
use PerlSkeleton::Util;

# Aliasing ( for sanity )
*config:: 	= *PerlSkeleton::Config::;
*html:: 	= *PerlSkeleton::Html::;
*routes::	= *PerlSkeleton::Routes::;
*util:: 	= *PerlSkeleton::Util::;
}

package PerlSkeleton::Main {
	
	# Configuration settings
	our %settings;
	
	# Cookie data
	our %cookie;
	
	# Visitor signature
	our $signature;
	
	####		Core functions		####
	
	# Initialization
	sub start {
		my $uri		= $config::uri;
		my $scheme	= $config::scheme; 
		my $method	= $config::method;
		
		# Filter request method
		$method	= filter_method( $method );
		
		# Find which common vars are set in the options
		foreach my $okey ( keys %config::opts ) {
			
			# If the environment variable is defined...
			if ( defined $ENV{$config::opts{$okey}} ) {
				$config::opts{$okey} = 
					$ENV{$config::opts{$okey}};
			} else {
				$config::opts{$okey} = undef;
			}
		}
		
		# Load any cookie data
		cookie_data();
		
		# Call router
		router( $uri, $method );
	}
	
	# URL path router
	sub router {
		my ( $path, $method )	= @_;
		if ( !$path || !$method ) {
			return;
		}
		my $found = 0;
		
		# Iterate through given routes
		foreach my $route ( sort keys %routes::paths ) {
			my $filter =  filter_route( $route );
			my %params;	# Placeholder vars
			
			# If we found this route has a handler
			if ( $path =~ m/^$filter(\/)?$/i ) {
				$found = 1;
				
				# Push named parameters into capture hash
				$params{$_} = $+{$_} for keys %+;
				
				# Call designated handler
				$routes::paths{$route}->( 
					$method, $path, %params 
				);
				
				# Break out of search
				last;
			}
		}
		
		if ( $found ) {
			return;
		}
		
		# Fallback to not found
		routes::not_found( $method, $path );
	}
	
	# Replace convenience placeholders with regex equivalents
	sub filter_route {
		my $route	= shift;
		if ( !$route ) {
			return '';
		}
		
		$route =~ s/(\:\w+)/$config::routesubs{$1}/gi;
		
		return $route;
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
			/GET/		and do { $out = 'get';		last; };
		}
		
		if ( $out ne '' ) {
			return ( $out );
		}
		
		print 'Method not allowed';
		exit(0);
	}
	
	# Get a specific setting
	sub setting {
		my $name	= shift;
		if ( !%settings ) {
			%settings = load_settings();
		}
		
		return exists( $settings{$name} ) ? 
				$settings{$name} : '';
	}
	
	# Settings file
	sub load_settings {
		# TODO
	}
	
	# Generate an anti-cross-site request forgery token
	sub gen_csrf {
		my ( $form, $path ) = @_;
		my $salt	= util::rnd( 6 );
		my %cdata	= (
			'nonce'	=> util::rnd( 6 ),
			'exp'	=> time() + $config::formexp
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
		
		# Reset cookie after verification
		set_cookie( 
			$form . 'form', 
			( 'nonce' => '', 'exp' => 0 ) 
		);
		
		if ( !%data ) {
			return 0;
		}
		
		# Empty values?
		if ( !$data{'nonce'} || !$data{'exp'} ) {
			return 0;
		}
		
		# Check for anti-CSRF token expiration
		my $exp = int( $data{'exp'} );
		if ( $exp < time() - $config::formexp ) {
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
	
	
	# Find posts by date
	sub find_by_date {
		my ( %params )	= @_;
		
		
		my $out = '<p>';
		foreach my $k ( sort keys %params ) {
			$out .= $k . ' = ' . $params{$k};
			$out .= "; ";
		}
		
		$out .= "</p>";
		
		return $out;
	}
	
	# Hash a password
	sub password {
		my ( $pass, $salt ) = @_;
		
		if ( !defined( $salt ) || $salt eq '' ) {
			$salt	= util::rnd( $config::ssize );
		}
		
		# Generate hash
		my $hash	= 
		util::genpbk( 
			$pass, $salt, $config::rounds, $config::passlen 
		);
		
		# Convert to hex
		my $password	= unpack( "H*", $hash );
		
		# Package constituents
		return 
		join( '$', $salt, 
			$config::rounds, 
			$config::passlen, 
			$password 
		);
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
		util::genpbk( 
			$pass, $salt, $rounds, $passlen 
		);
		
		my $password	= unpack( "H*", $hash );
		
		# Sent password hash matches stored hash
		if ( $password eq $raw ) {
			return 1;
		}
		
		# Defaults to false
		return 0;
	}
	
	# Redirect and end script execution
	sub redir {
		my $url = shift;
		print "Status: 302 Moved\n";
		print "Location: $url\n\n";
		exit ( 0 );
	}
	
	
	
	####	Cookies and authorization	####
	
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
			
			# PerlSkeleton::Util clean cookie data
			$name	= util::clean_name( $name );
			$value	= util::clean_param( $value );
			
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
		my $c	= $config::opts{'cookie'};
		if ( !$c ) {
			return '';
		}
		
		# Basic clean
		$c	= util::scrub( $c );
		
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
		util::sha256( $raw . signature() ) ;
		
		$raw			= util::base64_encode( $raw );
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
			util::base64_decode( $raw );
			
			# Verify checksum against current user signature
			my $verify		= 
			util::sha256( $raw . signature() );
			
			# Check cookie checksum
			if ( $check ne $verify ) {
				return %data;
			}
			
			# Split key/value pairs by delimiter
			my @seg	= split( /;/, $raw );
			
			foreach ( @seg ) {
				
				# Extract key value pairs
				my ( $k, $v ) = split( /=/, $_ );
				$data{$k} = util::scrub( $v );
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
		
		my $exp = gmtime( time() + $config::cookiexp );
		foreach my $k ( keys %cookie ) {
			print 
			"Set-Cookie: $k=$cookie{$k}; path=$path; expires=$exp;\n";
		}
	}
	
	# Visitor signature
	sub signature {
		if ( $signature ) {
			return $signature;
		}
		my $ua		= $config::opts{'ua'};	# User agent string
		my $addr	= $config::opts{'addr'};	# IP address
		my $lang	= $config::opts{'lang'};	# Accept language
		my $dnt		= $config::opts{'dnt'};	# Do Not Track
		
		$signature	= 
		util::sha256( $ua . $addr . $lang . $dnt );
		
		return $signature;
	}
	
	# Authorization
	sub authorization {
		# TODO
		return 1;
	}
	
	
	####		Form handling		####
	
	# Raw data sent by the user
	# http://www.perlmonks.org/?node_id=135323
	sub raw_content {
		
		# Require content length
		if ( !$config::opts{'clen'} ) {
			%config::opts = ( 
				%config::opts, 
				( clen => $config::maxclen ) 
			);
		}
		
		if ( 
			$config::opts{'clen'} > 
			$config::maxclen 
		) {
			return '';
		}
		
		my $data	= '';
		my $len		= 0;
		my $raw;
		
		# Read user input in chunks up to maximum content length
		while( read( STDIN, $raw, $config::rblock ) ) {
			if ( 
				$len > $config::opts{'clen'} || 
				( $len + $config::rblock ) > 
					$config::maxclen 
			) {
				die( 'Content exceeded' );
			}
			$data	.= $raw;
			$len	+= $config::rblock;
		}
		
		return html::trim( $data );
	}
	
	# Form data
	sub form_data {
		my $method	= shift;
		my $raw;
		my @sent;
		
		for ( $method ) {
			/get/ and do { 
				# Check for empty query string
				if ( !defined( $config::opts{'qs'} ) ) {
				}
				
				# Get sent values from the query string
				$raw	= $config::opts{'qs'};
				last; 
			};
			
			/post/ and do {
				# Check for empty content length
				if ( !defined( $config::opts{'clen'} ) ) {
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
	
	# Process form data
	sub parse_form {
		my $raw		= shift;
		my @sent	= split( /&/, $raw );
		my %parsed;
		
		foreach my $data ( @sent ) {
			my ( $name, $value ) = split( /=/, $data );
			
			# PerlSkeleton::Util cleaning
			$name	= util::clean_name( $name );
			$value	= util::clean_param( $value );
			
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
}

1;

__END__
