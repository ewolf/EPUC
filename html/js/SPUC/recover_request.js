var subbut = byId( 'reset-req' );
var unorem = byName( 'unorem' );
subbut.setAttribute( 'disabled', unorem.value.match(/^\s*$/) );

unorem.addEventListener( 'keyup', () => {
    if( unorem.value.match( /\S/ ) ) {
        subbut.removeAttribute( 'disabled' );
    } else {
        subbut.setAttribute( 'disabled', true );
    }
} );
