package SPUC::LinkedList;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

#
# Fields :
#   head
#   tail
#

sub add {
    my( $self, $item, $sorter ) = @_;

    my $newnode = $self->store->create_container
        ( 'SPUC::LinkedListNode', {
            item => $item,
            list => $self,
          } );
    
    my $head = $self->get_head;
    
    if( $head ) {
        my $tail  = $self->get_tail;
        if( $sorter ) {
            if( &$sorter( $item, $tail->get_item ) >= 0 ) {
                $tail->set_next( $newnode );
                $newnode->set_prev( $tail );
                $self->set_tail( $newnode );
            }
            elsif( &$sorter( $item, $head->get_item ) <= 0 ) {
                $head->set_prev( $newnode );
                $newnode->set_next( $head );
                $self->set_head( $newnode );
            }
            else {
                my $next = $head;
                do {
                    $head = $next;
                    $next = $head->get_next;
                }  
                while( &$sorter( $item, $next->get_item ) >= 0 );
                
                $head->set_next( $newnode );
                $newnode->set_prev( $head );
                if( $next ) {
                    $newnode->set_next( $next );
                    $next->set_prev( $newnode );
                }
            }
        } else {
            $tail->set_next( $newnode );
            $newnode->set_prev( $tail );
            $self->set_tail( $newnode );
        }
    }
    else {
        print "Setting head : $item\n";
        $self->set_head( $newnode );
        $self->set_tail( $newnode );
    }
    $self;
} #add

1;
__END__
# my $ll = $store->create_container( 'SPUC::LinkedList' );

# for my $add (sort { ($a*0)+(int(rand(3))-1) <=> ($b*0)+(int(rand(3))-1) } (30..48) ) {
#     print ")$add\n";
#     $ll->add( $add, sub { my( $a, $b ) = @_; $b <=> $a } );
# }
# print "head ". $ll->get_head->get_item."\n";
# print "tail ". $ll->get_tail->get_item."\n";

# my $next = $ll->get_head;
# while( $next ) {
#     print ">".$next->get_item."\n";
#     $next = $next->get_next;
# }
       
