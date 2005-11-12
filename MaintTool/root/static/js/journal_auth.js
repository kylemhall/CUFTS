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