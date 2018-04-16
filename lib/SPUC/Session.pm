package SPUC::Session;

use strict;
use warnings;

use base 'SPUC::Base';

sub _reset {
    my $self = shift;
    $self->set__idx( [ $self ] );
    $self->set__id2idx( { $self->store->_get_id($self) => 0 } );
    $self->set_reset(1);
}

sub _init {
    my $self = shift;
    $self->set__idx([$self]);
    $self->set__id2idx( { $self->store->_get_id($self) => 0 } );
}

#
# A user gets one permanent session object
#
# Fields :
#   ids  - id -> object known to the session
#   user - owner of the session
#   last_id - last session id used
#

# -- the following methods are just for the
# -- RPC infrastructure
sub _fetch {
    my( $self, $idx ) = @_;
    $self->get__idx([$self])->[$idx];
}


sub _stow {
    my( $self, $item ) = @_;
    if( ref( $item ) ) {
        my $id2idx = $self->get__id2idx;
        my $idx = $id2idx->{$self->store->_get_id($item)};
        return $idx if defined($idx);
        
        my $idxs = $self->get__idx;
        push @$idxs, $item;
        $id2idx->{$self->store->_get_id($item)} = $#$idxs;
        return $#$idxs;
    }
    elsif( defined( $item ) ) {
        return "v$item";
    }
    return 'u';
}

#
# Returns a list of objects that may need updates since
# the last time this method was called.
#
sub _updates {
    my( $self, $last_update, $seen ) = @_;
    $seen //= {};
    my $store = $self->store;
    my $idxs = $self->get__idx;
    my $res = [];
    for my $item (@$idxs) {
        if( $store->last_updated( $item ) >= $last_update && ! $seen->{$self->store->_get_id($item)}++ ) {
            push @$res, $item;
        }
    }
    return $res;
} #_updates

#
# A test sort of thing
#
sub dorand {
    no warnings 'numeric';
    my( $self, @args ) = @_;
    my $user= $self->get_user;
    my $fico = $user->get__finished_comics;
    my( $comic ) = sort { ($a*0+rand) <=> ($b*0+rand) } @$fico;
    return ["BEEP ($args[0])",$comic];
}


1;
