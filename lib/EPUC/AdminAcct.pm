package EPUC::AdminAcct;

use strict;

use Yote::Server;
use base 'EPUC::Acct';

sub _init {
    my $self = shift;
    $self->set_is_admin( 1 );
    $self->SUPER::_init;
}
sub _load {
    my $self = shift;
    $self->SUPER::_load;

#    my $pw = 'epuc';
#    $self->set__password_hash( crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($self->{ID} ) )  );
}
sub _onLogin {
    my $self = shift;
    $self->SUPER::_onLogin;
}

sub create_user_account {
    my( $self, $username, $password, $is_admin ) = @_;
    my $app = $self->get_app;
    my $acct;
    if( $is_admin ) {
        if( $self->get_is_super ) {
            $acct = $app->_create_account( $username, $password, 'EPUC::AdminAcct' );
        } else {
            die "Couldn't create admin account from non-superuser account";
        }
    } else {
        $acct = $app->_create_account( $username, $password );
    }
    $acct->get_avatar->set_user( $username );
    $acct;
}

sub reset_user_password {
    my( $self, $username, $pw ) = @_;
    die "Password required" unless $pw;
    my $accts = $self->get_app->get__accts({});
    my $acct = $accts->{$username};
    die "Account not found"  unless $acct;
    die "Cannot set password of superuser" if $acct->get_is_super && ! $self->get_is_super;
    $acct->set__password_hash( crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($acct->{ID} ) )  );
    $acct;
}

sub list_accounts {
    my( $self ) = @_;
    [values %{$self->get_app->get__accts({})}];
}

sub all_in_progress {
    my $self = shift;
    if( ! $self->get_is_super ) {
        die { err =>  "Superuser only function for the moment" };
    }
    my $app = $self->get_app;
    return $app->get__in_progress_strips;
} #all_in_progress

1;
