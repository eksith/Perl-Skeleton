#!/usr/bin/perl -T

use strict;
use warnings;

# Unicode handling
use utf8;

# PerlSkeleton Configuration settings and variables
package PerlSkeleton::Config;
{
	# Base variables
	our $app	= 'Perl Skeleton';		# App name
	our $version	= '0.1';			# App version
	
	our $ssize	= 16;				# Password salt size
	our $passlen	= 48;				# Password hash length
	our $rounds	= 10000;			# Hash rounds
	our $robots	= "index, follow";		# Robots meta tag
	our $maxclen	= 50000;			# Maximum content length (bytes)
	our $rblock	= 1024;				# Read block size
	
	our $formexp	= 3600;				# Input form expiration (1 hour)
	our $cookiexp	= 604800;			# Cookie expiration (7 days)
	
	our $store	= 'data';			# Storage folder (ideally outside web root)
	
	our $templates	= 'templates';			# Templates directory
	our $theme	= 'basic';			# Template name
	
	
	# Common vars (always sent)
	our ( $uri, $scheme, $method ) = (
		$ENV{'REQUEST_URI'},			# Visitor path
		$ENV{'REQUEST_SCHEME'},			# http or https
		$ENV{'REQUEST_METHOD'}			# GET, POST etc...
	);
	
	# Common options (usually sent, sometimes broken)
	our %opts = (
		'lang'		=> 'HTTP_ACCEPT_LANGUAGE',	# Preferred language
		'ua'		=> 'HTTP_USER_AGENT',		# User agent string
		'enc'		=> 'HTTP_ACCEPT_ENCODING',	# Character encoding
		'dnt'		=> 'HTTP_DNT',			# Do not track token
		'addr'		=> 'REMOTE_ADDR',		# IP address
		'qs'		=> 'QUERY_STRING',		# Any querystrings
		'clen'		=> 'CONTENT_LENGTH',		# Content length
		'cookie'	=> 'HTTP_COOKIE'		# User cookie
	);
	
	# Common meta tags
	our %common_meta = (
		
		# Mobile compatibility
		viewport	=> 'width=device-width, initial-scale=1',
		
		# Show application name (comment this out to hide)
		generator	=> "$app $version",
		
		# Robot follow/index
		robots		=> $robots
	);
	
	# Routing and verification substitutions for brevity
	our %routesubs = (
		# REST actions
		':action'	=> '(?<action>new|edit|delete|save)',
		
		# Calendar markers (2xxx, 01-12, 01-3x)
		':year'		=> '(?<year>[2][0-9]{3})',	
		':month'	=> '(?<month>[0-1][0-2]{1})',
		':day'		=> '(?<day>[0-3][0-9]{1})',
		
		# Page slug (search engine friendly string)
		':slug'		=> '(?<slug>\w{1,80})',
		
		# Pagination number (up to 999)
		':page'		=> '(?<page>[1-9][0-9]{0,2})',
		
		# Account
		':user'		=> '(?<user>[\w\-]{2,30})',
		':pass'		=> '(?<pass>[\x20-\x7E]{5,255})',
		':email'	=> '(?<email>[\x21-\x7E\.]{5,255})', # Not even gonna try
		':account'	=> '(?<account>login|register|changepass|logout)',
		
		# Category
		':category'	=> '(?<cat>[\w]{3,20})',
		
		# Everything
		'*'		=> '(?<all>.+?)'
	);
}

1;

__END__
