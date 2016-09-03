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


sub handler {
    my $orig = shift;
    my $r = Apache2::Request->new( $orig );

    #
    # For debug have this reload each time so I don't have to
    # retstart the f%^&n server.
    #
    
    my $dostuff = "/home/wolf/proj/EPUC/lib/EPUC/Operator.pm";
    delete $INC{$dostuff};
    require $dostuff;

    my $ret = EPUC::Operator::make_page( $r, $orig );
    
    return $ret;
} #handler

1;
