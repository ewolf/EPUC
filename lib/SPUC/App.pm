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
        needs       => 4, # TODO - remove for prod
        app         => $self,
                                          } );
    
    $artist->add_to__unfinished_comics( $comic );

    $self->add_to__unfinished_comics( $comic );

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
    sort { (0*$b) + rand() <=> (0*$a) + rand() }  # initial random sort
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

    my $link = "https://madyote.com/cgi-bin/yote.cgi\?path=/recover\&tok=$restok";
    
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
        From => 'noreply@madyote.com',
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