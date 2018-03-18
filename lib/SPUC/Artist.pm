package SPUC::Artist;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use Digest::MD5;


#
# Fields :
#
# ** credentials**
#  display_name
#  _email
#  _login_name
#  _enc_pw
#
# ** session management **
#  _session - session object
#  _created  - time
#  _logged_in_since - time
#
# ** about the user **
#  _avatars
#  _deleted_avatars
#  avatar
#  bio
#
#  ** comics **
#  _unfinished_comics
#  finished_comics - list of comic objects, more recent are first
#
# ** game state **
#  _playing - comic object currently playing
#
sub _setpw {
    my( $self, $pw ) = @_;
    my $un = $self->get__login_name;
    my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
    $self->set__enc_pw( $enc_pw );
}

sub _checkpw {
    my( $self, $pw ) = @_;
    my $un = $self->get__login_name;
    my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
    $enc_pw eq $self->get__enc_pw;
}

sub _display {
    my $self = shift;
    my $ln = $self->get__login_name;
    my $dn = $self->get_display_name;
    if( $ln ne $dn ) {
        return "$dn/$ln";
    } else {
        return $ln;
    }
}


1;
