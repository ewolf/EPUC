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


our $singleton;


#
# Input is the url path, parameters and the session id.
#
# Return is
#   content-ref,http status,session
#
#
sub handle {
    my( $path, $params, $sess_id, $uploader, $options ) = @_;
    _singleton($options)->_handle( $path, $params, $sess_id, $uploader, $options );
}


#
# root container has
#   SPUC - the SPUC app
#   default_session
#   dummy_user
#   _sessions - sessid -> session obj
#   _emails - email to -> artist
#   _unames - user name -> artist
sub _singleton {
    return $singleton if $singleton;
    
    my $options = shift;
    my $store = Data::ObjectStore::open_store( $options->{datadir} );
    my $root  = $store->load_root_container;
    my $app   = $root->get_SPUC;
    unless( $app ) {
        $app = $store->create_container( 'SPUC::App', {
            site      => $options->{site},
            spuc_path => $options->{spuc_path},
            imagedir  => $options->{imagedir},
                                         } );
        $root->set_SPUC( $app );
    }

    $singleton = bless {
        store => $store,
        root  => $root,
        app   => $app,
        locks => [],
        notes => [],
        xslate => new Text::Xslate(
            path => $options->{template_dir},
            input_layer => ':utf8',
            ),
            map { $_ => $options->{$_} } qw( site spuc_path basedir template_dir datadir lockdir imagedir logdir group ),
    }, 'SPUC::RequestHandler';
    open( $singleton->{logfh}, '>>', $options->{logdir} );
}

#
#
#---------- instance methods ---------------
#
#

sub reset {
    my $self = shift;
    $self->{errs}  = [];
    $self->{msgs}  = [];
}

sub err {
    my( $self, $err ) = @_;
    push @{$self->{errs}}, $err;
}

sub has_errs {
    @{shift->{errs}} > 0;
}

sub errs {
    [splice @{shift->{errs}}];
}

sub msg {
    my( $self, $msg ) = @_;
    push @{$self->{msgs}}, $msg;
}

sub msgs {
    [splice @{shift->{msgs}}];
}


# returns locks for unlock
sub lock {
    my( $self, @names ) = @_;
    
    my @fhs;
    for my $name (@names) {
        open my $fh, '>', "$self->{lockdir}/$name";
        flock( $fh, 2 ); #WRITE LOCK
        push @fhs, $fh;
    }
    push @{$self->{locks}}, @fhs;
}
sub unlock {
    my $self = shift;
    my $fhs = $self->{locks};
    for my $fh (@$fhs) {
        flock( $fh, 8 );
    }
    splice @$fhs;
}

sub write_notes {
    my $self = shift;
    my $notes = $self->{notes};
    if( @$notes ) {
        my $fh = $self->{logfh};
        $self->lock( "LOG" );
        my $log = $self->{app}->get__log([]);
        for my $msg (@$notes) {
            print $fh "$msg\n";
            print STDERR "$msg\n";
            unshift @$log, "$msg";
        }
        splice @$notes;
    }
}

sub note {
    my( $self, $txt, $user ) = @_;

    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $tdis = sprintf( "[%02d/%02d/%02d %02d:%02d]", $year%100,$mon+1,$mday,$hour,$min );
    my $msg = "$tdis $txt - ".( $user ? $user->_display : '?' );
    push @{$self->{notes}}, $msg;
}

sub check_password {
    my( $self, $pw1, $pw2, $user, $oldpw ) = @_;

    if( $user ) {
        if( ! $user->_checkpw( $oldpw ) ) {
            $self->err( 'old password incorrect' );            
        }
    }
    
    if( length( $pw1 ) < 8 ) {
        $self->err( 'password too short');
    }
    if( $pw1 ne $pw2 ) {
        $self->err( 'password do not match' );
    }
    
}


