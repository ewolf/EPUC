// EPUC stuff
window.epuc = {};
var backstack = [], showingDetail = false; //, hashaction = false, curhash;

function set_app( a ) {
    window.app = a;
}
function get_app() { return window.app; }

// --------------- ACCOUNTS ACCESS -----------------
function set_login( li ) {
    window.login = li;
}
function get_login() { return window.login; }

function onLogout() {
    $( '#login' ).show();
    $( '.side' ).hide();
    set_login( undefined );
    set_template( 'about' );
    showStrips( $( '.recent-strips' ), get_app().get( 'recently_completed_strips' ) );
}

function onLogin( acct ) {
    $( '#login' ).hide();
    $( '.side' ).show();
    $( 'body' ).toggleClass( 'is-admin', acct.get( 'is_admin' ) == 1  );
    $( 'body' ).toggleClass( 'is-super', acct.get( 'is_super' ) == 1  );
    set_login( acct );

    $( '.info' ).each( function() {
        var $this = $(this);
        var fld = $this.data( 'field' );
        var txt = get_login().get('avatar').get( fld );
        $this.val( txt );
    } );

    var icon = acct.get('avatar').get('icon');
    icon.url( [ '80x80' ], function(url) {
        $( '.icon' ).attr( 'src', url );
    } );
    $( '.name' ).empty().append( acct.get('user') );
    set_template( 'about' );    
}

// --------------- MESSAGES -----------------

function msg( txt, sele ) {
    sele = sele || '.message';
    $( sele ).empty().append( txt );
}
function warn( txt, sele ) {
    sele = sele || '.message';
    $( sele ).empty().append( txt );
}

// --------------- TEMPLATE SYSTEM -----------------

function set_template( template ) {
    msg('');

    // check if template is there all ready
    if( $('.main > #' + template).length === 1 ) {
        return; //nothing to do
    }
    
    var $new = $( '.templates #' + template );
    if( $new ) {
        var action = onTemplate[ template ];
        if( action ) {
            action();
        }
        $new.detach();
        var $old = $('.main > .content' ).detach();
        if( $old ) {
            backstack.push( $old.attr('id') );
            $old.appendTo( '.templates' );
        }
        $new.appendTo( '.main' );
    } else {
        console.warn( "template '" + template + "' not found" );
    }
}

function setupActionLinks() {
    $( '.action' ).off('click').on('click', function() {
        var $this = $(this);
        var hash = $this.attr('href');
        var action = hash.substring(1);
        
        set_template( action );
    } );
}

var onTemplate = {
    'inprogress' : function() {
        if( get_login() ) {
            show_strips( {
                key    : 'inprogress',
                strips : get_login().get( 'in_progress_strips' ),
                container : $( '#inprogress>#strips' ),
                start : 0,
                end : 5,
                clickhandler : detailHandler
            } );
        }
    },
    'list-accounts' : function() {
        get_login().list_accounts( [], function( accts ) {
            $( '#accounts' ).empty().append(
                accts.map( function( acct ) {
                    return acct.get('user') + ( acct.get('is_admin') ? ' *admin*' : '' );
                } ).join("<br>")
            );
        } );
    },
    'findstrip' : function() {
        get_login().play_random_strip([], function( strip, panel ) {
            if( strip && panel ) {
                play_panel( panel, strip, $( '#foundstrip' ), false );
            } else {
                $( '#foundstrip' ).empty();
                msg( 'No strip seems available' );
            }
        } );
    },
    'reserved' : function() {
        if( get_login() ) {
            var res_strips = get_login().get( 'reserved_strips' );
            var $res_strips = $( '#reserved-strips' ).empty();
            res_strips.each( function( strip ) {
                $res_strips.append( "<div id='strip_" + strip.id + "'></div>" );
                strip.reserved_panel( [ get_login() ], function( panel ) {
                    play_panel( panel, strip, $( '#strip_' + strip.id ), true );
                } );
            } );
        }
    },
    'completed' : function() {
        if( get_login() ) {
            var cmplt_strips = get_login().get( 'avatar' ).get( 'completed_strips' );
            var $cmplt_strips = $( '#completed-strips' ).empty();
            showStrips( $cmplt_strips, cmplt_strips );
        } //get_login
    }, //completed
    'admin-in-progress' : function() {
        get_login().all_in_progress([], function( inProgStrips ) {
            show_strips( { key : 'admin-in-progress',
                           strips : inProgStrips,
                           container : $('#in-progress-strips'),
                           start : 0,
                           end : 5,
                           clickhandler : detailHandler,
                           override : 1
                         } );
        } );
    }
}; //onTemplate actions

