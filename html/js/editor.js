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
canvas.addEventListener('touchend', drawEnd );

