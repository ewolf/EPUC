package EPUC::Panel;

use strict;

use Yote::Server;
use Scalar::Util qw( refaddr );

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

sub kudocount {
    my $self = shift;
    scalar( keys %{$self->get_kudos({})} );
}

sub add_kudo {
    my( $self, $acct ) = @_;
    $self->get_kudos({})->{$acct} = 1;
    $self->get__artist->set_kudo_count( 1 + $self->get__artist->get_kudo_count );
}

sub can_kudo {
    my( $self, $acct ) = @_;
    ! $self->get_kudos({})->{$acct} && $acct->get_avatar != $self->get__artist;
}

sub is_active_panel {
    my $self = shift;
    my $strip = $self->get__strip;
    my $strip_panels = $strip->get__panels;
    return $strip->get__state eq 'pending' && $self->get__panel_number == $#$strip_panels;
}

sub reserve {
    my( $self, $acct, $ostrip ) = @_;
    die { err =>  "Not active panel" } unless $self->is_active_panel;
    die { err =>  "Incorrect login" } unless $acct->isa( 'EPUC::Acct' );
    my $ava = $acct->get_avatar;
    my $strip = $self->get__strip;

    if( ! $strip->get__reserved_by ) {
        $self->set__reserved_by( $ava );
        $strip->set__reserved_by( $ava );
        print STDERR Data::Dumper->Dump(["ADDING TO ReSrVD ($strip)"]);
        $acct->add_once_to_reserved_strips( $strip );
    } elsif( $self->get__reserved_by != $ava ) {
        _log( "$ava, ".$self->get__reserved_by );
        die { err =>  "Strip was just reserved by someone else" };
    }
    $self;
} #reserve

sub free {
    my( $self, $acct, $admin ) = @_;
    $self->get__strip->free( $acct, $admin );
} #free


1;
