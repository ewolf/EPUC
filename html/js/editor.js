var brushSize  = 8;
var maxUndos   = 50;
var brushColor = 'rgba(0,0,0,255)';
var mode       = 'drawing';
var P2         = 2*Math.PI;

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

var touchDo = fun => {
    return ev => {
        if( ev.touches.length == 1 ) {
            ev.preventDefault();
            ev.stopPropagation();
            fun( ev.touches[0].pageX - canvas.offsetLeft,
                 ev.touches[0].pageY - canvas.offsetTop );
        }
    };
};

var canvas  = byId("canv");
canvas.height = height;
canvas.width  = width;

var ctx     = canvas.getContext("2d");
var colorDisplays = byClass('color-display');


// **********************************
//       save action buttons
// **********************************
var user = byId('use-picture');
var usePicture = () => {
    if( confirm( 'really use this picture' ) ) {
        var upper = byId('upper');
        var upform = byId('edform');
        upper.value = canvas.toDataURL('image/png');
        upform.submit();
    }
};
if( user ) {
    user.addEventListener('click', usePicture );
    user.addEventListener('touchstart', touchDo( usePicture ) );
}
var saver = byId('save-picture');
var savePicture = () => {
    var upper = byId('upper-save');
    var upform = byId('saveform');
    upper.value = canvas.toDataURL('image/png');
    upform.submit();
};
if( saver ) {
    saver.addEventListener('click', savePicture );
    user.addEventListener('touchstart', touchDo( savePicture ) );
}

// **********************************
//         undo/redo/init
// **********************************
var blankscreen =
    ctx.getImageData( 0, 0, width, height );

var startPanel = 
    ctx.getImageData( 0, 0, width, height );

var undoFrames = [ startPanel ]; 
var redoFrames = [];

if( window.initimage ) {
    var i = new Image();
    i.src = initimage;
    i.onload = function() {
        ctx.drawImage( i, 0, 0 );
        startPanel = ctx.getImageData( 0, 0, width, height );
        undoFrames[0] = startPanel;
    }
}

// list of image frames to undo/redo.
// make it stacky
var undoButton = byId( 'undo' );
var redoButton = byId( 'redo' );

var undo = () => {
    if( undoFrames.length > 1 ) {
        redoFrames.unshift( undoFrames.shift() );
        redoButton.classList.add( 'active' );
    }
    ctx.putImageData( undoFrames[0], 0, 0 );
    if( undoFrames.length > 1 ) {
        undoButton.classList.add( 'active' );
    } else {
        undoButton.classList.remove( 'active' );
    }

};
var redo = () => {
    var pane = redoFrames.shift();
    if( pane ) {
        undoFrames.unshift( pane );
        ctx.putImageData( undoFrames[0], 0, 0 );
        undoButton.classList.add( 'active' );
    }
    if( redoFrames.length > 0 ) {
        redoButton.classList.add( 'active' );
    } else {
        redoButton.classList.remove( 'active' );
    }
};
undoButton.addEventListener( 'click', undo );
redoButton.addEventListener( 'click', redo );
         undoButton.addEventListener( 'click', ev => { undo } );
         redoButton.addEventListener( 'click', ev => { redo } );


// **********************************
//       brush size buttons
// **********************************

var size2brush = {};
var brushbuttons = byClass('brush-control');
brushbuttons.forEach( bb => {
    size2brush[ bb.getAttribute('data-size') ] = bb;

    var bsize = bb.getAttribute('data-size');
    
    bb.addEventListener('click', ev => { setBrushSize(bsize) } );
    bb.addEventListener('touchstart',
                        touchDo( () => { setBrushSize( bsize ); } ) );

    var brushIcon = document.createElement('p');
    bb.appendChild( brushIcon );
    if( bsize == brushSize ) {
        bb.classList.add( 'picked' );
        brushIcon.classList.add( 'picked' );
    }

    var rsize = (bsize/2)+'px';
    
    brushIcon.classList.add( 'brush-size' );
    brushIcon.style.width = bsize + 'px';
    brushIcon.style.height = bsize + 'px';
    brushIcon.style['-moz-border-radius'] = rsize;
    brushIcon.style['-webkit-border-radius'] = rsize;
    brushIcon.style['border-radius'] = rsize;
    
    // erasor mode
    var eraseIcon = document.createElement('p');
    eraseIcon.classList.add( 'erasor-brush' );
    eraseIcon.style.width = bsize;
    eraseIcon.style.height = bsize;
    bb.appendChild( eraseIcon );
    
} );
var setBrushSize = newSize => {
    brushSize = newSize;
    brushbuttons.forEach( bb => {
        bb.classList.remove('picked');
    } );
    var bb = size2brush[ brushSize ];
    if( bb ) {
        bb.classList.add('picked');
    }
};


