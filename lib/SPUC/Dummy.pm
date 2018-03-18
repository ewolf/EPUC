package SPUC::Dummy;

#
# Dummy user to prevent timing oracle.
#

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use Digest::MD5;

#always returns false
sub _checkpw {
    my( $self, $pw ) = @_;
    my $un = $self->get__login_name;
    my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
    0;
}

1;
