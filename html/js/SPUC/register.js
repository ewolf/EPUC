var err = byId( 'err' );
var but = oneTag( 'button' );
var pw1 = byName( 'pw' );
var pw2 = byName( 'pw2' );
var un  = byName( 'un' );
var em  = byName( 'em' );

but.setAttribute( 'disabled', true );

function error( errs ) {
    err.textContent = errs.join(',');
}

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

    // USERNAME CHECK
    if( un.value.length < 3 ) {
        if( un.value == "" ) {
            errs.push( "missing username" );
        } else {
            errs.push( "username too short" );
        }
        un.classList.add('error');
    } else {
        un.classList.remove('error');
    }

    // EMAIL CHECK
    if( em.checkValidity() ) {
        if( em.value.length == 0 ) {
            errs.push( "missing email" );
            em.classList.add('error');
        } else {
            em.classList.remove('error');
        }
    } else {
        errs.push( "invalid email" );
        em.classList.add('error');
    }

    
    if( errs.length === 0 ) {
        but.removeAttribute( 'disabled' );
    } else {
        but.setAttribute( 'disabled', true );
    }
    
    error( errs );
}
var pw2popped = false;

em.addEventListener( 'keyup', function() {
    if( pw2popped ) {
        check();
    }
} );

un.addEventListener( 'keyup', function() {
    if( pw2popped ) {
        check();
    }
} );

pw2.addEventListener( 'keyup', function() {
    if( pw2popped === false ) {
        pw1.addEventListener( 'keyup', check );
        pw2popped = true;
    }
    check();
} );


