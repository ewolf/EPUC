package EPUC::Acct;

use strict;
use namespace::clean;

use Yote;
use Yote::Server;
use base 'Yote::Server::Acct';

use EPUC::Panel;
use EPUC::Strip;
use EPUC::Picture;

sub _init {
    my $self = shift;
    $self->set_my_in_progress_strips( [] );
    $self->set_my_reserved_strips( [] );
    $self->set_my_completed_strips( [] );
    my $icon = $self->{STORE}->newobj( {}, 'EPUC::Picture' );
    $icon->develop(  $self->{STORE}->newobj( {
        extension => 'png',
        file_path => '/home/wolf/proj/EPUC/html/images/question.png',
                                             } ), '80x80' );
    $self->set_icon( $icon );
}

sub _load {
    my $self = shift;
    $self->get_icon( $self->{STORE}->newobj( {}, 'EPUC::Picture' ) );
    my $inpr = $self->get_my_in_progress_strips( [] );
    my $comp = $self->get_my_completed_strips( [] );
    my $res  = $self->get_my_reserved_strips( [] );
    if( @$inpr ) {
        $self->set__my_data( {
            in_progress_strips => $inpr,
            completed_strips   => $comp,
            reserved_strips    => $res,
                         } );
        $self->set_my_in_progress_strips( [] );
        $self->set_my_reserved_strips( [] );
        $self->set_my_completed_strips( [] );
    }
}

sub _onLogin {
    my $self = shift;
    print STDERR Data::Dumper->Dump([$self->{DATA},$self->isa("EPUC::AdminAcct"),"ONLOGIN"]);
}

our %fields = map { $_ => 1 } ('name','about');
sub setInfo {
    my( $self, $field, $val ) = @_;
    if( $fields{$field} ) {
        $self->set( $field, $val );
    }
    else {
        die "Unknown field '$field'";
    }
} #setInfo

sub getInfo {
    my( $self, $field, $val ) = @_;
    if( $fields{$field} ) {
        return $self->get( $field, $val );
    }
    else {
        die "Unknown field '$field'";
    }
} #getInfo

sub uploadIcon {
    my( $self, $image ) = @_;
    my $icon = $self->get_icon->develop( $image, '80x80' );
    $self->set_icon( $icon );

    $icon;
} #uploadIcon

sub start_strip {
    my( $self, $sentence ) = @_;
    die { err =>  "Needs a starting sentence" } unless $sentence =~ /\S/;
    my $panel = $self->{STORE}->newobj( {
        type     => 'sentence',
        sentence => $sentence,
        _artist  => $self,
                                        }, 'EPUC::Panel' );
    my $strip = $self->{STORE}->newobj( {
        _state   => 'pending',
        _title   => $sentence,
        _artist  => $self,
        _players => [ $self ],
        panels_to_go => 2,#8, (8 is correct, there are 9 panels total)
        _next    => 'picture',
        _panels  => [ $panel ],
                                        }, 'EPUC::Strip' );

    my $app = $self->get_app;
    $app->add_to__in_progress_strips( $strip );
    $self->add_to_my_in_progress_strips( $strip );

    $strip;
} #start_strip

# returns strip and panel objects
sub play_random_strip {
    my $self = shift;
    my $app = $self->get_app;

    # sort by strips you've not played yet
    my $strips = $app->get__in_progress_strips([]);
    my( @new_strips );
    for my $strip (@$strips) {
        if( (0 == grep { $self == $_}
            @{$strip->get__players()} ) && $strip->get__reserved_by != $self )
        {
            push @new_strips, $strip;
        }
    }

    return unless @new_strips;

    my( $strip ) = sort { sprintf( "%.0f", rand(2)-1) } @new_strips;

    my $panels = $strip->get__panels;

    return ( $strip, $panels->[$#$panels] );
} #play_random_strip

sub reset_password {
    my( $self, $newpw, $oldpw ) = @_;

    my $old_hash = crypt( $oldpw, length( $oldpw ) . Digest::MD5::md5_hex($self->{ID} ) );

    die { err => "must supply old password" } unless $old_hash eq $self->get__password_hash;
#    die { err => "bad password" } unless length($newpw) > 5;

    my $new_hash = crypt( $newpw, length( $newpw ) . Digest::MD5::md5_hex($self->{ID} ) );

    $self->set__password_hash( $new_hash );
    $self;
} #reset_password


1;
