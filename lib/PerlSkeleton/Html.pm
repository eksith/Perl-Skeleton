#!/usr/bin/perl -T

use strict;
use warnings;

# Package modules
use Unicode::Normalize;					# Needed for URL slugs and special characters


BEGIN {
use lib '.';
use PerlSkeleton::Config;

# Aliasing
*config:: 	= *PerlSkeleton::Config::;
}

# PerlSkeleton Meta tag and HTML Handling and filtering
package PerlSkeleton::Html;
{
	
	# Trim text
	sub trim {
		my $data = shift;
		if ( !$data ) {
			return '';
		}
		
		$data	=~ s/^\s+//;
		$data	=~ s/\s+$//;
		
		return $data;
	}
	
	# Create a URL slug
	# http://stackoverflow.com/a/4009519
	sub slugify {
		my ( $txt ) = shift;
		if ( !$txt ) {
			return '';
		}
		
		$txt	= Unicode::Normalize::NFKD( $txt );	# Normalize the Unicode string
		$txt	=~ tr/\000-\177//cd;	# Strip non-ASCII characters (>127)
		$txt	=~ s/[^\w\s-]//g;	# Remove all characters that are not word characters (includes _), spaces, or hyphens
		$txt	=~ s/^\s+|\s+$//g;	# Trim whitespace from both ends
		$txt	= lc( $txt );		# Lowercase
		$txt	=~ s/[-\s]+/-/g;        # Replace all occurrences of spaces and hyphens with a single hyphen
		
		return $txt;
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
	
	# Render a given template
	sub render {
		my ( $name, %data, $ctheme ) = @_;
		my $tpl		= load_template( $name, $ctheme );
		my $html	= placeholders( $tpl, %data );
		
		print "Content-Type: text/html; charset=utf-8\n\n";
		print $html;
		
		exit( 0 );
	}
	
	# Substitute placeholders with sent data
	sub placeholders {
		my ( $tpl, %data ) = @_;
		if ( !$tpl ) {
			return '';
		}
		if ( !%data ) {
			return $tpl;
		}
		
		# Swap {label} markers with label => values from $data
		$tpl =~ s/\{([\w]+)\}/$data{$1}/g;
		return $tpl;
	}
	
	# Load a template file
	sub load_template {
		my ( $name, $ctheme )	= @_;
		my $ltheme		= 
		$ctheme ? $ctheme : $config::theme;
		
		my $file		= 
		$config::templates . '/' . 
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
	
	
	
	
	####		HTML Handling		####
	
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
	
	# Convert non-ASCII characters
	sub html_to_ascii {
		my $text	= shift;
		
		$text =~ s/([^[:ascii:]])/'&#' . ord($1) . ';'/ge;
		return $text;
	}
	
	# Escape special characters
	sub html_special {
		my $text	= shift;
		my %chars = (
			'&'	=> '&amp;',
			'<'	=> '&lt;',
			'>'	=> '&gt;',
			'"'	=> '&quot;',
			q{'}	=> '&apos;'
		);
		
		$text =~ s/([&<>"'])/$chars{$1}/g;
		return $text;
	}
	
	# Markdown links
	# https://gist.github.com/jbroadway/2836900
	# http://www.perlmonks.org/?node_id=647616
	# https://gist.github.com/kappa/312135
	# https://github.com/eksith/Zine/blob/master/index.php#L866
	sub html_links {
		my ( $img, $txt, $url ) = @_;
		$img = scrub( $img );
		$url = scrub( $url );
		$txt = scrub( $txt );
		
		if ( $img ) {
			return sprintf( "<img src='%s' alt='%s' />", $url, $txt );
		}
		return sprintf( "<a href='%s'>%s</a>", $txt, $url );
	}
	
	
	# Markdown (TODO (Hopefully before Jesus comes back) )
	sub markdown {
		my %find = (
			# Links 
			'/(\!)?\[([^\[]+)\]\(([^\)]+)\)/s'	=> \&html_links,
			'/(\*(\*)?|_(_)?|\~\~|\:\")(.*?)\1/'	=> '',
			'/([#]{1,6}+)\s?(.+)/'			=> '',
			'/\n(\*|([0-9]\.+))\s?(.+)/'		=> '',
			'/<\/(ul|ol)>\s?<\1>/'			=> '',
			'/\n\>\s(.*)/'				=> '',
			'/<\/(p)><\/(blockquote)>\s?<\2>/'	=> '',
			'/\n`{3,}(.*)\n`{3,}/'			=> '',
			'/`(.*)`/'				=> '',
			'/\n-{5,}/'				=> '',
			'/\n([^\n(\<\/ul|ol|li|h|blockquote|code|pre)?]+)\n/'		=> ''
		);
		
	}
	
	
	# Convert raw text to HTML 
	sub html {
		my ( $text, $mark ) = @_;
		
		my $html = html_special( $text );
		if ( !$mark ) {
			$mark = 0;
		}
		
		return $html;
	}
}

1;

__END__
