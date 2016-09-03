package EPUC::Operator;

use strict;


use APR::Request::Param;

use UUID::Tiny;

use Yote::Server;


use Apache2::Cookie;
use Apache2::Const qw(:common);
use Apache2::Request;
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::Upload;
use APR::Request::Param;
use APR::Request::Apache2;

use Data::Dumper;


sub handler {
    my $r = Apache2::Request->new( shift );

    my $ret = EPUC::Operator::make_page( $r );
    
    return $ret;
} #handler


sub new {
    my( $class, $r ) = @_;
    my( $app, $page, @rest ) = grep { $_ } split /\//, $r->uri;

    my $jar = Apache2::Cookie::Jar->new($r);
    my $token_cookie = $jar->cookies("token");
    my $token = $token_cookie ? $token_cookie->value : 0;
    return bless {
        r     => $r,
        page  => $page,
        path  => [@rest],
        initial_path  => \@rest,
        token => $token,
    }, $class;
}

sub dc {
    my $txt = shift;
    Encode::decode( 'utf8', $txt );
}

sub make_page {
    my $op = new EPUC::Operator( @_ );
    $op->_make_page;
}

sub _make_page {
    my $self = shift;

    eval {
        $self->make_main;
    };
    if( $@ ) {
        if( ref( $@ ) eq 'HASH' ) {
            $self->{message} = $@->{err};
            if( $@->{needs_login} ) {
                $self->{page} = 'login';
                $self->make_main;
            }
        } else {
            $self->{message} = $@;
        }
    }

    my $main = $self->{main};
    
    my $r = $self->{r};
    
    # see if there is a token that leads to a logged in account
    
    my $body_classes = join ' ', @{$self->{body_classes}||[]};
    if( ref $@ eq 'HASH' ) {
        $main = $@->{err};
    }
    elsif( $@ ) {
        use Carp 'longmess'; print STDERR Data::Dumper->Dump([longmess]);
        $main = "Internal Server Error ($@)";
    }

    my $html = <<"END";
<!DOCTYPE html>
<html>
  <head>
    <title>EPUC</title>
    <script src="/js/jquery-1.12.0.min.js"></script>
    <script src="/js/yote.js"></script>
    <meta charset="utf-8" />
    <style>
//      div { border: solid 1px black; }
      div.strip {
         vertical-align: top;
      }
      div.strip.detail {
         display: block;
      }
      div.strip {
         display: inline-block;
         border: solid 1px black;
         margin : 1em;
         padding : 1em;
      }
      div.sentence {
         font-size: x-large;
         text-align: center;
      }
      .artist-link {
         font-family: cursive;
         font-style: oblique;
      }
      .side { float: left; display: none; margin-right: 1em; }

      .logged-in .side { display: block; }

      .logged-in #login-link {
        display : none;
      }
      .needs-admin {
        display : none;
      }
      .needs-super {
        display : none;
      }
      .is-super li.needs-super {
        display : list-item;
      }
      .is-super tr.needs-super {
        display : table-row;
      }
      .is-admin .needs-admin {
        display : block;
      }
      .logged-in .enclosure {
        margin-left: 15em;
      }
    </style>
  </head>
  
  <body class="$body_classes">
    <div class="header" style="float:right">
      <a href="/spuc/login" id="login-link">log in</a>
    </div>
    

    <div class="top" style="text-align:left;padding:1em">
      <a href="/spuc/about">
        <h1>Scarf Poutine U Clone</h1>
      </a>
    </div>

    <div class="body" style="align-content:center">

      <div class="side">
        <a href="/spuc/updateprefs"><img class="icon" src="$self->{icon_url}"><br></a>
        Welcome <span class="name">$self->{name}</span>
        <h3>Artwork</h3>
        <ul>
          <li><a href="/spuc/recent" class="action">show recent strips</a></li>
          <li><a href="/spuc/completed" class="action">my completed strips</a></li>
          <li><a href="/spuc/inprogress" class="action">my in progress strips</a></li>
        </ul>
        <h3>Play</h3>
        <ul>
          <li><a href="/spuc/playstrip/find" class="action">find a strip to play</a></li>
          <li><a href="/spuc/startstrip" class="action">start a new strip</a></li>
          <li><a href="/spuc/reserved" class="action">my reserved strips</a></li>
        </ul>
        <h3>Actions</h3>
        <ul>
          <li><a href="/spuc/updateprefs" class="action">update user preferences</a></li>
          <li><a href="/spuc/logout" class="action" id="logout">log out</a></li>
        </ul>
        <div class="needs-admin">
          <h3>Admin Actions</h3>
          <ul>
            <li><a href="/spuc/list-accounts" class="action">list accounts</a></li>
            <li><a href="/spuc/create-account" class="action">create account</a></li>
            <li><a href="/spuc/set-password" class="action">set password</a></li>
            <li class="needs-super"><a href="/spuc/allinprogress" class="action">in progress strips</a></li>
          </ul>
        </div>
      </div> <!-- side -->
      
      <div class="enclosure">
        <span class="message">$self->{message}</span>
        <div class="main">$main</div>
      </div>
    </div>
  </body>
