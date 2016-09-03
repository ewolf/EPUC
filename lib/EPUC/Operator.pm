package EPUC::Operator;

use strict;

use Apache2::Cookie;
use Apache2::Const qw(:common);
use Apache2::Upload;

use APR::Request::Param;

use UUID::Tiny;

use Yote::Server;

sub new {
    my( $class, $r ) = @_;
    my( $page, @rest ) = grep { $_ } split /\//, $r->path_info;

    my $jar = Apache2::Cookie::Jar->new($r);
    my $token_cookie = $jar->cookies("token");
    my $token = $token_cookie ? $token_cookie->value : 0;
    return bless {
        r     => $r,
        page  => $page,
        path  => \@rest,
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
      .logged-in .enclosure {
        margin-left: 15em;
      }
    </style>
  </head>
  
  <body class="$body_classes">
    <div class="header" style="float:right">
      <a href="/epucc/login" id="login-link">log in</a>
    </div>
    

    <div class="top">
      <h1>Scarf Poutine U Clone</h1>
    </div>

    <div class="body">

      <div class="side">
        <a href="/epucc/updateprefs"><img class="icon" src="$self->{icon_url}"><br></a>
        Welcome <span class="name">$self->{name}</span>
        <h3>Artwork</h3>
        <ul>
          <li><a href="/epucc/about" class="action">about</a></li>
          <li><a href="/epucc/recent" class="action">show recent strips</a></li>
          <li><a href="/epucc/completed" class="action">my completed strips</a></li>
          <li><a href="/epucc/inprogress" class="action">my in progress strips</a></li>
        </ul>
        <h3>Play</h3>
        <ul>
          <li><a href="/epucc/playstrip/find" class="action">find a strip to play</a></li>
          <li><a href="/epucc/startstrip" class="action">start a new strip</a></li>
          <li><a href="/epucc/reserved" class="action">my reserved strips</a></li>
        </ul>
        <h3>Actions</h3>
        <ul>
          <li><a href="/epucc/updateprefs" class="action">update user preferences</a></li>
          <li><a href="/epucc/logout" class="action" id="logout">log out</a></li>
        </ul>
        <div class="needs-admin">
          <h3>Admin Actions</h3>
          <ul>
            <li><a href="#list-accounts" class="action">list accounts</a></li>
            <li><a href="#create-account" class="action">create account</a></li>
            <li><a href="#set-password" class="action">set password</a></li>
            <li><a href="#strip-editor" class="action">strip editor</a></li>
            <li class="needs-super"><a href="#admin-in-progress" class="action">in progress strips</a></li>
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
                                                 -path => "/epucc",
                                                 -value => $self->{token} );
        
        $token_cookie->bake( $r );
    }
    
    my( $app, $login ) = $root->fetch_app( 'EPUC::App' );
    $app->{SESSION} = $root->{SESSION};
    $self->{app}   = $app;
    $self->{login} = $login;
    if( $login ) {
        push @{$self->{body_classes}}, 'logged-in';
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

sub path {
    @{shift->{path}};
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

sub make_main {
    my $self = shift;

    my $app = $self->app();

    my $page = $self->{page};
    my $r = $self->{r};

    if( $page eq 'comic' ) {

    } elsif( $page eq 'play' ) {

    } elsif( $page eq 'recent' ) {
        #pagination
        my $strips = $self->recent_strips;
        $self->{main} = <<"END";
<h2>Recent Strips</h2>
$strips
END
        
    } elsif( $page eq 'reserved' ) {        
        my $login = $self->login;

        #pagination
        my $strips = $self->strips_html( $login->get_reserved_strips, '/epucc/reserved/' );
        $self->{main} = <<"END";
<h2>My reserved strips</h2>
$strips
END
    } elsif( $page eq 'artist' ) {
        # show icon, name and about
        # then recent strips
        my( $avatar_id ) = $self->path;
        my $avatar = $self->{store}->fetch($avatar_id);
        if( $avatar ) {
            my( $handle, $name, $about ) = map { dc($_) } (
                $avatar->get_user,
                $avatar->get_name,
                $avatar->get_about );

            if( $name ) { $name = "<h3>Given Name</h3>$name" }
            if( $about ) { $about = "<h3>About</h3>$about" }
            
            my $icon_url = $avatar->get_icon->url( '400x400' );
            $self->{main} = <<"END";
 <h1>$handle</h1>
 <img src="$icon_url"> <br>
 $name
 $about
END
        }
        
    } elsif( $page eq 'completed' ) {
        my $login = $self->login;

        #pagination
        my $strips = $self->strips_html( $login->get_avatar->get_completed_strips, '/epucc/completed/' );
        $self->{main} = <<"END";
<h2>My completed strips</h2>
$strips
END
    } elsif( $page eq 'detail' ) {
        $self->{size} = '700x700';
        $self->{show_artist} = 1;
        my( $strip_id, $strips_id ) = $self->path;
        my( $strip, $strips ) = map { $self->{store}->fetch($_) } ( $strip_id, $strips_id );
        # complete strips can strips with you as a participant can be displayed in detail
        
        if( $strip && $strip->can_see( $self->{login} ) ) {
            my $strip_html = $self->strip_html( $strip, $strips );
            my $prevnext = '';
            if( ref $strips eq 'ARRAY' ) {
                if( @$strips > 1 ) {
                    $prevnext = '<div>';
                    for( my $i=0; $i<@$strips; $i++ ) {
                        my $list_strip = $strips->[$i];
                        if( $strip == $list_strip ) {
                            if( $i > 0 ) {
                                my $prev = $strips->[$i-1];
                                $prevnext .= sprintf( '<a href="/epucc/detail/%s/%s">%s</a>',
                                                      $prev->{ID},
                                                      $strips_id,
                                                      'prev' );
                            }
                            if( $i < $#$strips ) {
                                if( $i > 0 ) {
                                    $prevnext .= ' ';
                                }
                                my $next = $strips->[$i+1];
                                $prevnext .= sprintf( '<a href="/epucc/detail/%s/%s">%s</a>',
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
    } elsif( $page eq 'playstrip' ) {
        my @path = $self->path;
        my $action = shift @path;
        my $login = $self->login;
        if( $action eq 'submitsentence' ) {
            my( $panel ) = ( map { $self->{store}->fetch( $_ ) } @path );
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
            my( $panel ) = ( map { $self->{store}->fetch( $_ ) } @path );
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
            my( $panel_id ) = @path;
            my $panel = $self->{store}->fetch( $panel_id );
            $panel->reserve( $login );
            $self->{main} = "Reserved Strip. You can find this under the 'reserved strips list'";
        } elsif( $action eq 'free' ) {
            my( $panel_id ) = @path;
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
            $self->{main} = $self->about();
        } else {
            $self->{main} = <<"END";
<h2>Start a Strip</h2>
<form action="/epucc/startstrip" method="POST">
  <textarea name="startsentence"></textarea>
  <br>
  <input type="submit" value="start new strip">
</form>
END
        }
    } elsif( $page eq 'inprogress' ) {
        my $login = $self->login;
        my $strip_html = $self->strips_html( $login->get_in_progress_strips, '/epucc/inprogress/' );
        $self->{main} =<<"END";
<h2>In Progress Strips</h2>
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
 <form method="POST" enctype="multipart/form-data" action="/epucc/updateprefs">
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
                    $self->{main} = $self->about();
                    push @{$self->{body_classes}}, 'logged-in';
                    $self->{message} = "logged in as $un";
                };
                if( $@ ) {
                    $err_span = '<span class="error">' . err( $@ ) . '</span>';
                }
            }
            unless( $self->{login} ) {
                $self->{main} = <<"END";
$err_span
<form action="/epucc/login" method="POST">
  <table>
    <tr> <th>Handle</th>   <td><input type="text" name="un"> </td> </tr>
    <tr> <th>Password</th> <td><input type="password" name="pw"> </td> </tr>
  </table><BR>
  <input type="submit" value="Log In">
</form>
END
            }
        } else {
            $self->{main} = $self->about();
        }
    } elsif( $page eq 'logout' ) {
        my $token_cookie = Apache2::Cookie->new( $r,
                                                 -name => "token",
                                                 -path => "/epucc",
                                                 -value => 0 );
        $token_cookie->bake( $r );
        $self->{message} = 'logged out';
        $self->{body_classes} = [grep { $_ ne 'logged-in' } @{$self->{body_classes}}];
        $self->{main} = $self->about();
    } else {  #about page
        $self->{main} = $self->about();
    }

    $self->save;
} #make_main

sub play_panel {
    my( $self, $panel ) = @_;
    if( $panel->get_type eq 'sentence' ) {
        my $can_free = $panel->get__reserved_by;
        return sprintf( 'Submit and image for this sentence' .
                        '<form method="POST" enctype="multipart/form-data" action="/epucc/playstrip/submitpicture/%s">' .
                        '<div class="sentence">%s</div>'.
                        '<br>'.
                        '<input type="file" name="pictureup">'.
                        '<input type="submit" value="submit picture">'.
                        '</form><p>'.
                        ( $can_free ? '<a href="/epucc/playstrip/free/%s">stop reserving this sentence</a>' :
                          '<a href="/epucc/playstrip/reserve/%s">reserve this sentence for later</a>' ) .
                        '</p>',
                        $panel->{ID},
                        dc( $panel->get_sentence ),
                        $panel->{ID},
            );
    } else {
        my $url = $panel->get_picture->url( '700x700' );
        return sprintf( '<img src="%s"><br> ' .
                        '<form method="POST" action="/epucc/playstrip/submitsentence/%s">' .
                        ' Enter a caption <textarea name="newcaption"></textarea>' .
                        ' <input type="submit">' .
                        '</form>', $url, $panel->{ID} );
    }
}

sub recent_strips {
    my $self = shift;
    my $app = $self->app();
    $self->strips_html( $app->get_recently_completed_strips, '/epucc/recent/' );
}  #recent_strips

sub strip_html {
    my( $self, $strip, $strips ) = @_;
    my $strip_html = '<div class="strip">';
    if( $strip->get__reserved_by ) {
        $strip_html .= $self->play_panel( $strip->_last_panel );
    }
    else {
        my $panels = $strip->get__panels;
        for my $i (0..(@$panels-1)) {
            my $panel = $panels->[$i];
            my $artist = $panel->get__artist;
            if( $self->{show_artist} ) {
                $strip_html .= sprintf( '<div><a class="artist-link" href="/epucc/artist/%s">%s</a></div>',
                                        $artist->{ID},
                                        dc( $artist->get_user ),
                    );
            }
            if( $panel->get_type eq 'sentence' ) {
                if( $i == 0 && $self->{show_detail} ) {
                    use Encode;
                    $strip_html .= sprintf( '<a href="/epucc/detail/%s/%s">%s</a>', 
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
    my( $self, $strips, $href, $size ) = @_;
    my( $start ) = $self->path;
    $start //= 0;
    $size  //= 4;
    my $end = $start + $size;

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
            $strip_html .= qq~<a href="$href$newstart">back</a>~;
        }
        if( $end < @$strips ) {
            if( $start > 0 ) {
                $strip_html .= ' ';
            }
            $strip_html .= qq~<a style="margin-left:2em;" href="$href$end">forward</a>~;
        }
        $strip_html .= "</div>";
    }

    $self->{show_detail} = 1;
    $strip_html .= '<div class="strips">';
    for( my $i=$start; $i<$end; $i++ ) {
        my $strip = $strips->[$i];
        $strip_html .= $self->strip_html( $strip, $strips );
    }
    $strip_html .= '</div></div>';
    $strip_html;
} #strips_html

sub about {
    my $self = shift;
    my $recent = $self->recent_strips;
    return <<"END";
        <p>
          <img class="starticon" src="/epuc/images/coyo.jpg"> Coyo here. I really miss the the <i><b>eat poop u cat</b></i> site,
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