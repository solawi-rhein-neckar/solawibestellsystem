/*
 * Requires: solawiEditor, solawiValidator
 *
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    This file is meant to be used by solawiTable.
*/
function SolawiTableEditor(pSbs, pSolawiTable, pDisableUnavailableProducts) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    		enhanceDataCell: enhanceDataCell,
    		addColumnHeaders: addColumnHeaders,
    		addColumnCells: addColumnCells,
    		setResponse: function(pPath, pResponse) {if (solawiEditor) { solawiEditor.setResponse(pPath, pResponse); } }
    };

    /* private vars */
    var sbs = pSbs;
    var solawiTable = pSolawiTable;
    var disableUnavailableProducts = pDisableUnavailableProducts;
    var solawiEditor = SolawiEditor(sbs, solawiTable.onEntitySaved, disableUnavailableProducts);


/**** public ****/

    function addColumnHeaders(tr, keys) {
    	addCreateButton(tr.firstChild, keys);
    	if (keys) {
    		addDeleteButtonColumnHeader(tr);
    		addWeekSelectColumnHeader(tr);
    	}
    }

    function addColumnCells(tr, dataRow) {
    	addDeleteButtonCell(tr, dataRow);
    	addWeekSelectCell(tr, dataRow['ID']);
    }

    function enhanceDataCell(div, key) {
        /* if disableUnavailableProducts ist true, only certain columns are editable, else all columns (except audit metadata) are editable. */
        if ( ((! disableUnavailableProducts) || (key == 'Kommentar' && (solawiTable.getTableName() != 'BenutzerZusatzBestellung' || (div.innerText && div.innerText.trim() != '' && div.innerText.trim() != '-'))) || key == 'EndWoche') && key != 'ID' && key != 'AenderBenutzer_ID' && key != 'AenderZeitpunkt' && key != 'ErstellZeitpunkt') {
            div.addEventListener('click', showEditor);
            div.style.cursor = "pointer";
            if (disableUnavailableProducts) {
            	div.style['border-bottom'] = "1px dotted black";
            }
            div.title = "click to edit!";
        }
    }


    /**** private ****/

    function addDeleteButtonColumnHeader(tr) {
        var delTd = document.createElement("TD");
        delTd.innerText= 'löschen';
        tr.appendChild(delTd);
    }

    function addDeleteButtonCell(tr, dataRow) {
        var delTd = document.createElement("TD");
        if ((!disableUnavailableProducts) || ( (! (dataRow['StartWoche'] && dataRow['StartWoche'] < sbs.week) ) && (! (dataRow['Woche'] && (dataRow['Woche'] < addWeek(sbs.week, -1) || (sbs.week == sbs.AbgeschlosseneWoche && dataRow['Woche'] == sbs.AbgeschlosseneWoche) ) ) ) )) {
            var delBtn = document.createElement("BUTTON");
            delBtn.innerText='-';
          delBtn.className="btn_minus"
            delBtn.dataId = dataRow['ID'];
            delBtn.addEventListener('click', function(event) {
                if (confirm(solawiTable.getTableName() + "/" + event.target.dataId + ' wirklich löschen?')) {
                    deleteAjax(solawiTable.getTableName() + "/" + event.target.dataId, function(){solawiTable.reload();});
                }
            });
            delTd.appendChild(delBtn);
    	}
        tr.appendChild(delTd);
    }

    function addWeekSelectColumnHeader(tr) {
        if (solawiTable.getTableName() == 'ModulInhalt') {
            var wtd = document.createElement("TD");
            wtd.className='col_ModulInhaltWoche';
            wtd.innerText='Wochen';
            tr.appendChild(wtd);

        }
    }

    function addWeekSelectCell(tr, rowId) {
        if (solawiTable.getTableName() == 'ModulInhalt') {
            var td = document.createElement("TD");
            td.className='col_ModulInhaltWoche';
            tr.appendChild(td);
            var weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'ModulInhaltWoche/ModulInhalt_ID/' + rowId,
            weekSelect.postData = {ModulInhalt_ID: rowId, Woche: sbs.selectedWeek},
            weekSelect.addTo(td);
        }
    }

    function addCreateButton(td, keys) {
		td.innerText = '';
        var btn = document.createElement('BUTTON');
        td.appendChild(btn);
        var tableName = solawiTable.getTableName();
        btn.addEventListener('click', createFuncAddNew(	keys ? keys
        												: tableName == 'BenutzerZusatzBestellung' ? ['Benutzer_ID', 'Produkt_ID', 'Anzahl', 'Kommentar', 'Woche']
        											 	: tableName == 'ModulInhaltWoche' 	? ['ModulInhalt_ID']
        												: tableName == 'ModulInhalt' 		? ['Modul_ID', 'Produkt_ID']
        											 	: tableName == 'BenutzerModulAbo' 	? ['Benutzer_ID', 'Modul_ID', 'Anzahl', 'Kommentar', 'StartWoche', 'EndWoche']
        												: tableName == 'BenutzerUrlaub' 	? ['Benutzer_ID', 'Woche']
        											 	: ['Name']));
        btn.innerText = tableName == 'BenutzerZusatzBestellung' ? 'Tauschen' : '+';
        btn.className='btn_plus'
        if ( disableUnavailableProducts && tableName == 'BenutzerZusatzBestellung' && (sbs.selectedWeek < sbs.week ||  sbs.selectedWeek == sbs.AbgeschlosseneWoche) ) {
    		btn.disabled='disabled';
        }
    }
    
    function showEditor(event) {
    	solawiEditor.showEditorForCell(solawiTable.getTableName(), event);
    }

    function createFuncAddNew(keys) {
        return function(event) {
        	event.stopPropagation();
        	solawiEditor.showForAdding(solawiTable.getTableName(), keys, solawiTable.editorDefault)
        }
    }

    return pub;
}
