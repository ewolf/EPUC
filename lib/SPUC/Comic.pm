package SPUC::Comic;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use SPUC::Panel;

#
# Fields :
#   started  - when this was started
#   finished - when this was completed
#   rating   - rating of comic
#   comments - list of comments
#   creator - who started this strip
#   _player - Artist object who is currently playing this
#   artists - hash (set) of artists working on this
#   panels - list of Panel objects that make this up
#   needs - number of panels this needs to have to be complete
#   app - app object
#
#

sub needs {
    my $self = shift;
}

sub has_artist {
    my( $self, $artist ) = @_;
    return $self->get_artists->{$artist};
}

sub is_last_artist {
    my( $self, $artist ) = @_;
    $artist == $self->last_panel->get_artist;
}

sub last_panel {
    my $self = shift;
    my $panels = $self->get_panels;
    return $panels->[$#$panels];
}
sub is_complete {
    my $self = shift;
    return @{$self->get_panels} >= $self->get_needs;
}
sub add_caption {
    my( $self, $caption, $user ) = @_;

    if( ! $self->is_free( $user ) ) {
        return ('', 'this comic is reserved by an other artist' );
    }
    if( $self->last_panel->get_type eq 'caption' ) {
        return ('', 'caption cant follow caption' );
    }
    my $panel = $self->store->create_container( 'SPUC::Panel', {
        artist  => $user,
        caption => $caption,
        type    => 'caption',
        comic   => $self,
                                                } );
    $self->add_panel( $panel, $user );
}

sub add_picture {
    my( $self, $picture, $user ) = @_;

    if( ! $self->is_free( $user ) ) {
        return ('', 'this comic is reserved by an other artist' );
    }
    
    if( $self->last_panel->get_type eq 'picture' ) {
        return ('', 'picture cant follow picture' );
    }
    my $panel = $self->store->create_container( 'SPUC::Panel', {
        artist  => $user,
        picture => $picture,
        type    => 'picture',
        comic   => $self,
                                          } );
    $self->add_panel( $panel, $user );
}
sub add_panel {
    my( $self, $panel, $user ) = @_;
    my $panels = $self->get_panels;
    if( $self->is_complete ) {
        return ('', 'strip already completed' );
    }
    my $type = $panel->get_type;
    if( $self->last_panel->get_type eq $panel->get_type ) {
        return ('', "$type cant follow $type" );
    }
    push @$panels, $panel;
    my $arts = $self->get_artists;

    $self->set_last_updated( time );

    $user->add_once_to__unfinished_comics( $self );
    $user->add_once_to__all_comics( $self );
    
    $arts->{$user} = $user;

    return ('added panel','');
} #add_panel

sub is_free {
    my( $self, $user ) = @_;
    ! $self->is_complete && 
        ( $self->get__player == $user || $self->get__hold_expires < time || ! $self->get__player);
}

1;
