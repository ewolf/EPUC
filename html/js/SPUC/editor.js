var width = 150;
var height = 150;

var h = document.getElementById("editor");
var eye = document.getElementById("eyedrop");
var c = document.getElementById("canv");
c.height = height;
c.width = width;
c.style['width'] = width + 'px';
c.style['height'] = height + 'px';

var pal = document.getElementById("palette");
var ctx = c.getContext("2d");
var size = 8;
var maxUndos = 50;
var lastX, lastY;
var color = 'rgba(0,0,0,255)';

var usingCompo = false;
var compocolor, inicolor;


var isDrawing = false;
var pickedBrush;
var isEyedrop = false;
var isErase = false;

function max() {
    var m = 0;
    for( var i=0; i<arguments.length; i++ ) {
        if( arguments[i] > m ) {
            m = arguments[i];
        }
    }
    return m;
}
function min() {
    var m = 9999;
    for( var i=0; i<arguments.length; i++ ) {
        if( arguments[i] < m ) {
            m = arguments[i];
        }
    }
    return m;
}

var slider_boxes = document.getElementsByClassName('colorslide');
function setup_sliders() {
    var lastslide;
    var x;
    var colors = [0,0,0,255];
    
    var sat   = ['#FF0000','#00FF00','#0000FF','#FFFFFF' ];
    var unsat = ['#FFFFFF','#FFFFFF','#FFFFFF','#000000' ];
    
    var compo = document.getElementById("composite");
    
    function setup_slider(sliderbox) {
        var sliding = false;
        var arry = [255,255,255];
        var slide = sliderbox.firstElementChild;

        var cidx = sliderbox.getAttribute('data-color-idx');
        
        sliderbox.style['background'] = 'linear-gradient(to right,'+unsat[cidx]+','+sat[cidx]+')';
        
        function updateslide(newx) {
            if( newx >=0 && newx <= 255 ) {
                x = newx;
                slide.style['margin-left'] = x+'px';
                colors[cidx] = x;
                
                var bright = parseInt(colors[3]);
                var r = parseInt(colors[0]);
                var g = parseInt(colors[1]);
                var b = parseInt(colors[2]);
                inicolor = [ r, g, b, bright ];
                var mx = max( r, g, b );
                var mi = min( r, g, b );

                var delta = bright - mx;
                r += delta;
                g += delta;
                b += delta;
                
                // interpolate the bright. if the bright is 255, then set the max color to 255
                // and interpolate the others accordingly.
                compocolor = 'rgba(' + r + ',' + g + ',' + b + ',255)';
                compo.style.display = 'block';
                compo.setAttribute( 'data-color', compocolor );
                compo.style['background-color'] = compocolor;
                usingCompo = true;
                compo.changecolor();
            }
        }
        sliderbox.updateslide = updateslide;
        sliderbox.addEventListener('click', function(ev) {
            ev.preventDefault();
            ev.stopPropagation();
            sliding = false;
            lastslide = this;
            updateslide( ev.offsetX );
        } );

        sliderbox.addEventListener('mousedown', function(ev) {
            ev.preventDefault();
            ev.stopPropagation();
            sliding = true;
            lastslide = this;
        } );
        slide.addEventListener('mouseup', function() { sliding = false; } );
        sliderbox.addEventListener('mouseup', function() { sliding = false; } );
        slide.addEventListener('mousemove', function(ev) {
            if( sliding ) {
                updateslide( ev.offsetX );
            }
        } );
        sliderbox.addEventListener('mousemove', function(ev) {
            if( sliding ) {
                updateslide( ev.offsetX );
            }
        } );
        
    } //setup_slider

    var slider_boxes = document.getElementsByClassName('colorslide');
    for( var i=0; i<slider_boxes.length; i++ ) {
        setup_slider( slider_boxes[i] );
    }

    window.addEventListener( 'keydown', function(ev) {
        var press = ev.key;
        if( press === 'ArrowLeft' ) {
            if( lastslide ) {
                lastslide.updateslide( x - 1 );
            }
        } else if( press === 'ArrowRight' ) {
            if( lastslide ) {
                lastslide.updateslide( x + 1 );
            }
        }
    } );
    window.addEventListener( 'keyup', function(ev) {
        var press = ev.key;
        if( press === 'ArrowLeft' ) {
            if( lastslide ) {
                lastslide.updateslide( x - 1 );
            }
        } else if( press === 'ArrowRight' ) {
            if( lastslide ) {
                lastslide.updateslide( x + 1 );
            }
        } else if( press === 'PageUp' ) {
            if( lastslide ) {
                lastslide.updateslide( 255 );
            }
        } else if( press === 'PageDown' ) {
            if( lastslide ) {
                lastslide.updateslide( 0 );
            }
        }
    } );    
} //setup_sliders
setup_sliders();



