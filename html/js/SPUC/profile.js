
var openedits = byClass( 'toggleedit' );
var avedit = byId( 'avedit' );

openedits.forEach( function( oe ) {
    oe.addEventListener( 'click', function(ev) {
        ev.preventDefault();
        ev.stopPropagation();
        if( avedit.classList.contains( 'open' ) ) {
            avedit.classList.remove( 'open' );
            if( this.textContent == 'Close' ) {
                this.textContent = 'Manage Avatars';
            }
        } else {
            avedit.classList.add( 'open' );
            if( this.textContent == 'Manage Avatars' ) {
                this.textContent = 'Close';
            }
        }
    } );
} );

var submit = byId( 'avsub' );
submit.setAttribute( 'disabled', true );
var fileinput = byId( 'avfileinput' );
fileinput.addEventListener( 'change', function() {
    if( this.value !== undefined ) {
        submit.removeAttribute( 'disabled' );
    }
} );


// ------------- CHANGE PASSWORD


var subbut = byId( 'uppw' );
subbut.setAttribute( 'disabled', true );

var pwold = byName( 'pwold' );
var pw1 = byName('pw');
var pw2 = byName('pw2');
var pw2popped = false;

pwold.addEventListener( 'keyup', function() {
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
    if( pwold.length < 8 ) {
        errs.push( "need original password" );
        pwold.classList.add( 'error' );
    } else {
        pwold.classList.remove( 'error' );
    }

    if( errs.length === 0 ) {
        subbut.removeAttribute( 'disabled' );
    } else {
        subbut.setAttribute( 'disabled', true );
    }
    
    error( errs );
}