</html>
END

    $r->content_type('text/html');
    $r->print( $html );
    return OK;
    
} #make_page

sub save {
    my $self = shift;
    $self->{server} && $self->{server}->store->stow_all;
}

sub app {
    my $self = shift;

    
    if( $self->{app} ) {
        return $self->{app};
    }

    my $r = $self->{r};
    
    eval('use Yote::ConfigData');
    my $yote_root_dir = $@ ? '/opt/yote' : Yote::ConfigData->config( 'yote_root' );
    unshift @INC, "$yote_root_dir/lib";
    my $options = Yote::Server::load_options( $yote_root_dir );
    my $server = new Yote::Server( $options );
    $self->{server} = $server;
    my $store = $server->store;
    $self->{store} = $store;

    my $root = $store->fetch_server_root;
    $self->{root} = $root;

    $root->{SESSION} = $root->_fetch_session( $self->{token} );
    unless( $root->{SESSION} ) {
        ( $self->{root}, $self->{token} ) = $root->init_root;
        my $token_cookie = Apache2::Cookie->new( $r,
                                                 -name => "token",
                                                 -path => "/spuc",
                                                 -value => $self->{token} );
        
        $token_cookie->bake( $r );
    }
    
    my( $app, $login ) = $root->fetch_app( 'EPUC::App' );
    $app->{SESSION} = $root->{SESSION};
    $self->{app}   = $app;
    $self->{login} = $login;
    if( $login ) {
        push @{$self->{body_classes}}, 'logged-in';
        push @{$self->{body_classes}}, 'is-admin' if $login->isa( 'EPUC::AdminAcct' );
        push @{$self->{body_classes}}, 'is-super' if $login->isa( 'EPUC::AdminAcct' ) && $login->get_is_super;        
        $self->{icon_url} = $login->get_avatar->get_icon->url( '80x80' );
        $self->{name} = dc( $login->get_avatar->get_user );
    }
    return $app;
} #app

sub err {
    my $err = shift;
    if( ref( $err ) eq 'HASH' ) {
        return $err->{err};
    } else {
        use Carp 'longmess'; print STDERR Data::Dumper->Dump([longmess]);
        return "Internal Server Error ($err)";
    }
}

sub login {
    my $login = shift->{login};
    unless( $login ) {
        die { err =>  "not loggged in",
              needs_login => 1 };
    }
    $login;
}

sub upload {
    my( $self, $name ) = @_;
    my $upload = $self->{r}->upload( $name );
    if( $upload ) {
        my $fn = $upload->filename;
        my( $original_name, $extension )  = ( $fn =~ m!([^/]+\.([^/\.]+))$! );

        my $tmprand = "/tmp/".UUID::Tiny::create_uuid_as_string();
        $upload->link( $tmprand );

        my $img = $self->{store}->newobj( {
            file_name      => $original_name,
            file_extension => $extension,
            file_path      => $tmprand,
                                          } );
        return $img;
    }
} #upload

