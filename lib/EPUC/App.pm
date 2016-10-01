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

sub _load {
    my $self = shift;
#    print STDERR $self->_DUMP_ALL;
#    print STDERR ")_))))))\n";

    unless( $self->get__has_all_strips ) {
        $self->get__all_strips([]);
        # update to make sure all strip and panel states are accurate
        for my $strip (@{$self->get_recently_completed_strips},@{$self->get__in_progress_strips}) {
            $self->add_once_to__all_strips( $strip );
        }
        for my $acct (values %{$self->get__accts}) {
            for my $strip (@{$acct->get_reserved_strips},
                           @{$acct->get_in_progress_strips},
                           @{$acct->get_avatar->get_completed_strips},
                ) {
                $self->add_once_to__all_strips( $strip );
            }
        }
        $self->set__has_all_strips(1);
    } #_has_all_strips

    unless( $self->get__panels_have_numbers ) {
        for my $strip (@{$self->get__all_strips}) {
            my $panels = $strip->get__panels;
            if( @$panels == 9 ) {
                $strip->set__state( 'complete' );
                for my $acct (values %{$self->get__accts}) {
                    $acct->remove_from_reserved_strips( $strip );
                    $acct->remove_from_in_progress_strips( $strip );
                }
            } else { 
                $strip->set__state( 'pending' );
                for my $acct (values %{$self->get__accts}) {
                    $acct->get_avatar->remove_from_completed_strips( $strip );
                }
            }

            for( my $i=0; $i<@$panels; $i++ ) {
                my $panel = $panels->[$i];
                $panel->set__strip( $strip );
                $panel->set__panel_number( $i );
                if( $i < $#$panels ) {
                    $panel->set__reserved_by( undef );
                } else {
                    my $revd = $panel->get__reserved_by;
                    if( $revd ) {
                        if( $revd->isa( 'EPUC::Acct' ) ) {
                            $revd = $revd->get_avatar;
                            $panel->set__reserved_by( $revd );
                        }
                        $strip->set__reserved_by( $revd );
                        $revd->get__account->add_once_to_reserved_strips( $strip );
                    }
                }
            }
        } #all strips
        
        $self->set__panels_have_numbers( 1 );
    } # _panels_have_numbers

    unless( $self->get__avatars_have_names ) {
        for my $acct ( values %{$self->get__accts({})} ) {
            $acct->get_avatar->set_user( $acct->get_user );
        }
        $self->set__avatars_have_names( 1 );
    }

} #_load

sub lookup_player {
    my( $self, $name ) = @_;
    my $accts = $self->get__accts({});
    $accts->{lc($name)};
}

sub completed_strips {
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
