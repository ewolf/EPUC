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
sub _singleton {
    return $singleton if $singleton;
    
    my $options = shift;

    my $store = Data::ObjectStore::open_store( $options->{datadir}, $options );
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
    $singleton;
}


#
#
#---------- instance methods ---------------
#
#

sub handle_RPC {
    my( $params, $sess_id, $uploader, $options ) = @_;
    _singleton($options)->_handle_RPC( $params, $sess_id, $uploader, $options );
}

our $PKG2METHS = {};
sub _methods {
    my $pkg = shift;
    my $meths = _meths( $pkg );
    use strict 'refs';
    $meths;
}
sub _meths {
    my $pkg = shift;
    return [] if $pkg =~ /^(UNIVERSAL|Data::ObjectStore::Container)$/;

    my $meths = $PKG2METHS->{$pkg};
    if( $meths ) {
        return $meths;
    }

    no strict 'refs';
    push @$meths, (
        grep { $_ !~ /(^_|^[sg]et|^[sg]et_|(^isa|import|move|make_path|AUTOLOAD|BEGIN|DESTROY|can|a|b|store|ISA|copy$)|::)/ }
        keys %{"$pkg\::"} );
    for my $class ( @{"${pkg}\::ISA" } ) {
        push @$meths, @{ _meths( $class ) };
    }
    $PKG2METHS->{$pkg} = $meths;
    $meths;
} #_meths

sub _handle_RPC {
    my( $self, $params, $sess_id, $uploader ) = @_;
    my $sessions = $self->{app}->get__sessions({});
    my $store = $self->{store};
    my $sess    = $sessions->{$sess_id};
    if( $sess ) {
        my $payload = from_json( $params->{p} );
        my $method      = $payload->{m};
        my $id          = $payload->{i};
        my $last_update = $payload->{t} || 0;
        print STDERR Data::Dumper->Dump([$payload,"PAYLOAD ($method,$id)"]);
        
        my $obj = $sess->_fetch( $id );
        
        if( $obj && $method !~ /^(_|[sg]et_|[sg]et$)/ && $obj->can( $method ) ) {
            my $args = _unpack( $payload->{a}, $sess );

            my $ups = [];
            my $ret = {
                r => _pack ( $obj->$method( @$args ), $sess ),
                u => $ups,
                t => time,
            };

            # reset is set upon log in
            if( $sess->get_reset ) {
                $ret->{R} = 1;
                $sess->set_reset(undef);
                undef $last_update;
            }

            # construct the payload. Find the items that need updating
            my $seen = {};
            my $updates = $sess->_updates( $last_update, $seen );
            while( @$updates ) {
                my $up = shift @$updates;
                my $meths = [];
                my $data;
                if( ref( $up ) eq 'HASH' ) {
                    $data = { map { $_ => $sess->_stow($up->{$_}) } keys %$up };
                }
                elsif( ref( $up ) eq 'ARRAY' ) {
                    $data = [ map { $sess->_stow($_) } @$up ];
                }
                else {
                    $meths = _methods( ref( $up ) );
                    $data = { map { $_ => $sess->_stow($up->get($_)) } grep { $_ !~ /^_/ } keys %{$up->[1]} };
                }
                push @$ups, {
                    i => $sess->_stow( $up ),
                    m => $meths,
                    f => $data,
                };
                if( 0 == @$updates ) {
                    push @$updates, @{$sess->_updates( $last_update, $seen ) };
                }
            }
            my $json_out = to_json( $ret );

            print STDERR Data::Dumper->Dump([$ret,$json_out,"RETURNY"]);
            
            $self->write_notes;
            
            $self->{store}->save;
            
            $self->unlock;
            
            return \$json_out, 200, $sess_id;
        }
        print STDERR Data::Dumper->Dump([ref($obj),"EEK ($method,$obj,$id)"]);
    }
    
} #_handleRPC

sub reset {
    my $self = shift;
    $self->{errs}  = [];
    $self->{msgs}  = [];
}

sub err {
    my( $self, $err, $user ) = @_;
    if( $err ) {
        push @{$self->{errs}}, $err;
    }
}

sub has_errs {
    @{shift->{errs}} > 0;
}

sub errs {
    [splice @{shift->{errs}}];
}