// --------------- STRIPS -----------------
function detailHandler(ev, strip, $str, idx, strips, override ) {
    /* // show detail strip
       $('.detail.artist').hide();
       $('.detail.strip').show(); */
    show_strip( {
        size  : 'big',
        strip : strip,
        strip_container : $( '.detail-strip' ).empty().append('<div class="inner-strip"></div>' ),
        override : override
    } ); //login for kudos maybe?

    // update navigation
    var txt = '';
    if( idx > 0 ) {
        // previous
        txt += ' <a href="#prev" class="prev">prev</a> ';
    }
    if( idx < (strips.length()-1) ) {
        // next
        txt += ' <a href="#next" class="next">next</a> ';
    }
    
    var $nav = $( '.navigation' ).empty().append( txt );
    
    set_template( 'strip-detail' );

    if( idx > 0 ) {
        (function( newidx ) {
            var newstrip = strips.get( newidx );
            if( newstrip ) {
                $nav.find( '.prev' ).on( 'click', function(ev) {
                    detailHandler(ev,newstrip,$str,newidx,strips, override );
                } );
            }
        })( idx - 1 );
    }

    if( idx < (strips.length()-1) ) {
        (function( newidx ) {
            var newstrip = strips.get( newidx );
            if( newstrip ) {
                $nav.find( '.next' ).on( 'click', function(ev) {
                    detailHandler(ev,newstrip,$str,newidx,strips, override );
                } );
            }
        })( idx + 1 );
    }

} //detailHandler
function showStrips( $container, showStrips) {
    
    show_strips( { key : 'recent',
                   strips : showStrips,
                   container : $container,
                   start : 0,
                   end : 5,
                   clickhandler : detailHandler
                 } );
} //showStrips

//                function show_strips( key, strips, $strip_container, login, start, end, clickhandler ) {
function show_strips( args ) {
    
    var key              = args.key; //needed to different these strips from other strip containers
    var strips           = args.strips; //yote list
    var $strip_container = args.container; //jQuery object
    var start            = args.start;
    var end              = args.end;
    var clickhandler     = args.clickhandler;
    var sizes            = args.sizes || [];
    var override         = args.override;
    yote.ui.updateListener( strips,
                            'strip_' + key,
                            function() {
                                $strip_container.empty();
                                if( start === undefined ) start = 0;
                                if( end === undefined || end > strips.length() ) end = strips.length();
                                for( var i=start; i<end; i++ ) {
                                    var strip = strips.get(i);
                                    var $strip = $( '<div class="strip" data-id="' + strip.id + '" id="strip_' + key + "_" + strip.id + '"><div class="inner-strip"></div><div class="actions"></div></div>' ).appendTo( $strip_container );
                                    show_strip( {
                                        strip           : strip,
                                        strip_container : $strip,
                                        size            : sizes[ i ],
                                        override        : override
                                    } );
                                    if( clickhandler ) {
                                        (function(str,$str,idx,ss) {
                                            $strip.on( 'click', function( ev ) {
                                                var $str = $( this );
                                                clickhandler( ev, str, $str, idx, ss, override );
                                            } );
                                        }) (strip,$strip,i,strips);
                                    }

                                } //each strip
                            }, true ); //update listener
} // show_strips

function show_strip(args) {
    var strip  = args.strip;
    var $strip = args.strip_container;
    var size   = args.size || 'thumb';
    var override = args.override;
    var show_artists = false;
    var width = 600;
    var height = 450;

    if( size === 'big' ) {
        show_artists = true;
        size = '700x700';
        width = 600;
        height = 450;
    }
    if( size === 'medium' ) {
        size = '400x400';
    }
    if( size === 'thumb' ) {
        size = '50x50';
        width = 100;
        height = 58;
    }

    strip.can_change( [ get_login() ], function( can_change ) {
        if( false && can_change ) {
            $strip.find( '.actions' ).append( '<br><a href="#" class="delthis">delete this strip</a>' )
                .find( '.delthis' )
                .on( 'click', function( ev ) {
                    strip.delete_strip( [get_login()], function() {
                        msg( "Deleted" );
                    } );
                } );
        }
    } );
    
    strip.panels( [ get_login(), size, override ], function( panels ) {

        var $table = $( '<table>' ).appendTo( $strip.find( '.inner-strip' ) );
        panels.forEach( function( panel ) {
            var $tr = $( '<tr>' ).appendTo( $table );
            var txt;
            //            var txt = '<tr>';
            if( panel.type === 'sentence' ) {
                txt += '<td class="sentence">';
                if( show_artists ) {
                    var artist = panel.artist;
                    if( artist ) {
                        var user = artist.get('user');
                        txt += '<div class="artist"> <a href="#" class="artist-link">' + user + '</a> : </div>';
                    }
                }
                txt += '<div class="sentence">' + panel.sentence + '</div>';
            } else if( panel.type === 'picture' ) {
                txt += '<td class="picture">';
                if( show_artists ) {
                    var artist = panel.artist;
                    if( artist ) {
                        var user = artist.get('user');
                        txt += '<div class="artist"> <a href="#" class="artist-link">' + user + '</a> : </div>';
                    }
                }

                txt += '<img src="' + panel.url + '" width="' + width + '" height="' + height + '">';
            } else {
                txt += '<td>';
                txt += "<b>unknown panel</b>";
            }
            txt += '</td>'; //</tr>';
            $tr.append( txt );
            if( artist ) {
                (function (avatar) { 
                    $tr.find( '.artist-link' ).on( 'click', function(ev) {
                        
                        set_template( 'artist-detail' );
                        var $tmpl = $( '#artist-detail' );
                        var handle = $tmpl.find( '#artist-handle' ).empty().append( avatar.get('user') );
                        avatar.get( 'icon' ).url( [], function( url ) {
                            var ava = $tmpl.find( '#artist-avatar' ).attr( 'src', url );
                        } );
                        var name = $tmpl.find( '#artist-name' ).empty().append( avatar.get('name') );
                        var about = $tmpl.find( '#artist-about' ).empty().append( avatar.get('about') );
                        var strips = $tmpl.find( '#artist-recent-strips' ).empty();

                        var artist_strips = avatar.get('completed_strips');
                        showStrips( $('#artist-recent-strips'), artist_strips );
                    } );
                } )(artist);
            }
        } );
    } );
} //show_strip

