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
    # TODO - way to update a password for an account
    my $first_admin = $self->_create_account( 'epuc', 'slatherSLAPTY---+', 'EPUC::AdminAcct' );
    $first_admin->get_avatar->set_user( 'epuc' );
    $first_admin->set_is_super(1);
    $first_admin->set_is_admin(1);
    $self->set__first_admin( $first_admin );

    $self->set_recently_completed_strips([]);
    $self->set__in_progress_strips([]);
}

sub _load {
    my $self = shift;
} #_load


1;
