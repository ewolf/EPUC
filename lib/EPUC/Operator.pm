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

sub err {
    my( $self, $err ) = @_;
    $err //= $@;
    $self->{err} = $err;
}

sub msg {
    my( $self, $msg ) = @_;
    $self->{msg} = $msg;
}

sub _check_actions {
    my( $self ) = @_;

    my $path_args = $self->{path_args};
    my $req = $self->{req};
    my $app = $self->{app};

    my $subtemplate = $path_args->{'p'};
    $self->{state}{subtemplate} = $subtemplate;
    my $action = $req->param( 'action' );

    my $login = $self->{login};
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
		    $self->msg( "Logged in as " . $login->get_user );
		    $self->{redirect} = '/spuc';
		    return;
		}
	    }
	}
    }
    elsif( $subtemplate eq 'logout' ) {
	$self->logout;
	$self->{redirect} = '/spuc';
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
                        $login->get_avatar->get_icon->develop( $icon, '80x80' );N
                        $self->msg( 'Uploaded Icon' );
                    };
                } else {
                    $@ = 'Error in Uploading Icon';
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
                    $@ = 'passwords do not match';
                }
                if( length( $pw1 ) < 6 ) {
                    $@ = 'password too short';
                }
                eval {
                    $login->reset_password( $pw1, $curr_pw);
                    $self->msg( 'reset password' );
                };
            }	
        }
        elsif( $subtemplate eq 'findstrip' ) {
            my $last_strip = $login->get_last_random_strip;
            if( $path_args->{'do'} eq 'reserve' ) {
                if( $last_strip ) {
                    eval {
                        $last_strip->reserve( $login );
                        $self->msg(  'Reserved Strip' );
                    };
                } else {
                    $@ = "could not find strip to reserve";
                }
            }
            elsif( $last_strip ) {
                if( $action eq 'upload' ) {
                    eval {
                        my $upload = $self->upload( 'pictureup' );
                        if( $upload  && $last_strip->reserve($login) && $last_strip->add_picture( $login, $upload ) ) {
                            $self->msg( 'uploaded picure' );
                        } else {
                            $@ = "error uploading";
                        }
                    };
                }
                elsif( $action eq 'caption' ) {
                    eval {
                        if( $last_strip->reserve($login) && $last_strip->add_sentence( $login, $req->param('caption') ) ) {
                            $self->msg( 'added caption' );
                        }
                    };
                }
            }
            my $strip = $login->play_random_strip;
            $self->{strip} = $strip;
            $self->{panel} = $strip->_last_panel;
            $self->{allowed} = $login->allowed_reserve_count;
        } #findstrip
        elsif( $subtemplate eq 'showreserved' ) {
            if( $action eq 'upload' ) {
                eval {
                    my $last_strip = $login->get_last_random_strip;
                    my $upload = $self->upload( 'pictureup' );
                    if( $upload && $last_strip  && $last_strip->reserve($login) && $last_strip->add_picture( $login, $upload ) ) {
                        $self->msg( 'uploaded picure' );
                    } else {
                        $@ = $last_strip ? "error uploading" : "strip not found";
                    }
                };
            }
            elsif( $action eq 'unreserve' ) {
                eval {
                    my $reserved = $login->get_reserved_strips;
                    if( $path_args->{'do'} == 'unreserve' && $reserved->[ $path_args->{'s'} ] && $reserved->[ $path_args->{'s'} ]->free( $login ) ) {
                        $self->msg( 'Unreserved Caption' );
                    } else {
                        $@ = 'Error trying to Unreserve Caption';
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
    } #if login
    $self->err;

} #_check_actions

1;
