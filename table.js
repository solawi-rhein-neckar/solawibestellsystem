/*
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    Its expected that you have exactly ONE instance of the SolawiBestellSystem. We do not use 'this' anywhere.
    Assign your single instance ONCE like this (you can use whatever name you like instead SBS):

    var SBS = SolawiBestellSystem();  // no need to use 'new' or Object.create!
*/
function SolawiBestellSystem() {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
        fillCache: fillCache,
        showTableEditor: showTableEditor,
        showTable: showTable,
        getEditTable: function(){return editTable},
        getEditTablePath: function(){return editTablePath},
        getViewTable: function(){return viewTable},
        getViewTablePath: function(){return viewTablePath},
        reset: function(){clearContent('table');clearContent('tablePath');clearContent('tableEdit');clearContent('tableEditPath');editTable='';editTablePath='';viewTable='';viewTablePath='';}
    };
    /* public fields */
    pub.date = new Date();
    pub.day = 4;
    pub.week = pub.date.getWeekYear() + "." +  (pub.date.getDay() == 0 || pub.date.getDay() > pub.day ? pub.date.getWeek() + 1 : pub.date.getWeek());
    pub.selectedWeek = pub.week;
    pub.disableUnavailableProducts = 0;
    pub.user = null;

    /* private vars */
    var editTable;
    var editTablePath;
    var viewTable;
    var viewTablePath;

    /* private constants */
    const tableCache = {'Korb':[],'Role':[],'Depot':[],'Produkt':[]};
    const columnOrder = ['ID'
        ,'KurzName'
        ,'Name'
        ,'KorbInhalt_ID'
        ,'Woche'
        ,'Benutzer_ID'
        ,'Benutzer'
        ,'Depot_ID'
        ,'Depot'
        ,'Produkt_ID'
        ,'Produkt'
        ,'Menge'
        ,'Einheit'
        ,'Anzahl'
        ,'AnzahlKorb'
        ,'AnzahlZusatz'
        ,'Urlaub'
        ,'MindestAnzahl'
        ,'MaximalAnzahl'
        ,'Beschreibung'
        ,'Sorte'
        ,'Anteile'
        ,'StartWoche'
        ,'EndWoche'
        ,'Korb'
        ,'Korb_ID'
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
        ,'AnzahlKorb':1
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
    function fillCache(tableName) {
        getAjax(tableName, function(resp) {
            tableCache[tableName] = [];
            for(var i = 0; i < resp.length; i++) {
                tableCache[tableName][resp[i]['ID']] = resp[i];
            }
        });
    }

    /* public */
    function showTableEditor(response, path) {
        showTable(response, path, true);
    }

    /* public */
    function showTable(response, path, editable) {
        if (path.match(/^BenutzerBestellView.*$/) && pub.disableUnavailableProducts) {
            //save ZusatzBestellCount into ProductCache, so it can be reused for Validation!
            if (tableCache['Produkt']) {
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

        var table = document.getElementById(editable ? 'tableEdit' : 'table');
        table.innerHTML = '';
        if (editable) {
            editTablePath = path;
            editTable = path.match(/[^\/]*/)[0];
            setContent('tableEditPath', editTablePath);
            table.className = editTable;
        } else {
            viewTablePath = path;
            viewTable = path.match(/[^\/]*/)[0];
            setContent('tablePath', viewTablePath);
            table.className = viewTable;
        }
        var keys = null;
        if (response.length == 0 && editable) {
            var tr = document.createElement("TR");
            var td = document.createElement("TD");
            table.appendChild(tr);
            tr.appendChild(td);
            var btn = document.createElement('BUTTON');
            td.appendChild(btn);

            btn.addEventListener('click', createFuncAddNew(editTable == 'BenutzerZusatzBestellung' ? ['Benutzer_ID', 'Produkt_ID', 'Anzahl', 'Woche'] : editTable == 'KorbInhaltWoche' ? ['KorbInhalt_ID'] : editTable == 'KorbInhalt' ? ['Korb_ID', 'Produkt_ID'] : ['Name']));
            btn.innerText = editTable == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
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
                        btn.innerText = editTable == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
                        td.appendChild(btn);
                    } else {
                        td.innerText = keys[j];
                    }
                }
                if (editTable == 'KorbInhalt') {
                    var wtd = document.createElement("TD");
                    wtd.className='col_KorbInhaltWoche';
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
                    div.innerText = response[i][keys[j]] === undefined || response[i][keys[j]] === null ? '-' : response[i][keys[j]];
                    var relation = keys[j].match(/^(.*)_ID$/);
                    if (relation && tableCache[relation[1]]) {
                        var row = tableCache[relation[1]][div.innerText];
                        div.dataValue = div.innerText;
                        div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
                    }
                    if ((! pub.disableUnavailableProducts) && editable && keys[j] != 'ID' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && keys[j] != 'ErstellZeitpunkt') {
                        div.addEventListener('click', showEditor);
                        div.style.cursor = "pointer";
                        div.title = "click to edit!";
                    }
                    div.dataId = response[i]["ID"];
                    div.dataKey = keys[j];

                    td.appendChild(div);
                }
                if (editTable == 'KorbInhalt') {
                    var td = document.createElement("TD");
                    td.className='col_KorbInhaltWoche';
                    tr.appendChild(td);
                    var weekSelect = Object.create(WeekSelect);
                    weekSelect.year = Number(pub.selectedWeek.match(/[0-9]+/)[0]);
                    weekSelect.tableName = 'KorbInhaltWoche/KorbInhalt_ID/' + response[i]["ID"],
                    weekSelect.postData = {KorbInhalt_ID: response[i]["ID"], Woche: pub.selectedWeek},
                    weekSelect.addTo(td);
                }
                if (editable) {
                    var delTd = document.createElement("TD");
                    var delBtn = document.createElement("BUTTON");
                    delBtn.innerText='entf.';
                    delBtn.dataId = response[i]["ID"];
                    delBtn.addEventListener('click', function(event) {
                        if (confirm(editTable + "/" + event.target.dataId + ' wirklich löschen?')) {
                            deleteAjax(editTable + "/" + event.target.dataId, function(){getAjax(editTablePath, showTableEditor);if (viewTablePath)getAjax(viewTablePath, showTable);});
                        }
                    });
                    delTd.appendChild(delBtn);
                    tr.appendChild(delTd);
                }
            }
        }
    }

    function createFuncAddNew(keys) {
        return function() {
            var edit = resetEditor("Add new " + editTable);
            for (var j = 0; j < keys.length; j++) {
                if (keys[j] != 'ID' && keys[j] != 'ErstellZeitpunkt' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt') {

                    var inp = createInput(keys[j]);

                    if (keys[j] == 'Benutzer_ID') {
                        inp.value = pub.user.ID;
                    } else if (keys[j] == 'Woche' && pub.selectedWeek) {
                        inp.value = pub.selectedWeek;
                    }
                    edit.appendChild(inp);
                }
            }
            finishEditor(edit);
        }
    }

    function createInput(key) {
        var inp;
        var relation = key.match(/^(.*)_ID$/);
        if (relation && tableCache[relation[1]]) {
            inp = document.createElement("SELECT");
            for (var k=0; k<tableCache[relation[1]].length; k++) {
                var row = tableCache[relation[1]][k];
                if (row && row.ID) {
                    var opt = document.createElement("OPTION");
                    opt.value=row.ID;
                    opt.innerText=row.Name;
                    if (pub.disableUnavailableProducts && (row.AnzahlZusatzBestellungMax < 0 || (row.AnzahlZusatzBestellung > 0 && row.AnzahlZusatzBestellungMax <= row.AnzahlZusatzBestellung) || (row.AnzahlZusatzBestellungMax == 0 && row.AnzahlBestellung <= 0) )) {

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
        } else {
            inp = document.createElement("INPUT");
            if (numberColumnNames[key] ||  key.match(/^(.*)_ID$/)) {
                inp.type="number";
                inp.step=numberColumnNames[key] || 1;
                inp.min=key.match(/^(.*)_ID$/) ? "0" : "-10";
                inp.max=key.match(/^(.*)_ID$/) ? "99999" : "999";
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

            var data = {};
            var editor = document.getElementById('editor');
            for (var i = 0; i < editor.children.length; i++) {
                var inpEle = editor.children[i];
                var id;
                if (inpEle.tagName == 'INPUT' || inpEle.tagName == 'SELECT') {
                    data[inpEle.dataKey] = inpEle.value;
                    id = id || inpEle.dataId;
                }
            }

            if (pub.disableUnavailableProducts && data['Produkt_ID'] && tableCache['Produkt']) {
                if ((! data['Anzahl']) || data['Anzahl'] == 0) {
                    setContent('editError', 'Anzahl muss eingegeben werden!');
                    event2.target.disabled='';
                    return;
                }
                var row = tableCache['Produkt'][data['Produkt_ID']]
                if (row) {
                    var min = row.AnzahlBestellung * -1;
                    var max = row.AnzahlZusatzBestellungMax - row.AnzahlZusatzBestellung;
                    if (data['Anzahl'] < min || data['Anzahl'] > max) {
                        setContent('editError', 'Anzahl zu ' + (data['Anzahl'] < min ? 'gering' : 'groß') + '. Min: ' + min + ' / Max: ' + max + ' möglich für Produkt ' + row.Name);
                        event2.target.disabled='';
                        return;
                    }
                }
            }


            postAjax(editTable + (id ? '/'+id : ''), data, function(){getAjax(editTablePath, showTableEditor);if (viewTablePath)getAjax(viewTablePath, showTable);});
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