// **********************************
//       paint mixing controls
// **********************************
var mixValues = [0,0,0,255];
var mixColor  = 'rgba(0,0,0,0)';
var activeSlider = 0;
var useMix = false;
var sliding = false;
var palette = byId('palette');
var sliders = byClass('slider');
var sliderBoxes = byClass('color-slide');

window.addEventListener( 'keydown', ev => {
    var press = ev.key;
    if( useMix && press.match( /^(ArrowLeft|ArrowRight|ArrowUp|ArrowDown|PageDown|PageUp)$/ ) ) {
        ev.preventDefault();
        ev.stopPropagation();
        var toLeft;
        if( press === 'PageDown' ) {
            toLeft = 255;
        }
        else if( press === 'PageUp' ) {
            toLeft = 0;
        }
        else {
            var delta = 1;
            if( press === 'ArrowLeft' || press === 'ArrowDown' ) {
                delta = -1;
            }
            var slider = sliders[ activeSlider ];
            var left = slider.style['margin-left'].match( /^(\d+)px/ );
            toLeft = parseInt(left[1]) + delta;
        }
        updateMix( toLeft, activeSlider );
    }
} );

var sat   = ['#FF0000','#00FF00','#0000FF','#FFFFFF' ];
var unsat = ['#FFFFFF','#FFFFFF','#FFFFFF','#000000' ];
[0,1,2,3].forEach( i => {
    sliderBoxes[i].style['background'] = 'linear-gradient(to right,'+unsat[i]+','+sat[i]+')';
} )

sliderBoxes.forEach( sb => {
    sb.addEventListener( 'mouseout', ev => {
        if( sliding ) {
            updateMix( ev.offsetX, activeSlider );
            sliding = false;
        }
    } );
    sb.addEventListener( 'click', ev => {
        var idx = sb.getAttribute('data-color-idx');
        activeSlider = idx;
        updateMix( ev.offsetX, idx );
    } );
    sb.addEventListener( 'mousedown', ev => {
        sliding = true;
        activeSlider = sb.getAttribute('data-color-idx');
    } );
    sb.addEventListener( 'mouseup', ev => {
        sliding = false;
    } );
} );
var updateMix = (val,idx) => {
    val = parseInt(val) > 255 ? 255 : parseInt(val) < 0 ? 0 : parseInt(val);
    mixValues[idx] = val;
    var slide = sliders[idx];
    slide.style['margin-left'] = val + 'px';

    var bright = mixValues[3];
    var r = mixValues[0];
    var g = mixValues[1];
    var b = mixValues[2];

    var mx = max( r, g, b );
    
    var delta = bright - mx;
    r += delta;
    g += delta;
    b += delta;

    // so ... bright = delta + max(r,b,g)
    // delta = 255 - max(r,b,g)
    
    mixColor = 'rgba('+r+','+g+','+b+',255)';
    displayColor( mixColor );
    useMix = true; // once a pixel or whatever is drawn, this becomes false
};

var displayColor = color => {
    colorDisplays.forEach( disp => {
        disp.style['background-color'] = color;
    } );
    ctx.fillStyle = color;
};

