package SPUC::Base;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

sub privatize {
    my( $self, @fields ) = @_;
    for my $fld (@fields) {
        $self->set( "_$fld", $self->get( $fld ) );
        $self->set( $fld, undef );
    }
}

1;
