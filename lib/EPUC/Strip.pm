package EPUC::Strip;

use strict;

use Yote::Server;
use base 'Yote::ServerObj';

use EPUC::Picture;

use Scalar::Util qw( refaddr );

sub _init {
    my $self = shift;
    #
    # _state (pending|complete)
    # _title
    # _artist
    # _players
    # panels_to_go
    # _next (panel)
    # _panels
    # _reserved_by (Avatar)
    #
}

sub _load {
    my $self = shift;

    my $panels = $self->get__panels;
    for( my $i=0; $i<@$panels; $i++ ) {
        $panels->[$i]->set__panel_number( $i );
    }
#    print STDERR Data::Dumper->Dump([$self->{DATA},$self->_last_panel->{DATA},"WOOSTRIPLO"]);

}

sub _log {
    my( $msg, $sev ) = @_;
    $sev //= 1;
    open my $out, ">>/opt/yote/log/yote.log";
    print $out "$msg\n";
}

sub can_delete {
    my( $self, $acct ) = @_;
    my $panels = $self->get__panels;
    return @$panels == 1 && $panels->[0]->get__artist->get__account == $acct && ! $panels->[0]->get__reserved_by;
} #can_delete

sub delete_strip {
    my( $self, $acct ) = @_;
    die { err => "Cannot remove" } unless $self->can_delete($acct);
    my $app = $acct->get_app;
    $acct->remove_from_in_progress_strips( $self );
    $app->remove_from__in_progress_strips( $self );
}

# returns the panels on a strip
sub panels {
    my( $self, $acct, $size, $override ) = @_;

    #
    # completed, return the whole thing
    # looking to be reserved
    # 
    #

    if( $acct && $self->get__reserved_by == $acct->get_avatar() ) {
        my $panel = $self->reserved_panel($acct);
        my $phash = {
            type => $panel->get_type,
        };
        if( $panel->get_type eq 'picture' ) {
            $phash->{url} = $panel->get_picture->url( $size );
        } else {
            $phash->{sentence} = $panel->get_sentence;
        }
        return [ $phash ];
    }
    
    my @shown_panels;
    if( $self->get__state eq 'complete' || ($override&&$acct->get_is_admin) ) {
        for my $panel (@{$self->get__panels}) {
            my $phash = {
                type => $panel->get_type,
                artist => $panel->get__artist,
            };
            if( $panel->get_type eq 'picture' ) {
                $phash->{url} = $panel->get_picture->url( $size );
            } else {
                $phash->{sentence} = $panel->get_sentence;
            }
            push @shown_panels, $phash;
        }

        return \@shown_panels; #unroll into a normal array
    }    
    elsif( $self->get__state eq 'pending' ) {
        # grab the panels up to the last panel
        # this account was the author of

        my $panels = $self->get__panels;
        my $ava = $acct->get_avatar;
        my $found_panel_with_author = 0 < grep { $_->get__artist == $ava } @$panels;
        if( $found_panel_with_author ) {
            my( @pans );
            for my $panel (@$panels) {
                my $phash = {
                    type   => $panel->get_type,
                    artist => $panel->get__artist,
                };
                if( $panel->get_type eq 'picture' ) {
                    $phash->{url} = $panel->get_picture->url( $size );
                } else {
                    $phash->{sentence} = $panel->get_sentence;
                }
                push @pans, $phash;
            }
            return [@pans];
        }
        return [];
        
        # for my $panel (reverse @$panels) {
        #     if( $found_panel_with_author || $panel->get__artist == $acct->get_avatar ) {
        #         my $phash = {
        #             type => $panel->get_type,
        #         };
        #         if( $acct && $acct->get_is_super ) {
        #             $phash->{artist} = $panel->get__artist;
        #         }
                
        #         if( $panel->get_type eq 'picture' ) {
        #             $phash->{url} = $panel->get_picture->url( $size );
        #         } else {
        #             $phash->{sentence} = $panel->get_sentence;
        #         }
        #         print STDERR Data::Dumper->Dump([$phash,'WHUUf']);
        #         push @shown_panels, $phash;
                
        #         $found_panel_with_author = 1;
        #     }
        # }
        # return [reverse @shown_panels ];
    }
    die { err => 'unknown panels' };
} #panels

# returns the last panel of this strip to the one reserving it
sub reserved_panel {
    my( $self, $acct ) = @_;
    
    if( $self->get__reserved_by == $acct->get_avatar ) {
        return $self->_last_panel;
    }
    die { err => "Did not reserve this strip" };
} #reserved_panel

