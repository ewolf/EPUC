package EPUC::Panel;

use strict;

use Yote::Server;

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
    my $s = $self->get_sentence;
    if( $s =~ /bears on/ ) {
        # bears is in an internal perl format?
        print STDERR ")))$s\n";
        my $sen = 'Le Déjeuner sur l’herbe, featuring bears on drugs.';
        $sen = Encode::decode( 'utf8', $sen );
 my $osen = Encode::encode( 'utf8', $sen );
        my $tosen = encode_entities( $osen );
        print STDERR Data::Dumper->Dump([$sen,$osen,$tosen]);
#        $self->set_sentence( $sen );
       print STDERR "2)))$s\n";
    }
}

sub is_active_panel {
    my $self = shift;
    my $strip = $self->get__strip;
    my $strip_panels = $strip->get__panels;
    return $strip->get__state eq 'pending' && $self->get__panel_number == $#$strip_panels;
}

sub reserve {
    my( $self, $acct, $admin ) = @_;
    die "panel must be the last in the non completed strip to be reservable" unless $self->is_active_panel;
    die "non account trying to reserve" unless $acct->isa( 'EPUC::Acct' );
    
    my $ava = $acct->get_avatar;
    my $strip = $self->get__strip;
    if( ! $strip->get__reserved_by ) {
        $self->set__reserved_by( $ava );
        $strip->set__reserved_by( $ava );
        $acct->add_to_reserved_strips( $strip );
    } elsif( $self->get__reserved_by == $ava ) {
        # already reserved, so do nothing, no error
        $self;
    } else {
        _log( "$ava, ".$self->get__reserved_by );
        die { err => 'strip already reserved' };
    }
    $self;
} #reserve

sub sentence {
    my $self = shift;
    my $s = $self->get_sentence;
    use Encode;
    use HTML::Entities;
    use Text::Xslate qw(mark_raw);
    my $is_utf8 = Encode::is_utf8( $s );
    
    print STDERR ">>>($is_utf8) $s\n"; # <--- s is octets
    
    $s = Encode::decode( 'utf8', $s ); # <--- to internal perl
    $is_utf8 = Encode::is_utf8( $s );
    print STDERR ">>>($is_utf8) $s\n";
    
    $s = encode_entities( $s );
    $is_utf8 = Encode::is_utf8( $s );
    print STDERR ">>>($is_utf8) $s\n"; 
    mark_raw($s);
}

sub free {
    my( $self, $acct, $admin ) = @_;
    $self->get__strip->free( $acct, $admin );
} #free


1;
