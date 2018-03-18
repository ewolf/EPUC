package SPUC::App;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use SPUC::Comic;
use SPUC::Panel;

#
# Fields :
#   _unfinished_comic_head - linkedlistnode containting comic
#
#
#
#

sub begin_strip {
    my( $self, $artist, $caption ) = @_;

    if( length( $caption ) < 1 ) {
        return ('','missing caption');
    }
    my $store = $self->store;
    
    my $panel = $store->create_container( 'SPUC::Panel', {
        artist  => $artist,
        created => time,
        caption => $caption,
        type    => 'caption',
                                          } );
    
    my $comic = $store->create_container( 'SPUC::Comic', {
        creator     => $artist,
        started     => time,
        artists     => { $artist => $artist },
        last_artist => $artist,
        panels      => [ $panel ],
        needs       => 2, # TODO - remove for prod
        app         => $self,
                                          } );
    
    $artist->add_to__unfinished_comics( $comic );
    
    $self->add_to__unfinished_comics( $comic );

    return ("started comic",'');
    
} #begin_strip

sub find_comic_to_play {
    my( $self, $artist, $skip ) = @_;
    
    my $last_comic = $artist->get__playing;
    if( ! $skip && $last_comic ) {
        return $last_comic;
    }
    
    my $comics = $self->get__unfinished_comics;

    # comics are randomly sorted, other than comics with this artist are sorted last and
    # of those, the same artist is sorted very last
    my( $comic ) = sort { $a->has_artist($artist) && $b->has_artist($artist) ? 
                              $a->is_last_artist($artist) && $b->is_last_artist($artist) ? 0 : $a->is_last_artist($artist) ? 1 : -1
                              : $a->has_artist($artist) ? 1 : -1 
    } # comics that this artist has not contributed to are sorted first. comics that this artist was the last one
      #  to contribute to are sorted last
    sort { (0*$b) + rand() <=> (0*$a) + rand() }  # initial random sort
    grep { (! $skip) || $_ ne $last_comic } # if the comic was skipped dont show it again
    grep { ! $_->get__player }  #comics not being currently played
    @$comics;

    $comic;
    
} #find_comic_to_play

1;