sub free {
    my( $self, $acct, $admin ) = @_;
    my $ava = $acct->get_avatar;

    if( $self->get__reserved_by == $ava || ($admin && $admin->get__is_admin) ) {
        $self->set__reserved_by(undef);
        $self->_last_panel->set__reserved_by(undef);
    }
    $acct->remove_from_reserved_strips( $self );
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

    my $ava = $acct->get_avatar;
    
    my $panels = $self->get__panels;

    my $panel = $self->{STORE}->newobj( {
        _artist  => $ava,
        _strip   => $self,
        _panel_number => scalar( @$panels ),
    }, 'EPUC::Panel' );
    if( $is_picture ) {
        die { err => "two pictures in a row" } if $self->_last_panel->get_type ne 'sentence';
        $panel->set_type( 'picture' );
        my $picture = $self->{STORE}->newobj( {}, 'EPUC::Picture' );
        $picture->develop( $obj, '50x50', '400x400', '700x700' );
        $panel->set_picture( $picture );
    } else {
        die { err => "two sentences in a row" } if $self->_last_panel->get_type ne 'picture';
        $panel->set_type( 'sentence' );
        $panel->set_sentence( $obj );
    }
    $self->add_once_to__players( $ava );

    $self->set__reserved_by(undef);
    $self->_last_panel->set__reserved_by(undef);
    $acct->remove_from_reserved_strips( $self );
    $acct->add_once_to_in_progress_strips( $self );    

    my $togo = $self->get_panels_to_go - 1;
    $self->set_panels_to_go( $togo );
    if( $togo == 0 ) {
        $self->set__state( 'complete' );
        my $app = $acct->get_app;
        $app->remove_from__in_progress_strips( $self );
        $app->add_to__completed_strips( $self );
        my $recently_completed_strips = $app->get_recently_completed_strips([]);
        unshift @$recently_completed_strips, $self;
        if( @$recently_completed_strips > 20 ) {
            pop @$recently_completed_strips;
        }

        for my $artist (@{$self->get__players}) {
            $artist->get__account->remove_from_in_progress_strips( $self );
            $artist->add_to_completed_strips( $self );
        }
        
        # TODO - notify all the artists that this strip is completed?
    }
    push @$panels, $panel;
    $panel;
} #_add_panel

sub add_sentence {
    my( $self, $acct, $sentence ) = @_;

    die { err => "Error obtaining strip" }
        unless $self->get__reserved_by == $acct->get_avatar;

    $sentence =~ s/[\n\r]+/ /gs;
    $sentence =~ s/^\s*//;
    $sentence =~ s/\s*$//;
    
    die { err => "Must supply sentence" } unless $sentence =~ /\S/;
    $self->_add_panel( $acct, $sentence );
} #add_sentence

sub add_picture {
    my( $self, $acct, $picture ) = @_;

    print STDERR Data::Dumper->Dump([$self->{DATA},refaddr( $self )," add picture ($self) ".$self->get__reserved_by. " , ".$acct->get_avatar." DAAA", $self->get__reserved_by == $acct->get_avatar]);
    die { err => "Error obtaining strip" }
        unless $self->get__reserved_by == $acct->get_avatar;

    $self->_add_panel( $acct, $picture, 'is_picture' );

} #add_picture

sub reserve {
    my( $self, $acct ) = @_;
    
    print STDERR Data::Dumper->Dump([$self->{DATA},refaddr($self),
                                     exists( $self->{STORE}{_WEAK_REFS}{$self->{ID}} ),
                                     $self->{STORE}{_WEAK_REFS}{$self->{ID}},
                                     refaddr($self->_last_panel->get__strip),"RESERVE STRIP ($self) ".exists $self->{STORE}{_WEAKREFS}{$self->_last_panel->{DATA}{_strip}}]);

    $self->_last_panel->reserve( $acct, $self );
} #reserve

sub rate {
    my( $self, $acct, $new_rating ) = @_;
    my $ratings = $self->get__ratings({});
    my $old_rating = $ratings->{$acct};
    $ratings->{$acct} = $new_rating;
    my $tot = $self->set_rating_total( $self->get_rating_total + ( $new_rating - $old_rating ) );
    $self->set_rating_avg( $tot / scalar( keys %$ratings ) );
}

1;