function play_panel( panel, strip, $strip_container, isCurrentlyReserved ) {
    var drawstrip = '<div>';
    if( panel.get('type') === 'sentence' ) {
        drawstrip += '<b>' + panel.get('sentence') + '</b>';
        drawstrip += '<br><input id="panelUp" name="panelUp" type="file">';
        drawstrip += '<a href="#" id="upload">upload picture</a>';
        drawstrip += '<br><a href="#" id="unreserve_this" style="display:none">free this strip (unreserve)</a>';
        drawstrip += '<a href="#" id="reserve_this">reserve this strip</a>';
        if( ! isCurrentlyReserved ) {
            drawstrip += '<br><a href="#" id="find_again" id="">find an other strip</a>';
        }
    } else if( panel.get('type') === 'picture' ) {
        drawstrip += '<img id="panelpicture"><br><br>';
        drawstrip += '<input type="text" id="random_sentence"> <button type="button" id="submit_sentence">submit sentence</button>';
    }
    drawstrip += '</div>';
    $strip_container.empty().append( drawstrip );

    if( panel.get('type') == 'picture' ) {
        panel.get('picture').url( [ '700x700' ], function( url ) {
            $strip_container.find( 'img' ).attr( 'src', url );
        } );
    }
    
    if( isCurrentlyReserved ) {
        $strip_container.find('#reserve_this,#unreserve_this').toggle();
    }

    var $subm = $strip_container.find( '#submit_sentence' );
    $subm.on( 'click', function(ev) {
        ev.preventDefault();
        ev.stopPropagation();
        var $rand = $strip_container.find( '#random_sentence' );
        var sen = $rand.val();
        if( sen.match( /\S/ ) ) {
            strip.reserve( [ get_login() ], function() {
                strip.add_sentence( [ get_login(), sen ], function() {
                    msg( "added sentence" );
                    $strip_container.empty();
                    showStrips( $( '.recent-strips' ), get_app().get( 'recently_completed_strips' ) );
                }, function(err) { msg(err) } );
            } );
        } else {
            msg( "sentence can't be empty" );
        }
    } );
    
    var files;
    $strip_container.find( '#panelUp' ).on( 'change', function( ev ) {
        files = ev.target.files;
    } );
    
    $strip_container.find( '#upload' ).on( 'click', function(ev) {
        if( files && files.length == 1 ) {
            strip.reserve( [ get_login() ], function() {
                strip.add_picture( [get_login(),yote.prepUpload( files ) ], function( ret ) {
                    msg( 'uploaded panel' );
                    $strip_container.empty();
                } );
            }, function(err) { msg(err); }
                         );
        } else {
            msg( 'please select a file to upload' );
        }
    } );
    
    $strip_container.find( '#find_again' ).on( 'click', function( ev ) {
        get_login().play_random_strip([strip], function( strip, panel ) {
            if( strip && panel ) {
                play_panel( panel, strip, $( '#foundstrip' ), false );
            } else {
                $( '#foundstrip' ).empty();
                msg( 'No strip seems available' );
            }
        } );
    } );
    
    $strip_container.find( '#reserve_this' ).on( 'click', function( ev ) {
        ev.preventDefault();
        ev.stopPropagation();
        strip.reserve( [get_login()],
                       function( strip ) {
                           msg( "reserved strip" );
                           if( ! isCurrentlyReserved ) {
                               $strip_container.find('#reserve_this,#unreserve_this').toggle();
                           }
                       },
                       function( err ) {
                           msg( err );
                       } );
    } );
    $strip_container.find( '#unreserve_this' ).on( 'click', function( ev ) {
        ev.preventDefault();
        ev.stopPropagation();
        strip.free( [get_login()],
                    function( strip ) {
                        msg( "unreserved strip" );
                        if( isCurrentlyReserved ) {
                            $strip_container.hide();
                        } else {
                            $strip_container.find('#reserve_this,#unreserve_this').toggle();
                        }
                    },
                    function( err ) {
                        msg( err );
                    });
    } );
    
} // play_panel

