package EPUC::Test;

use strict;

use Apache2::Request;
use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const qw(:common);
use Apache2::Cookie;
use APR::Request::Param;
use APR::Request::Apache2;
use Data::Dumper;

sub handler {
    my $r = Apache2::Request->new(shift);

    # page info
    my( $page, @rest ) = grep { $_ } split /\//, $r->path_info;

    # see if there is a token that leads to a logged in account
    my $jar = Apache2::Cookie::Jar->new($r);
    my $token_cookie = $jar->cookies("token");
    my $token = $token_cookie ? $token_cookie->value : 0;

    my $main = '';
    if( $page eq 'comic' ) {

    } elsif( $page eq 'play' ) {
        
    } elsif( $page eq 'start' ) {
        
    } elsif( $page eq 'login' ) {
        my( $un, $pw ) = ( $r->param('username'), $r->param('password') );
        $main = "Login called ($un,$pw)";
        $token_cookie = Apache2::Cookie->new( $r,
                                              -name => "token",
                                              -path => "/epucc",
                                              -value => 22 );
        $token_cookie->bake( $r );
    } elsif( $page eq 'logout' ) {
        $main = "Logout called";
        $token_cookie = Apache2::Cookie->new( $r,
                                              -name => "token",
                                              -path => "/epucc",
                                              -value => 0 );
        $token_cookie->bake( $r );
    } else {  #about page
        $main = 'about'
    }

    my $html = <<"END";
<!DOCTYPE html>
<html>
  <head>
    <style>
      div { border: solid 1px black; }
    </style>
  </head>
  
  <body>
    <h1>Test Page ($token)</h1>
    <div>$main</div>
    <div>
      <form method="POST" action="/epucc/login">
        <input type="text" placeholder="username" name="username"> 
        <input type="password" placeholder="password" name="password"> 
        <input type="submit" value="Log In"> 
      </form>
    </div>
    <a href="/epucc/logout">Log Out</a>
  </body>
</html>
END

    
    $r->content_type('text/html');
    $r->print( $html );
    return OK;
} #handler

sub makePage {
    
}

1;
