package SPUC::Image;

use strict;
use warnings;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

#
# FIELDS
#
#   _original_name
#   extension
#   _origin_file
#

sub src {
    my $self = shift;
    my $of = $self->get__origin_file;
    $of =~ s!/var/www/html!!;
    $of;
}

sub size {
    my( $self, $w, $h ) = @_;
    my $orf = $self->get__origin_file;
    my $of = $orf;
    my $ext = $self->get_extension;
    $of =~ s/\.$ext$/_${w}_${h}.$ext/;

    unless( -e $of ) {
#        `rm $of`;
        `convert $orf -resize ${w}x$h $of`;
    }
    
    $of =~ s!/var/www/html!!;
    $of;
}

1;
