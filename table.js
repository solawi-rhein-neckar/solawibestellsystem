/*
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    Its expected to create max. 1 instance!

    var SBS = SolawiBestellSytem();  // no need to use 'new' or Object.create!
*/
function SolawiBestellSystem() {
   const pub = {
        fillCache: fillCache,
        saveOrdersIntoProductCache: saveOrdersIntoProductCache
    };
    /* public fields */
    pub.date = new Date();
    pub.day = 4;
    pub.week = pub.date.getWeekYear() + "." +  (pub.date.getDay() == 0 || pub.date.getDay() > pub.day ? pub.date.getWeek() + 1 : pub.date.getWeek());
    pub.selectedWeek = pub.week;
    pub.disableUnavailableProducts = 0;
    pub.user = null;

    /* private constants */
    const tableCache = {'Modul':[],'Role':[],'Depot':[],'Produkt':[]};
    pub.tableCache = tableCache;

    /* public */
    function fillCache(tableName) {
        getAjax(tableName, function(resp) {
            tableCache[tableName] = [];
            // convert response (array) into hash (by ID)
            for(var i = 0; i < resp.length; i++) {
                tableCache[tableName][resp[i]['ID']] = resp[i];
            }
        });
    }

    function saveOrdersIntoProductCache(response) {
        //save ZusatzBestellCount into ProductCache, so it can be reused for Validation!
        if (tableCache['Produkt']) {
            // first reset for all products. Because response will not contain orders for products that are NOT ordered
            for (var i = 0; i < tableCache['Produkt'].length; i++) {
                if (tableCache['Produkt'][i]) {
                    tableCache['Produkt'][i]['AnzahlZusatzBestellung'] = 0;
                    tableCache['Produkt'][i]['AnzahlBestellung'] = 0;
                }
            }
        }
        for (var i = 0; i<response.length; i++) {
            var row = response[i];
            if (tableCache['Produkt'] && row.Produkt_ID && tableCache['Produkt'][row.Produkt_ID]) {
                tableCache['Produkt'][row.Produkt_ID]['AnzahlZusatzBestellung'] = row.AnzahlZusatz;
                tableCache['Produkt'][row.Produkt_ID]['AnzahlBestellung'] = row.Anzahl;
            }
        }
    }

    return pub;
}

