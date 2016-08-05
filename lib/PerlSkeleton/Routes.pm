#!/usr/bin/perl -T

use strict;
use warnings;

# Unicode handling
use utf8;

BEGIN {

use lib '.';

use PerlSkeleton::Config;
use PerlSkeleton::Html;
use PerlSkeleton::Main;

# Aliasing
*config:: 	= *PerlSkeleton::Config::;
*html:: 	= *PerlSkeleton::Html::;
*pmain::	= *PerlSkeleton::Main::;
}

# PerlSkeleton Page Routes
package PerlSkeleton::Routes;
{
	# Application routes (add/edit as needed)
	# https://stackoverflow.com/questions/1915616/how-can-i-elegantly-call-a-perl-subroutine-whose-name-is-held-in-a-variable#1915709
	our %paths = (
		# Home route
		'/'					=> \&home,
		# Home pagination		
		'/page:page'				=> \&home,
		
		# Browse the archives
		'/posts/:year'				=> \&archive,
		'/posts/:year/page:page'		=> \&archive,
		
		'/posts/:year/:month'			=> \&archive,
		'/posts/:year/:month/page:page'		=> \&archive,
		
		'/posts/:year/:month/:day'		=> \&archive,
		'/posts/:year/:month/:day/page:page'	=> \&archive,
		
		# Post modification/creation
		'/posts/:action'			=> \&post,
		'/posts/:action/:year/:month/:day/:slug'=> \&post,
		
		# Read a page
		'/posts/:year/:month/:day/:slug'	=> \&page,
		
		# User actions
		'/user/:account'			=> \&user
	);
	
	
	# Do homey things
	sub home {
		my ( $method, $path, %params ) = @_;
		
		# Meta tags
		my %mtags	= 
		( 
			%config::common_meta, (
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
			'meta'		=> 
			html::meta_tags( %mtags )
		);
		
		# Send cookie values before rendering
		pmain::send_cookie();
		
		# Render a basic HTML page
		html::render( 'index', %template );
	}
	
	# Do post things
	sub post {
		my ( $method, $path, %params ) = @_;
		my $mode = $params{'action'} ? 
				$params{'action'} : 'read';
		
		for ( $mode ) {
			/new/ and do {
				new_page( $method, $path, %params );
				last;
			};
			
			/edit/ and do {
				if ( 
					!$params{'year'}	|| 
					!$params{'month'}	|| 
					!$params{'day'}		|| 
					!$params{'slug'}
				) {
					pmain::redir( '/' );
				}
				edit_page( $method, $path, %params );
				last;
			};
			
			/save/ and do {
				save_page( $method, $path, %params );
				last;
			};
			
			# Default read
		}
		
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Hello $path";
	}
	
	# Do user things
	sub user {
		my ( $method, $path, %params ) = @_;
		my $mode = $params{'account'} ? 
				$params{'account'} : 'view';
		for ( $mode ) {
			/login/ and do {
				login( $method, $path, %params );
				last;
			};
			
			/logout/ and do {
				if ( pmain::authorization() ) {
					logout( $method, $path, %params );
				} else {
					redir( '/' );
				}
				last;
			};
			
			/changepass/ and do {
				if ( pmain::authorization() ) {
					change_pass( $method, $path, %params );
				} else {
					pmain::redir( '/' );
				}
				last;
			};
			
			/register/ and do {
				register( $method, $path, %params );
				last;
			};
		}
		
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Hello $mode";
	}
	
	# Do post reading things
	sub page {
		my ( $method, $path, %params ) = @_;
		
		my %mtags	= 
		( 
			%config::common_meta, (
				description	=> 'Page description',
				author		=> 'Page author'
			) 
		);
		
		my $entries	= pmain::find_by_date( %params );
		
		# Load partial template
		my $post_tpl	= html::load_template( '_post' );
		
		
		# Build reading page
		my %template	= (
			'title'		=> 'Reading a page',
			'heading'	=> 'Viewing a content page',
			'body'		=> '<p>Hello world</p>' . $entries,
			'meta'		=> html::meta_tags( %mtags )
		);
		
		pmain::send_cookie();
		
		# Render page read
		html::render( 'post', %template );
	}
	
	# Do archive things
	sub archive {
		my ( $method, $path, %params ) = @_;
		my $out		= '';
		
		# Override description
		my %mtags	= 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Get posts by date
		my $entries = pmain::find_by_date( %params );
		
		my %template	= (
			'title'		=> 'Archive',
			'heading'	=> 'This is an archive page',
			'body'		=> $out . ' ' . $entries,
			'meta'		=> html::meta_tags( %mtags )
		);
		
		pmain::send_cookie();
		html::render( 'archive', %template );
	}
	
	# Do new page things
	sub new_page {
		my ( $method, $path, %params ) = @_;
		my $slug = $params{'slug'} ? 
				$params{'slug'} : '';
		
		
		# Post data was sent
		if ( $method eq "post" ) {
			save_page( $method, $path, %params );
		}
		
		# Override robots follow
		my %mtags	= 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Create anti-CSRF token
		my $csrf	= pmain::gen_csrf( 'editpage', '/save' );
		
		# Build new page
		my %template	= (
			'title'		=> 'Create a new page',
			'heading'	=> 'Creating a new page',
			'action'	=> $path,
			'post_slug'	=> $slug,
			'csrf'		=> $csrf,
			'meta'		=> html::meta_tags( %mtags )
		);
		
		pmain::send_cookie();
		html::render( 'new', %template );
	}
	
	# Do page editing things
	sub edit_page {
		my ( $method, $path, %params ) = @_;
		
		# Override robots follow
		my %mtags	= 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		my $csrf	= pmain::gen_csrf( 'editpage', '/save' );
		
		# TODO Find page to edit
		
		# Build edit page
		my %template	= (
			'title'		=> 'Edit a page',
			'heading'	=> 'Editing a created page',
			'post_title'	=> 'A test page',
			'post_body'	=> 'Test content',
			'post_pub'	=> '2015-09-24T12:00:30',
			'post_slug'	=> 'rufflo',
			'action'	=> '/save',
			'csrf'		=> $csrf,
			'meta'		=> html::meta_tags( %mtags )
		);
		
		pmain::send_cookie();
		html::render( 'edit', %template );
	}
	
	# Do save page things
	sub save_page {
		my ( $method, $path, %params ) = @_;
		
		# Post data was sent
		if ( $method ne "post" ) {
			pmain::redir( '/' );
		}
		
		my %data	= pmain::form_data( 'post' );
		
		# Check anti-CSRFtoken
		my $csrf	= pmain::field( 'csrf', %data );
		if ( !pmain::verify_csrf( 'editpage', $path, $csrf ) ) {
			pmain::redir( '/' );
		}
		
		my $content	= pmain::field( 'body', %data );
		my $title	= pmain::field( 'title', %data );
		my $slug	= pmain::field( 'slug', %data );
		my $pubdate	= pmain::field( 'pubdate', %data );
		
		# Convert slug to proper format or generate from title
		if ( $slug ) {
			$slug = html::slugify( $slug );
		} else {
			$slug = html::slugify( $title );
		}
		
		$content .= ' ' . $slug;
		
		# Merge any sent meta tags with default ones
		my %mtags = 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		my %template	= (
			'title'		=> 'Newly saved page',
			'heading'	=> $title,
			'meta'		=> 
				html::meta_tags( 
					%config::common_meta 
				),
			'body'		=> $content
		);
		
		pmain::send_cookie();
		html::render( 'post', %template );
		
		
		# After saving the page, redirect
		#redir( '/' );
	}
	
	# Do profile things
	sub profile {
		my ( $method, $path, %params ) = @_;
		
		if ( pmain::authorization() ) {
			if ( $method eq "post" ) {
				save_profile( $path );
			} else {
				edit_profile( $method, $path, %params );
			}
		}
		
		my %mtags	= 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Hello $path";
	}
	
	# Do profile edit form things
	sub edit_profile {
		my ( $method, $path, %params ) = @_;
		
		my $csrf	= 
		pmain::gen_csrf( 'editpage', $path );
		
		my %template	= (
			'title'		=> 'Editing profile',
			'heading'	=> 'Public profile',\
			'action'	=> $path,
			'csrf'		=> $csrf,
			'user_title'	=> '',
			'user_email'	=> '',
			'user_bio'	=> '',
			'user_web'	=> '',
			'meta'		=> 
			html::meta_tags( 
				%config::common_meta 
			)
		);
		
		send_cookie();
		
		# Render page read
		render( 'editprofile', %template );
	}
	
	# Do profile saving things
	sub save_profile {
		my $path	= shift;
		
		# TODO
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Hello $path";
	}
	
	# Do logging in things
	sub login {
		my ( $method, $path, %params ) = @_;
		
		# Login info was sent
		if ( $method eq "post" ) {
			process_login( $path );
		}
	
		# Everything else,  display login form
		my %mtags	= 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Anti-CSRF token
		my $csrf	= 
		pmain::gen_csrf( 'loginpage', '/login' );
		
		# TODO access login data
		
		# Build login page
		my %template	= (
			'title'		=> 'Login',
			'heading'	=> 'Site access',
			'action'	=> $path,
			'csrf'		=> $csrf,
			'meta'		=> 
			html::meta_tags( %mtags )
		);
				
		pmain::send_cookie();
		html::render( 'login', %template );
	}
	
	# Process login data
	sub process_login {
		my $path = shift;
		my %data	= pmain::form_data( 'post' );
		my $csrf	= pmain::field( 'csrf', %data );
		
		# If anti-CSRF token failed, redirect to home
		if ( !pmain::verify_csrf( 
			'loginpage', $path, $csrf 
		) ) {
			pmain::redir( '/' );
		}
		
		my $missing	= '';
		
		my $username	= 
		pmain::field( 'username', %data );
		
		my $password	= 
		pmain::field( 'password', %data );
		
		if ( !$username ) {
			$missing .= 'username, ';
		}
		if ( !$password ) {
			$missing .= 'password, ';
		}
		
		$missing = html::trim( $missing );
		chomp( $missing );
		
		if ( $missing ) {
			print "Content-Type: text/html; charset=utf-8\n\n";
			print "The following required fields were invalid:\n";
			print $missing;
			exit( 0 );
		}
		
		
		# TODO check login
		
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Processed\n";
		exit( 0 );
	}
	
	# Do register in things
	sub register {
		my ( $method, $path, %params ) = @_;
		
		# Login info was sent
		if ( $method eq "post" ) {
			process_register( $path );
		}
	
		# Everything else,  display login form
		my %mtags	= 
		( 
			%config::common_meta, 
			( $config::robots => 'noindex, nofollow' ) 
		);
		
		# Anti-CSRF token
		my $csrf	= 
		pmain::gen_csrf( 'registerpage', '/user/register' );
		
		# TODO access login data
		
		# Build login page
		my %template	= (
			'title'		=> 'Registe',
			'heading'	=> 'Register',
			'action'	=> '/user/register',
			'csrf'		=> $csrf,
			'meta'		=> html::meta_tags( %mtags )
		);
				
		pmain::send_cookie();
		html::render( 'register', %template );
	}
	
	# Filter and process registration
	sub process_register {
		my $path	= shift;
		
		my %data	= pmain::form_data( 'post' );
		my $csrf	= pmain::field( 'csrf', %data );
		
		# If anti-CSRF token failed, redirect to home
		if ( !pmain::verify_csrf( 
			'registerpage', $path, $csrf 
		) ) {
			pmain::redir( '/' );
		}
			
		my $terms	= pmain::field( 'terms', %data );
		if( !$terms ) {
			print "Content-Type: text/html; charset=utf-8\n\n";
			print "Terms agreement required";
			exit( 0 );
		}
		
		my $missing	= '';
		
		my $username	= pmain::field( 'username', %data );
		my $password	= pmain::field( 'password', %data );
		my $email	= pmain::field( 'email', %data );
		my %subs	= %config::routesubs;
		
		if ( !$username =~ m/^$subs{':user'}$/ ) {
			$missing .= 'username, ';
		}
		
		if ( !$password =~ m/^$subs{':pass'}$/ ) {
			$missing .= 'password, ';
		}
	
		if ( !$email =~ m/^$subs{':email'}$/) {
			$missing .= 'email, ';
		}
		
		$missing = html::trim( $missing );
		chomp( $missing );
		
		if ( $missing ) {
			print "Content-Type: text/html; charset=utf-8\n\n";
			print "The following required fields were invalid:\n";
			print $missing;
			exit( 0 );
		}
			
		print "Content-Type: text/html; charset=utf-8\n\n";
		print "Processed\n";
		exit( 0 );
	}
	
	# Do logging out things
	sub logout {
		my ( $method, $path, %params ) = @_;
		my %auth = (
			'auth' => ''
		);
		
		pmain::set_cookie( 'auth', %auth );
		pmain::send_cookie();
		pmain::redir( '/' );
	}
	
	# Do password changing things
	sub change_pass {
		my ( $method, $path, %params ) = @_;
		
		# Data was sent
		if ( $method eq 'post' ) {
			
			# Process change password
			my %data	= pmain::form_data( 'post' );
			my $csrf	= pmain::field( 'csrf', %data );
			
			if ( !pmain::verify_csrf( 'loginpage', $path, $csrf ) ) {
				pmain::redir( '/' );
			}
			
			# TODO change password
		}
		
		my %mtags = 
		( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' )
		);
		
		my $csrf	= pmain::gen_csrf( 'passpage', '/changepass' );
		
		my %template	= (
			'title'		=> 'Change password',
			'heading'	=> "Change your password",
			'action'	=> '/changepass',
			'csrf'		=> $csrf,
			'meta'		=> html::meta_tags( %mtags )
		);
		
		pmain::send_cookie();
		html::render( 'changepass', %template );
	}
	
	# Do saving new password things
	sub save_pass {
		my ( $method, $path, %params ) = @_;
		
		pmain::send_cookie();
		
		# After changing the password, redirect
		pmain::redir( '/' );
	}
	
	# Do not found things
	sub not_found {
		my ( $method, $path ) = @_;
		
		my %mtags = ( 
			%config::common_meta, 
			( robots => 'noindex, nofollow' ) 
		);
		
		# Build 404 page
		my %template	= (
			'title'		=> '404 Not found',
			'heading'	=> "Couldn't find the page you're looking for",
			'meta'		=> html::meta_tags( %mtags ),
			'body'		=> '<p>Return to <a href="/">index</a>.</p>'
		);
		
		html::render( '404', %template );
	}
}

1;

__END__
