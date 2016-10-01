package EPUC::Panel;

use strict;

use Yote::Server;

use base 'Yote::ServerObj';

sub _init {
    my $self = shift;
    #
    # type (sentence|picture)
    # _artist
    # sentence
    # picture
    # _reserved_by (Avatar)
    #
}

sub _load {
    my $self = shift;
}

sub hasKudoFrom {
    0;
}

sub is_active_panel {
    my $self = shift;
    my $strip = $self->get__strip;
    my $strip_panels = $strip->get__panels;
    return $strip->get__state eq 'pending' && $self->get__panel_number == $#$strip_panels;
}

sub reserve {
    my( $self, $acct ) = @_;
    die "Not active panel" unless $self->is_active_panel;
    die "Incorrect login" unless $acct->isa( 'EPUC::Acct' );
    my $ava = $acct->get_avatar;
    my $strip = $self->get__strip;
    if( ! $strip->get__reserved_by ) {
        $self->set__reserved_by( $ava );
        $strip->set__reserved_by( $ava );
        $acct->add_to_reserved_strips( $strip );
    } elsif( $self->get__reserved_by != $ava ) {
        _log( "$ava, ".$self->get__reserved_by );
        die "Strip was just reserved by someone else";
    }
    $self;
} #reserve

sub free {
    my( $self, $acct, $admin ) = @_;
    $self->get__strip->free( $acct, $admin );
} #free


1;