/*
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    Its expected to create max. 1 or 2 instances - in this case use:

    var SBTedit= SolawiTable(SBS, 'tableHtmlId', 'tablePathHtmlId', true);  // no need to use 'new' or Object.create!

    If you have dependent table that should also be reloaded whenever the editable table changes:

    var SBTview = SolawiTable(SBS, 'viewRableHtmlId', 'viewTablePathHtmlId', false);
    var reloadEdit = SBTedit.reload;
    SBTedit.reload = function() {SBTview.reload(); reloadEdit();}

    You have to provide the global SolawiBestellSytem (SBS) as first parameter!

    No need to recreate the instance at anytime, to display another table just call SBT.showTable once again with another response.
    You will only need multiple instances to display multiple tables at the same time.
*/
function SolawiTable(pSbs, pElemIdTable, pElemIdLabel, pEditable, pDisableUnavailableProducts) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
        showTable: showTable,
        getTableName: function(){return tableName},
        getTablePath: function(){return tablePath},
        reload: function(){getAjax(tablePath, showTable)},
        reset: function(){clearContent(elemIdTable);clearContent(elemIdLabel);tableName='';tablePath='';}
    };

    /* private vars */
    var sbs = pSbs;
    var elemIdTable = pElemIdTable;
    var elemIdLabel = pElemIdLabel;
    var editable = pEditable;
    var tableName;
    var tablePath;
    var disableUnavailableProducts = pDisableUnavailableProducts
    var responseCache;

    /* private constants */
    const columnOrder = ['ID'
        ,'KurzName'
        ,'Name'
        ,'ModulInhalt_ID'
        ,'Woche'
        ,'Benutzer_ID'
        ,'Benutzer'
        ,'Depot_ID'
        ,'Depot'
        ,'Modul'
        ,'Modul_ID'
        ,'Produkt_ID'
        ,'Produkt'
        ,'Menge'
        ,'Einheit'
        ,'Anzahl'
        ,'AnzahlModul'
        ,'AnzahlZusatz'
        ,'Urlaub'
        ,'MindestAnzahl'
        ,'MaximalAnzahl'
        ,'Beschreibung'
        ,'Sorte'
        ,'Anteile'
        ,'StartWoche'
        ,'EndWoche'

        ,'Punkte'
        ,'PunkteStand'
        ,'PunkteWoche'
        ,'Role'
        ,'Role_ID'
        ,'StellvertreterBenutzer_ID'
        ,'VerantwortlicherBenutzer_ID'
        ,'Tabelle'
        ,'Spalte'
        ,'SpalteBenutzerID'
        ,'LeseAlle'
        ,'LeseEigene'
        ,'LeseRechtDefault'
        ,'SchreibeAlle'
        ,'SchreibeEigene'
        ,'SchreibRechtDefault'
        ,'Cookie'
        ,'Passwort'
        ,'AnzahlZusatzBestellungMax'
        ,'ErstellZeitpunkt'
        ,'AenderZeitpunkt'
        ,'AenderBenutzer_ID'
        ];

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

    const columnWeight = {};

    /* public */
    function showTable(response, path) {
        if (path.match(/^BenutzerBestellView.*$/) && disableUnavailableProducts) {
            sbs.saveOrdersIntoProductCache(response);
        }
        responseCache = response;

        var table = document.getElementById(elemIdTable);
        table.innerHTML = '';
        tablePath = path;
        tableName = path.match(/[^\/]*/)[0];
        setContent(elemIdLabel, tablePath);
        table.className = tableName;
        var keys = null;
        if (response.length == 0 && editable) {
            var tr = document.createElement("TR");
            var td = document.createElement("TD");
            table.appendChild(tr);
            tr.appendChild(td);
            var btn = document.createElement('BUTTON');
            td.appendChild(btn);

            btn.addEventListener('click', createFuncAddNew(	tableName == 'BenutzerZusatzBestellung' ? ['Benutzer_ID', 'Produkt_ID', 'Anzahl', 'Woche'] 
            											 	: tableName == 'ModulInhaltWoche' 	? ['ModulInhalt_ID'] 
            												: tableName == 'ModulInhalt' 		? ['Modul_ID', 'Produkt_ID'] 
            											 	: tableName == 'BenutzerModulAbo' 	? ['Benutzer_ID', 'Modul_ID', 'Anzahl', 'Sorte', 'StartWoche', 'EndWoche'] 
            												: tableName == 'BenutzerUrlaub' 	? ['Benutzer_ID', 'Woche'] 
            											 	: ['Name']));
            btn.innerText = tableName == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
            if ( disableUnavailableProducts && tableName == 'BenutzerZusatzBestellung' && sbs.selectedWeek < sbs.week ) {
        		btn.disabled='disabled';
            }
        }
        for (var i = 0; i < response.length; i++) {
            if(!keys) {
                keys = Object.keys(response[i]).sort(columnSortFunc);

                var tr = document.createElement("TR");
                table.appendChild(tr);
                for (var j = 0; j < keys.length; j++) {
                    var td = document.createElement("TD");
                    td.className='col_'+keys[j];
                    tr.appendChild(td);
                    if (j == 0 && editable) {
                        var btn = document.createElement('BUTTON');
                        btn.addEventListener('click', createFuncAddNew(keys));
                        btn.innerText = tableName == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
                        if ( disableUnavailableProducts && tableName == 'BenutzerZusatzBestellung' && sbs.selectedWeek < sbs.week ) {
                    		btn.disabled='disabled';
                        }
                        td.appendChild(btn);
                    } else if (keys[j].match(/^[0-9][0-9][.].*/) ) {
                        td.innerText = keys[j].substr(3);
                    } else {
                        td.innerText = keys[j];
                    }
                }
                if (tableName == 'ModulInhalt') {
                    var wtd = document.createElement("TD");
                    wtd.className='col_ModulInhaltWoche';
                    wtd.innerText='Wochen';
                    tr.appendChild(wtd);

                }
                if (editable) {
                    var delTd = document.createElement("TD");
                    delTd.innerText= 'löschen';
                    tr.appendChild(delTd);
                }
            }

            for (var j = 0; j < keys.length; j++) {
                var tr = document.createElement("TR");
                table.appendChild(tr);
                for (var j = 0; j < keys.length; j++) {
                    var td = document.createElement("TD");
                    td.className='col_'+keys[j];
                    tr.appendChild(td);

                    var div = document.createElement("DIV");
                    div.id = "span_" + path + "_" + i + "_" + j;
                    div.innerText = response[i][keys[j]] === undefined || response[i][keys[j]] === null || response[i][keys[j]] === '' ? '-' : response[i][keys[j]];
                    var relation = keys[j].match(/^(?:Verantwortlicher|Stellvertreter)?(.*)_ID$/);
                    if (relation && sbs.tableCache[relation[1]]) {
                        var row = sbs.tableCache[relation[1]][div.innerText];
                        div.dataValue = div.innerText;
                        div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
                    }
                    if ( ((! disableUnavailableProducts) || keys[j] == 'Sorte' || keys[j] == 'EndWoche') && editable && keys[j] != 'ID' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && keys[j] != 'ErstellZeitpunkt') {
                        div.addEventListener('click', showEditor);
                        div.style.cursor = "pointer";
                        if (disableUnavailableProducts) {
                        	div.style['border-bottom'] = "1px dotted black";
                        }
                        div.title = "click to edit!";
                    }
                    div.dataId = response[i]["ID"];
                    div.dataKey = keys[j];

                    td.appendChild(div);
                }
                if (tableName == 'ModulInhalt') {
                    var td = document.createElement("TD");
                    td.className='col_ModulInhaltWoche';
                    tr.appendChild(td);
                    var weekSelect = Object.create(WeekSelect);
                    weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
                    weekSelect.tableName = 'ModulInhaltWoche/ModulInhalt_ID/' + response[i]["ID"],
                    weekSelect.postData = {ModulInhalt_ID: response[i]["ID"], Woche: sbs.selectedWeek},
                    weekSelect.addTo(td);
                }
                if (editable) {
                    var delTd = document.createElement("TD");
                    if ((!disableUnavailableProducts) || ( (! (response[i]['StartWoche'] && response[i]['StartWoche'] < sbs.week) ) && (! (response[i]['Woche'] && response[i]['Woche'] < addWeek(sbs.week, -1) ) ) )) {
	                    var delBtn = document.createElement("BUTTON");
	                    delBtn.innerText='entf.';
	                    delBtn.dataId = response[i]["ID"];
	                    delBtn.addEventListener('click', function(event) {
	                        if (confirm(tableName + "/" + event.target.dataId + ' wirklich löschen?')) {
	                            deleteAjax(tableName + "/" + event.target.dataId, function(){pub.reload();});
	                        }
	                    });
	                    delTd.appendChild(delBtn);
                	}
                    tr.appendChild(delTd);
                }
            }
        }
    }

    function createFuncAddNew(keys) {
        return function() {
            var edit = resetEditor("Add new " + tableName);
            for (var j = 0; j < keys.length; j++) {
                if (keys[j] != 'ID' && keys[j] != 'ErstellZeitpunkt' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && (/*generated column Produkt.Name*/ tableName != 'Produkt' || keys[j] != 'Name')) {

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
        var relation = key.match(/^(?:Verantwortlicher|Stellvertreter)?(.*)_ID$/);
        if (relation && sbs.tableCache[relation[1]]) {
            inp = document.createElement("SELECT");
            for (var k=0; k<sbs.tableCache[relation[1]].length; k++) {
                var row = sbs.tableCache[relation[1]][k];
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
        } else if (key.match(/^(Start|End)?Woche$/)) {
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
        } else {
            inp = document.createElement("INPUT");
            if (numberColumnNames[key] ||  key.match(/^(.*)_ID$/)) {
                inp.type="number";
                inp.step=numberColumnNames[key] || 1;
                inp.min=key.match(/^(.*)_ID$/) ? "0" : "-10";
                inp.max=key.match(/^(.*)_ID$/) ? "99999" : "999";
            } else if (key.match(/^(Start|End)?Woche$/)) {
            	inp.pattern="^(2019|2020|2021|2022|9999)[.](0[1-9]|[1-4][0-9]|5[0-3])$"
            }
        }
        inp.className = 'editor inp_' + key;
        inp.dataKey = key;
        inp.placeholder = key;
        return inp;
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

    function resetEditor(label) {
        var edit = document.getElementById('editor');
        var label = document.createElement("SPAN");
        edit.className = 'edit' + tableName;
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
                    if (disableUnavailableProducts && inpEle.dataId && responseCache && (!data['StartWoche']) && (!data['Modul_ID']) && !data['Anzahl']) {
                    	var editRow = {};
                    	for (var a = 0; a < responseCache.length; a++) {
                    		if (responseCache[a] && responseCache[a]['ID'] == inpEle.dataId) {
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
            }

            if (disableUnavailableProducts) {
                if (typeof data['Anzahl'] != 'undefined' && ((! data['Anzahl']) || data['Anzahl'] == 0)) {
                    setContent('editError', 'Anzahl muss eingegeben werden!');
                    event2.target.disabled='';
                    return;
                }
            	var min = 0;
            	var max = 9999;
                if (data['Produkt_ID'] && sbs.tableCache['Produkt']) {
	                var row = sbs.tableCache['Produkt'][data['Produkt_ID']]
	                if (row) {
	                    min = row.AnzahlBestellung * -1;
	                    max = row.AnzahlZusatzBestellungMax - row.AnzahlZusatzBestellung;
	                }
                } else if (data['Modul_ID'] && sbs.tableCache['Modul']) {
                    if (data['StartWoche'] > data['EndWoche']) {
                        setContent('editError', 'Start muss vor Ende sein.');
                        event2.target.disabled='';
                        return;
                    }
                    var row = sbs.tableCache['Modul'][data['Modul_ID']]
	                if (row) {
	                	if (row.WechselWochen && (((!id) && row.WechselWochen.indexOf(data['StartWoche'].substr(5)) < 0) || row.WechselWochen.indexOf(addWeek(data['EndWoche'], 1).substr(5)) < 0)) {
	                        setContent('editError', 'Ungültige Start/EndWoche für ' + row.Name + ', erlaubte StartWochen: ' + row.WechselWochen + ', EndWoche jeweils eins weniger.' );
	                        event2.target.disabled='';
	                        return;
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
                }
                if (typeof data['Anzahl'] != 'undefined' && (data['Anzahl'] < min || data['Anzahl'] > max)) {
                    setContent('editError', 'Anzahl zu ' + (data['Anzahl'] < min ? 'gering' : 'groß') + '. Min: ' + min + ' / Max: ' + max + ' möglich für ' + row.Name);
                    event2.target.disabled='';
                    return;
                }
            }


            postAjax(tableName + (id ? '/'+id : ''), sendData, function(){pub.reload();});
            hide('blockui_edit');
        }
    }

    function columnSortFunc(a,b){return columnWeight[a] && columnWeight[b] ? columnWeight[a] - columnWeight[b] : columnWeight[a] ? -1 : columnWeight[b] ? 1 : a>b ? 1 : a<b ? -1 : 0}

    function initColumnWeight() {
        for (var i = 0; i < columnOrder.length; i++) {
            columnWeight[columnOrder[i]] = i+1;
        }
    }

    initColumnWeight();
    return pub;
}