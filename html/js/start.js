var starter = byId( 'startcomic' );
starter.setAttribute( 'disabled', true );
var starttext = byName( 'start' );
starttext.addEventListener( 'keyup', function(ev) {
    if( starttext.value.match( /\S/ ) ) {
        starter.removeAttribute( 'disabled' );
    } else {
        starter.setAttribute( 'disabled', true );
    }
} );
