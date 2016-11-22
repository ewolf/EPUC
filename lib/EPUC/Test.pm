package EPUC::Test;

use strict;

use Apache2::Request;
use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Upload;
use Apache2::Const qw(:common);
use APR::Request::Param;
use APR::Request::Apache2;
use Data::Dumper;

use EPUC::Operator;

sub handler {
    my $r = Apache2::Request->new( shift );

    my $operator = new EPUC::Operator(
        template_path => '/opt/yote/templates',
        );
    $operator->handle_request( $r );
} #handler

1;
