/*
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).
    
    This file is meant to be used by solawiTableEditor.
*/
function SolawiTableValidator(pSbs) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    		validateEditorInput: validateEditorInput,
    		setResponse: function(path, response) {responseCache = response;}
    };

    /* private vars */
    var sbs = pSbs;
    var responseCache;

/**** public ****/
    function validateEditorInput(data, id) {
    	lookupRowDataInResponseCacheForValidation(id, data);
    	
    	var result = validateEditorZusatzBestellung(data, id);
        if (result != null) {
        	return result;
        }
        /* else */
        result = validateEditorModulAbo(data, id);
        if (result != null) {
    		return result;
        }
        /* else */
        return validateEditorAnzahl(data['Anzahl'], 0, 9999);
    }
   

/**** private ****/

    function validateEditorAnzahl(anzahl, min, max, name) {
    	if (typeof anzahl != 'undefined' && ((! anzahl) || anzahl == 0)) {
            setContent('editError', 'Anzahl muss eingegeben werden!');
            return false;
        }
    	if (typeof anzahl != 'undefined' && (anzahl < min || anzahl > max)) {
            setContent('editError', 'Anzahl zu ' + (anzahl < min ? 'gering' : 'groß') + '. Min: ' + min + ' / Max: ' + max + (name ? ' möglich für ' + name : ' möglich.'));
            return false;
        }
        return true;
    }

    function validateEditorZusatzBestellung(data, id) {
    	if (data['Produkt_ID'] && sbs.tableCache['Produkt']) {
        	var min = 0;
        	var max = 9999;
            var row = sbs.tableCache['Produkt'][data['Produkt_ID']]
            if (row) {
                min = row.AnzahlBestellung * -1;
                max = row.AnzahlZusatzBestellungMax - row.AnzahlZusatzBestellung;
            }
        	return validateEditorAnzahl(data['Anzahl'], min, max, row ? row.Name : '');
        }
    	return null;
    }

    function validateEditorModulAbo(data, id) {
    	if (data['Modul_ID'] && sbs.tableCache['Modul']) {
	    	var min = 0;
	    	var max = 9999;
	        if (data['StartWoche'] > data['EndWoche']) {
	            setContent('editError', 'Start muss vor Ende sein.');
	            return false;
	        }
	        var row = sbs.tableCache['Modul'][data['Modul_ID']]
	        if (row) {
	        	if (row.WechselWochen && (((!id) && row.WechselWochen.indexOf(data['StartWoche'].substr(5)) < 0) || row.WechselWochen.indexOf(addWeek(data['EndWoche'], 1).substr(5)) < 0)) {
	                setContent('editError', 'Ungültige Start/EndWoche für ' + row.Name + ', erlaubte StartWochen: ' + row.WechselWochen + ', EndWoche jeweils eins weniger.' );
	                return false;
	        	}
	        	if (row.AnzahlProAnteil != 0 && responseCache) {
	        		max = row.AnzahlProAnteil * sbs.user.Anteile;
	        		for (var a = 0; a < responseCache.length; a++) {
	        			var abo = responseCache[a];
	        			if (abo['Modul_ID'] == data['Modul_ID'] && abo['StartWoche'] <= data['EndWoche'] && abo['EndWoche'] >= data['StartWoche'] && abo['Anzahl'] && ((!id) || abo['ID'] != id) ) {
	        				max -= abo['Anzahl'];
	        			}
	        		}
	        	}
	        }
	    	return validateEditorAnzahl(data['Anzahl'], min, max, row ? row.Name : '');
    	}
    	return null;
    }
    
    function lookupRowDataInResponseCacheForValidation(rowId, data) {
        /* if not all inputFields are displayed inside this editor (i.e. singleField editor for EndWoche), look up important values in the tableCache */
        if (rowId && responseCache && (!data['StartWoche']) && (!data['Modul_ID']) && !data['Anzahl']) {
        	var editRow = {};
        	for (var a = 0; a < responseCache.length; a++) {
        		if (responseCache[a] && responseCache[a]['ID'] == rowId) {
        			editRow = responseCache[a];
        		}
        	}
        	if (editRow['Modul_ID'] && editRow['StartWoche'] && editRow['Anzahl']) {
        		data['Modul_ID'] = editRow['Modul_ID'];
        		data['StartWoche'] = editRow['StartWoche'];
        		data['Anzahl'] = editRow['Anzahl'];
        	}
        }
    }

    return pub;
}
