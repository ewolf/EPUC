package EPUC::Util;

use CGI;
use DateTime;
use Data::Dumper;
use JSON;
use URI::Escape;

sub _log {
    my( $msg ) = @_;
    open my $out, ">>/opt/yote/log/yote.log";
    print $out "$msg\n";
}

sub init {
    unless( $main::yote_server ) {
        eval('use Yote::ConfigData');
        my $yote_root_dir = $@ ? '/opt/yote' : Yote::ConfigData->config( 'yote_root' );
        unshift @INC, "$yote_root_dir/lib";

        my $options = Yote::Server::load_options( $yote_root_dir );

        $main::yote_server = new Yote::Server( $options );
    }

    my $cgi = CGI->new;
    return( $main::yote_server, $cgi );
} #init

1;
