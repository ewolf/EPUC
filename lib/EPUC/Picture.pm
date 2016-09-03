package EPUC::Picture;

use strict;

use Yote::Server;

use base 'Yote::ServerObj';

use File::Copy;
use File::Path 'make_path';
use UUID::Tiny;

sub url {
    my( $self, $size ) = @_;

    my $image = $self->get_image;
    my $ext   = $image->get_file_extension;
    my $sizes = $image->get_sizes;
    if( @$sizes ) {
        my( $found_size ) =  grep { $_ eq $size } @$sizes;
        $found_size ||= $sizes->[0];
        return $image->get_base_url . "_$found_size.$ext";
    }
    return $image->get_base_url . ".$ext";
} #url

sub develop {
    my( $self, $image, @sizes ) = @_;

    $self->set_image( $image );
    
    my $orig_file_path = $image->get_file_path;
    my $ext            = $image->get_file_extension;
    
    my( @path ) = split( /-/, UUID::Tiny::create_uuid_as_string() );

    my $filename      = pop @path;
    my $relative_path = join( '/', @path );

    my $file_root_path = "/var/www/html/epuc_data/images/$relative_path";
    my $file_path      = "$file_root_path/$filename";
    make_path( $file_root_path );

    $image->set_sizes( [@sizes] );
    if( @sizes ) {
        for my $size (@sizes) {
            `convert $orig_file_path -resize $size ${file_path}_$size.$ext`;
        }
    } else {
        copy( $image->get_file_path, $file_path ) or die "$@ $!";
    }

    $image->set_base_url( "/epuc_data/images/$relative_path/$filename" );

    $self;
} #develop

1;
