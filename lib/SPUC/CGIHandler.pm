package SPUC::CGIHandler;
 
use strict;
use warnings;

use Apache2::Request;
use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Upload;
use Apache2::Const qw(:common);
use APR::Request::Param;
use APR::Request::Apache2;
use Data::Dumper;

sub handler {
    my $r = Apache2::Request->new( shift );
    my $content =<<"END";
WELCOME
END
    $r->content_type('text/html');
    $r->print( $content );
    print STDERR Data::Dumper->Dump([$content]);
    return OK;
}


1;
