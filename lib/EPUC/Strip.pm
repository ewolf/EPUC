package EPUC::Strip;

use strict;

use Yote::Server;

use base 'Yote::Server::Acct';

use EPUC::Util;

sub _init {

}

sub _load {
    my $self = shift;
}

# returns the panels on a strip
sub panels {
    my( $self, $acct ) = @_;

    #
    # completed, return the whole thing
    # looking to be reserved
    # 
    # 
    
    if( $self->get__state eq 'pending' ) {
        # grab the panels up to the last panel
        # this account was the author of

        my $panels = $self->get__panels;
        my( @shown_panels );
        my $found_panel_with_author;
        for my $panel (reverse @$panels) {
            if( $found_panel_with_author || $panel->get__artist == $acct ) {
                push @shown_panels, $panel;
                $found_panel_with_author = 1;
            }
        }
        return [reverse @shown_panels ];
    }
    elsif( $self->get__state eq 'complete' ) {
        return [@{$self->get__panels}]; #unroll into a normal array
    }
    die { err => 'unknown panels' };
} #panels

# returns the last panel of this strip to the one reserving it
sub reserved_panel {
    my( $self, $acct ) = @_;

    if( $self->get__reserved_by == $acct ) {
        return $self->_last_panel;
    }
    die { err => "Did not reserve this strip" };
} #reserved_panel

sub reserve {
    my( $self, $acct, $admin ) = @_;
    if( ($admin && $admin->get__is_admin) ||
            ! $self->get__reserved_by ) {
        die "non account trying to reserve" unless $acct->isa( 'EPUC::Acct' );
        $self->set__reserved_by( $acct );
        $acct->add_to_my_reserved_strips( $self );
    } elsif( $self->get__reserved_by == $acct ) {
        print STDERR "ALREADY RESERVED\n";
        # already reserved, so do nothing, no error
        $self;
    } else {
        die { err => 'strip already reserved' };
    }
    $self;
} #reserve

sub free {
    my( $self, $acct, $admin ) = @_;
    if( $self->get__reserved_by == $acct || ($admin && $admin->get__is_admin) ) {
        $self->set__reserved_by(undef);
        $acct->remove_from_my_reserved_strips( $self );
    } else {
        die { err => 'could not free strip' };
    }
    $self;
} #free

sub _last_panel {
    my $pans = shift->get__panels([]);
    if( @$pans ) {
        return $pans->[$#$pans];
    }
} #_last_panel

sub _add_panel {
    my( $self, $acct, $obj, $is_picture ) = @_;

    my $panel = $self->{STORE}->newobj( {
        _artist  => $acct,
    }, 'EPUC::Panel' );
    if( $is_picture ) {
        die { err => "two pictures in a row" } if $self->_last_panel->get_type ne 'sentence';
        $panel->set_type( 'picture' );
        $panel->set_picture( $obj );
    } else {
        die { err => "two sentences in a row" } if $self->_last_panel->get_type ne 'picture';
        $panel->set_type( 'sentence' );
        $panel->set_sentence( $obj );
    }
    if( 0 == grep { $acct == $_ } @{$self->get__players} ) {
        $self->add_to__players( $acct );
    }
    $self->set__reserved_by(undef);
    $acct->remove_from_my_reserved_strips( $self );
    $acct->add_once_to_my_in_progress_strips( $self );    

    my $togo = $self->get_panels_to_go - 1;
    $self->set_panels_to_go( $togo );
    if( $togo == 0 ) {
        $self->set__state( 'complete' );
        $acct->remove_from_my_reserved_strips( $self );
        $acct->remove_from_my_in_progress_strips( $self );
        $acct->add_to_my_completed_strips( $self );
        my $app = $acct->get_app;
        $app->remove_from__in_progress_strips( $self );
        $app->add_to__completed_strips( $self );
        my $recently_completed_strips = $app->get_recently_completed_strips([]);
        unshift @$recently_completed_strips, $self;
        if( @$recently_completed_strips > 20 ) {
            pop @$recently_completed_strips;
        }
    }
    $self->add_to__panels( $panel );
    $panel;
} #_add_panel

sub add_sentence {
    my( $self, $acct, $sentence ) = @_;

    die { err => "need to reserve this strip to play it" }
        unless $self->get__reserved_by == $acct;

    if( $sentence =~ /\S/ ) {
        return $self->_add_panel( $acct, $sentence );
    } else {
        die { err => "cannot use blank sentence" };
    }
} #add_sentence

sub add_picture {
    my( $self, $acct, $picture ) = @_;

print STDERR "GETPIC : ". $self->get__reserved_by. " == $acct\n";
    
    die { err => "need to reserve this strip to play it" }
        unless $self->get__reserved_by == $acct;

    EPUC::Util::developPicture( $picture );

    $self->_add_panel( $acct, $picture, 'is_picture' );

} #add_picture


1;
