package EPUC::Operator;

use strict;

use Apache2::Cookie;
use Apache2::Const qw(:common);
use APR::Request::Param;

use UUID::Tiny;

use Yote::Server;

print STDERR Data::Dumper->Dump(["LOadyOP"]);

sub new {
    my( $class, $r, $orig ) = @_;
    my( $page, @rest ) = grep { $_ } split /\//, $r->path_info;

    my $jar = Apache2::Cookie::Jar->new($r);
    my $token_cookie = $jar->cookies("token");
    my $token = $token_cookie ? $token_cookie->value : 0;
    return bless {
        r     => $r,
        orig  => $orig,
        page  => $page,
        path  => \@rest,
        token => $token,
    }, $class;
}

sub make_page {
    my $op = new EPUC::Operator( @_ );
    $op->_make_page;
}

sub _make_page {
    my $self = shift;
    
    $self->make_main;

    my $main = $self->{main};
    
    my $r = $self->{r};
    
    # see if there is a token that leads to a logged in account
    
    print STDERR Data::Dumper->Dump(["ERRY?",$@]);
    my $body_classes = join ' ', @{$self->{body_classes}};
    if( ref $@ eq 'HASH' ) {
        $main = $@->{err};
    }
    elsif( ref $@ eq 'HASH' ) {
        $main = "Internal Server Error";
    }

    my $html = <<"END";
<!DOCTYPE html>
<html>
  <head>
    <title>EPUC</title>
    <script src="/js/jquery-1.12.0.min.js"></script>
    <script src="/js/yote.js"></script>

    <style>
      div { border: solid 1px black; }

      .side { float: left; display: none; }

      .logged-in .side { display: block; }

      .logged-in #login-link {
        display : none;
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

    <span class="message">$self->{message}</span>
    
    <div class="body">

      <div class="side">
        <a href="/epucc/updateprefs"><img class="icon" src="$self->{icon_url}"><br></a>
        Welcome <span class="name"></span>
        <h3>Artwork</h3>
        <ul>
          <li><a href="/epucc/about" class="action">about</a></li>
          <li><a href="#recentstrips" class="action">show recent strips</a></li>
          <li><a href="#completed" class="action">my completed strips</a></li>
          <li><a href="#inprogress" class="action">my in progress strips</a></li>
        </ul>
        <h3>Play</h3>
        <ul>
          <li><a href="#findstrip" class="action">find a strip to play</a></li>
          <li><a href="#startstrip" class="action">start a new strip</a></li>
          <li><a href="#reserved" class="action">my reserved strips</a></li>
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

      <div class="main">$main</div>
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

    my $root = $server->store->fetch_server_root;
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
    }
    return $app;
} #app

sub err {
    my $err = shift;
    if( ref( $err ) eq 'HASH' ) {
        return $err->{err};
    } else {
        return 'Internal Server Error';
    }
}

sub make_main {
    my $self = shift;

    my $app = $self->app();

    my $page = $self->{page};
    my $r = $self->{r};

    if( $page eq 'comic' ) {

    } elsif( $page eq 'play' ) {
        
    } elsif( $page eq 'start' ) {

    } elsif( $page eq 'updateprefs' ) {        
        my $login = $self->{login};
        unless( $login ) {
            die "not loggged in";
        }
        my $ava = $login->get_avatar;
                    
        # check for inputs
        use Apache2::Upload;
        my $orig = $self->{orig};
        my $upload = $r->upload("iconup");

        if( $upload ) {
            my $fn = $upload->filename;
            my( $original_name, $extension )  = ( $fn =~ m!([^/]+\.([^/\.]+))$! );

            my $tmprand = "/tmp/".UUID::Tiny::create_uuid_as_string();
            $upload->link( $tmprand );
            print STDERR Data::Dumper->Dump([$fn,$original_name,$extension,"BGOS ($tmprand)"]);
            my $img = $self->{server}->store->newobj( {
                file_name      => $original_name,
                file_extension => $extension,
                file_path      => $tmprand,
                                                          } );
            $login->uploadIcon( $img );
            $self->{icon_url} = $ava->get_icon->url( '80x80' );
        } #if image upload
        my $name = $ava->get_name;
        my $about = $ava->get_about;
        if( $r->param('info') eq 'update info' ) {
            ( $name, $about ) = ( $r->param( 'name' ), $r->param( 'about' ) );
            $ava->set_name( $name );
            $ava->set_about( $about );
        }
        $self->{main} = <<"END";
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
                    $self->{main} = about();
                    push @{$self->{body_classes}}, 'logged-in';
                    $self->{message} = "logged in as $un";
                };
                if( $@ ) {
                    print STDERR Data::Dumper->Dump([$@,"SS"]);
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
            $self->{main} = about();
        }
    } elsif( $page eq 'logout' ) {
        my $token_cookie = Apache2::Cookie->new( $r,
                                              -name => "token",
                                              -path => "/epucc",
                                              -value => 0 );
        $token_cookie->bake( $r );
        $self->{message} = 'logged out';
        $self->{body_classes} = [grep { $_ ne 'logged-in' } @{$self->{body_classes}}];
        $self->{main} = about();
    } else {  #about page
        $self->{main} = about();
    }

    $self->save;
} #make_main

sub about {
    "about";
}

1;
