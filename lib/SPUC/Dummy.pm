package SPUC::Dummy;

#
# Dummy user to prevent timing oracle.
#

use strict;
use warnings;

use Data::ObjectStore;
use SPUC::Artist;
use base 'SPUC::Artist';

use Digest::MD5;

#always returns false
sub _checkpw {
    my( $self, $pw ) = @_;
    $self->SUPER::_checkpw($pw);
    0;
}


1;
