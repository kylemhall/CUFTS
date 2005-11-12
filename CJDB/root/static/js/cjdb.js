function imageSwap(image, image1, image2) {
	var currentSrc = document[image].src;
	imgregex = new RegExp(image1 + '$')	

	if (currentSrc.match(imgregex) == image1) {
		document[image].src = image2;
	} else {
		document[image].src = image1;
	}

	return false;
}


function showDiv(show, hide, field, displayStyle) {
    if (!document.getElementById) return true;

    var show_obj;
    if (show) {
        var show_obj = document.getElementById(show);
	if (!show_obj) return true;

    }

    var hide_obj;
    if (hide) {
        var hide_obj = document.getElementById(hide);
	if (!hide_obj) return true;

    }

    var field_obj;
    if (field) {
        var field_obj = document.getElementById(field);
	if (!field_obj) return true;

    }

    if (hide_obj)  hide_obj.style.display = 'none';
    if (show_obj)  show_obj.style.display = displayStyle || 'block';
    if (field_obj) field_obj.focus();

    return false;
}


function showTagManageDivs() {
	var sd1 = showDiv('manage-tags','show-manage-tags');
	var sd2 = showDiv(undefined, 'my-tags-group');

	// Why Javascript wont let me && the above to calls directly is beyond me.

	return(sd1 && sd2);
}



function simpleHideClick(contentlayer, hiddenclass, visibleclass, imagelayer, hiddenimage, visibleimage) {
	classSwap(contentlayer, hiddenclass, visibleclass);

	if (imagelayer && hiddenimage && visibleimage) {
		imageSwap(imagelayer, hiddenimage, visibleimage);
	}

	return false;
}


function classSwap(layer, class1, class2) {
	if (document.layers) {   // NS4x?
		if (document.layers[layer]) {
			if (document.layers[layer].className == class1) {
				document.layers[layer].className = class2;
			} else {
				document.layers[layer].className = class1;
			}
		}
	} else if (document.all) {   // IE
		if (document.all[layer]) {
			if (document.all[layer].className == class1) {
				document.all[layer].className = class2;
			} else {
				document.all[layer].className = class1;
			}
		}
	} else if (document.getElementById) {  // Mozilla, Safari, etc.
		if (document.getElementById(layer)) {
			if (document.getElementById(layer).className == class1) {
				document.getElementById(layer).className = class2;
			} else {
				document.getElementById(layer).className = class1;
			}
		} 
	}

	return false;
}
