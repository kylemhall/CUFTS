function add_input_line (field_type) {
	var newHTML;
	var row = window['marc_field_max'][field_type];
	var div_class;
	if (row == -1) {
		div_class = 1;
	} else {
		div_class = row % 2;
	}
	row += 1;

	var div = document.getElementById('journal-auth-' + field_type);

	// Get the div object to append HTML to

	newHTML = '<div class="row' + div_class + '"> ';

	// Add indicators

	newHTML += '<input style="width: 1.1em;" type="text" name="' + row + '-' + field_type + '-1" value="" size="1" maxlength="1" /> ';
	newHTML += '<input style="width: 1.1em;" type="text" name="' + row + '-' + field_type + '-2" value="" size="1" maxlength="1" /> ';

	// Add subfields

	var i;
	for (i = 0; i < window['marc_field_config'][field_type]['subfields'].length; i++) {
		var subfield = window['marc_field_config'][field_type]['subfields'][i];
		var size = window['marc_field_config'][field_type]['size'][i];

		newHTML += subfield + ' ';
		newHTML += '<input type="text" name="' + row + '-' + field_type + subfield + '" value="" size="' + size + '" /> ';
	}

	newHTML += ' <input type="hidden" name="' + row + '-' + field_type + '-exists" value="1" /> ';
	newHTML += ' <input style="background: #D0DEED; margin-left: 10px;" type="submit" name="clear" value="clear" onClick="return clear_field(\'' + row + '\', \'' + field_type + '\', \'journal_auth\');" />';

	newHTML = newHTML + '</div>';

	div.innerHTML = div.innerHTML + newHTML;

	window['marc_field_max'][field_type] += 1;
	return false;
}

function clear_field (field_index, field_type, form_name) {
	if (!confirm("Clear field?")) {
		return false;
	}

	var search_string = field_index + '-' + field_type;

	var i;
	for (i = 0; i < document.forms[form_name].elements.length; i++) {
		var name = document.forms[form_name].elements[i].name;
		if (name.indexOf(search_string) == 0 && name.indexOf('exists') == -1) {
			document.forms[form_name].elements[i].value='';
		}
	}			

	return false;
}


function add_edit_line (field_type) {
	var newHTML;
	var row = window['field_max'][field_type];
	var div_class;
	if (row == -1) {
		div_class = 1;
	} else {
		div_class = (row + 1) % 2;
	}

	// Get the div object to append HTML to
	var div = document.getElementById('journal-auth-edit-' + field_type);
    newHTML = '<div class="row' + div_class + '"> ';

	if (field_type == 'issns'){
        newHTML = newHTML + '<input type="text" size="10" maxlength="9" name="new' + row + '_issn" value="" /> ';
        newHTML = newHTML + '<input type="text" size="30" maxlength="512" name="new' + row + '_info" value="" />';
	}
    if (field_type == 'titles') {
        newHTML = newHTML + '<input type="text" size="40" maxlength="1024" name="new' + row + '_title" value="" /> ';
        newHTML = newHTML + '<input type="text" size="4" maxlength="3" name="new' + row + '_count" value="" />';
	}

    newHTML = newHTML + '</div>';
	div.innerHTML = div.innerHTML + newHTML;

	window['field_max'][field_type] += 1;

	return false;
}

function show_edit_line (field_type) {
    var row    = window['field_max'][field_type] + 1;
    var div_id = 'new' + row + '_' + field_type;
	var div    = document.getElementById(div_id);
	
	if (! div) {
	    alert('Unable to show new ' + field_type + ' field.  Please save this record and try editting again.');
	    return false;
	}
	
	div.style.display = '';

	window['field_max'][field_type] = row;

	return false;
}



