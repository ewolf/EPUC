#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5;

use lib "$ENV{HOME}/proj/EPUC/lib";

use Data::ObjectStore;
use SPUC::App;
use SPUC::Artist;
use SPUC::Dummy;
use SPUC::Image;
use SPUC::Session;

umask(0);
my $gid = getgrnam( 'www-data' );

our $site         = 'madyote.com';
our $basedir      = "/var/www";
our $spuc_path    = '/cgi-bin/spuc.cgi';
our $imagedir     = "$basedir/html/spuc/images";

Data::ObjectStore::upgrade_store( "/var/www/data/spuc/", { group => $gid } );

my $store = Data::ObjectStore::open_store( "/var/www/data/spuc/", { group => $gid } );
my $root  = $store->load_root_container;


# set the root password
# set up question mark default avatar
# set up initial account?
# view logs?

#
# The SPUC app itself
#
my $app = $root->get_SPUC;

# one time adjustment
if( $app ) {
    $app->privatize( qw( site spuc_path imagedir dummy_user default_session finished_comics ) );
    my $unames = $app->get__users({});
    for my $user (values %$unames) {
        $user->privatize( qw( finished_comics ) );
    }
}

unless( $app ) {
    $app = $store->create_container( 'SPUC::App', {
            _site      => $site,
            _spuc_path => $spuc_path,
            _imagedir  => $imagedir,
                                     } );
    $root->set_SPUC( $app );
}


#
# set the default avatar
#
my $defava = $app->get__default_avatar;
unless( $defava ) {
    $defava = $store->create_container( 'SPUC::Image', {
        _original_name => 'question.png',
        extension => 'png',
        _origin_file => "/var/www/html/spuc/images/question.png",
                                        } );
    $app->set__default_avatar( $defava );
}


#
# Dummy user with default session
#
my $user = $app->get__dummy_user;
unless( $user ) {
    my $un = 'dummy';

    $user = $store->create_container( 'SPUC::Dummy', {
        display_name => $un,
        _login_name  => $un,
        __avatar     => $app->get__default_avatar,
        _created     => time,
                                      } );
    $app->set__dummy_user( $user );
}

my $sess = $app->get__default_session;
unless( $sess ) {
    $sess = $store->create_container( 'SPUC::Session', {
        user => $user,
        ids => {
            $app => $app,
        },
                                      } );
    $app->set__default_session( $sess );
    my $sessions = $app->get__sessions({}); 
    $sessions->{0} = $sess;    
    $user->set__session( $sess );
}


$store->save;

print "SPUC ADMIN. Type 'help' to get help\n\nSPUC>";
while( <STDIN> ) {
    my $app = $root->get_SPUC;
    if( /^(\?|help)/ ) {
        print "SPUC ADMIN COMMANDS\n";
        print join( "\n",
                    "? or help - this entry",
                    "defava - show default avatar image",
                    "defava <filename> - set default avatar image",
                    "exit - end admin program",
                    "passwd <user> - set user password",
                    "users - list users",
                    
                    "admin <user> - make user into an admin",
                    "logs - list logs (unimplemented)",

                    "user <user> - details about user",

                    "" );
    }
    elsif( /^\s*admin\s+(\S+)/ ) {
        my $un = $1;
        my $unames = $app->get__users({});
        my $user = $unames->{lc($un)};
        if( $user ) {
            $user->set__is_admin(1);
            print "'$un' is now an admin.\n";
        } else {
            print "User '$un' not found\n";
        }
    }
    elsif( /^\s*unadmin\s+(\S+)/ ) {
        my $un = $1;
        my $unames = $app->get__users({});
        my $user = $unames->{lc($un)};
        if( $user ) {
            $user->set__is_admin(0);
            print "'$un' is no longer an admin.\n";
        } else {
            print "User '$un' not found\n";
        }
    }
    elsif( /^\s*defava\s+(\S+)/ ) {
        $defava->set__origin_file( $1 );
        print "Default Avatar Image set to "  . $defava->get__origin_file . "\n";
    }
    elsif( /^\s*defava/ ) {
        print "Default Avatar Image at "  . $defava->get__origin_file . "\n";
    }
    elsif( /^\s*exit/ ) {
        exit;
    }
    elsif( /^\s*users/ ) {
        my $unames = $app->get__users({});
        print "USERS\n";
        my( @uns ) = sort keys %$unames;
        my $longest;
        if( @uns ) {
            ( $longest ) = sort { $b <=> $a } map { length($_) } (@uns);
            my $hl = ($longest-4)/2;
            printf "%${hl}s%s Email\n","User", " "x$hl
        } else {
            print "No users found\n";
        }
        for my $un (@uns) {
            my $user = $unames->{$un};
            my $last_active = $user->get__active_time;
            my $last_login = $user->get__login_time;
            
            printf "%${longest}s %s %s Last Active : %s, Last Login : %s\n",$un, $user->get__email, $user->get__is_admin ? 'admin-user' : '', $app->format_time( $last_active ), $app->format_time( $last_login );
        }
    }
    elsif( /^\s*passwd\s+(\S+)/ ) {
        my $un = $1;
        my $unames = $app->get__users({});
        my $user = $unames->{lc($un)};
        if( $user ) {
            print "New Password for user $un :";
            my $pw1 = <STDIN>;
            chomp( $pw1 );
            print "Repeat Password :";
            my $pw2 = <STDIN>;
            chomp( $pw2 );
            if( $pw1 ne $pw2 ) {
                print "Passwords don't match\n";
            } elsif( length($pw1) < 4 ) {
                print "Password too short\n";
            } else {
                $user->_setpw( $pw1 );
                print "Password updated\n";
            }
        } else {
            print "User '$un' not found\n";
        }
    } # password <user>
    $store->save;
    print "SPUC>";
}


__END__
