package SPUC::Image;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

sub src {
    my $self = shift;
    my $of = $self->get__origin_file;
    $of =~ s!/var/www/html!!;
    $of;
}

1;
