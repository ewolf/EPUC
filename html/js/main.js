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
var _cache = {};
var _top_id = 0;
var cacheFetch = (id) => {
    id = parseInt( id );
    var item = _cache[id];
    if( item === undefined ) {
        let upd = localStorage.getItem( id );
        if( upd ) {
            item = _update( JSON.parse( upd ), true );
        }
    }
    return item;
};
var cacheStow = (id,item,update) => {
    id = parseInt( id );
    localStorage.setItem( id, JSON.stringify(update) );
    _cache[id] = item;
    if( id > _top_id ) {
        _top_id = id;
        localStorage.setItem( 'top-id', id );
    }
};
var resetCache = () => {
    var top = parseInt(localStorage.getItem( 'top-id' ));
    if( top > 0 ) {
        for( var i=0; i<top; i++ ) {
            localStorage.removeItem( i );
        }
        localStorage.removeItem( 'top-id' );
        localStorage.removeItem( 'last-update' );
    }
    
};

function error( errs ) {
    var errbox = byClass( 'err-txt' );
    if( errs && errs.length > 0 ) {
        var txt = errs.join(',');
        errbox.forEach( box => {
            while( box.hasChildNodes() ) {
                box.removeChild( box.lastChild );
            }
            errs.forEach( err => {
                var p = document.createElement('span');
                p.textContent = err;
                box.appendChild( p );
            } );
            box.classList.add( 'error' );
        } );
    } else {
        errbox.forEach( box => {
            while( box.hasChildNodes() ) {
                box.removeChild( box.lastChild );
            }
            box.classList.remove( 'error' );
        } );
    }
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
}

//init().then( function() { alert("INI") } );

function _update( update, noFetchCache ) {
    var id = update.i;
    let obj = noFetchCache ? undefined : cacheFetch( id );
    if( obj === undefined ) {
        obj = {
            id        : id,
            listeners : [], // update listeners?
            get       : fld => {
                return this.fields[fld];
            },
            addUpdateListener : listener => {
                this.listeners.push( listener );
            }
        };
        update.m.forEach( method => {
            obj[method] = args => {
                return RPCCall( obj.id, method, args );
            };
        } );
        obj.fields = update.f;
        cacheStow( id, obj, update );
    }
    else {
        obj.fields = update.f;
        obj.listeners.forEach( l => ( l(obj) ) );
    }

    // notify the listsners that this has changed
    obj.listeners.forEach( listener => {
        listener( this );
    } );

    return obj;
} //_update

function _pack( item ) {
    if( Array.isArray( item ) ) {
        return item.map( _pack );
    }
    else if( typeof item === 'object' ) {
        if( cacheFetch(item.id) === item ) {
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
} // pack

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
    if( (''+item).match( /^v(.*)/ ) ) {
        return item.substring(1);
    }
    if( (''+item).match( /^u/ ) ) {
        return undefined;
    }
    return cacheFetch( item );
} // _unpack

function RPCCall( id, method, args ) {
    return new Promise(function( resolve, reject)  {
        const req = new XMLHttpRequest();
        var sendData = new FormData();
        const url = '?path=/RPC';

        // ready the send data
        var payload = JSON.stringify( {
            'i' : id,
            'm' : method,
            'a' : _pack(args),
            't' : localStorage.getItem('last-update') || '0',
        } );

        sendData.set( 'p', payload );
        

        // ready the send mechanism
        req.open('POST',url);
        req.responseType = 'json';
        req.onload = function() {
//            try {
                if( req.status === 200 ) {
                    const resp = req.response;
                    if( typeof resp === 'object' ) {
                        // updates
                        if( resp.R ) {
                            resetCache();
                            alert('r');
                        }
                        localStorage.setItem('last-update', resp.t );

                        resp.u.forEach( _update );
                        
                        // response
                        
                        resolve( _unpack(resp.r) );
                    } else {
                        reject(Error('RPC response failed'));
                    }
                } else {
                    reject(Error('Bad thing happened : ' + req.statusText));
                }
            // } catch( Err ) {
            //     reject(Err);
            // }
        };
        req.onerror = function() {
            reject(Error('Bad thing happened : ' + req.statusText));
        };

        // do the send
        req.send(sendData);
    });
} //RPCCall

