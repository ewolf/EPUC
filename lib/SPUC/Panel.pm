package SPUC::Panel;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

#
# Fields :
#   type - 'caption' or 'picture'
#   artist - artist obj who created this panel
#   caption - caption text ( if type is caption )
#   created - when this was created
#
#
sub note {
    my $self = shift;
    my $c = $self->get_caption;
    `echo '$c' > /tmp/wuu_$self`;
}

1;
