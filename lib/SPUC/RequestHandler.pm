package SPUC::RequestHandler;

use strict;
use warnings;

use Data::ObjectStore;
use Digest::MD5;
use Email::Valid;
use Text::Xslate qw(mark_raw);

use SPUC::Artist;
use SPUC::Image;
use SPUC::Session;

our $xslate = new Text::Xslate(
    path => "/var/www/templates/SPUC",
    );
our $store = Data::ObjectStore::open_store( "/var/www/data/SPUC/" );
our $root  = $store->load_root_container;
our $logfh;
open( $logfh, '>>', "/tmp/log" );

sub note {
    my( $txt, $lvl ) = @_;
    $lvl //= 1;
    my $log = $root->get_log([]);
    print $logfh "$txt\n";
    print STDERR "$txt\n";
    unshift @$log, "$lvl $txt";
}

#
# Input is the url path, parameters and the session id.
#
# Return is
#   content-ref,http status,session
#
#
sub handle {
    my( $path, $params, $sess_id, $uploader ) = @_;
    
    # might be on to something here
    # in order to avoid a race condition, the getid and transationcs are handy
    # however, if we could have some sort of list that, when appended to, appends to a similar index row.
    # yes, I think we can do this with what we havre now. Just
    # use the new id creating feature in Data::Objectsore coupled with
    # the fixed  record store's atomicic id generation to get a file coordinated store
    
    my $sessions = $root->get__sessions({}); 
    my( $user, $err, $msg );
    
    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        $user = $sessions->{$sess_id};
        
        unless( $user ) {
            note( "invalid sessions $sess_id" );
        }
        
    }

    if( $path =~ m~^/comic~ ) {

    }
    elsif( $path =~ m~^/artist~ ) {
        
    }
    elsif( $path =~ m~^/create~ ) {
        
    }
    elsif( $path =~ m~^/logout~ ) {
        if( $user ) {
            note( "$user logged out", 3 );
            delete $sessions->{$sess_id};
            undef $sess_id;
            undef $user;
            $msg = "Logged out";
        }
    }
    elsif( $path =~ m~^/register~ ) {
        # just do squishy for now and organically
        # grow this, dont yet force it. code can move
        # where it wants to

        my $emails = $root->get__emails({});
        my $unames = $root->get__users({});
        
        my $pw = $params->{pw};
        my $pw2 = $params->{pw2};
        my $un = $params->{un};
        my $em = $params->{em};

        # see if the account or email is already registered
        if( $emails->{$em} ) {
            $err = 'email already registered';
        }
        elsif( $unames->{$un} ) {
            $err = 'username already taken';
        }
        elsif( $pw ne $pw2 ) {
            $err = 'passwords dont match';
        }
        elsif( length( $pw ) < 8 ) {
            $err = 'passwords too short. Must be at least 8 characters.';
        }
        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1, -mxcheck => 1 ) ) {
            $err = 'unable to verify email.';
        }

        if( ! $err ) {            
            # no error defined, so create the user
            # and session and attach the user to the session
            # also add to emails and unames lookups
            my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );

            $user = $store->create_container( 'SPUC::Artist', {
                display_name => $un,
                
                _email       => $em,
                _login_name  => $un,
                _enc_pw      => $enc_pw,

                __avatar     => $root->get__default_avatar,
                
                _created         => time,
                _logged_in_since => time,
                                              } );
            my $found;
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }
            note( "created user $un", 0 );
            
            $msg = "Created artist account '$un'. You are now logged in and ready to play. An email will be delivered to the address given for account confirmation.";
            $sessions->{$sess_id} = $user;
            $unames->{$un} = $user;
            $emails->{$em} = $user;
        }
    }
    elsif( $path =~ m~^/login/~ ) {
        
    }

    $store->save;
    
    # try the rule you can register if you
    # are already logged in
    
    # show the homepage
    my $txt = $xslate->render( "main.tx", {
        path   => $path,
        params => $params,
        user   => $user,
        err    => $err,
        msg    => $msg,
                               } );
    return \$txt, 200, $sess_id;

} #handle

1;