sub detail {
    my( $self, $page ) = @_;
    $self->{size} = '700x700';
    $self->{show_artist} = 1;
    my( $strip_id ) = $self->shift_path;
    my( $strips_id ) = $self->shift_path;
    my( $strip, $strips ) = map { $self->{store}->fetch($_) } ( $strip_id, $strips_id );
    # complete strips can strips with you as a participant can be displayed in detail
    if( $strip && $strip->can_see( $self->{login} ) ) {
        $self->{is_detail} = 1;
        my $strip_html = $self->strip_html( $strip, $strips );
        my $prevnext = '';
        if( ref $strips eq 'ARRAY' ) {
            if( @$strips > 1 ) {
                $prevnext = '<div style="text-align:left;padding: 0em 3em 0em 3em">';
                for( my $i=0; $i<@$strips; $i++ ) {
                    my $list_strip = $strips->[$i];
                    if( $strip == $list_strip ) {
                        if( $i > 0 ) {
                            my $prev = $strips->[$i-1];
                            $prevnext .= sprintf( '<a href="/spuc/%s/detail/%s/%s">%s</a>',
                                                  $page,
                                                  $prev->{ID},
                                                  $strips_id,
                                                  'prev' );
                        }
                        if( $i < $#$strips ) {
                            if( $i > 0 ) {
                                $prevnext .= ' ';
                            }
                            my $next = $strips->[$i+1];
                            $prevnext .= sprintf( '<a href="/spuc/%s/detail/%s/%s" style="float:right">%s</a>',
                                                  $page,
                                                  $next->{ID},
                                                  $strips_id,
                                                  'next' );
                        }
                        last;
                    }
                }
                $prevnext .= '</div>';
            }
        }
        # prev and next
        $self->{main} = <<"END";
$prevnext
$strip_html
END
    } else {
        $self->{message} = "Cannot view incomplete strip";
        $self->{main} = '';
    }
}

sub shift_path {
    shift @{shift->{path}};
}