function setDrawingControls() {
    var undob = document.getElementById("undo");
    var redob = document.getElementById("redo");
//    var iy = document.getElementById( 'imgy' );


    var blankscreen = ctx.getImageData( 0, 0, width, height );
//    iy.src = c.toDataURL("image/png");
//    iy.style['border'] = '1px black solid';

    var undos = [ blankscreen ];
    var paintpoint = -1;
    var redos = [];
    var outtime;

    function blank() {
        if( confirm( "Really clear?" ) ) {
            ++paintpoint;
            ctx.putImageData( blankscreen, 0, 0 );
            undos[paintpoint+1] = blankscreen;
            undos.length = paintpoint+2;
            checkundoredo();
        }
    }

    function checkundoredo() {
        if( paintpoint >= 0 ) {
            undob.classList.add('active');
        } else {
            undob.classList.remove('active');
        }
        if( paintpoint < (undos.length-2) ) {
            redob.classList.add('active');
        } else {
            redob.classList.remove('active');
        }
//        iy.src = c.toDataURL("image/png" );

    }

    function undo() {
        if( paintpoint >= 0 ) {
            ctx.putImageData( undos[paintpoint--], 0, 0 );
            checkundoredo();
        }
    }

    function redo() {
        if( paintpoint < (undos.length-2) ) {
            ctx.putImageData( undos[++paintpoint+1], 0, 0 );
            checkundoredo();
        }
    }

    function starttouch(ev) {
        if( ev.touches.length == 1 ) {
            startdraw( ev.touches[0].pageX - c.offsetLeft,
                       ev.touches[0].pageY - c.offsetTop );
        }
    }
    function startmousedraw(ev) {
        startdraw( ev.offsetX, ev.offsetY );
    }
    function startdraw(x,y) {
        //save how things are
        if( isEyedrop ) {
            // select a color
            
            var pixel = ctx.getImageData( x, y, 1, 1 ).data;
            var pcolor = 'rgba(' + pixel[0] + ',' + pixel[1] + ',' + pixel[2] + ',' + pixel[3] + ')';
            if( colorcontrol[pcolor] ) {
                colorcontrol[pcolor].changecolor();
            }
            isEyedrop = false;
            c.style.cursor = 'default';
        }
        else {
            isDrawing = true;
            lastX = x;
            lastY = y;
            drawPoint( lastX, lastY );
            if( usingCompo ) {
                // add to palette
                if( colorcontrol[ compocolor ] ) {
                    colorcontrol[ compocolor ].changecolor();
                } else { 
                    var newc = document.createElement("span");
                    newc.classList.add( 'colorpick' );
                    newc.classList.add( 'circle' );
                    newc.setAttribute( 'data-color', compocolor );
                    newc.style['background-color'] = compocolor;
                    newc.changecolor = changecolor;
                    newc.setAttribute( 'data-inicolor', inicolor.join(',') );
                    newc.addEventListener('click', function() {
                        var icl = this.getAttribute( 'data-inicolor' ).split(',');
                        for( var i=0; i<4; i++ ) {
                            slider_boxes[i].updateslide( icl[i] );
                        }
                        this.changecolor();
                    } );
                    colorcontrol[ compocolor ] = newc;
                    pal.appendChild( newc );
                }
                usingCompo = false;
            }
        }
    }
    function movem(ev) {
        if( isDrawing ) {
            if( typeof outtime !== 'undefined' ) {
                clearTimeout( outtime );
                outtime = undefined;
            }
            move( ev.offsetX, ev.offsetY );
        }
    }
    function movet(ev) {
        ev.preventDefault();
        ev.stopPropagation();
        if( ev.touches.length == 1 ) {
            if( isDrawing ) {
                move( Math.round(ev.touches[0].pageX - c.offsetLeft ),
                      Math.round( ev.touches[0].pageY - c.offsetTop ) );
            } else {
                drawPoint( Math.round(ev.touches[0].pageX - c.offsetLeft ),
                           Math.round( ev.touches[0].pageY - c.offsetTop ) );
            }
        }
    } //movet
    
    function enddraw() {
        if( isDrawing ) {
            isDrawing = false;
            ++paintpoint;
            var idata = ctx.getImageData( 0, 0, width, height );
            undos[paintpoint+1] = idata;
            undos.length = paintpoint+2;
            if( undos.length > maxUndos ) {
                undos.shift();
                --paintpoint;
            }
            checkundoredo();
        }
    } //enddraw

    function mouseout() {
        if( isDrawing ) {
            outtime = setTimeout( enddraw, 300 );
        }
    }
    
    var P2 = 2*Math.PI;
    
    function move( x2, y2 ) {
        var x1 = lastX;
        var y1 = lastY;
        
        
        lastX = x2;
        lastY = y2;
        
        var delx = Math.abs(x2 - x1);
        var dely = Math.abs(y2 - y1);

        var del = delx+dely;
        var A = 0, B = 0, a = 0, b = 0;
        for( var i=0; i<del; i++ ) {
            if( A > B ) {
                b = b + 1;
                B = B + delx;
            } else {
                a = a + 1;
                A = A + dely
            }
            if( y1 > y2 ) {
                //down to up
                if( x1 > x2 ) {
                    // right to left
                    drawPoint( x1 - a, y1 - b );
                } else {
                    // left to right
                    drawPoint( x1 + a, y1 - b );
                }
            } else {
                //up to down
                if( x1 > x2 ) {
                    // right to left
                    drawPoint( x1 - a, y1 + b );
                } else {
                    // left to right
                    drawPoint( x1 + a, y1 + b );
                }
            }
        }
    } //move

    function drawPoint(x,y) {
        if( isErase ) {
            ctx.clearRect( x - size/2, y - size/2, size, size );
        } else {
            ctx.beginPath();
            ctx.arc( x, y, size, 0, P2, true );
            ctx.fill();
        }
    } //drawPoint

    var undoel = document.getElementById('undo');
    undoel.addEventListener('click', undo );
    var redoel = document.getElementById('redo');
    redoel.addEventListener('click', redo );
    var clearey = document.getElementById('cleary');
    clearey.addEventListener('click', blank );
    
    c.addEventListener('mousedown', startmousedraw );
    c.addEventListener('mouseup', enddraw );
    c.addEventListener('mousemove', movem );
    c.addEventListener('mouseout', mouseout );
    
    c.addEventListener('touchstart', starttouch );
    c.addEventListener('touchmove', movet );
    c.addEventListener('touchend', enddraw );
    
}
setDrawingControls();



