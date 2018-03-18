package SPUC::RequestHandler;

use strict;
use warnings;

use Data::ObjectStore;
use Email::Valid;
use Encode qw/ decode encode /;
use File::Copy;
use File::Path qw(make_path);
use MIME::Base64;
use Text::Xslate qw(mark_raw);
use JSON;

use SPUC::App;
use SPUC::Artist;
use SPUC::Comic;
use SPUC::Image;
use SPUC::Panel;
use SPUC::Session;

our $basedir = "/var/www";
our $datadir = "$basedir/data/SPUC/";
our $lockdir = "$basedir/lock";
our $imagedir = "$basedir/html/spuc/images";

our $xslate = new Text::Xslate(
    path => "$basedir/templates/SPUC",
    input_layer => ':utf8',
    );
make_path( $datadir );
our $store = Data::ObjectStore::open_store( $datadir );
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
    my $msg = "$tdis $txt - ".( $user ? $user->_display : '?' );
    # LOCK app _log
    push @locks, lock( "LOG" );
    my $log = $app->get__log([]);
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

# returns locks for unlock
sub lock {
    my( @names ) = @_;
    my @fhs;
    make_path( $lockdir );
        
    for my $name (@names) {
        open my $fh, '>', "$lockdir/$name";
        flock( $fh, 2 ); #WRITE LOCK
        push @fhs, $fh;
    }
    @fhs;
}
sub unlock {
    my @fhs = shift;
    for my $fh (@fhs) {
        flock( $fh, 8 );
    }
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

    my( $user, $sess, $err, $msg, @locks );
    my $action = $params->{action} || '';
    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        my $sessions = $root->get__sessions({});
        $sess = $sessions->{$sess_id};
        if( $sess ) {
            $user = $sess->get_user;
            unless( $user ) {
                note( "invalid sessions (no user) $sess_id", $user );
                undef $sess_id;
            }
        } else {
            note( "session not found for $sess_id", $user );
            undef $sess_id;
        }
    }
    
    unless( $sess ) {
        $sess = $root->get_default_session;
    }


    if( $path =~ m~^/logout~ ) {
        undef $sess_id;
        # LOCK root _sessions
        push @locks, lock( "SESSIONS" );
        my $sessions = $root->get__sessions({});
        
        delete $sessions->{$sess_id};
        if( $user ) {
            undef $user;
            $msg = "Logged out";
        }
    } #logout


    elsif( $path =~ m~^/register~ && $action eq 'registering' ) {
        # just do squishy for now and organically
        # grow this, dont yet force it. code can move
        # where it wants to
        
        # LOCK root _emails, _users, sessions
        push @locks, lock( "SESSIONS", "EMAILS", "USERS" );
        my $emails = $root->get__emails({});
        my $unames = $root->get__users({});

        my $pw = $params->{pw};
        my $pw2 = $params->{pw2};
        my $un = encode( 'UTF-8', $params->{un} );
        my $em = encode( 'UTF-8',$params->{em} );

        # see if the account or email is already registered
        if( $emails->{lc($em)} ) {
            $err = 'email already registered';
        }
        elsif( $unames->{lc($un)} ) {
            $err = 'username already taken';
        }
        elsif( $un !~ /^\w+$/ ) {
            $err = 'invalid username';
        }
        elsif( $pw ne $pw2 ) {
            $err = 'passwords dont match';
        }
        elsif( length( $pw ) < 8 ) {
            $err = 'passwords too short. Must be at least 8 characters.';
        }
        #        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1, -mxcheck => 1 ) ) {
#        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1 ) ) {
#            $err = 'unable to verify email.';
#        }

        if( ! $err ) {
            # no error defined, so create the user
            # and session and attach the user to the session
            # also add to emails and unames lookups
            $user = $store->create_container( 'SPUC::Artist', {
                display_name => $un,

                _email       => $em,
                _login_name  => lc($un),

                avatar       => $app->get__default_avatar,
                _avatars     => [],

                _created         => time,
                _logged_in_since => time,
                                              } );
            $user->_setpw( $pw );
            my $found;
            
            my $sessions = $root->get__sessions({});

            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }

            $msg = "Created artist account '$un'. You are now logged in and ready to play.";
            my $sess = $sessions->{$sess_id} =
                $store->create_container( 'SPUC::Session', {
                    last_id => $sess_id,
                    user    => $user,
                                          } );
            $user->set__session( $sess );

            $unames->{lc($un)} = $user;
            $emails->{lc($em)} = $user;
        }
    } #register

    # profile
    elsif( $path =~ m~^/profile~ && $user ) {
        if( $action eq 'select-avatar' ) {
            my $avaidx = $params->{avatar};
            my $avas = $user->get__avatars;
            my $ava = $avas->[$avaidx];
            $ava && $user->set_avatar( $ava );
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
                my $destdir = "$imagedir/avatars/$user";
                make_path( $destdir );
                my $dest = "$destdir/$img.png";
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
                    my $destdir = "$imagedir/avatars/$user";
                    make_path( $destdir );
                    my $dest = "$destdir/$img.$ext";
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
            my $avas = $user->get__avatars;
            if( @$avas > 0 ) {
                my $avaidx = $params->{avatar};
                my( $delava ) = splice @$avas, $avaidx, 1;
                $user->set__last_deleted_avatar( $delava );
                $msg = 'deleted avatar';
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
        my $un = encode( 'UTF-8', $params->{un} );
        my $pw = $params->{pw};

        my $emails = $root->get__emails({});
        my $unames = $root->get__users({});
        my $uu = $unames->{lc($un)};
        my $eu = $emails->{lc($un)};
        $user =  $uu || $eu || $root->get_dummy_user;

        # dummy automatically fails _checkpw
        if( $user->_checkpw( $pw ) ) {
            my $found;
            #LOCK root _sessions
            push @locks, lock( "SESSIONS" );
            my $sessions = $root->get__sessions({});
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
            undef $user;
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
                    my $destdir = "$imagedir/comics/$comic";
                    make_path( $destdir );
                    my $dest = "$destdir/$img.png";

                    open my $out, '>', $dest;
                    print $out $png;
                    close $out;
                    $img->set__origin_file( $dest );
                    ( $msg, $err ) = $comic->add_picture( $img, $user );
                    $user->set__playing(undef);
                    $comic->set__player( undef );
                }
                elsif( (my $fh = $uploader->fh('uppanel')) ) {
                    my( $ext ) = ( $fn =~ /\.([^.]+)$/ );
                    if( $ext =~ /^(png|jpeg|jpg|gif)$/ ) {
                        my $img = $store->create_container( 'SPUC::Image',
                                                            {
                                                                _original_name => $fn,
                                                                extension      => $ext,
                                                            });
                        my $destdir = "$imagedir/comics/$comic";
                        make_path( $destdir );
                        my $dest = "$destdir/$img.$ext";
                        $img->set__origin_file( $dest );
                        copy( $fh, $dest );
                        ( $msg, $err ) = $comic->add_picture( $img, $user );
                        $user->set__playing(undef);
                        $comic->set__player( undef );
                    } else {
                        $err = "avatar file format not recognized";
                    }
                } #file up
                else {
                    note("upload called without anything to upload", $user );
                }
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
        my $comic = $app->find_comic_to_play( $user, $params->{skip} );
        if( $comic ) {
            $user->set__playing( $comic );
            $comic->set__player( $user );
            $msg = "found comic to play";
        } else {
            $msg = "no comic found. start one?";
        }
    } #play

    # start new comic
    elsif( $path =~ m~^/start~ && $user && $action eq 'start-comic' ) {
        my $start = encode( 'UTF-8', $params->{start});
        # LOCK app _unfinished_comics
        ( $msg, $err ) = $app->begin_strip( $user, $start );
    }

    elsif( $path =~ m~^/recover_request~ && $action eq 'request-link' ) {
        my $unorem = encode( 'UTF-8', $params->{unorem});
        my $emails = $root->get__emails({});
        my $unames = $root->get__users({});
        my $emu = $emails->{lc($unorem)};
        my $umu = $unames->{lc($unorem)};
        $user = $umu || $emu;
        $user && $app->_send_reset_request($user);
        $msg = "sent reset request";
    }

    elsif( $path =~ m~^/recover~ ) {
        my $tok = $params->{tok};
        my $user = $app->get__resets({})->{$tok};
        if( $user && 
            $user->get__reset_token eq $tok &&
            $user->get__reset_token_good_until > time ) {
            $msg = 'reset your password';
        } else {
            undef $user;
        }
    }
    

    elsif( $path =~ m~^/artist~ ) {

    }
    
    elsif( $path =~ m~^/play~ && $user ) {
        
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
