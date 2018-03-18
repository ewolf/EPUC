package SPUC::Image;

use strict;
use warnings;

use Image::Resize;

use Data::ObjectStore;
use base 'Data::ObjectStore::Container';

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
    print STDERR Data::Dumper->Dump([$of,$orf,"ORF"]);
    unless( -e $of ) {
        my $img = Image::Resize->new( $orf );
        my $gd = $img->resize( $w, $h );
        open my $out, '>', $of;
        print $out $gd->$ext();
        close $out;
    }
    $of =~ s!/var/www/html!!;
    $of;
}

1;