// **********************************
//       paint color controls
// **********************************
var color2control = {};
var paintButtons = byClass('paint-control');
paintButtons.forEach( pb => {
    var pcolor = pb.getAttribute('data-color');
    
    var parts = pcolor.match( /\((\d+),(\d+),(\d+),/ );
    if( parts && parts.length > 0 ) {
        var mix = [ parseInt( parts[1]), parseInt( parts[2] ), parseInt( parts[3] ) ];
        var mx = max( mix[0], mix[1], mix[2] );
        var delta = 255 - mx;
        mix = mix.map( n => { return parseInt(n)+delta; } );
        var bright = max( mix[0], mix[1], mix[2] ) - delta;
        pb.setAttribute( 'data-mix-color', mix.join(",") + "," + bright );
    }
    
    color2control[ pcolor ] = pb;
    pb.style['background-color'] = pcolor;
    pb.addEventListener( 'click', ev => { pickColor(pcolor); } );
    pb.addEventListener( 'touchstart',
                         touchDo( () => { pickColor(pcolor); } ));
    if( pcolor === brushColor ) {
        pb.classList.add('picked');
    }
} );
displayColor( brushColor );
var pickColor = color => {
    useMix = false;
    paintButtons.forEach( pb => {
        pb.classList.remove('picked');
    } );
    var cc = color2control[color];
    if( cc ) {
        cc.classList.add('picked');
    } else {
        // add to palette
        cc = document.createElement("span");
        cc.classList.add( 'palette' );
        cc.classList.add( 'picked' );
        cc.classList.add( 'paint-control' );
        paintButtons.push( cc );
        cc.classList.add( 'circle' );
        cc.setAttribute( 'data-color', color );
        cc.setAttribute( 'data-mix-color', mixValues.join(',') );
        cc.style['background-color'] = color;
        cc.addEventListener( 'click', ev => { pickColor(color); } );
        cc.addEventListener( 'touchstart',
                               touchDo( () => { pickColor(color); } ));

        color2control[ color ] = cc;
        palette.appendChild( cc );
    }
    mode = color === 'erase' ? 'erasing' : color === 'eyedrop' ? 'eyedropping' : 'drawing';
    var dt = byId( 'editor' );
    dt.classList.remove( 'eyedropping' );
    dt.classList.remove( 'drawing' );
    dt.classList.remove( 'erasing' );
    dt.classList.add( mode );
    displayColor( color );

    // set the slider controls to the chosen color
    var mixCol = cc.getAttribute( 'data-mix-color' );
    if( mixCol ) {
        var mixVals = mixCol.split(',');
        mixColor = cc.getAttribute( 'data-color');
        [0,1,2,3].forEach( i => {
            sliders[i].style['margin-left'] = mixVals[i] + 'px';
            mixValues[i] = parseInt(mixVals[i]);
        } );
    }
};


// **********************************
//       clear the canvas
// **********************************
var clearCanvas = () => {
    if( confirm( "really clear?" ) ) {
        undoFrames.unshift( blankscreen );
        ctx.putImageData( blankscreen, 0, 0 );
        undoButton.classList.add( 'active' );
    }
};
var clearCtl = byId('cleary');
clearCtl.addEventListener( 'click', ev => { clearCanvas(); } );
clearCtl.addEventListener( 'touchstart', touchDo( clearCanvas ) );

// **********************************
//       eyedrop a color
// **********************************

// also make sure undo,redo are enabled when appropriate


// **********************************
//       finally painting!
// **********************************
var outOfCanvasTimer = undefined;
var lastX, lastY;
var brushDown = false;

var drawPoint = (x,y) => {
    if( mode === 'erasing' ) {
        ctx.clearRect( x - brushSize/2, y - brushSize/2, brushSize, brushSize );
    } else {
        ctx.beginPath();
        ctx.arc( x, y, brushSize, 0, P2, true );
        ctx.fill();
    }
}; //drawPoint

var startDraw = ( x, y ) => {
    if( mode === 'drawing' || mode === 'erasing' ) {
        lastX = x;
        lastY = y;
        if( mode === 'drawing' && useMix ) {
            pickColor( mixColor );
        }
        brushDown = true;
        drawPoint( lastX, lastY );
    }
    else { // mode === 'eyedropping'
        var pixel = ctx.getImageData( x, y, 1, 1 ).data;
        pickColor( 'rgba(' + pixel[0] + ',' + pixel[1] + ',' + pixel[2] + ',' + pixel[3] + ')' );
        mode = 'drawing';
    }
   
};
var moveDraw = ( x2, y2 ) => {
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
}; //moveDraw

var drawEnd = () => {
    if( brushDown ) {
        brushDown = false;
        var frame = ctx.getImageData( 0, 0, width, height );
        undoFrames.unshift( frame );
        undoButton.classList.add( 'active' );
    }
};

canvas.addEventListener('mousedown', ev => {
    startDraw( ev.offsetX, ev.offsetY );
} );

canvas.addEventListener('touchstart', touchDo( startDraw ) );
canvas.addEventListener('touchmove', touchDo( moveDraw ) );

canvas.addEventListener('mousemove', ev => {
    if( brushDown ) {
        if( typeof outOfCanvasTimer !== 'undefined' ) {
            clearTimeout( outOfCanvasTimer );
            outOfCanvasTimer = undefined;
        }
        moveDraw( ev.offsetX, ev.offsetY );
    }
} );

// if the mouse moves briefly outside the
// canvas, dont freak out :)
canvas.addEventListener('mouseout', ev => {
    outtime = setTimeout( drawEnd, 300 );
} );
canvas.addEventListener('mouseup', drawEnd );

/*

canvas.addEventListener('mouseout', mouseout );

canvas.addEventListener('touchstart', starttouch );
canvas.addEventListener('touchmove', movet );
canvas.addEventListener('touchend', enddraw );
*/


// **********************************
//       paint color controls
// **********************************


/*
var editor  = byId("editor");
var eyedrop = byId("eyedrop");
var canvas  = byId("canv");

// color -> picker
var colorcontrol = {};

canvas.height = height;
canvas.width = width;
canvas.style['width'] = width + 'px';
canvas.style['height'] = height + 'px';

var pal = byId("palette");

var ctx = canvas.getContext("2d");
var size = 8;
var maxUndos = 50;
var lastX, lastY;
var color = 'rgba(0,0,0,255)';
var color_displays = byClass( 'display' );

var usingComposite = false;
var inicolor;


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

//  THE COLOR SLIDERS
var slider_boxes = document.getElementsByClassName('color-slide');
function setup_sliders() {
    var lastslide;
    var x;
    var colors = [0,0,0,255];
    
    var sat   = ['#FF0000','#00FF00','#0000FF','#FFFFFF' ];
    var unsat = ['#FFFFFF','#FFFFFF','#FFFFFF','#000000' ];

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
                color = 'rgba(' + r + ',' + g + ',' + b + ',255)';
                ctx.fillStyle = color;
                // update the displays to the color chosen
                color_displays.forEach( disp => {
                    disp.style['background-color'] = color;
                } );

                // demo composite
                usingComposite = true;
            }
        } // slide updated
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

    var slider_boxes = document.getElementsByClassName('color-slide');
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
    var isSaved = true;
    var undob = byId("undo");
    var redob = byId("redo");
//    var iy = byId( 'imgy' );


    var blankscreen = ctx.getImageData( 0, 0, width, height );
//    iy.src = canvas.toDataURL("image/png");
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
//        iy.src = canvas.toDataURL("image/png" );

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
            ev.preventDefault();
            ev.stopPropagation();
            startdraw( ev.touches[0].pageX - canvas.offsetLeft,
                       ev.touches[0].pageY - canvas.offsetTop );
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
            canvas.style.cursor = 'default';
        }
        else {
            isDrawing = true;
            lastX = x;
            lastY = y;
            drawPoint( lastX, lastY );
            if( usingComposite ) {
                // add to palette
                if( colorcontrol[ color ] ) {
                    colorcontrol[ color ].changecolor();
                } else {
//                if( !(colorcontrol[ color ] && colorcontrol[ color ].classList.contains('palette') ) ) {
                    var newc = document.createElement("span");
                    newc.classList.add( 'palette' );
                    newc.classList.add( 'colorpick' );
                    newc.classList.add( 'circle' );
                    newc.setAttribute( 'data-color', color );
                    newc.style['background-color'] = color;
                    newc.changecolor = changecolor;
                    newc.setAttribute( 'data-inicolor', inicolor.join(',') );
                    newc.addEventListener('click', function() {
                        var icl = this.getAttribute( 'data-inicolor' ).split(',');
                        for( var i=0; i<4; i++ ) {
                            slider_boxes[i].updateslide( icl[i] );
                        }
                        this.changecolor();
                    } );
                    colorcontrol[ color ] = newc;
                    pal.appendChild( newc );
                }
                usingComposite = false;
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
                move( Math.round(ev.touches[0].pageX - canvas.offsetLeft ),
                      Math.round( ev.touches[0].pageY - canvas.offsetTop ) );
            } else {
                drawPoint( Math.round(ev.touches[0].pageX - canvas.offsetLeft ),
                           Math.round( ev.touches[0].pageY - canvas.offsetTop ) );
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
            isSaved = false;
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

    var undoel = byId('undo');
    undoel.addEventListener('click', undo );
    var redoel = byId('redo');
    redoel.addEventListener('click', redo );
    var clearey = byId('cleary');
    clearey.addEventListener('click', blank );
    
    canvas.addEventListener('mousedown', startmousedraw );
    canvas.addEventListener('mouseup', enddraw );
    canvas.addEventListener('mousemove', movem );
    canvas.addEventListener('mouseout', mouseout );
    
    canvas.addEventListener('touchstart', starttouch );
    canvas.addEventListener('touchmove', movet );
    canvas.addEventListener('touchend', enddraw );

}
setDrawingControls();



function setSizeControls() {

    var picks = byClass('brushcontrol');
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

var changecolor = function changecolor() {
    var picks = byClass('colorpick');
    for( var i=0; i<picks.length; i++ ) {
        picks[i].classList.remove( 'picked' );
    }
    this.classList.add( 'picked' );
    color = this.getAttribute('data-color');
    if( color === 'eyedrop' ) {
        isEyedrop = true;
        isErase = false;
        editor.classList.remove('erasing');
        canvas.style.cursor = 'crosshair';
    } else {
        isErase = color === 'erase';
        if( isErase ) {
            editor.classList.add('erasing');
        } else {
            editor.classList.remove('erasing');
        }
        isEyedrop = false;
        canvas.style.cursor = 'default';
        ctx.fillStyle = color;
        pickedBrush.style.backgroundColor = color;
        color_displays.forEach( compo => {
            compo.style.backgroundColor = color;
        } );
    }
} //changecolor
function setColorControls() {
    var picks = byClass('colorpick');
    for( var i=0; i<picks.length; i++ ) {
        var pick = picks[i];
        pick.changecolor = changecolor;
        var pickcolor = pick.getAttribute('data-color');
        pick.style.backgroundColor = pickcolor;
        colorcontrol[pickcolor] = pick;
        if( pickcolor == color ) {
            pickedBrush.style.backgroundColor = color;
            pick.classList.add( 'picked' );
        }
        if( pickcolor == 'white' ) {
            pick.classList.add( 'white' );
        }
        pick.addEventListener('click', changecolor );
        pick.addEventListener('touchstart', changecolor );
    }
} //setColorControls
setColorControls();

var user = byId('use-picture');
if( user ) {
    user.addEventListener('click', ev => {
        ev.preventDefault();
        ev.stopPropagation();
        if( confirm( 'really use this picture' ) ) {
            var upper = byId('upper');
            var upform = byId('edform');
            upper.value = canvas.toDataURL('image/png');
            upform.submit();
        }
    } );
}

var saver = byId('save-picture');
if( saver ) {
    saver.addEventListener('click', ev => {
        ev.preventDefault();
        ev.stopPropagation();
        var upper = byId('upper-save');
        var upform = byId('saveform');
        upper.value = canvas.toDataURL('image/png');
        upform.submit();
    } );
}

if( window.initimage ) {
    var i = new Image();
    i.src = initimage;
    i.onload = function() {
        ctx.drawImage( i, 0, 0 );
    }
}

*/
