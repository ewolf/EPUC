package EPUC::Acct;

use strict;
use namespace::clean;
use POSIX;

use Yote;
use Yote::Server;
use base 'Yote::Server::Acct';

use EPUC::NewsItem;
use EPUC::Panel;
use EPUC::Picture;
use EPUC::Strip;

sub _log {
    my( $msg, $sev ) = @_;
    $sev //= 1;
    open my $out, ">>/opt/yote/log/yote.log";
    print $out "$msg\n";
}

sub _init {
    my $self = shift;
    $self->SUPER::_init;
    
    my $icon = $self->{STORE}->newobj( {}, 'EPUC::Picture' );
    $icon->develop(  $self->{STORE}->newobj( {
        extension => 'png',
        file_path => '/var/www/html/epuc_data/images/question.png',
                                             } ), '80x80' );

    $self->set_avatar( $self->{STORE}->newobj( {
        _account => $self,
        icon     => $icon,
        completed_strips => [],
                       } ) );
    
    $self->set_in_progress_strips( [] );
    $self->set_reserved_strips( [] );
} #_init

sub _load {
    my $self = shift;
}

sub _onLogin {
    my $self = shift;
    $self->set_has_initial_login(1);
    $self->set_last_logged_in( time );
}

sub add_news {
    my( $self, $msg, $strip, $showtimes ) = @_;
    my $news = $self->get_news([]);
    push @$news, $self->{STORE}->newobj( {
        acct => $self,
        showtimes => $showtimes || 2,
        seen => 0,
        msg  => $msg,
        strip => $strip,
        time => time,
                                         }, 'EPUC::NewsItem' );
    $news;
}

sub last_logged_in {
    my $self = shift;
    my $epoch_seconds = $self->get_last_logged_in;
    $epoch_seconds ?
        POSIX::strftime( "%m/%d/%Y %H:%M", localtime($epoch_seconds) )
        : 'never logged in';
}

our %fields = map { $_ => 1 } ('name','about');
sub setInfo {
    my( $self, $field, $val ) = @_;
    if( $fields{$field} ) {
        $self->get_avatar->set( $field, $val );
    }
    else {
        die "Unknown field '$field'";
    }
} #setInfo

sub getInfo {
    my( $self, $field, $val ) = @_;
    if( $fields{$field} ) {
        return $self->get_avatar->get( $field, $val );
    }
    else {
        die "Unknown field '$field'";
    }
} #getInfo

sub uploadIcon {
    my( $self, $image ) = @_;
    my $av = $self->get_avatar;
    my $icon = $av->get_icon->develop( $image, '80x80', '400x400' );
    $av->set_icon( $icon );

    $icon;
} #uploadIcon

sub start_strip {
    my( $self, $sentence ) = @_;
    die { err => "Must include sentence" } unless $sentence =~ /\S/;
    my $panel = $self->{STORE}->newobj( {
        type     => 'sentence',
        sentence => $sentence,
        _artist  => $self->get_avatar,
                                        }, 'EPUC::Panel' );
    my $strip = $self->{STORE}->newobj( {
        _state   => 'pending',
        _title   => $sentence,
        _artist  => $self->get_avatar,
        _players => [ $self->get_avatar ],
        panels_to_go => 8,   # 9 panels total
        panel_size => 9,
        _next    => 'picture',
        _panels  => [ $panel ],
                                        }, 'EPUC::Strip' );

    $panel->set__strip( $strip);
    
    my $app = $self->get_app;
    
    $app->add_to__in_progress_strips( $strip );
    $app->add_to__all_strips( $strip );
    $self->add_to_in_progress_strips( $strip );

    $strip;
} #start_strip

# returns strip and panel objects
sub play_random_strip {
    my( $self ) = @_;
    
    my $app = $self->get_app;

    # sort by strips you've not played yet
    my $strips = $app->get__in_progress_strips([]);

    # if there was a locked strip here, put it the first to check
    if( $self->get_lock_strip ) {
        unshift @$strips, $self->get_lock_strip;
    }
    
    my( @new_strips, @playing_strips );
    my $ava = $self->get_avatar;

    _log( "RAND : AVA $ava" );
    
    for my $strip (@$strips) {
        _log( "RANDSTR RES BY : " . $strip->get__reserved_by );

        if( ! $strip->get__reserved_by # != $ava
            && $strip != $self->get_last_random_strip
            )
        {
            if(0 == grep { $ava == $_ } @{$strip->get__players()} ) {
                push @new_strips, $strip;
            } elsif( $strip->_last_panel->get__artist != $ava ) {
                push @playing_strips, $strip;
            }
        }
    }

    return unless @new_strips || @playing_strips;

    my( $strip ) = sort { sprintf( "%d", rand(3) )-1 } @new_strips;

    unless( $strip ) {
        # pick a strip you are already in last unless you did the last
        # panel. This will only come into play if nothing else is
        # available.
        ( $strip ) = sort { sprintf( "%d", rand(3) )-1 } @playing_strips;
    }
    
    $self->set_last_random_strip( $strip );
    return $strip;
} #play_random_strip

sub reserves_available {
    my $self = shift;
    return $self->reserves_allowed - scalar( @{$self->get_reserved_strips([])} );
}

sub reserved_count {
    my $self = shift;
    scalar( @{$self->get_reserved_strips([])} );
}

sub reserves_allowed {
    3;
}

sub starts_available {
    my $self = shift;
    # 5 starts available until strips are finished
    
}

sub reset_password {
    my( $self, $newpw, $oldpw ) = @_;

    my $old_hash = crypt( $oldpw, length( $oldpw ) . Digest::MD5::md5_hex($self->{ID} ) );

    die { err => "incorrect current password" } unless $old_hash eq $self->get__password_hash;
    die { err => "bad password. Password should be at least 6 characters long" } unless length($newpw) > 5;

    my $new_hash = crypt( $newpw, length( $newpw ) . Digest::MD5::md5_hex($self->{ID} ) );

    $self->set__password_hash( $new_hash );
    $self;
} #reset_password


1;
