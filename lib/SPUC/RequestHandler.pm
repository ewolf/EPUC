package SPUC::RequestHandler;

use strict;
use warnings;

use Data::ObjectStore;
use Email::Valid;
use Encode qw/ decode encode /;
use File::Copy;
use MIME::Base64;
use Text::Xslate qw(mark_raw);
use JSON;

use SPUC::App;
use SPUC::Artist;
use SPUC::Comic;
use SPUC::Image;
use SPUC::Panel;
use SPUC::Session;

our $xslate = new Text::Xslate(
    path => "/var/www/templates/SPUC",
    input_layer => ':utf8',
    );
our $store = Data::ObjectStore::open_store( "/var/www/data/SPUC/" );
our $root  = $store->load_root_container;

#
# root container has
#   SPUC - the SPUC app
#   default_session
#   dummy_user
#   _sessions - sessid -> session obj
#   _emails - email to -> artist
#   _unames - user name -> artist


our $app   = $root->get_SPUC;
our $logfh;
open( $logfh, '>>', "/tmp/log" );

sub note {
    my( $txt, $user ) = @_;

    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $tdis = sprintf( "[%02d/%02d/%02d %02d:%02d]", $year%100,$mon+1,$mday,$hour,$min );
    
    my $msg = "$tdis $txt - ".$user->_display;
    my $log = $app->get_log([]);
    print $logfh "$msg\n";
    print STDERR "$msg\n";
    unshift @$log, "$msg";
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
    my $action = $params->{action} || '';

    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        $sess = $sessions->{$sess_id};
        if( $sess ) {
            $user = $sess->get_user;
            unless( $user ) {
                note( "invalid sessions (no user) $sess_id", 4 );
            }
        } else {
            note( "session not found for $sess_id", 4 );
        }
    }
    unless( $sess ) {
        $sess = $root->get_default_session;
    }


    if( $path =~ m~^/comic~ ) {

    }


    elsif( $path =~ m~^/artist~ ) {

    }

    elsif( $path =~ m~^/logout~ ) {
        if( $user ) {
            delete $sessions->{$sess_id};
            undef $sess_id;
            undef $user;
            $msg = "Logged out";
        }
    } #logout


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
            $user = $store->create_container( 'SPUC::Artist', {
                display_name => $un,

                _email       => $em,
                _login_name  => $un,

                avatar       => $app->get__default_avatar,

                _created         => time,
                _logged_in_since => time,
                                              } );
            $user->_setpw( $pw );
            my $found;
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }

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
    } #register

    # profile
    elsif( $path =~ m~^/profile~ && $user ) {
        if( $action eq 'select-avatar' ) {
            my $avaid = $params->{avatar};
            my $avas = $user->get__avatars;
            for my $ava (@$avas) {
                if( $ava->_id == $avaid ) {
                    $user->set_avatar( $ava );
                    last;
                }
            }
            $msg = "selected avatar";
        }

        elsif( $action eq 'upload-avatar' ) {
            my $fn = $params->{avup};
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
                $user->set_avatar( $img );
                $msg = "created new avatar";
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
                    $user->set_avatar( $img );
                    copy( $fh, $dest );
                    $msg = "uploaded new avatar";
                } else {
                    $err = "avatar file format not recognized";
                }
            }
        } #if upload
        elsif( $action eq 'delete-avatar' ) {
            my $avaid = $params->{avatar};
            my $avas = $user->get__avatars;
            my $selava = $user->get_avatar;
            if( @$avas > 1 ) {
                for my $ava (@$avas) {
                    if( $ava->_id == $avaid && $ava->_id != $selava->_id ) {
                        $user->remove_from__avatars( $ava );
                        $user->add_to__deleted_avatars( $ava );
                        $msg = 'deleted avatar';
                        last;
                    }
                }
            } else {
                $err = 'cannot delete last avatar';
            }
        }
        elsif( $action eq 'set-bio' ) {
            my $bio = encode( 'UTF-8', $params->{bio} );
            $user->set_bio( $bio );
            $msg = 'updated bio';
        }
        elsif( $action eq 'update-password' ) {
            my $oldpw = $params->{pwold};
            my $newpw = $params->{pw};
            # verify old password
            if( ! $user->_checkpw( $oldpw ) ) {
                $err = 'old password incorrect';
            }
            if( length( $newpw ) < 8 ) {
                $err = 'password too short';
            }
            if( $newpw ne $params->{pw2} ) {
                $err = 'password do not match';
            }
            if( ! $err ) {
                $user->_setpw( $newpw );
                $msg = "Updated password";
            }
        }
    } #profile


    # login
    elsif( $path =~ m~^/login~ && ! $user ) {
        my $un = $params->{un};
        my $pw = $params->{pw};

        my $unames = $root->get__users({});
        $user = $unames->{$un} || $root->get_dummy_user;

        # dummy automatically fails _checkpw
        if( $user->_checkpw( $pw ) ) {
            my $found;
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }
            $msg = 'logged in';
            my $sess = $user->get__session;
            delete $sessions->{$sess->get_last_id};
            $sessions->{$sess_id} = $sess;
            $sess->set_last_id( $sess_id );
        } else {
            $err = 'login failed';
        }
    } #login

    # play
    elsif( $path =~ m~^/play~ && $user ) {
        if( $action eq 'upload-panel' ) {
            my $comic = $user->get__playing;
            if( $comic ) {
                my $fn = $params->{uppanel};
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
                    ( $msg, $err ) = $comic->add_picture( $img, $user );
                    $user->set__playing(undef);
                    $comic->set__player( undef );
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
                        copy( $fh, $dest );
                        ( $msg, $err ) = $comic->add_picture( $img, $user );
                        $user->set__playing(undef);
                        $comic->set__player( undef );
                    } else {
                        $err = "avatar file format not recognized";
                    }
                } #file up
            } #if comic
        } #if upload to panel
        elsif( $action eq 'caption-picture' ) {
            my $comic = $user->get__playing;
            my $cap = encode( 'UTF-8', $params->{caption});
            ( $msg, $err ) = $comic->add_caption( $cap, $user );
            $user->set__playing(undef);
            $comic->set__player( undef );
            if( $comic->is_complete ) {
                $msg = "comleted comic";
            }
        }

        my $comic = $user->get__playing || $app->find_comic_to_play( $user, $params->{skip} );
        if( $comic ) {
            $user->set__playing( $comic );
            $comic->set__player( $user );
            $msg = "found comic to play";
        } else {
            $msg = "no comic found. start one?";
        }
    } #play

    # start new comic
    elsif( $path =~ m~^/start~ && $user ) {
        ( $msg, $err ) = $app->begin_strip( $user, $params->{start} );
        # start a comic object
        # attach it to the creator
        # attach it to the free comics
    }

    if( $err ) {
        note( $err, $user );
    }
    if( $msg ) {
        note( $msg, $user );
    }

    $store->save;

    # try the rule you can register if you
    # are already logged in

    # show the homepage
    my $txt = $xslate->render( "main.tx", {
        path   => $path,        
        params => $params,
        user   => $user,
        app    => $app,
        err    => $err,
        msg    => $msg,
                               } );
    return \$txt, 200, $sess_id;

} #handle

1;
