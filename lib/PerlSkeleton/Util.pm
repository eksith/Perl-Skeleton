#!/usr/bin/perl -T

use strict;
use warnings;

use Digest::SHA qw( hmac_sha1 sha256_hex );		# Needed for pbkdf2 and checksums
use MIME::Base64 qw( encode_base64 decode_base64 );	# Needed for safe packaging

# Unicode handling
use utf8;

# Utilities and helpers
package PerlSkeleton::Util;
{
	# Base64 encode binary or text data
	sub base64_encode {
		my $value	= shift;
		return MIME::Base64::encode_base64( $value, '' );
	}
	
	# Base64 decode in same format
	sub base64_decode {
		my $value	= shift;
		return MIME::Base64::decode_base64( $value );
	}
	
	# Clean a parameter
	sub clean_param {
		my $value	= shift;
		if ( !$value ) {
			return '';
		}
			
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
		if ( !$value ) {
			return '';
		}
		
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
	
	# Hexadecimal sha256
	sub sha256 {
		my $value	= shift;
		return Digest::SHA::sha256_hex( $value );
	}
	
	# Derive key with sha1 hmac
	sub genpbk {
		my ( $pass, $salt, $rounds, $passlen ) = @_;
		return 
		pbkdf2( 
			\&Digest::SHA::hmac_sha1, $pass, $salt, 
			$rounds, 
			$passlen 
		);
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
}

1;

__END__
