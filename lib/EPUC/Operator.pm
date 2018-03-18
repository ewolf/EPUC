package EPUC::Operator;

use strict;
use warnings;
no warnings 'uninitialized';

use base 'Yote::Server::ModperlOperator';

use UUID::Tiny;

sub new {
    my( $pkg, %options ) = @_;
    $options{apps}{spuc} = {
        app_name      => 'EPUC::App',
        cookie_path   => 'spuc',
        main_template => 'main',
        template_path => "spuc",
        state_manager_class   => 'EPUC::StateManager',
    };
    my $self = $pkg->SUPER::new( %options );
    bless $self, $pkg;
}

package EPUC::StateManager;

use base 'Yote::Server::ModperlOperatorStateManager';

sub make_err {
    $@ = { err => shift };
}

sub err {
    my( $self, $err ) = @_;
    $err //= $@;
    $self->{session}->set_err( ref $err ? $err->{err} : $err  );
    $self->{has_err} = 1 if $err;
}

sub msg {
    my( $self, $msg ) = @_;
    if( $self->{session}->get_redirect ) {
        $self->{session}->set_redirect;
    } else {
        $self->{session}->set_msg( $msg );
    }
}

sub redirect {
    my( $self, $loc ) = @_;
    $self->{redirect} = $loc;
    $self->{session}->set_redirect(1);
}


