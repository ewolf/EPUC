package EPUC::NewsItem;

use strict;

use Yote::Server;
use base 'Yote::ServerObj';

sub show {
    my $self = shift;
    my $seen = $self->set_seen( $self->get_seen + 1 );
    if( $seen > $self->get_showtimes ) {
        $self->get_acct->remove_from_news( $self );
    }
}

1;

__END__

Attached to a player, the news item tracks if it has been 
seen or not and sort of fades away.
