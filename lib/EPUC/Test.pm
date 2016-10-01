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
    my $r = Apache2::Request->new( shift );

    #
    # For debug have this reload each time so I don't have to
    # retstart the f%^&n server.
    #
    my $basedir = "/home/wolf/proj/EPUC/lib/EPUC/";
    opendir my $dir, $basedir;
    my $SNARK;
    map {
        my $p = "$basedir$_";
        delete $INC{$p};
        require $p;
    } grep { /pm$/ } readdir( $dir );

    my $op = '/home/wolf/proj/Yote/ServerYote/lib/Yote/Server/ModperlOperator.pm';
    delete $INC{$op};
    require $op;

    my $operator = new EPUC::Operator(
        template_path => '/opt/yote/templates',
        );
    $operator->handle_request( $r );
} #handler

1;