sub make_main {
    my $self = shift;

    my $app = $self->app();

    my $page = $self->{page};
    my $r = $self->{r};

    if( $page eq 'comic' ) {
        
    } elsif( $page eq 'play' ) {

    } elsif( $page eq 'recent' ) {
        my $cmd = $self->shift_path;

        if( $cmd eq 'detail' ) {
            my $detail = $self->detail( 'recent' );
            $self->{main} = <<"END";
<div style="display:inline-block;text-align:center">
  <h2>Showing Recent Strips</h2>
  $detail
</div>
END
        } else {
            #pagination
            my $strips = $self->recent_strips('recent');
            $self->{main} = <<"END";
<h2>Recent Strips</h2>
<h3>Click on the strip title to get more detail</h3>
$strips
END
        }
    } elsif( $page eq 'reserved' ) {        
        my $login = $self->login;

        #pagination
        my $strips = $self->strips_html( $login->get_reserved_strips, '/spuc/reserved/' ) || 'no reserved strips';
        $self->{main} = <<"END";
<h2>My reserved strips</h2>
$strips
END
    } elsif( $page eq 'artist' ) {
        # show icon, name and about
        # then recent strips
        my( $avatar_id ) = $self->shift_path;
        my( $paginate ) = $self->shift_path;
        my $avatar = $self->{store}->fetch($avatar_id);
        if( $avatar ) {
            my( $handle, $name, $about ) = map { dc($_) } (
                $avatar->get_user,
                $avatar->get_name,
                $avatar->get_about );

            my $handle = $avatar->get_user;
            if( $name ) { $name = "<h3>Given Name</h3>$name" }
            if( $about ) { $about = "<h3>About</h3>$about" }
            
            my $icon_url = $avatar->get_icon->url( '400x400' );

            # recent strips for artist
            my $strips;
            if( $paginate eq 'detail' ) { 
                $strips = $self->detail( "artist/$avatar->{ID}" );
            } else {
                $strips = $self->strips_html( $avatar->get_completed_strips, "artist/$avatar_id" ) || 'no strips found';
            }
            
            $self->{main} = <<"END";
 <h1>$handle</h1>
 <div>
  <div style="float:left">
   <img src="$icon_url"> <br>
   $name
   $about
' </div>
  <div>
    <h3>Recent Strips for $handle</h3>
    $strips
  </div>
 </div>
END
        }
        
    } elsif( $page eq 'completed' ) {
        my $login = $self->login;

        #pagination
        my( $action ) = $self->shift_path;
        my $strips;
        if( $action eq 'detail' ) {
            $strips = $self->detail( 'completed' );
        } else {
            $strips = $self->strips_html( $login->get_avatar->get_completed_strips, 'completed' )  || 'no strips found';
        }
        $self->{main} = <<"END";
<h2>My completed strips</h2>
$strips
END
    } 
    elsif( $page eq 'playstrip' ) {
        my( $action ) = $self->shift_path;
        my $login = $self->login;
        my( $panel_id ) = $self->shift_path;
        if( $action eq 'submitsentence' ) {
            my $panel = $self->{store}->fetch( $panel_id );
            die "panel not found" unless $panel;
            my $sentence = $r->param( 'newcaption' );
            if( $sentence ) {
                eval {
                    $panel->reserve( $login );
                    $panel->get__strip->add_sentence( $login, $sentence );
                    $self->{main} = "submitted caption. You can view the strip in 'my in progress strips'";
                };
                if( $@ ) {
                    $self->{message} = err( $@ );
                }
            } else {
                die "must submit sentence";
            }
        } elsif( $action eq 'submitpicture' ) {
            my $panel = $self->{store}->fetch( $panel_id );
            die "panel not found" unless $panel;

            my $picture = $self->upload( 'pictureup' );
            if( $picture ) {
                eval {
                    $panel->reserve( $login );
                    $panel->get__strip->add_picture( $login, $picture );
                    $self->{main} = "submitted picture. You can view the strip in 'my in progress strips'";
                };
                if( $@ ) {
                    $self->{message} = err( $@ );
                }
            } else {
                die "must submit picture";
            }

        } elsif( $action eq 'reserve' ) {
            my $panel = $self->{store}->fetch( $panel_id );
            $panel->reserve( $login );
            $self->{main} = "Reserved Strip. You can find this under the 'reserved strips list'";
        } elsif( $action eq 'free' ) {
            my $panel = $self->{store}->fetch( $panel_id );
            if( $panel ) {
                $panel->free( $login );
                $self->{main} = "Freed Strip";
            } else {
                die "Unable to find strip to free";
            }
        } else {
            # default just find
            my( $strip, $panel ) = $login->play_random_strip;
            if( $strip ) {
                my $main = "<h2>Play SPUC</h2>";
                $self->{main} = $self->play_panel( $panel );
            } else {
                $self->{main} = "Could not find a strip to play";
            }
        }
    } elsif( $page eq 'startstrip' ) {
        my $login = $self->login;
        my $start = $r->param('startsentence');
        if( $start ) {
            $login->start_strip( $start );
            $self->{message} = "Started new strip";
            $self->{main} = $self->about;
        } else {
            $self->{main} = <<"END";
<h2>Start a Strip</h2>
<form action="/spuc/startstrip" method="POST">
  <textarea name="startsentence"></textarea>
  <br>
  <input type="submit" value="start new strip">
</form>
END
        }
    } elsif( $page eq 'inprogress' ) {
        my $login = $self->login;
        my( $action ) = $self->shift_path;
        my $strip_html;
        if( $action eq 'detail' ) {
            $strip_html = $self->detail( 'inprogress' );
        } else {
            $strip_html = $self->strips_html( $login->get_in_progress_strips, 'inprogress' )  || 'no strips found';;
        }
        $self->{main} =<<"END";
<h2>In Progress Strips</h2>
<h3>Click on the strip title to get more detail</h3>
$strip_html
END
    } elsif( $page eq 'updateprefs' ) {
        my $login = $self->login;
        my $ava = $login->get_avatar;
                    
        # check for inputs
        my $upload = $self->upload("iconup");

        my $err_span = '';

        if( $upload ) {
            $login->uploadIcon( $upload );
            $self->{icon_url} = $ava->get_icon->url( '80x80' );
        } #if image upload
        my $name = dc( $ava->get_name );
        my $about = dc( $ava->get_about );
        if( $r->param('info') eq 'update info' ) {
            ( $name, $about ) = ( dc($r->param( 'name' )), dc($r->param( 'about' )) );
            $ava->set_name( $name );
            $ava->set_about( $about );
        }
        if( $r->param('updpw') eq 'update password' ) {
            my( $oldpw, $newpw, $newpw2 ) = ( $r->param('oldpw'),$r->param('newpw'),$r->param('newpw2') );
            if( $newpw ) {
                if( $newpw eq $newpw2 ) {
                    eval {
                        $login->reset_password( $newpw, $oldpw );
                        $err_span = qq|<span class="info">reset password</span>|;
                    };
                    if( $@ ) {
                        $err_span = '<span class="error">' . err( $@ ) . '</span>';
                        undef $@;
                    }
                } else {
                    $err_span = '<span class="error">Passwords do not match</span>';
                }
            } else {
                    $err_span = '<span class="error">Must supply password</span>';
            }
        }
        $self->{main} = <<"END";
 <h2>Update User Preferences</h2>
 <form method="POST" enctype="multipart/form-data" action="/spuc/updateprefs">
  <h3>change icon</h3>
  <div>
    <img class="icon" src="$self->{icon_url}">
    <input type="file" name="iconup"> 
    <input type="submit" value="upload file">
  </div>
  <hr>
  <h3>Update Info</h3>
  <table>
    <tr> <th>My Name</th> <td><input type="text" class="info" name="name" value="$name"></td></tr>
    <tr> <th>Details about me</th> <td><textarea class="info" name="about">$about</textarea> </td></tr>
  </table> <br>
  <input type="submit" name="info" value="update info">
  <hr>
  <h3>change password</h3>
  $err_span
  <table>
    <tr> <th>Old Password</th> <td><input type="password" name="oldpw"></td></tr>
    <tr> <th>New Password</th> <td><input type="password" name="newpw"></td></tr>
    <tr> <th>New Password (again)</th> <td><input type="password" name="newpw2"></td></tr>
  </table> <br>
  <input type="submit" name="updpw" value="update password">
  
</form>
END
    } elsif( $page eq 'login' ) {
        unless( $self->{login} ) {
            my( $un, $pw ) = ( $r->param('un'), $r->param('pw') );
            my $err_span = '';
            if( $un && $pw ) {
                eval {
                    $self->{login} = $app->login( $un, $pw );
                    $self->{main} = $self->about;
                    push @{$self->{body_classes}}, 'logged-in';
                    push @{$self->{body_classes}}, 'is-admin' if $self->{login}->isa( 'EPUC::AdminAcct' );
                    $self->{message} = "logged in as $un";
                };
                if( $@ ) {
                    $err_span = '<span class="error">' . err( $@ ) . '</span>';
                }
            }
            unless( $self->{login} ) {
                $self->{main} = <<"END";
$err_span
<form action="/spuc/login" method="POST">
  <table>
    <tr> <th>Handle</th>   <td><input type="text" name="un"> </td> </tr>
    <tr> <th>Password</th> <td><input type="password" name="pw"> </td> </tr>
  </table><BR>
  <input type="submit" value="Log In">
</form>
END
            }
        } else {
            $self->{main} = $self->about;
        }
    } elsif( $page eq 'logout' ) {
        my $token_cookie = Apache2::Cookie->new( $r,
                                                 -name => "token",
                                                 -path => "/spuc",
                                                 -value => 0 );
        $token_cookie->bake( $r );
        $self->{message} = 'logged out';
        $self->{body_classes} = [grep { $_ ne 'logged-in' } @{$self->{body_classes}}];
        $self->{main} = $self->about;
    } elsif( $page eq 'list-accounts' ) {
        my $login = $self->login;
        if( $login ) {
            my $accts = $login->list_accounts;
            my $rows = '';
            for my $acct (@$accts) {
                my $status = $acct->get_is_super ? 'super admin' : $acct->get_is_admin ? 'admin' : 'active';
                $rows .= sprintf( '<tr> <td> <a href="/spuc/artist/%s">%s</a> </td>' .
                                  '     <td> %s </td> </tr> ', $acct->get_avatar->{ID}, $acct->get_user, $status );
            }
            $self->{main} = <<"END";
<h2>User Accounts</h2>
<table>
 <tr> <th>Account Name</th> <th>Status</th> </tr>
 $rows
</table>
END
        }
    } elsif( $page eq 'set-password' ) {
        my $login = $self->login;
        die "error" if ! $login->isa( 'EPUC::AdminAcct' );
        my( $action ) = $self->shift_path;
        my( $success, $msg );
        if( $action eq 'submit' ) {
            my( $un, $pw ) = ( $r->param('un'), $r->param('pw') );
            eval {
                my $acct = $login->reset_user_password( $un, $pw );
                $success = $acct->get_user;
            };
            $msg = $@;
        }
        if( $success ) {
            $self->{main} = <<"END";
<h2>Set Password</h2>
Set Password for $success
END
        } else {
            $self->{main} = <<"END";
<h2>Set Password</h2>
<form method="POST" action="/spuc/set-password/submit">
  <div class="message">$msg</div>
  <table>
    <tr> <th>User</th>     <td><input type="text" name="un"></td> </tr>
    <tr> <th>Password</th> <td><input type="password" name="pw"></td> </tr>
  </table>
  <br>
  <input type="submit" name="set-password" value="set password">
</form>
END
        }        
    } elsif( $page eq 'create-account' ) {
        my $login = $self->login;  
        die "error" if ! $login->isa( 'EPUC::AdminAcct' );
        my( $action ) = $self->shift_path;
        my( $success, $msg );
        if( $action eq 'submit' ) {
            my( $un, $pw, $isadmin ) = ( $r->param('un'), $r->param('pw'), $r->param('new-admin') );
            my $err_span = '';
            eval {
                $login->create_user_account( $un, $pw, $isadmin );
                $success = 1;
            };
            $msg = $@;
        }
        if( $success ) {
            $self->{main} = <<"END";
<h2>Create Account</h2>
Created Account
END
        } else {
            $self->{main} = <<"END";
<h2>Create Account</h2>
<form method="POST" action="/spuc/create-account/submit">
  <div class="message">$msg</div>
  <table>
    <tr> <th>User</th>     <td><input type="text" name="un"></td> </tr>
    <tr> <th>Password</th> <td><input type="password" name="pw"></td> </tr>
    <tr class="needs-super"> <th>is admin</th> <td><input type="checkbox" value="1" name="new-admin"></td> </tr>
  </table>
  <br>
  <input type="submit" name="create-account" value="create account">
</form>
END
        }
    } elsif( $page eq 'allinprogress' ) {
        my $login = $self->login;
        die "error" if ! ($login->isa( 'EPUC::AdminAcct' ) && $login->get_is_super );

        my( $action ) = $self->shift_path;

        my $strip_html;
        if( $action eq 'detail' ) {
            $strip_html = $self->detail( 'allinprogress' );
        } else {
            my $all_inprogress = $self->{app}->get__in_progress_strips;
            $strip_html = $self->strips_html( $all_inprogress, 'allinprogress') || ' no in progress strips ';
        }
        $self->{main} = <<"END";
<h2>admin show all in progress strips</h2>
$strip_html
END
        
    } else {  
        #about page
        $self->{main} = $self->about;
    }

    $self->save;
} #make_main

