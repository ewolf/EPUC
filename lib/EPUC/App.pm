package EPUC::App;

use strict;
use warnings;
no warnings 'uninitialized';

use Yote;
use EPUC::Acct;
use EPUC::AdminAcct;

use base 'Yote::Server::App';

sub _acct_class { "EPUC::Acct" }

sub _init {
    my $self = shift;
    $self->SUPER::init;
    # TODO - way to update a password for an account
    my $first_admin = $self->_create_account( 'epuc', 'slatherSLAPTY---+', 'EPUC::AdminAcct' );
    $first_admin->get_avatar->set_user( 'epuc' );
    $first_admin->set_is_super(1);
    $first_admin->set_is_admin(1);
    $self->set__first_admin( $first_admin );

    $self->set_recently_completed_strips([]);
    $self->set__in_progress_strips([]);
}

sub hi {
    "HELLO";
}

sub _load {
    my $self = shift;

    $self->get__all_strips([]);
    
    for my $strip (@{$self->get_recently_completed_strips},@{$self->get__in_progress_strips}) {
        $self->add_once_to__all_strips( $strip );
        $strip->set_panel_size( 9 );
    }
    for my $acct (values %{$self->get__accts}) {
        for my $strip (@{$acct->get_reserved_strips},
                       @{$acct->get_in_progress_strips},
                       @{$acct->get_avatar->get_completed_strips},
            ) {
            $self->add_once_to__all_strips( $strip );
        }
    }

} #_load

sub lookup_player {
    my( $self, $name ) = @_;
    my $accts = $self->get__accts({});
    $accts->{lc($name)};
}

sub strip_list {
    my( $self, $mode, $sort, $artist ) = @_;
    
    my $login = $self->{SESSION}->get_acct;

    my $strips;
    if( $mode eq 'completed' ) {
        $strips = $self->get__completed_strips;
    }
    elsif( $mode eq 'artist-strips' ) {
        if( $sort eq 'pending' && $login && $artist == $login ) {
            $strips = $artist->get_in_progress_strips;
        } elsif( $sort eq 'reserved' && $login && $artist == $login ) {
            $strips = $artist->get_reserved_strips;
        } else {
            $strips = $artist->get_completed_strips;
        }
    }

    #sorting?
    if( $sort eq 'top' ) {

    } elsif( $sort eq 'discussed' ) {
        
    }
    
    $strips;
} #strip_list

sub completed_strips_old {
    my( $self, $sort ) = @_;
    # search thru all. if there become too
    # many, keep a running list that is updated
    # also, look at iterators, because they're dope
    if( $sort eq 'rating' ) {
        return [ sort { $b->get_rating_avg <=> $a->get_rating_avg } @{$self->get__completed_strips([])} ];
    }
    $self->get__completed_strips;
}

1;
