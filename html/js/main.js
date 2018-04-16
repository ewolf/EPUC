function byName( name ) {
    return document.getElementsByName( name )[0];
}
function byClass( name ) {
    return Object.values( document.getElementsByClassName( name ) );
}
function oneByClass( name ) {
    return Object.values( document.getElementsByClassName( name ) )[0];
}
function byId( id ) {
    return document.getElementById( id );
}
function oneTag( tagname ) {
    return document.getElementsByTagName( tagname )[0];
}

function text_activate( txt, subbut ) {
    subbut.setAttribute( 'disabled', true );
    txt.addEventListener( 'keyup', ev => {
        if( txt.value.match( /\S/ ) ) {
            subbut.removeAttribute( 'disabled' );
            subbut.classList.add( 'enabled' );
        } else {
            subbut.setAttribute( 'disabled', true );
            subbut.classList.remove( 'enabled' );
        }
    } );
    txt.focus();
}

var user;
var token;
var cache = {};

function error( errs ) {
    var errbox = Object.values(document.getElementsByClassName);
    var txt = errs.join(',');
    errbox.forEach( box => {
        box.textContent = txt;
    } );
}


// how about just get the user?
function initApp(appname) {
    return new Promise(function( resolve, reject )  {
        return RPCCall(0,'load',[appname]).then( function() {
            resolve( cache[0] ); // return the apploader
        } );
    } );
}
async function init(appname) {
    user = await initRPC();
    alert(loader);
}

//init().then( function() { alert("INI") } );

function _update( update ) {
    var id = update.i;
    let obj = _fetchobj( id );
    if( typeof obj !== 'object' ) {
        obj = {
            id        : id,
            listeners : [],
            get       : fld => {
                return this.fields[fld];
            },
            addUpdateListener : listener => {
                this.listeners.push( listener );
            }
        };
        update.m.forEach( method => {
            obj[method] = args => {
                return RPCCall( this.id, method, args );        
            };
        } );
        cache[id] = obj;
    }
    obj.fields = update.f;

    // notify the listsners that this has changed
    obj.listeners.forEach( listener => {
        listener( this );
    } );
    
} //_update

function _fetchobj( id ) {
    return cache[id];
}

function _pack( item ) {
    if( Array.isArray( item ) ) {
        return item.map( _pack );
    }
    else if( typeof item === 'object' ) {
        if( cache[item.id] === item ) {
            return item.id;
        }
        const ret = {};
        for( let key in item ) {
            ret[key] = _pack( item[key] );
        }
        return ret;
        
    }
    else if( typeof item === 'undefined' ) {
        return 'u';
    }
    return 'v' + item;
}

function _unpack( item ) {
    if( Array.isArray( item ) ) {
        return item.map( _unpack );
    }
    if( typeof item === 'object' ) {
        const ret = {};
        for( let key in item ) {
            ret[key] = _unpack( item[key] );
        }
        return ret;
    }
    if( item.match( /^v(.*)/ ) ) {
        return item.substring(1);
    }
    if( item.match( /^u/ ) ) {
        return undefined;
    }
    return _fetchobj( item );
}

function RPCCall( id, method, args ) {
    return new Promise(function( resolve, reject)  {
        const req = new XMLHttpRequest();
        var sendData = new FormData();
        const url = '?path=/RPC';

        // ready the send data
        var payload = JSON.stringify( {
            'i' : id,
            'm' : method,
            'a' : args,
        } );
        sendData.set( 'p', payload );
        sendData.set( 't', token );
        

        // ready the send mechanism
        req.open('POST',url);
        req.responseType = 'json';
        req.onload = function() {
            try {
                if( req.status === 200 ) {
                    const resp = JSON.parse( req.response );
                    if( typeof resp === 'object' ) {
                        // updates
                        resp.u.forEach( _update );
                        
                        // response
                        
                        // token
                        token = resp.t;
                        
                        resolve( _unpack(resp) );
                    } else {
                        reject(Error('RPC response failed'));
                    }
                } else {
                    reject(Error('Bad thing happened : ' + req.statusText));
                }
            } catch( Err ) {
                reject(Err);
            }
        };
        req.onerror = function() {
            reject(Error('Bad thing happened : ' + req.statusText));
        };

        // do the send
        req.send(sendData);
    });
} //RPCCall