sub play_panel {
    my( $self, $panel ) = @_;
    if( $panel->get_type eq 'sentence' ) {
        my $can_free = $panel->get__reserved_by;
        return sprintf( 'Submit and image for this sentence' .
                        '<form method="POST" enctype="multipart/form-data" action="/spuc/playstrip/submitpicture/%s">' .
                        '<div class="sentence">%s</div>'.
                        '<br>'.
                        '<input type="file" name="pictureup">'.
                        '<input type="submit" value="submit picture">'.
                        '</form><p>'.
                        ( $can_free ? '<a href="/spuc/playstrip/free/%s">stop reserving this sentence</a>' :
                          '<a href="/spuc/playstrip/reserve/%s">reserve this sentence for later</a>' ) .
                        '</p>',
                        $panel->{ID},
                        dc( $panel->get_sentence ),
                        $panel->{ID},
            );
    } else {
        my $url = $panel->get_picture->url( '700x700' );
        return sprintf( '<img src="%s"><br> ' .
                        '<form method="POST" action="/spuc/playstrip/submitsentence/%s">' .
                        ' Enter a caption <textarea name="newcaption"></textarea>' .
                        ' <input type="submit">' .
                        '</form>', $url, $panel->{ID} );
    }
}

sub recent_strips {
    my( $self, $page ) = @_;
    my $app = $self->app();
    $self->{size} = '400x400';
    $self->strips_html( $app->get_recently_completed_strips, $page ) || 'no strips found';;
}  #recent_strips

