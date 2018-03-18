package SPUC::Session;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

#
# Fields :
#   ids  - id -> object known to the session
#   user - owner of the session
#


sub fetch {
    my( $self, $id ) = @_;
    my $ids = $self->get_ids({});
    return $ids->{$id};
}

sub stow {
    my( $self, $item ) = @_;
    my $id = $self->store->_get_id( $item );
    my $ids = $self->get_ids({});
    $ids->{$id} = $item;
    return $id;
}

1;
