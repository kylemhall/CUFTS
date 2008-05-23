// A mix of helpful utility functions and user extensions for ExtJS
// - Todd Holbrook

Ext.namespace( 'Ext.ux' );

Ext.ux.utils = {
    
    formSubmitFailure: function(form, action) {
        if ( action.result && !action.result.success ) {
            if ( action.result.errorMessage ) {
                Ext.MessageBox.alert( 'Error', action.result.errorMessage );
            }
            else if ( action.result.errors ) {
                Ext.MessageBox.alert('Error', 'There was an error with one or more fields.');
                form.markInvalid( action.result.errors );
            }
            else {
                Ext.MessageBox.alert('Error', 'Unknown form submission error.');
            }
        }
        else {
            Ext.ux.utils.ajaxServerFailure( action.response )
        }
    },

    ajaxCheckResponse: function(response) {
      response_json = Ext.decode(response.responseText);
      if ( !response_json.success ) {
          if ( response_json.errorMessage ) {
              Ext.MessageBox.alert( 'Error', response_json.errorMessage );
          }
          else {
              Ext.MessageBox.alert( 'Error', 'No errorMessage found.');
          }
          return false;
      }
      return true;
    },

    ajaxServerFailure: function(response) {
        Ext.MessageBox.alert(
            'Server Error',
            'There was an error communicating with the server:<br /><b>' 
            + response.statusText
            + '</b>'
        );

    },
    
    handleEmptyCombo: function( combo, record, index ) {
        var v = record.get('id');
        if ( v===undefined || v === null || v==='' ) {
            combo.clearValue();
        }
    }
    
};