sub msg {
    my( $self, $msg ) = @_;
    if( $msg ) {
        push @{$self->{msgs}}, $msg;
    }
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
    my( $self, $pw1, $pw2, $oldpw, $user ) = @_;

    if( $user ) {
        if( ! $user->_checkpw( $oldpw ) ) {
            $self->err( 'old password incorrect', $user );
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
    
    my( $user, $sess );
    my $action = $params->{action} || '';
    # see if the session is attached to a user. If not
    # then create a default unlogged in "session".
    if( $sess_id ) {
        my $sessions = $self->{app}->get__sessions({});
        $sess = $sessions->{$sess_id};
        if( $sess ) {
            $user = $sess->get_user;
            unless( $user ) {
                $self->note( "invalid sessions (no user) $sess_id", $user );
                undef $sess_id;
            }
            my $t = time;
            if( ( $t - $user->get__active_time($t) ) > 3600*24*3 ||
                ( $t - $user->get__login_time($user->get__active_time) ) > 3600*24*30 ) {
                $self->err( 'session expired' );
                $self->note( "session expired", $user );           
            }
            $user->set__active_time( $t );
        } else {
            $self->note( "session not found for $sess_id", $user );
            undef $sess_id;
        }
    }
    
    unless( $sess ) {
        $sess = $self->{app}->get__default_session;
    }

    # --------- the decision tree based on the path
    
    if( $path =~ m~^/logout~ ) {
        undef $sess_id;
        # LOCK root _sessions
        $self->lock( "SESSIONS" );
        my $sessions = $self->{app}->get__sessions({});
        delete $sessions->{$sess_id};
        if( $user ) {
            $self->note( "Logged Out", $user );
            undef $user;
            $self->msg( "Logged out" );
            
        }
    } #logout


    elsif( $path =~ m~^/register~ && $action eq 'registering' ) {
        # just do squishy for now and organically
        # grow this, dont yet force it. code can move
        # where it wants to
        
        # LOCK root _emails, _users, sessions
        $self->lock( "EMAILS", "USERS" );
        my $emails = $self->{app}->get__emails({});
        my $unames = $self->{app}->get__users({});

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
        elsif( ! Email::Valid->address( -address => $em, -tldcheck => 1 ) ) {
            $self->err( 'unable to verify email.' );
        }

        if( ! $self->has_errs ) {
            # no error defined, so create the user
            # and session and attach the user to the session
            # also add to emails and unames lookups
            $user = $self->{store}->create_container( 'SPUC::Artist', {
                display_name => $un,

                _email       => $em,
                _login_name  => lc($un),

                avatar       => $self->{app}->get__default_avatar,
                _avatars     => [],

                _created      => time,
                _login_time   => time,
                _active_time  => time,
                                              } );
            $user->_setpw( $pw );
            my $found;

            $self->note( "Registered", $user );
            
            $self->lock( "SESSIONS" );
            my $sessions = $self->{app}->get__sessions({});
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }

            $self->msg( "Created artist account '$un'. You are now logged in and ready to play." );
            my $sess = $sessions->{$sess_id} =
                $self->{store}->create_container( 'SPUC::Session', {
                    last_id => $sess_id,
                    user    => $user,
                    app     => $self->{app},
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
            $self->msg( "selected avatar" );
            $self->note( "selected avatar", $user );
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
                $self->msg( "created new avatar" );
                $self->note( "drew new avatar", $user );
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
                    $self->msg( "uploaded new avatar" );
                    $self->note( "uploaded new avatar", $user );
                } else {
                    $self->err( "avatar file format not recognized", $user );
                }
            }
        } #if upload
        elsif( $action eq 'delete-avatar' ) {
            my $avas = $user->get__avatars;
            if( @$avas > 0 ) {
                my $avaidx = $params->{avatar};
                my( $delava ) = splice @$avas, $avaidx, 1;
                $user->set__last_deleted_avatar( $delava );
                $self->msg( 'deleted avatar', $user );
                $self->note( "deleted avatar", $user );
            } else {
                $self->err( 'cannot delete last avatar', $user );
            }
        }
        elsif( $action eq 'set-bio' ) {
            my $bio = encode( 'UTF-8', $params->{bio} );
            if( length($bio ) > 2000 ) {
                $bio = substr( $bio, 0, 2000 );
            }
            $user->set_bio( $bio );
            $self->msg( 'updated bio' );
            $self->note( "updated bio", $user );
        }
        elsif( $action eq 'update-password' ) {
            my $newpw = $params->{pw};
            $self->check_password( $newpw, $params->{pw2}, $params->{pwold}, $user );
            if( ! $self->has_errs ) {
                $user->_setpw( $newpw );
                $self->msg( "Updated password" );
                $self->note( "updated password", $user );
            }
        }
    } #profile


    # login
    elsif( $path =~ m~^/login~ && ! $user ) {
        my $un = encode( 'UTF-8', $params->{un} );
        my $pw = $params->{pw};

        my $emails = $self->{app}->get__emails({});
        my $unames = $self->{app}->get__users({});
        my $uu = $unames->{lc($un)};
        my $eu = $emails->{lc($un)};
        $user =  $uu || $eu || $self->{app}->get__dummy_user;

        # dummy automatically fails _checkpw
        if( $user->_checkpw( $pw ) ) {
            my $found;
            $self->lock( "SESSIONS" );
            my $sessions = $self->{app}->get__sessions({});
            until( $found ) {
                $sess_id = int(rand(2**64));
                $found = ! $sessions->{$sess_id};
            }
            $self->note( "logged in", $user );
            $self->msg( 'logged in' );
            my $sess = $user->get__session;
            delete $sessions->{$sess->get_last_id};
            $sessions->{$sess_id} = $sess;
            $sess->set_last_id( $sess_id );
            $user->set__login_time( time );
            $sess->_reset;
        } else {
            $self->err( 'login failed' );
            undef $user;
        }
    } #login

    # play
    elsif( $path =~ m~^/play~ && $user ) {
        my $comic = $user->get__playing;
        if( $comic && ($action eq 'caption-picture' || $action eq 'upload-panel') ) {
            if( ! $comic->is_free( $user ) ) {
                $self->err( "this comic was grabbed by an other artist. your hold had expired" );
            }
            else {
                if( $action eq 'upload-panel' ) {
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
                        my( $msg, $err ) = $comic->add_picture( $img, $user );
                        $self->msg( $msg );
                        $self->err( $err );
                        $self->note( "drew panel", $user );
                        $user->set__playing(undef);
                        $comic->set__player( undef );
                        $user->set__saved_panel( undef );
                        $user->get__saved_comic( $comic );
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
                            my( $msg, $err ) = $comic->add_picture( $img, $user );
                            $self->msg( $msg );
                            $self->err( $err );
                            $self->note( "uploaded panel", $user );
                            $user->set__playing(undef);
                            $user->set__saved_panel( undef );
                            $comic->set__player( undef );
                        } else {
                            $self->err( "avatar file format not recognized" );
                        }
                    } #file up
                    else {
                        $self->note( "upload called without anything to upload", $user );
                    }
                } #if upload to panel
                elsif( $action eq 'caption-picture' ) {
                    my $cap = encode( 'UTF-8', $params->{caption});
                    if( length($cap) > 200 ) {
                        $cap = substr( $cap, 0, 200 );
                    }
                    my( $msg, $err ) = $comic->add_caption( $cap, $user );
                    $self->msg( $msg );
                    $self->err( $err );
                    $self->note( "added caption", $user );
                    $user->set__playing(undef);
                    $comic->set__player( undef );
                }

                if( $comic->is_complete ) {
                    my $arts = $comic->get_artists;
                    $self->lock( "UNFINISHED" );
                    $self->note( "completed comic", $user );
                    for my $thing ( $self->{app}, values %$arts) {
                        $thing->remove_from__unfinished_comics( $comic );
                        my $fin = $thing->get__finished_comics([]);
                        unshift @$fin, $comic;
                    }
                    for my $art (values %$arts) {
                        my $updates = $art->get__updates([]);
                        my $all_comics = $art->get__all_comics([]);
                        for( my $i=0; $i<@$all_comics; $i++ ) {
                            if( $all_comics->[$i] == $comic ) {
                                unshift @$updates, { msg   => "a comic you wrote for finished",
                                                     type  => 'comic',
                                                     comic => $i };
                                last;
                            }
                        }
                    }
                    $self->msg( "comleted comic" );
                }
            }
        } #if action played

        if( $action eq 'save-panel' && $comic && $comic->is_free( $user ) ) {
            if( ! $comic->is_free( $user ) ) {
                $self->err( "this comic was grabbed by an other artist. your hold had expired" );
            }
            else {
                my $fn = $params->{uppanel};
                $comic->set__hold_expires( time + 7*24*3600 ); # in 1 week
                $comic->set__player( $user );

                if( $fn =~ /^data:image\/png;base64,(.*)/ ) {
                    my $png = MIME::Base64::decode( $1 );
                    my $img = $self->{store}->create_container( 'SPUC::Image',
                                                                {
                                                                    _original_name => 'upload',
                                                                    extension      => 'png',
                                                                });
                    my $destdir = "$self->{imagedir}/saves/$user";
                    make_path( $destdir, { group => $self->{group}, mode => 0775 } );
                    my $dest = "$destdir/$img.png";
                    
                    open my $out, '>', $dest;
                    print $out $png;
                    close $out;
                    $img->set__origin_file( $dest );
                    
                    $user->set__saved_panel( $img );
                    $self->note( "saved panel", $user );
                    $self->msg( "saved picture for later" );
                    $path = '/';
                }
            }
        } #if save for later

        else {
            # find new comic
            $self->lock( "COMIC" );
            $comic = $self->{app}->find_comic_to_play( $user, $params->{skip} );
            if( $comic ) {
                $user->set__playing( $comic );
                $comic->set__player( $user );
                $comic->set__hold_expires( time + 2*3600 ); # in 2 hours
                $self->msg( "found comic to play" );
            } else {
                $self->msg( "no comic found. start one?" );
            }
        }
    } #play

    # start new comic
    elsif( $path =~ m~^/start~ && $user && $action eq 'start-comic' ) {
        my $start = encode( 'UTF-8', $params->{start});
        if( length($start) > 200 ) {
            $start = substr( $start, 0, 200 );
        }
        # LOCK app _unfinished_comics
        $self->lock( "UNFINISHED" );
        my( $msg, $err ) = $self->{app}->begin_strip( $user, $start );
        $self->msg( $msg );
        $self->err( $err );
        $self->note( "started comic", $user );
    }

    elsif( $path =~ m~^/recover_request~ && $action eq 'request-link' ) {
        my $unorem = encode( 'UTF-8', $params->{unorem});
        my $emails = $self->{app}->get__emails({});
        my $unames = $self->{app}->get__users({});
        my $emu = $emails->{lc($unorem)};
        my $umu = $unames->{lc($unorem)};
        $user = $umu || $emu;
        $self->lock( "RESETS" );
        $user && $self->{app}->_send_reset_request($user);
        $self->msg( "sent reset request" );
        $self->note( "requested reset", $user );
        undef $user;
    }

    elsif( $path =~ m~^/recover~ ) {
        my $tok = $params->{tok};
        if( $tok ) {
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
                        $self->note( "recovered and set password", $user );
                    }
                } else {
                    $self->msg( 'reset your password' );
                }
            } else {
                undef $user;
            }
        }
    } #recover

    elsif( $path eq '/lounge' && $user ) {
        if( $action eq 'chat' ) {
            my $txt = $params->{comment};
            if( length( $txt ) > 2000 ) {
                $txt = substr( $txt, 0, 2000 );
            }
            my $comment = $self->{store}->create_container( {
                artist => $user,
                comment => $txt,
                time => time(),
                                                            } );
            my $chat = $self->{app}->get__chat([]);
            unshift @$chat, $comment;
            $self->note( "added chat", $user );
        }
        elsif( $action eq 'suggest' ) {
            
        }
    }
    
    elsif( $action =~ /^(comment|bookmark|unbookmark|kudo)$/ && $user && defined( $params->{idx} ) ) {
        my $comics;
        if( $path eq '/mine' ) { 
            $comics = $user->get__finished_comics;
        }
        elsif( $path eq '/bookmarks' ) {
            $comics = $user->get__bookmarks;
        }
        elsif( $path eq '/unfinished' ) {
            $comics = $user->get__unfinished_comics;
        }
        elsif( $params->{artist} ) {
            my $artist = $self->{app}->artist( $params->{artist} );
            $comics = $artist->get__finished_comics;
        }
        else {
            $comics //= $self->{app}->get__finished_comics;
        }
        
        my $comic = $comics->[$params->{idx}];
        if( $comic ) { 
            if( $action eq 'comment' && $params->{comment} =~ /\S/ ) {
                my $txt = $params->{comment};
                if( length( $txt ) > 2000 ) {
                    $txt = substr( $txt, 0, 2000 );
                }
                my $comment = $self->{store}->create_container( {
                    artist => $user,
                    comment => $txt,
                    time => time(),
                                                            } );
                $comic->add_to_comments( $comment );
                $self->note( "added comment", $user );
            }
            elsif( $action eq 'bookmark' ) {
                $user->bookmark( $comic );
            }
            elsif( $action eq 'unbookmark' ) {
                $user->unbookmark( $comic );
            }
            elsif( $action eq 'kudo' ) {
                my $panel = $comic->get_panels->[$params->{panel}];
                if( $panel && ! $user->has_kudo_for( $panel ) ) {
                    $user->kudo( $panel );
                }
            }
        }
    } #added comment or bookmark or removed bookmark

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

} #_handle


sub _pack {
    my( $item, $session ) = @_;
    my $r = ref($item);
    if( $r eq 'HASH' ) {
        my $tied = tied (%$item);
        if( $tied ) {
            return $session->_stow( $item );
        } else {
            return { map { $_ => _pack($item->{$_},$session) } keys %$item };
        }
    }
    elsif( $r eq 'ARRAY' ) {
        my $tied = tied (@$item);
        if( $tied ) {
            return $session->_stow( $item );
        } else {
            return [ map { _pack($_,$session) } @$item ];
        }
    }
    elsif( $r ) {
        return $session->_stow( $item );
    }
    elsif( defined( $item ) ) {
        return "v$item";
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
    elsif( $item =~ /^v(.*)/ ) {
        return $1;
    }
    elsif( $item =~ /^u/ ) {
        return undef;
    }
    return $session->_fetch( $r );
}


1;

__END__

