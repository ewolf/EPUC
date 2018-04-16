// ------------- CHANGE PASSWORD


var subbut = byId( 'uppw' );
subbut.setAttribute( 'disabled', true );

var pwold = byName( 'pwold' );
var pw1 = byName('pw');
var pw2 = byName('pw2');
var pw2popped = false;

if( pwold ) {
    pwold.addEventListener( 'keyup', () => {
        if( pw2popped ) {
            check();
        }
    } );
}

pw2.addEventListener( 'keyup', () => {
    if( pw2popped === false ) {
        pw1.addEventListener( 'keyup', check );
        pw2popped = true;
    }
    check();
} );

function check() {
    var errs = [];

    // PASSWORD CHECKS
    if( pw1.value !== pw2.value ) {
        errs.push( "passwords must match" );
        pw1.classList.add( 'error' );
        pw2.classList.add( 'error' );
    }
    if( pw1.value.length < 8 ) {
        errs.push( "password too short" );
        pw1.classList.add( 'error' );
        pw2.classList.add( 'error' );
    }
    if( errs.length === 0 ) {
        pw1.classList.remove( 'error' );
        pw2.classList.remove( 'error' );
    }
    if( pwold ) {
        if( pwold.length < 8 ) {
            errs.push( "need original password" );
            pwold.classList.add( 'error' );
        } else {
            pwold.classList.remove( 'error' );
        }
    }

    if( errs.length === 0 ) {
        subbut.removeAttribute( 'disabled' );
    } else {
        subbut.setAttribute( 'disabled', true );
    }
    
    error( errs );
} //check
