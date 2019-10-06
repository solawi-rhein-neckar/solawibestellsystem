/*
 * Requires: solawiTableValidator
 * 
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).
    
    This file is meant to be used by solawiTable.
*/
function SolawiTableEditor(pSbs, pSolawiTable, pEditable, pDisableUnavailableProducts) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    		addDeleteButtonColumnHeader: addDeleteButtonColumnHeader,
    		addDeleteButtonCell: addDeleteButtonCell,
    		addWeekSelectColumnHeader: addWeekSelectColumnHeader,
    		addWeekSelectCell: addWeekSelectCell,
    		addCreateButton: addCreateButton,
    		showEditor: showEditor,
    		setResponse: function(pPath, pResponse) {if (disableUnavailableProducts) { tableValidator.setResponse(pPath, pResponse); } }
    };

    /* private vars */
    var sbs = pSbs;
    var solawiTable = pSolawiTable;
    var editable = pEditable;
    var disableUnavailableProducts = pDisableUnavailableProducts;
    var tableValidator = SolawiTableValidator(sbs);

    const numberColumnNames = {
            'Menge':1
            ,'Anzahl':1
            ,'AnzahlModul':1
            ,'AnzahlZusatz':1
            ,'AnzahlZusatzBestellungMax':1
            ,'MindestAnzahl':1
            ,'MaximalAnzahl':1
            ,'Anteile':1
            ,'Punkte':1
            ,'Menge':0.01
        }

