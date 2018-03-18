#!/usr/bin/perl

use strict;
use warnings;

use Data::ObjectStore;

my $store = Data::ObjectStore::open_store( "/var/www/data/SPUC/" );
my $root  = $store->load_root_container;

# set the root password
# set up question mark
# set up initial account?
# view logs?

my $defava = $root->get__default_avatar;
unless( $defava ) {
    $defava = $store->create_container( 'SPUC::Image', {
        _origin_file => "/var/www/html/spuc/images/question.png",
                                        } );
    $root->set__default_avatar( $defava );
    $store->save;
}

print "SPUC ADMIN. Type 'help' to get help\n";
while( <STDIN> ) {
    if( /^(\?|help)/ ) {
        print "SPUC ADMIN COMMANDS\n";
        print join( "\n",
                    "? or help - this entry",
                    "defava - show default avatar image",
                    "defava <filename> - set default avatar image",
                    "passwd <user> - set user password",
                    "logs - list logs (unimplemented)",
                    "users - list users",
                    "other stuff - no idea yet",
                    "" );
    }
    elsif( /^\s*defava\s+(\S+)/ ) {
        $defava->set__origin_file( $1 );
        print "Default Avatar Image set to "  . $defava->get__origin_file . "\n";
    }
    elsif( /^\s*defava/ ) {
        print "Default Avatar Image at "  . $defava->get__origin_file . "\n";
    }
    elsif( /^\s*users/ ) {
        my $unames = $root->get__users({});
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
            printf "%${longest}s %s\n",$un, $user->get__email;
        }
    }
    elsif( /^\s*passwd\s+(\S+)/ ) {
        my $un = $1;
        print "New Password for user $un :";
        my $pw1 = <STDIN>;
        chomp( $pw1 );
        print "Repeat Password :";
        my $pw2 = <STDIN>;
        chomp( $pw2 );
        if( $pw1 ne $pw2 ) {
            print "Passwords don't match\n";
        } else {
            print "Password updated\n";
        }
    }
    $store->save;
}


__END__
