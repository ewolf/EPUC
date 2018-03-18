package SPUC::Uploader;

sub from_cgi {
    my $q = pop;
    bless { q => $q }, 'SPUC::Uploader';
}

sub fh {
    my( $self, $field ) = @_;
    $self->{q}->upload( field );
}

1;
