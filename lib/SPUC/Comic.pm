package SPUC::Comic;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use SPUC::Panel;

sub needs {
    my $self = shift;
}

sub has_artist {
    my( $self, $artist ) = @_;
    return $self->get_artists->{$artist};
}

sub is_last_artist {
    my( $self, $artist ) = @_;
    $artist == $self->get_last_artist;
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
    
    if( $self->last_panel->get_type eq 'caption' ) {
        return ('', 'caption cant follow caption' );
    }
    my $panel = $self->store->create_container( 'SPUC::Panel', {
        artist  => $user,
        caption => $caption,
        type    => 'caption',
                                          } );
    $self->add_panel( $panel, $user );
}
sub add_picture {
    my( $self, $picture, $user ) = @_;
    if( $self->last_panel->get_type eq 'picture' ) {
        return ('', 'picture cant follow picture' );
    }
    my $panel = $self->store->create_container( 'SPUC::Panel', {
        artist  => $user,
        picture => $picture,
        type    => 'picture',
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
    $arts->{$user} = $user;
    $user->add_once_to__unfinished_comics( $self );

    if( $self->is_complete ) {
        my $app = $self->get_app;
        $app->remove_from__unfinished_comics( $self );
        my $finished = $app->get_finished_comics([]);
        unshift @$finished, $self;
        
        for my $art (values %$arts) {
            $art->remove_from__unfinished_comics( $self );
            my $finished = $art->get_finished_comics([]);
            unshift @$finished, $self;
        }
        return ('comic was finished','');
    }

    return ('added panel','');
} #add_panel

1;