sub _handle {
    my( $self, $path, $params, $sess_id, $uploader ) = @_;
    # might be on to something here
    # in order to avoid a race condition, the getid and transationcs are handy
    # however, if we could have some sort of list that, when appended to, appends to a similar index row.
    # yes, I think we can do this with what we havre now. Just
    # use the new id creating feature in Data::Objectsore coupled with
    # the fixed  record store's atomicic id generation to get a file coordinated store

    $self->reset;
    
    my( $user, $sess, $err, $msg );
    my $action = $params->{action} || '';
    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        my $sessions = $self->{root}->get__sessions({});
        $sess = $sessions->{$sess_id};
        if( $sess ) {
            $user = $sess->get_user;
            unless( $user ) {
                $self->note( "invalid sessions (no user) $sess_id", $user );
                undef $sess_id;
            }
        } else {
            $self->note( "session not found for $sess_id", $user );
            undef $sess_id;
        }
    }
    
    unless( $sess ) {
        $sess = $self->{root}->get_default_session;
    }

    # --------- the decision tree based on the path
    
    if( $path =~ m~^/logout~ ) {
        undef $sess_id;
        # LOCK root _sessions
        $self->lock( "SESSIONS" );
        my $sessions = $self->{root}->get__sessions({});
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
        $self->lock( "SESSIONS", "EMAILS", "USERS" );
        my $emails = $self->{root}->get__emails({});
        my $unames = $self->{root}->get__users({});

        my $pw = $params->{pw};
        my $pw2 = $params->{pw2};
        my $un = encode( 'UTF-8', $params->{un} );
        my $em = encode( 'UTF-8',$params->{em} );

        # see if the account or email is already registered
        if( $emails->{lc($em)} ) {
            $self->err( 'email already registered' );
        }
        elsif( $unames->{lc($un)} ) {
            $self->err( 'username already taken' );
        }
        elsif( $un !~ /^\w+$/ ) {
            $self->err( 'invalid username' );
        }
        elsif( $pw ne $pw2 ) {
            $self->err( 'passwords dont match' );
        }
        elsif( length( $pw ) < 8 ) {
            $self->err( 'passwords too short. Must be at least 8 characters.' );
        }
        #        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1, -mxcheck => 1 ) ) {
#        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1 ) ) {
#            $self->err( 'unable to verify email.' );
#        }

        if( ! $err ) {
            # no error defined, so create the user
            # and session and attach the user to the session
            # also add to emails and unames lookups
            $user = $self->{store}->create_container( 'SPUC::Artist', {
                display_name => $un,

                _email       => $em,
                _login_name  => lc($un),

                avatar       => $self->{app}->get__default_avatar,
                _avatars     => [],

                _created         => time,
                _logged_in_since => time,
                                              } );
            $user->_setpw( $pw );
            my $found;
            
            $self->lock( "SESSIONS" );
            my $sessions = $self->{root}->get__sessions({});
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }

            $msg = "Created artist account '$un'. You are now logged in and ready to play.";
            my $sess = $sessions->{$sess_id} =
                $self->{store}->create_container( 'SPUC::Session', {
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
                my $img = $self->{store}->create_container( 'SPUC::Image',
                                                    {
                                                        _original_name => 'upload',
                                                        extension      => 'png',
                                                    });
                my $destdir = "$self->{imagedir}/avatars/$user";
                make_path( $destdir, { group => $self->{group}, mode => 0775 } );
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
                    my $img = $self->{store}->create_container( 'SPUC::Image',
                                                        {
                                                            _original_name => $fn,
                                                            extension      => $ext,
                                                        });
                    my $destdir = "$self->{imagedir}/avatars/$user";
                    make_path( $destdir, { group => $self->{group}, mode => 0775 } );
                    my $dest = "$destdir/$img.$ext";
                    $img->set__origin_file( $dest );
                    $user->add_to__avatars( $img );
                    $user->set_avatar( $img );
                    copy( $fh, $dest );
                    $msg = "uploaded new avatar";
                } else {
                    $self->err( "avatar file format not recognized" );
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
                $self->err( 'cannot delete last avatar' );
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
                $self->err( 'old password incorrect' );
            }
            if( length( $newpw ) < 8 ) {
                $self->err( 'password too short' );
            }
            if( $newpw ne $params->{pw2} ) {
                $self->err( 'password do not match' );
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

        my $emails = $self->{root}->get__emails({});
        my $unames = $self->{root}->get__users({});
        my $uu = $unames->{lc($un)};
        my $eu = $emails->{lc($un)};
        $user =  $uu || $eu || $self->{root}->get_dummy_user;

        # dummy automatically fails _checkpw
        if( $user->_checkpw( $pw ) ) {
            my $found;
            $self->lock( "SESSIONS" );
            my $sessions = $self->{root}->get__sessions({});
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
            $self->err( 'login failed' );
            undef $user;
        }
    } #login

    # play
    elsif( $path =~ m~^/play~ && $user ) {
        if( $action eq 'caption-picture' || $action eq 'upload-panel' ) {
            my $comic = $user->get__playing;
            if( $action eq 'upload-panel' ) {
                if( $comic ) {
                    my $fn = $params->{uppanel};
                    if( $fn =~ /^data:image\/png;base64,(.*)/ ) {
                        my $png = MIME::Base64::decode( $1 );
                        my $img = $self->{store}->create_container( 'SPUC::Image',
                                                            {
                                                                _original_name => 'upload',
                                                                extension      => 'png',
                                                            });
                        my $destdir = "$self->{imagedir}/comics/$comic";
                        make_path( $destdir, { group => $self->{group}, mode => 0775 } );
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
                            my $img = $self->{store}->create_container( 'SPUC::Image',
                                                                {
                                                                    _original_name => $fn,
                                                                    extension      => $ext,
                                                                });
                            my $destdir = "$self->{imagedir}/comics/$comic";
                            make_path( $destdir, { group => $self->{group}, mode => 0775 } );
                            my $dest = "$destdir/$img.$ext";
                            $img->set__origin_file( $dest );
                            copy( $fh, $dest );
                            ( $msg, $err ) = $comic->add_picture( $img, $user );
                            $user->set__playing(undef);
                            $comic->set__player( undef );
                        } else {
                            $self->err( "avatar file format not recognized" );
                        }
                    } #file up
                    else {
                        $self->notes( "upload called without anything to upload", $user );
                    }
                } #if comic
            } #if upload to panel
            elsif( $action eq 'caption-picture' ) {
                my $cap = encode( 'UTF-8', $params->{caption});
                ( $msg, $err ) = $comic->add_caption( $cap, $user );
                $user->set__playing(undef);
                $comic->set__player( undef );
            }
            if( $comic->is_complete ) {
                my $arts = $comic->get_artists;
                $self->lock( "UNFINISHED" );
                for my $thing ( $self->{app}, values %$arts) {
                    $thing->remove_from__unfinished_comics( $comic );
                    my $fin = $thing->get_finished_comics([]);
                    unshift @$fin, $comic;
                }
                $self->msg( "comleted comic" );
            }
        } #if action played

        # find new comic
        $self->lock( "COMIC" );
        my $comic = $self->{app}->find_comic_to_play( $user, $params->{skip} );
        if( $comic ) {
            $user->set__playing( $comic );
            $comic->set__player( $user );
            $self->msg( "found comic to play" );
        } else {
            $self->msg( "no comic found. start one?" );
        }
    } #play

    # start new comic
    elsif( $path =~ m~^/start~ && $user && $action eq 'start-comic' ) {
        my $start = encode( 'UTF-8', $params->{start});
        # LOCK app _unfinished_comics
        $self->lock( "UNFINISHED" );
        ( $msg, $err ) = $self->{app}->begin_strip( $user, $start );
    }

    elsif( $path =~ m~^/recover_request~ && $action eq 'request-link' ) {
        my $unorem = encode( 'UTF-8', $params->{unorem});
        my $emails = $self->{root}->get__emails({});
        my $unames = $self->{root}->get__users({});
        my $emu = $emails->{lc($unorem)};
        my $umu = $unames->{lc($unorem)};
        $user = $umu || $emu;
        $self->lock( "RESETS" );
        $user && $self->{app}->_send_reset_request($user);
        $self->msg( "sent reset request" );
    }

    elsif( $path =~ m~^/recover~ ) {
        my $tok = $params->{tok};
        $user = $self->{app}->get__resets({})->{$tok};
        if( $user && 
            $user->get__reset_token eq $tok &&
            $user->get__reset_token_good_until > time ) 
        {
            if( $action eq 'update-password' ) {
                $self->check_password( $params->{pw}, $params->{pw2} );
                if( ! $self->has_errs ) {
                    $user->_setpw( $params->{pw} );  
                    $user->set__reset_token(undef);
                    $user->set__reset_token_good_until(undef);
                    $self->lock( "RESETS" );
                    delete $self->{app}->get__resets({})->{$tok};
                    $self->msg( 'updated password' );
                }
            } else {
                $self->msg( 'reset your password' );
            }
        } else {
            undef $user;
        }
    }
    

    elsif( $path =~ m~^/artist~ ) {

    }
    
    if( $err ) {
        $self->note( $err, $user );
    }
    if( $msg ) {
        $self->note( $msg, $user );
    }
    
    $self->write_notes;
    
    $self->{store}->save;

    $self->unlock;

    # try the rule you can register if you
    # are already logged in

    # show the homepage
    my $txt = $self->{xslate}->render( "main.tx", {
        path   => $path,        
        params => $params,
        user   => $user,
        app    => $self->{app},
        errs   => $self->errs,
        msgs   => $self->msgs,
                               } );
    return \$txt, 200, $sess_id;

} #handle

1;

__END__

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
    my $sessions = $self->{root}->get__sessions({});

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
