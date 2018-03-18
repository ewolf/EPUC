package SPUC::Artist;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use Digest::MD5;
use MIME::Lite;

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
#  _unfinished_comics - list of comic objects
#  finished_comics - linked list node of comic objects
#  _bookmarks
#
# ** game state **
#  _viewing_comic - current comic viewed in pagination
#  _viewing_source  - 'recent', 'top', 'bookmarks', 'mine', 'inprogress', etc...
#  _playing - comic object currently playing
#
sub _setpw {
    my( $self, $pw ) = @_;
    my $un = $self->get__login_name;
    my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
    $self->set__enc_pw( $enc_pw );
} #_setpw

sub _checkpw {
    my( $self, $pw ) = @_;
    my $un = $self->get__login_name;
    my $enc_pw = crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($un) );
    $enc_pw eq $self->get__enc_pw;
} #_checkpw

sub _display {
    my $self = shift;
    my $ln = $self->get__login_name;
    my $dn = $self->get_display_name;
    if( $ln ne $dn ) {
        return "$dn/$ln";
    } else {
        return $ln;
    }
} #_display

sub _send_confirmation_email {
    my( $self ) = @_;
}

sub _has_bookmark {
    my( $self, $comic ) = @_;
    defined $self->get__bookmark_hash({})->{$comic}
}

sub bookmark {
    my( $self, $comic ) = @_;
    unless( $self->_has_bookmark( $comic ) ) {
        $self->get__bookmark_hash->{$comic} = $comic;
        $self->add_to__bookmarks( $comic );
    }
}
sub unbookmark {
    my( $self, $comic ) = @_;
    delete $self->get__bookmark_hash->{$comic};
    $self->remove_from__bookmarks( $comic );
}

sub has_kudo_for {
    my( $self, $panel ) = @_;
    defined $self->get__kudos({})->{$panel};
}
sub kudo {
    my( $self, $panel ) = @_;
    $self->get__kudos({})->{$panel} = $panel;
    $panel->set_kudos( 1 + $panel->get_kudos );
    $panel->set__kudo_givers({})->{$self} = $self;
    my $artist = $panel->get_artist;
    
    my $updates = $artist->get__updates([]);
    unshift @$updates, { msg  => "you got a kudo",
                         type => 'comic',
                         comic => $panel->get_comic };
}
1;
