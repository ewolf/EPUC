



// --------------- OPEN CLOSE FOR MANAGE AVATARS
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

// DELETE AVATARS
var dels = byClass('delete');
dels.forEach( function( delly ) {
    delly.addEventListener( 'click', function(ev) {
        if( ! confirm( 'really delete avatar' ) ) {
            ev.preventDefault();
            ev.stopPropagation();
        }
    } );
} );




