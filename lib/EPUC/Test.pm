package EPUC::Test;

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const qw(:common);
use Data::Dumper;

sub handler {
    print STDERR Data::Dumper->Dump(["CALL",\@_]);
    my $r = shift;
    $r->content_type('text/html');
    $r->print("HELLO WEB");
    return OK;
}

1;
