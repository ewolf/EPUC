#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

use lib '/home/wolf/proj/EPUC/lib';
use lib '/home/wolf/proj/Yote/ObjectStore/lib';
use lib '/home/wolf/proj/Yote/FixedRecordStore/lib';

use SPUC::RequestHandler;

use CGI;

use Data::Dumper;
use SPUC::Uploader;

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
        = SPUC::RequestHandler::handle( $path, $params, $sess_id, $uploader );
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
 );
#print "<html><body>FOO      🔍</body></html>"
print $$content_ref;
