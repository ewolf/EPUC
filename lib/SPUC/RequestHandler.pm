package SPUC::RequestHandler;

use strict;
use warnings;

use Data::ObjectStore;
use Digest::MD5;
use Email::Valid;
use File::Copy;
use MIME::Base64;
use Text::Xslate qw(mark_raw);
use JSON;

use SPUC::App;
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

sub _pack {
    my( $item, $session ) = @_;
    my $r = ref($item);
    if( $r eq 'HASH' ) {
        my $tied = tied (%$item);
        if( $tied ) {
            return $session->stow( $item );
        } else {
            return { map { $_ => _pack($item->{$_},$session) } keys %$item };
        }
    }
    elsif( $r eq 'ARRAY' ) {
        my $tied = tied (@$item);
        if( $tied ) {
            return $session->stow( $item );
        } else {
            return [ map { _pack($_,$session) } @$item ];
        }
    }
    elsif( $r ) {
        return $session->stow( $item );
    }
    elsif( defined( $r ) ) {
        return "v$r";
    }
    return undef;
} #_pack

sub _unpack {
    my( $item, $session ) = @_;
    my $r = ref($item);
    if( $r eq 'HASH' ) {
        return { map { $_ => _unpack($_,$session) } keys %$item };
    }
    elsif( $r eq 'ARRAY' ) {
        return [ map { _unpack($_,$session) } @$item ];
    }
    elsif( $r =~ /^v(.*)/ ) {
        return $1;
    }
    elsif( $r =~ /^u/ ) {
        return undef;
    }
    return $session->fetch( $r );
}

sub handle_RPC {
    my( $params, $sess_id, $uploader ) = @_;
    my $sessions = $root->get__sessions({});
    
    my $sess    = $sessions->{$sess_id};
    if( $sess ) {
        my $payload = from_json( $params->{p} );
        my $method  = $payload->{m};
        my $id      = $payload->{i};
        if( $id == 0 ) {
            if( $method eq 'load' ) {
                my $user = $sess->get_user;
                
            }
        }
        my $args    = _unpack( $payload->{a}, $sess );
        # just return the user object if its loaded
    }        
    else {
        
    }
} #handleRPC

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
    my( $user, $sess, $err, $msg );
    
    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        $sess = $sessions->{$sess_id};
        if( $sess ) {
            $user = $sess->get_user;
            unless( $user ) {
                note( "invalid sessions (no user) $sess_id" );
            }
        } else {
            note( "session not found for $sess_id" );
        }
    }
    unless( $sess ) {
        $sess = $root->get_default_session;
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
            my $sess = $sessions->{$sess_id} = 
                $store->create_container( 'SPUC::Session', {
                    last_id => $sess_id,
                    user    => $user,
                                          } );
            $user->set__session( $sess );
                
            $unames->{$un} = $user;
            $emails->{$em} = $user;
        }
    }
    elsif( $path =~ m~^/profile~ ) {
        if( (my $avaid = $params->{avatar}) ) {
            my $avas = $user->get__avatars;
            for my $ava (@$avas) {
                if( $ava->_id == $avaid ) {
                    $user->set_avatar( $ava );
                    last;
                }
            }
        }
        elsif( (my $fn = $params->{avup}) ) {
            if( $fn =~ /^data:image\/png;base64,(.*)/ ) {
                my $png = MIME::Base64::decode( $1 );
                my $img = $store->create_container( 'SPUC::Image',
                                                    {
                                                        _original_name => 'upload',
                                                        extension      => 'png',
                                                    });
                my $dest = "/var/www/html/spuc/images/$img.png";
                open my $out, '>', $dest;
                print $out $png;
                close $out;
                $img->set__origin_file( $dest );
                $user->add_to__avatars( $img );
            }
            elsif( (my $fh = $uploader->fh('avup')) ) {
                my( $ext ) = ( $fn =~ /\.([^.]+)$/ );
                if( $ext =~ /^(png|jpeg|jpg|gif)$/ ) {
                    my $img = $store->create_container( 'SPUC::Image',
                                                        {
                                                            _original_name => $fn,
                                                            extension      => $ext,
                                                        });
                    my $dest = "/var/www/html/spuc/images/$img.$ext";
                    $img->set__origin_file( $dest );
                    $user->add_to__avatars( $img );
                    copy( $fh, $dest );
                }
            }
        }
    }
    elsif( $path =~ m~^/login~ ) {
        my $un = $params->{un};
        my $pw = $params->{pw};
        
        my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
        my $unames = $root->get__users({});
        $user = $unames->{$un};
        if( $user ) {
            if( $user->get__enc_pw eq $enc_pw ) {
                my $found;
                until( $found ) {
                    $sess_id = int(rand(2**64));
                    $found = ! $sessions->{$sess_id};
                }

                my $sess = $user->get__session;
                delete $sessions->{$sess->get_last_id};
                $sessions->{$sess_id} = $sess;
                $sess->set_last_id( $sess_id );
            }
        } else {
            $root->get_dummy_user;
        }
            
        
        
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
