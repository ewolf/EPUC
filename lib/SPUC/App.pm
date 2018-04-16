package SPUC::App;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

use SPUC::Comic;
use SPUC::Panel;

our @mon = qw( jan feb mar apr may jun jly aug sep oct nov dec );
#
# Fields :
#   _unfinished_comics - list
#   finished_comics    - list
#   default_session
#   dummy_user
#   _sessions - sessid -> session obj
#   _emails - email to -> artist
#   _unames - user name -> artist
#

sub artist {
    my( $self, $name ) = @_;
    $self->get__users->{$name};
} #artist

sub format_time {
    my( $self, $time ) = @_;
    my( @thentime ) = localtime( $time // time );
    my( @nowtime )  = localtime( time );

    #
    #    0    1     2     3    4     5
    #  sec, min, hour, mday, mon, year
    #
    
    # different year
    if( $thentime[5] != $nowtime[5] ) {
        return sprintf( "%s %02d", $mon[$thentime[4]], $thentime[5] + 1900);
    }
    if( $thentime[4] != $nowtime[4] || $nowtime[3] > (1+$thentime[3])) {
        return sprintf( "%s %d", $mon[$thentime[4]], $thentime[3] );
    }
    if( $nowtime[3] == $thentime[3] ) {
        return sprintf( "today %02d:%02d", $thentime[2], $thentime[1] );
    }
    return sprintf( "yesterday %02d:%02d", $thentime[2], $thentime[1] );

}

sub artists {
    [sort { $a->get__login_name cmp $b->get__login_name } values %{shift->get__users}];
}

sub begin_strip {
    my( $self, $artist, $caption ) = @_;

    if( ! $artist ) {
        return ('','missing artist');
    }
    
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
        needs       => 9,
        app         => $self,
                                          } );
    
    $artist->add_to__unfinished_comics( $comic );
    $artist->add_once_to__all_comics( $comic );

    $self->add_to__unfinished_comics( $comic );
    $self->add_to__all_comics( $comic );

    return ("started comic",'');
    
} #begin_strip


sub find_comic_to_play {
    my( $self, $artist, $skip ) = @_;
    
    my $last_comic = $artist->get__playing;
    if( $last_comic ) {
        if( $skip ) {
            $last_comic->set__player(undef);
        } else {
            return $last_comic;
        }
    }
    my $comics = $self->get__unfinished_comics;

    # comics are randomly sorted, other than comics with this artist are sorted last and
    # of those, the same artist is sorted very last
    my( $comic ) = sort { $a->has_artist($artist) && $b->has_artist($artist) ? 
                              $a->is_last_artist($artist) && $b->is_last_artist($artist) ? 0 : $a->is_last_artist($artist) ? 1 : -1
                              : $a->has_artist($artist) ? 1 : -1 
    } # comics that this artist has not contributed to are sorted first. comics that this artist was the last one
      #  to contribute to are sorted last
    sort { (@{$b->get_panels}) * rand() <=> (@{$b->get_panels}) * rand() }  # initial random sort, favoring more complete comics
    grep { (! $skip) || $_ ne $last_comic } # if the comic was skipped dont show it again
    grep { ! $_->get__player }  #comics not being currently played
    @$comics;
    
    $comic;
    
} #find_comic_to_play


sub _send_reset_request {
    my( $self, $user ) = @_;

    my $resets = $self->get__resets({});
    
    my $restok;
    my $found;
    until( $found ) {
        $restok  = int( rand( 10_000_000 ) );
        $found = ! $resets->{$restok};
    }
    $resets->{$restok} = $user;
    my $gooduntil = time + 3600;
    
    $user->set__reset_token( $restok );
    $user->set__reset_token_good_until( $gooduntil );

    my $site = $self->get_site;
    my $path = $self->get_spuc_path;
    my $link = "https://$site$path\?path=/recover\&tok=$restok";
    
    my $body_html = <<"END";
<body>
<h1>SPUC Password Reset Request</h1>

<p>
To reset your password, please visit <a href="$link">$link</a>.
This link will work for an hour. If you did not request this, please let us know.
</p>

<p>Thanks</p>

<p style="font-style:italic">Scarf Poutine You Clone</p>

</body>
END

    my $body_txt = <<"END";
SPUC Password Reset Request

To reset your password, please visit 
$link.
This link will work for an hour. 
If you did not request this, please let us know.

Thanks
  Scarf Poutine You Clone

END

    my $msg = MIME::Lite->new(
        From => "noreply\@$site",
        To   => $user->get__email,
        Subject => 'SPUC Password Reset',
        Type => 'multipart/alternative',
        );
    
    $msg->attach(Type => 'text/plain', Data => $body_txt);
    $msg->attach(Type => 'text/html', 
                 Data => $body_html, 
                 Encoding => 'quoted-printable');
    
    $msg->send;

    
} #_send_reset_request


1;