function setSizeControls() {

    var picks = document.getElementsByClassName('brushcontrol');
    function changesize( ev ) {
        for( var i=0; i<picks.length; i++ ) {
            picks[i].classList.remove( 'picked' );
            picks[i].firstChild.style['background-color'] = 'white';
        }

        this.classList.add( 'picked' );
        pickedBrush = this.firstChild;
        this.firstChild.style['background-color'] = color;
        
        size = this.getAttribute('data-size');
        
    }

    for( var i=0; i<picks.length; i++ ) {
        var pickout = picks[i];
        var pickin = document.createElement('p');
        pickout.appendChild( pickin );

        var bsize = pickout.getAttribute('data-size');
        if( bsize == size ) {
            pickout.classList.add( 'picked' );
            pickin.classList.add( 'picked' );
            pickedBrush = pickin;
        }
        
        pickin.classList.add( 'brushsize' );
        
        var rsize = (bsize/2)+'px';
        
        bsize += 'px';
        pickin.style.width = bsize;
        pickin.style.height = bsize;
        pickin.style['-moz-border-radius'] = rsize;
        pickin.style['-webkit-border-radius'] = rsize;
        pickin.style['border-radius'] = rsize;
        pickout.addEventListener('click', changesize );
        pickout.addEventListener('touchstart', changesize );
        var erasr = document.createElement('p');
        erasr.classList.add( 'erasorbrush' );
        erasr.style.width = bsize;
        erasr.style.height = bsize;
        pickout.appendChild( erasr );
    }
} //setSizeControls
setSizeControls();
var colorcontrol = {};
var picks = document.getElementsByClassName('colorpick');
var changecolor = function changecolor() {    
    for( var i=0; i<picks.length; i++ ) {
        picks[i].classList.remove( 'picked' );
    }
    this.classList.add( 'picked' );
    color = this.getAttribute('data-color');
    if( color === 'eyedrop' ) {
        isEyedrop = true;
        isErase = false;
        h.classList.remove('erasing');
        c.style.cursor = 'crosshair';
    } else {
        isErase = color === 'erase';
        if( isErase ) {
            h.classList.add('erasing');
        } else {
            h.classList.remove('erasing');
        }
        isEyedrop = false;
        c.style.cursor = 'default';
        ctx.fillStyle = color;
        pickedBrush.style.backgroundColor = color;
    }
}
function setColorControls() {

    for( var i=0; i<picks.length; i++ ) {
        var pick = picks[i];
        pick.changecolor = changecolor;
        var pickcolor = pick.getAttribute('data-color');
        if( pickcolor ) {
            pick.style.backgroundColor = pickcolor;
            colorcontrol[pickcolor] = pick;
            if( pickcolor == color ) {
                pickedBrush.style.backgroundColor = color;
                pick.classList.add( 'picked' );
            }
            if( pickcolor == 'white' ) {
                pick.classList.add( 'white' );
            }
        }
        pick.addEventListener('click', changecolor );
        pick.addEventListener('touchstart', changecolor );
    }
} //setColorControls
setColorControls();

var uped = document.getElementById('upedit');
uped.addEventListener('click', function(ev) {
    ev.preventDefault();
    ev.stopPropagation();
    var avup = document.getElementById('avup');
    var edform = document.getElementById('edform');
    avup.value = c.toDataURL('image/png');
    edform.submit();
} );
