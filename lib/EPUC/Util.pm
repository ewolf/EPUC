package EPUC::Util;

use strict;

use File::Copy;
use File::Path 'make_path';
use UUID::Tiny;

sub developPicture {
    my( $picture ) = @_;

    # TODO - add fail cases
    # now move this thing and add a url
    my $ext = $picture->get_file_extension;

    my( @path ) = split( /-/, UUID::Tiny::create_uuid_as_string() . ".$ext" );
    my $filename = pop @path;
    my $relative_path = join( '/', @path );

    my $file_root_path = "/var/www/html/epuc/images/$relative_path";
    my $file_path      = "$file_root_path/$filename";
    make_path( $file_root_path );

    $picture->set_url( "/epuc/images/$relative_path/$filename" );
    copy( $picture->get_file_path, $file_path ) or die;
    unlink $picture->get_file_path;
    $picture->set_file_path( $file_path );
    $picture;
} #developPicture

1;
