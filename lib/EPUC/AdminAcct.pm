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
            die { err => "Only superuser can create admin accounts" };
        }
    } else {
        $acct = $app->_create_account( $username, $password );
    }
    $acct->get_avatar->set_user( $username );
    $acct;
}

sub reset_user_password {
    my( $self, $username, $pw ) = @_;
#    die { err => "bad password" } unless length($pw) > 5;
    my $accts = $self->get_app->get__accts({});
    my $acct = $accts->{$username};
    die  { err => "May not set superuser password" } if $acct->get_is_super && ! $self->get_is_super;
    die  { err => "No account found" } unless $acct;
    $acct->set__password_hash( crypt( $pw, length( $pw ) . Digest::MD5::md5_hex($acct->{ID} ) )  );
    $acct;
}

sub list_accounts {
    my( $self ) = @_;
    [values %{$self->get_app->get__accts({})}];
}

1;
