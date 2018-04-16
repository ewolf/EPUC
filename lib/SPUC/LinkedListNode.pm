package SPUC::LinkedListNode;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

#
# Fields
#    item
#    list
#    next
#    prev
#


1;

__END__

sub _init {
    my $self = shift;
    $self->set_lists({});
}

#
# A linked list node that can exist in multiple
# linked lists. There isn't a list object defined
# they are implicitly created from the nodes.
#
# Fields :
#   thing - comic (or other) object
#             0              1              2
#   lists - { listname : [previd,nextid],
#             ... }
#
#   item  - item contained in this list
#
sub sortinto {
    my( $self, $node, $listname, $sortsub ) = @_;
    $listname //= 'default';
    my $sort = &$sortsub( $self->get_item, $node->get_item );
    if( $sort < 0 ) {
        my $prev = $self->getprev($listname);
        if( $prev ) {
            return $prev->sortinto( $node, $listname, $sortsub );
        } 
        $self->setprev($node,$listname);

    } elsif( $sort >= 0 ) {
        my $next = $self->getnext($listname);
        if( $next && $sort > 0 ) {
            return $next->sortinto( $node, $listname, $sortsub );
        } 
        $self->setnext($node,$listname);
    }
} #sortinto

sub insert_prev {
    my( $self, $prev, $listname ) = @_;
    $listname //= 'default';
    my $lists = $self->get_lists;
    my $oldprev = $lists->{$listname}[0];
    if( $oldprev ) {
        $oldprev->get_lists->{$listname}[1] = $prev;
        $prev->get_lists->{$listname}[0] = $oldprev;
    }
    $prev->get_lists->{$listname}[1] = $self;
    $lists->{$listname}[0] = $prev;
} #insert_prev

sub insert_next {
    my( $self, $next, $listname ) = @_;
    # me -> next -> oldnext
    $listname //= 'default';
    my $lists = $self->get_lists;
    my $oldnext = $lists->{$listname}[1];
    if( $oldnext ) {
        $oldnext->get_lists->{$listname}[0] = $next;
        $next->get_lists->{$listname}[1] = $oldnext;
    }
    $next->get_lists->{$listname}[0] = $self;
    $lists->{$listname}[1] = $next;
} #insert_next

sub getnext {
    my( $self, $listname ) = @_;
    $listname //= 'default';
    my $lists = $self->get_lists;
    $lists->{$listname}[1];
}

sub getprev {
    my( $self, $listname ) = @_;
    $listname //= 'default';
    my $lists = $self->get_lists;
    $lists->{$listname}[0];
}

sub tolist {
    my( $self, $listname ) = @_;
    $listname //= 'default';
    my $head = $self->head( $listname );
    my $ret = [];
    while( $head ) {
        push @$ret, $head->get_item;
        $head = $head->getnext($listname);
    }
    return $ret;
}
sub head {
    my( $self, $listname ) = @_;
    $listname //= 'default';
    my $prev = $self->get_lists->{$listname}[0];
    if( $prev ) {
        return $prev->head;
    }
    return $self;
}

#
# Return self plus the next count
#
sub next {
    my( $self, $count, $listname ) = @_;
    $listname //= 'default';
    my $res = [ $self ];
    my $last = $self;
    while( $count-- > 0 ) {
        $last = $last->getnext( $listname );
        if( $last ) {
            push @$res, $last;
        } else {
            last;
        }
    }
    return $res;
}

# finds the nth previous one to this that is not
# null
sub find_prev {
    my( $self, $nth, $listname ) = @_;
    $listname //= 'default';
    my $last = $self;
    while( $nth-- > 0 ) {
        $self = $last->getprev($listname);
        if( $self ) {
            $last = $self;
        } else {
            return $last;
        }
    }
    return $self;
}

# returns the nth one after self
sub nth {
    my( $self, $nth, $listname ) = @_;
    $listname //= 'default';
    while( $nth-- > 0 ) {
        $self = $self->getnext($listname);
        unless( $self ) {
            return undef;
        }
    }
    return $self;
}

1;
