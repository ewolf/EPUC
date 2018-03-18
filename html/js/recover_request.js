var subbut = byId( 'reset-req' );
var unorem = byName( 'unorem' );

unorem.addEventListener( 'keyup', () => {
    if( unorem.value.match( /\S/ ) ) {
        subbut.removeAttribute( 'disabled' );
    } else {
        subbut.setAttribute( 'disabled', true );
    }
} );
