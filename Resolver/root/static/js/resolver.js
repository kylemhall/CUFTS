function toggleServicesLayer(layer_number) {
	layer = 'others' + layer_number;

	if (document.layers) {
		if (document.layers[layer].display == 'none') {
			document.layers[layer].display = '';
			toggleShowServicesLayer(layer_number, 1);
		} else {
			document.layers[layer].display = 'none';
			toggleShowServicesLayer(layer_number, 0);
		}
	}
	if (document.all) {
		if (document.all[layer].style.display == 'none') {
			document.all[layer].style.display = '';
			toggleShowServicesLayer(layer_number, 1);
		} else {
			document.all[layer].style.display = 'none';
			toggleShowServicesLayer(layer_number, 0);
		}
        }
	if (!document.all && document.getElementById) {
		if (document.getElementById(layer).style.display == 'none') {
			document.getElementById(layer).style.display = '';
			toggleShowServicesLayer(layer_number, 1);
		} else {
			document.getElementById(layer).style.display = 'none';
			toggleShowServicesLayer(layer_number, 0);
		}
	}
}

function toggleShowServicesLayer(layer_number, toggle) {
	layer = 'showhide' + layer_number;
	if (toggle == 1) {
		message = '(hide other services)';
	} else {
		message = '(show other services)';
	}
	writeLayer(layer, message);
}

function writeLayer(layer, s) {
	if (document.layers) {
		document.layers[layer].open();
		document.layers[layer].write(s);
		document.layers[layer].close();
	
	}
	if (document.all) {
		document.all[layer].innerHTML = s;
        }
	if (!document.all && document.getElementById) {
		document.getElementById(layer).innerHTML = s;
	}
}