/**** public ****/
    function addDeleteButtonColumnHeader(tr) {
        if (editable) {
            var delTd = document.createElement("TD");
            delTd.innerText= 'löschen';
            tr.appendChild(delTd);
        }
    }
    
    function addDeleteButtonCell(tr, dataRow) {
        if (editable) {
            var delTd = document.createElement("TD");
            if ((!disableUnavailableProducts) || ( (! (dataRow['StartWoche'] && dataRow['StartWoche'] < sbs.week) ) && (! (dataRow['Woche'] && dataRow['Woche'] < addWeek(sbs.week, -1) ) ) )) {
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
        btn.innerText = tableName == 'BenutzerZusatzBestellung' ? 'Änderung' : '+';
        btn.className='btn_plus'
        if ( disableUnavailableProducts && tableName == 'BenutzerZusatzBestellung' && sbs.selectedWeek < sbs.week ) {
    		btn.disabled='disabled';
        }
    }

    function showEditor(event) {
        var edit = resetEditor("ID " + event.target.dataId + ": " + event.target.dataKey + " ");

        var inp = createInput(event.target.dataKey);
        inp.dataId = event.target.dataId;
        inp.value = event.target.dataValue || event.target.innerText;
        inp.addEventListener('keypress', saveEditorInputs);
        /*inp.addEventListener('change', saveEditorInputs);*/

        edit.appendChild(inp);
        finishEditor(edit);
    }

    
/**** private ****/   
    
    function createFuncAddNew(keys) {
        return function() {
            var edit = resetEditor("Add new " + solawiTable.getTableName());
            for (var j = 0; j < keys.length; j++) {
                if (keys[j] != 'ID' && keys[j] != 'ErstellZeitpunkt' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && (/*generated column Produkt.Name*/ solawiTable.getTableName() != 'Produkt' || keys[j] != 'Name')) {

                    var inp = createInput(keys[j]);

                    if (keys[j] == 'Benutzer_ID') {
                        inp.value = sbs.user.ID;
                    } else if (keys[j] == 'Woche' && sbs.selectedWeek) {
                        inp.value = sbs.selectedWeek;
                    }
                    edit.appendChild(inp);
                }
            }
            finishEditor(edit);
        }
    }    
    
    function createInput(key) {
        var inp;

        /* foreign key lookup in sbs.tableCache */
        var relation = key.match(/^(?:Besteller|Verwalter)?(.*)_ID$/);
        if (relation && sbs.tableCache[relation[1]]) {
        	inp = createInputSelect(sbs.tableCache[relation[1]]);
        } else if (key.match(/^(Start|End|Punkte)?Woche$/)) {
        	inp = createInputDateSelect();
        } else {
            inp = document.createElement("INPUT");
            if (numberColumnNames[key] ||  key.match(/^(.*)_ID$/)) {
                inp.type="number";
                inp.step=numberColumnNames[key] || 1;
                inp.min=key.match(/^(.*)_ID$/) ? "0" : "-10";
                inp.max=key.match(/^(.*)_ID$/) ? "99999" : "999";
            } else if (key.match(/^(Start|End|Punkte)?Woche$/)) {
            	inp.pattern="^(2019|2020|2021|2022|9999)[.](0[1-9]|[1-4][0-9]|5[0-3])$"
            }
        }
        inp.className = 'editor inp_' + key;
        inp.dataKey = key;
        inp.placeholder = key;
        return inp;
    }
    
    function createInputSelect(response) {
        inp = document.createElement("SELECT");
        for (var k=0; k<response.length; k++) {
            var row = response[k];
            if (row && row.ID) {
                var opt = document.createElement("OPTION");
                opt.value=row.ID;
                opt.innerText=row.Name;
                if (disableUnavailableProducts && (row.AnzahlZusatzBestellungMax < 0 || (row.AnzahlZusatzBestellung > 0 && row.AnzahlZusatzBestellungMax <= row.AnzahlZusatzBestellung) || (row.AnzahlZusatzBestellungMax == 0 && row.AnzahlBestellung <= 0) )) {

                    opt.disabled='disabled';
                    if (row.AnzahlZusatzBestellungMax <= 0) {
                        opt.innerText+=' (nur abo)';
                    } else {
                        opt.innerText+=' (max. ' + row.AnzahlZusatzBestellungMax + ')';
                    }
                    opt.title='Maximale Zusatz-Bestellmenge überschritten!';
                }
                inp.appendChild(opt);
            }
        }
        return inp;
    }
    
    function createInputDateSelect() {
        inp = document.createElement("SELECT");
        for (var year=2019; year<=(new Date().getFullYear()) + 3; year++) {
            for (var month=1; month<=weekCount(year); month++) {
                var opt = document.createElement("OPTION");
                opt.value=year + (month < 10 ? '.0' : '.') + month;
                opt.innerText=opt.value;
                if ((!disableUnavailableProducts) || opt.value >= sbs.week) {
                	inp.appendChild(opt);
                }
            }
        }
        var opt = document.createElement("OPTION");
        opt.value='9999.99';
        opt.innerText=opt.value;
        inp.appendChild(opt);
        return inp;
    }

    function resetEditor(label) {
        var edit = document.getElementById('editor');
        var label = document.createElement("SPAN");
        edit.className = 'edit' + solawiTable.getTableName();
        label.innerText = label;
        edit.appendChild(label);
        while (edit.firstChild) edit.removeChild(edit.firstChild);
        setContent('editError', '');
        show('blockui_edit');
        return edit;
    }

    function finishEditor(edit) {
        var btn = document.createElement("BUTTON");
        btn.innerText="Save";
        btn.style['margin-left'] = '5px';
        btn.style['margin-right'] = '10px';
        btn.addEventListener('click', saveEditorInputs);

        var btn2 = document.createElement("BUTTON");
        btn2.innerText="Cancel";
        btn2.addEventListener('click', function(){hide('blockui_edit');});
        edit.appendChild(btn);
        edit.appendChild(btn2);
    }

    function saveEditorInputs(event2) {
        if (event2.keyCode == null /*blur*/ || event2.keyCode == 13 /*enter*/) {
            event2.target.disabled='disabled';

            var id;
            var data = {};
            var sendData = {};
            var editor = document.getElementById('editor');
            for (var i = 0; i < editor.children.length; i++) {
                var inpEle = editor.children[i];
                if (inpEle.tagName == 'INPUT' || inpEle.tagName == 'SELECT') {
                    data[inpEle.dataKey] = inpEle.value;
                    sendData[inpEle.dataKey] = inpEle.value;
                    id = id || inpEle.dataId;
                }
            }

            if (disableUnavailableProducts &&   ! tableValidator.validateEditorInput(data, id) ) {
                event2.target.disabled='';
            } else {
            	postAjax(solawiTable.getTableName() + (id ? '/'+id : ''), sendData, function(){solawiTable.reload();});
	            hide('blockui_edit');
            }
        }
    }

    return pub;
}