function init_page( root, app, login ) {
    set_login( undefined );
    set_app( app );
    if( login ) {
        onLogin( login );
    }
    
    setupActionLinks();

    $( '#doLogin' ).on( 'click',
                        function() {
                            set_login( undefined );
                            var un = $( '#username' ).val();
                            var pw = $( '#password' ).val();
                            $( '#loginerr' ).empty().append( "logging in" );
                            get_app().login( [ un, pw ],
                                       
                                       function( acct ) {
                                           $( '#loginerr' ).empty().append( "logged in" );
                                           backstack.pop(); //pop off the login page
                                           onLogin(acct);
                                       },
                                       function( err ) {
                                           $( '#loginerr' ).empty().append( err );
                                       } );
                        } );
    $( '#logout' ).on( 'click', function(ev) {
        yote.logout( function( res ) {
            onLogout();
        } );
    } );

    $( '#doStart' ).on( 'click', function() {
        if( get_login() ) {
            var starting = $( '#startsentence' ).val();
            get_login().start_strip( [ starting ],
                               function( strip ) {
                                   $( '.message' ).empty().append( "started strip" ).removeClass( 'error' );
                                   $( '#startsentence' ).val('');
                               },
                               function( err ) {
                                   $( '.message' ).empty().append( err ).addClass( 'error' );
                               } );
        }
    } );

    if( get_login() ) {
        $( '.info' ).each( function() {
            var $this = $(this);
            var fld = $this.data( 'field' );
            var txt = get_login().get('avatar').get( fld );
            $this.val( txt );
        } );
    }
    $( '#iconup' ).on( 'change', function(ev) {
        var files = ev.target.files;
        if( files.length == 1 ) {
            get_login().uploadIcon( [yote.prepUpload( files )], function(icon) {
                icon.url( ['80x80' ], function( url ) {
                    $( '.icon' ).attr( 'src', url );
                    msg( 'uploaded icon' );
                } );
            }, function( err ) { msg ( err ); } );
        }        
    } );
    $( '.info' ).on( 'keyup', function(ev) {
        var $this = $(this);
        var fld = $this.data('field');
        var txt = $this.val();
        get_login().setInfo( [fld, txt] );
    } );

    $( '#do-create-account' ).on( 'click', function(ev) {
        var un = $( '#new-username' ).val();
        var pw = $( '#new-password' ).val();
        var admin = $( '#new-admin' ).is(':checked') ? 'admin' : '';
        get_login().create_user_account( [ un, pw, admin ],
                                   function( acct ) {
                                       msg( 'created user ' + un );
                                       $( '#new-username' ).val('');
                                       $( '#new-password' ).val('');
                                       $( '#new-admin' ).attr( 'checked', false );
                                   },
                                   function( err ) {
                                       msg( err );
                                   } );
    } );
    
    $( '#do-password-set' ).on( 'click', function(ev) {
        var un = $( '#username-set' ).val();
        var pw = $( '#password-set' ).val();
        get_login().reset_user_password( [ un, pw ],
                                   function( acct ) {
                                       msg( 'reset password for ' + un );
                                       $( '#username-set' ).val('');
                                       $( '#password-set' ).val('');
                                   },
                                   function( err ) {
                                       msg( err );
                                   } );
    } );

    $( '#resetpw' ).on( 'click', function( ev ) {
        ev.preventDefault();
        ev.stopPropagation();
        if( $('#newpw').val() == $('#newpw2').val() ) {
            get_login().reset_password( [$('#newpw').val(),$('#oldpw').val()], function(newacct) {
                msg( "reset password for " + newacct.get('user') );
                $('#newpw').val('');
                $('#oldpw').val('');
                $('#newpw2').val('');
            }, function( err ) { msg( err ); } );
        } else {
            warn( "Error, passwords do not match" );
        }
    } );
    showStrips( $( '.recent-strips' ), get_app().get( 'recently_completed_strips' ) );
    set_template( 'about' );
           
} //init_page