#
# These are mainly here rather than in the templates because
# the templates can't really handle thrown exceptions at all.
#
sub _check_actions {
    my( $self ) = @_;

    $self->{has_err} = 0;
    
    my $path_args = $self->{path_args};
    my $req = $self->{req};
    my $app = $self->{app};
    my $sess = $self->{session};
    my $login = $self->{login};
    my $action = $req->param( 'action' );

    $self->msg;
    $self->err;
    
    my $subtemplate = $path_args->{'p'} || 'view';
    if( $subtemplate ) {
        if( ! $login && ( $subtemplate !~ /^(view|search|login|news|about)$/ ) ) {
            $subtemplate = 'login';
            if( $action ne 'login' ) {
                $self->msg( "Your session has expired. Please Log In.");
            }
        }
    } else {
        $subtemplate = 'view';
    }

    my $avatar = $login ? $login->get_avatar : undef;

    if( $subtemplate eq 'login' ) {
        if( $action eq 'login' ) {
            my( $un, $pw ) = ( $req->param('un'), $req->param('pw') );
            if( $un && $pw ) {
                eval {
                    undef $self->{login};
                    $login = $app->login( $un, $pw );
                    $self->{login} = $login;
                };
                if( $login ) {
                    $self->msg( "Login successfull" );
                    $self->redirect( '/spuc' );
                    return;
                } else {
                    $self->err( $@ );
                }
            }
        }
    }
    elsif( $subtemplate eq 'logout' ) {
        $self->logout;
        $self->msg( 'logged out' );
        $self->redirect( '/spuc' );
        return;
    }
    if( $login ) {
        if( $login->get_is_admin ) {
            if( $subtemplate eq 'createacct' && $action eq 'createacct' ) {
                eval {
                    $login->create_user_account( $req->param("un"), $req->param("pw"), $req->param("is_admin") );
                    $self->msg( "created account");
                };
            } #create acct
            elsif( $subtemplate eq 'resetuserpw' && $action eq 'resetuserpw' ) {
                my( $un, $pw ) = ( $req->param("un"), $req->param("pw") );
                eval {
                    $login->reset_user_password( $un, $pw );
                    $self->msg( 'reset password' );
                };
                if( $@ ) {
                    $self->{un} = $un;
                }
            }
        }
        if( $subtemplate eq 'userprefs' ) {
            if( $action eq 'iconup' ) {
                my $icon = $self->upload( 'iconup' );
                if( $icon ) {
                    eval {
                        $login->get_avatar->get_icon->develop( $icon, '80x80' );
                        $self->msg( 'Uploaded Icon' );
                    };
                } else {
                    $@ = { err =>'Error in Uploading Icon'};
                }
            }
            elsif( $action eq 'updateinfo' ) {
                my( $name, $about ) = ( $req->param( 'name' ), $req->param( 'about' ) );
                $avatar->set_name( $name );
                $avatar->set_about( $about );
                $self->msg( 'updated info' );
            }
            elsif( $action eq 'resetpw' ) {
                my( $curr_pw, $pw1, $pw2 ) = ( $req->param('pw'), $req->param('pw1'), $req->param('pw2') );

                if( $pw1 ne $pw2 ) {
                    $@ = { err => 'passwords do not match' };
                }
                elsif( length( $pw1 ) < 6 ) {
                    $@ =  { err => 'password too short' };
                }
                else {
                    eval {
                        $login->reset_password( $pw1, $curr_pw);
                        $self->msg( 'reset password' );
                    };
                }
            }
        }
        elsif( $subtemplate eq 'play' ) {
            my $last_strip = $login->get_last_random_strip;

            if( $action eq 'reserve' ) {
                $login->set_lock_strip( $last_strip );
                if( $last_strip ) {
                    if( $login->reserves_available > 0 ) {
                        eval {
                            $last_strip->reserve( $login );
                            $self->msg( 'Reserved Strip' );
                            $login->set_last_random_strip;
                            $login->set_lock_strip;
                        };
                    } else {
                        $@ = { err => "out of strips to reserve" };
                    }
                } else {
                    $@ = { err => "could not find strip to reserve" };
                }
            }
            elsif( $last_strip ) {
                if( $action eq 'upload' ) {
                    $login->set_lock_strip( $last_strip );
                    eval {
                        my $upload = $self->upload( 'pictureup' );
                        if( $upload  && $last_strip->reserve($login) && $last_strip->add_picture( $login, $upload ) ) {
                            $self->msg( 'uploaded picure' );
                            $login->set_last_random_strip;
                            $login->set_lock_strip;
                        } else {
                            $last_strip->free($login);
                            $@ = { err => "error uploading" };
                        }
                    };
                }
                elsif( $action eq 'caption' ) {
                    $login->set_lock_strip( $last_strip );
                    eval {
                        if( $last_strip->reserve($login) && $last_strip->add_sentence( $login, $req->param('caption') ) ) {
                            $self->msg( 'added caption' );
                            $login->set_last_random_strip;
                            $login->set_lock_strip;
                        }
                    };
                    if( $@ ) {
                        $last_strip->free($login);
                    }
                }
            }
            my $strip = $login->play_random_strip;
            if( $strip ) {
                $self->{strip} = $strip;
                $self->{panel} = $strip->_last_panel;
                $self->{allowed} = $login->reserves_available;
            } else {
                # no error, the page checks
            }
        } #play
        elsif( $subtemplate eq 'showreserved' ) {
            if( $action eq 'upload' ) {
                my $strip_idx = $req->param('strip_idx');
                if( defined( $strip_idx ) ) {
                    my $reserved = $login->get_reserved_strips;
                    my $strip = $reserved->[$strip_idx];
                    if( $strip ) {
                        eval {
                            my $upload = $self->upload( 'pictureup' );
                            if( $upload && $strip->reserve($login) ) {
                                $strip->add_picture( $login, $upload );
                                $self->msg( 'uploaded picure' );
                            } else {
                                $@ = { err => "Error in Strip for Upload" };
                            }
                        };
                    } else {
                        $@ = { err => $strip ? "error uploading" : "strip not found" };
                    }
                };
            }
            elsif( $action eq 'unreserve' ) {
                eval {
                    my $reserved = $login->get_reserved_strips;
                    my $strip = $reserved->[ $req->param('strip-idx') ];
                    if( $strip && $strip->free( $login ) ) {
                        $self->msg( "freed strip reserveation" );
                    } else {
                        $@ = { err => 'Error trying to Unreserve Caption' };
                    }
                };
            }
        } #showreserved
        elsif( $subtemplate eq 'startstrip' ) {
            if( $action eq 'startstrip' ) {
                eval {
                    $login->start_strip( $req->param('start-sentence') );
                    $self->msg( 'started strip' );
                };
            }
        }
        elsif( $subtemplate eq 'myinprogress' ) {
            if( $action eq 'delete' ) {
                eval {
                    my $strips = $login->get_in_progress_strips;
                    my $strip = $strips->[$req->param('strip-number')];
                    if( $strip->can_delete( $login ) ) {
                        $strip->delete_strip( $login );
                        $self->msg( 'deleted strip' );
                        my $idx = $path_args->{'d'} - 1;
                        if( @$strips > 0 ) {
                            $idx = 0 if $idx < 0;
                            $self->redirect( "/spuc/p/myinprogress/s/$path_args->{s}/d/$idx" );
                        } else {
                            $self->redirect( "/spuc/p/myinprogress" );
                        }
                    }
                };
            }
        } #myinprogress
        if( $action eq 'kudo' ) {
            my $panel = $sess->fetch( $req->param('panel') );
            if( $panel && $panel->can_kudo( $login ) ) {
                $panel->add_kudo( $login );
                $self->msg( 'added kudo' );
            } else {
                $@ = { err => 'Error trying to kudo caption' };
            }
        }
        elsif( $action eq 'message' ) {
            my $msg = $req->param('message');
            my $strip = $sess->fetch( $req->param('strip') );
            if( $strip && $msg =~ /\S/ ) {
                $strip->add_message( $msg, $login );
                $self->msg( 'message added' );
            } else {
                $@ = { err => 'Error adding message' };
            }
        }

    } #if login

    $self->err;
    $self->{state}{subtemplate} = $subtemplate;
    return ! $self->{has_err};
    
} #_check_actions

1;