sub strip_html {
    my( $self, $strip, $strips, $page ) = @_;
    my $strip_class = $self->{is_detail} ? "strip detail" : "strip";
    my $strip_html = '<div class="$strip_class">';
    if( $strip->get__reserved_by ) {
        $strip_html .= $self->play_panel( $strip->_last_panel );
    }
    else {
        my $panels = $strip->get__panels;
        for my $i (0..(@$panels-1)) {
            my $panel = $panels->[$i];
            my $artist = $panel->get__artist;
            if( $self->{show_artist} ) {
                $strip_html .= sprintf( '<div><a class="artist-link" href="/spuc/artist/%s">%s</a></div>',
                                        $artist->{ID},
                                        dc( $artist->get_user ),
                    );
            }
            if( $panel->get_type eq 'sentence' ) {
                if( $i == 0 && $self->{show_detail} ) {
                    use Encode;
                    $strip_html .= sprintf( qq~<div class="sentence"><a href="/spuc/$page/detail/%s/%s">%s</a></div>~, 
                                            $strip->{ID},
                                            $self->{store}->_get_id( $strips ),
                                            dc( $panel->get_sentence ) );
                } else {
                    $strip_html .= '<div class="sentence">'. dc( $panel->get_sentence ) .'</div>';
                }
            } else {
                my $url = $panel->get_picture->url( $self->{size} || '400x400' );
                $strip_html .= qq~<img src="$url">~;
            }
            $strip_html .= "<br>";
        }
    }
    $strip_html .= '</div>';
    $strip_html;
} #strip_html

