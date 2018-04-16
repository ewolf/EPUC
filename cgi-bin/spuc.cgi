#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

use lib "$ENV{PROJHOME}/EPUC/lib";

use Encode qw/ decode encode /;
use CGI;

use Data::Dumper;
use File::Path qw/make_path mkpath/;

use SPUC::RequestHandler;
use SPUC::Uploader;

# ---------------------------------------
#     config
# ---------------------------------------

our $site         = $ENV{SERVER_NAME};
our $spuc_path    = '/cgi-bin/spuc.cgi';
our $basedir      = "/var/www";
our $template_dir = "$basedir/templates/spuc";
our $datadir      = "$basedir/data/spuc";
our $lockdir      = "$basedir/lock";
our $imagedir     = "$basedir/html/spuc/images";
our $logdir       = '/tmp/log';

umask(0);

my $group = getgrnam( 'www-data' );

make_path( $datadir, $lockdir, $template_dir,
           { group => $group, mode => 0775 } );

# ---------------------------------------
#     request
# ---------------------------------------

my $q = new CGI;

my $params = $q->Vars;

# grab session
my $sess_id = $q->cookie('session');
my( $path ) = ( $ENV{QUERY_STRING} =~ /path=([^\&\#]*)/ );
$path ||= '/';

# ---------------------------------------
#     processing
# ---------------------------------------

#
# uploads..hmmm
#
my $uploader = SPUC::Uploader::from_cgi( $q );

my( $content_ref, $status, $new_sess_id, $content_type );
if( $path eq '/RPC' ) {
    print STDERR Data::Dumper->Dump([$params, $sess_id, "RPC CALL"]);
    ( $content_ref, $status, $new_sess_id )
        = SPUC::RequestHandler::handle_RPC( $params, $sess_id, $uploader );
    $content_type = 'text/json';
}
else {
    ( $content_ref, $status, $new_sess_id )
        = SPUC::RequestHandler::handle( $path, $params, $sess_id, $uploader, {
            site         => $site,
            spuc_path    => $spuc_path,
            basedir      => $basedir,
            template_dir => $template_dir,
            datadir      => $datadir,
            lockdir      => $lockdir,
            imagedir     => $imagedir,
            logdir       => $logdir,
            group        => $group,
                                        } );
    $content_type = 'text/html;charset=UTF-8';

}
# ---------------------------------------
#     result
# ---------------------------------------
my $sesscook;

if( $sess_id ne $new_sess_id ) {
    if( $new_sess_id ) {
        $sesscook = $q->cookie(
            -name  => 'session',
            -value => $new_sess_id,
            );
    } else {
        # no new session id, so remove the old one
        $sesscook = $q->cookie(
            -name  => 'session',
            -expired => '+1s',
            -value => 0,
            );
    }
}

print $q->header( 
    -type => $content_type,
    -cookie => [$sesscook],
    -status => $status,
    -charset => 'utf-8',
 );

my $out = $$content_ref;
print $out;