sub strips_html {
    my( $self, $strips, $page, $size ) = @_;
    my( $start ) = $self->shift_path;
    $start //= 0;
    $size  //= 4;
    my $end = $start + $size;

    if( @$strips == 0 ) {
        return '';
    }

    my $strip_html = '<div>';

    if( $end > @$strips ) {
        $end = @$strips;
    }

    if( $start > 0 || $end < @$strips ) {
        # needs pagination
        $strip_html .= "<div>";
        if( $start > 0 ) {
            my $newstart = $start - $size;
            if( $newstart < 0 ) {
                $newstart = 0;
            }
            $strip_html .= qq~<a href="/spuc/$page/paginate/$newstart">&lt;&lt;back</a>~;
        }
        if( $end < @$strips ) {
            if( $start > 0 ) {
                $strip_html .= ' ';
            }
            $strip_html .= qq~<a style="margin-left:2em;" href="/spuc/$page/paginate/$end">forward&gt;&gt;</a>~;
        }
        $strip_html .= "</div>";
    }

    $self->{show_detail} = 1;
    $strip_html .= '<div class="strips">';
    for( my $i=$start; $i<$end; $i++ ) {
        my $strip = $strips->[$i];
        $strip_html .= $self->strip_html( $strip, $strips, $page );
    }
    $strip_html .= '</div></div>';
    $strip_html;
} #strips_html

sub about {
    my $self = shift;
    my $recent = $self->recent_strips('recent');
    return <<"END";
        <p>
          <img class="starticon" src="/epuc_data/images/coyo.jpg"> Coyo here. I really miss the the <i><b>eat poop u cat</b></i> site,
          so I made this little clone of it. This site, madyote.com doesn&#39;t have much in the way of horsepower
          or even storage, so this is by necessity a small affair. The framework the site runs on requires javascript
          to use and is experimental so potentially buggy. For this reason, there are a few limitations on strips.
        </p>
        <p>
          To get an account, <a href="mailto:coyocanid\@gmail.com">contact me</a>  or any of the admins of the site. Include
          the user handle you would like.
        </p>
        <h3>Recent Strips</h3>
        <p class="recent-strips">$recent</p>
END
}

1;
