/*
 * Requires: solawiTableEditor, solawiTableValidator, solawiBestellSystem
 *
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
function SolawiTable(pSbs, pElemIdTable, pElemIdLabel, pEditable, pDisableUnavailableProducts, pVerwalter) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
        showTable: showTable,
        getTableName: function(){return tableName},
        getTablePath: function(){return tablePath},
        onEntitySaved: onEntitySaved,
        reload: function(){if(tablePath){getAjax(tablePath, showTable)}},
        reset: function(){clearContent(elemIdTable);clearContent(elemIdLabel);tableName='';tablePath='';},
        setSortBy: function(sortBy){sortByColumn2 = sortByColumn1; sortByColumn1 = sortBy;},
        columns: [],
        editorDefault: {},
        editAtOnce: false
    };

    /* private vars */
    var sbs = pSbs;
    var elemIdTable = pElemIdTable;
    var elemIdLabel = pElemIdLabel;
    var tableName;
    var tablePath;
    var responseCache;
    var sortByColumn1 = null;
    var sortByColumn2 = null;
    var tableExtensions = [];
    if (pEditable) tableExtensions.push(SolawiTableEditor(sbs, pub, pDisableUnavailableProducts, pEditable));
    if (pVerwalter) tableExtensions.push(SolawiTableVerwalter(sbs, pub));

    /* private constants */
    const columnWeight = {};

/**** public ****/
    function showTable(response, path) {
        console.log('show table ' + path);

        if (path.match(/^BenutzerBestellView.*$/) || path.match(/^BenutzerBestellungView.*$/)) {
            sbs.saveOrdersIntoProductCache(response);
        }

        sortResponse(response);

        responseCache = response;
        tableExtensions.forEach(function(ext){ext.setResponse(path, responseCache);});

        var table = document.getElementById(elemIdTable);
        table.innerHTML = '';
        tablePath = path;
        tableName = path.match(/[^\/]*/)[0];
        setContent(elemIdLabel, tablePath);
        table.className = tableName;
        var keys = null;
        if (response.length == 0) {
            var tr = handleEmpty(table);
            tableExtensions.forEach(function(ext){ext.addColumnHeaders(tr, keys);});
        }
        for (var i = 0; i < response.length; i++) {
            if(!keys) {
                keys = pub.columns.length ? pub.columns : Object.keys(response[i]).sort(columnSortFunc);
                if (pub.columns.length) {
                    for (var j = 0; j < keys.length; j++) {
                        keys[j] = keys[j].replace(' ', '');
                    }
                }
                var tr = addColumnHeaderRow(table, pub.columns.length ? pub.columns : keys, keys);
                tableExtensions.forEach(function(ext){ext.addColumnHeaders(tr, keys);});
                /*tr.childNodes.forEach(function(child){
                    var div = document.createElement("DIV");
                    div.innerText = child.innerText;
                    div.style.position = 'absolute';
                    div.style.backgroundColor = 'white';
                    child.insertBefore(div, child.firstChild);
                });*/
            }
            var dataRow = response[i];
            for (var j = 0; j < keys.length; j++) {
                var tr = document.createElement("TR");
                table.appendChild(tr);
                for (var j = 0; j < keys.length; j++) {
                    var div = addDataCell(keys[j], dataRow, tr);
                    div.id = "span_" + tablePath + "_" + i + "_" + j;
                    tableExtensions.forEach(function(ext){ext.enhanceDataCell(div, keys[j]);});
                }
                tableExtensions.forEach(function(ext){ext.addColumnCells(tr, dataRow);});
            }
        }
    }

    function onEntitySaved(result, path, data) {
        tableExtensions.forEach(function(ext){if (ext.onEntitySaved) {ext.onEntitySaved(result, path, data)};});
        pub.reload();
        if (result && result.type == 'insert' && sbs && sbs.tableCache && sbs.tableCache[path]) {
            sbs.fillCache(path);
        }
    }

/**** private ****/

    function handleEmpty(table) {
        var tr = document.createElement("TR");
        var td = document.createElement("TD");
        table.appendChild(tr);
        tr.appendChild(td);
        td.innerText = ' (empty) ';
        return tr;
    }

    function addDataCell(key, dataRow, tr) {
        var value = dataRow[key];
        var td = document.createElement("TD");
        td.className='col_'+key;
        tr.appendChild(td);

        var div = document.createElement("DIV");
        div.dataValue = value;

        if (pub.hideZeros && value != null && value != undefined && value.match && value.match(/^-?[0-9]+[.][0459][09]([1-9]|[1-9][0-9]|[0-9][1-9]|[0-9][1-9][05]|[1-9][0-9][05])$/)) {
             var v = value.match(/^-?[0-9]+[.][45]/) ? Math.round(value * 2) / 2 : Math.round(value);
             var z = Math.round((value - v) * 20000)/2;
             if (z > 0 || z < 0) {
                 div.title = 'Tausch: ' + z;
                 div.className = 'hat_tausch';
             }
             value = v < 0 ? v * -1 : v;
        } else if (pub.hideZeros && value != null && value != undefined && value.match && value.match(/^[0-9]+[.][05]0+$/)) {
            value = value.match(/^[0-9]+[.][5]0+$/) ? Math.round(value * 2) / 2 : Math.round(value);

        }


        if (key.match(/^[A-Za-z1-9öäüÖÄÜ]+_ID_[0-9][0-9]?$/)) {

            key = key.replace(/.*_ID_/, '');

            var inp = document.createElement("INPUT");
            inp.type = 'number';
            inp.value = value;
            inp.size = 1;
inp.style.width='40px';
            inp.onchange = function(evt) {

            evt.target.disabled = 'disabled';

                postAjax('ModulInhaltWoche',
                        {ModulInhalt_ID: dataRow['_ID'], Depot_ID: key, Anzahl: evt.target.value == '' || evt.target.value < 0 ? null : evt.target.value, Woche: sbs.selectedWeek, onDuplicateKeyUpdate: 'Anzahl'},
                        function() {
                           evt.target.disabled = '';
                           if (evt.target.value < 0) {
                               evt.target.value = '';
                           }
                        });
            };

            div.appendChild(inp);

        } else {
            div.innerText = value === undefined || value === null || value === '' ? '-' : pub.hideZeros && (value === 0 || value === '0' || value === '0.0') ? '' : value;
        }


        /* foreign key lookup in sbs.tableCache */
        var relation = key.match(/^(?:Besteller|Verwalter)?(.*)_ID$/);
        if (relation && sbs.tableCache[relation[1]]) {
            var row = sbs.tableCache[relation[1]][div.innerText];
            div.dataValue = div.innerText;
            div.title = div.innerText;
            div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
        } else {
            var relation2 = key.match(/^(wp)(Mit)?ID$/);
            if (relation2 && sbs.tableCache[relation2[1]]) {
                var row = sbs.tableCache[relation2[1]][div.innerText];
                div.dataValue = div.innerText;
                div.title = row == null ? div.innerText : div.innerText + ': ' + row['display_name'];
                div.innerText = row == null ? ' (' + div.innerText + ') ' : row['user_email'];
            }
        }

        div.dataKey = key;
        div.dataId = dataRow["ID"];
        td.appendChild(div);
        return div;
    }

    function addColumnHeaderRow(table, columns, keys) {
        var tr = document.createElement("TR");
        table.appendChild(tr);
        for (var j = 0; j < columns.length; j++) {
            var td = document.createElement("TD");
            var span = document.createElement("SPAN");
            tr.appendChild(td);
            td.appendChild(span);
            td.className='col_'+keys[j];
            span.className = "TableHead";
            if (columns[j].match(/^[A-Za-z1-9öäüÖÄÜ]+_ID_[0-9][0-9]?$/)) {
                span.innerText = columns[j].replace(/_ID_.*/, '');
                span.dataKey = columns[j].replace(/.*_ID_/, '');
                span.addEventListener('click', createRedisplaySortedFunc(keys[j]) );
                span.style.cursor='pointer';
            } else if (columns[j].match(/^[0-9][0-9][.].*/) ) {
                span.innerText = columns[j].substr(3).replace('AnzahlModul', 'Jede_Woche-Abo').replace('AnzahlZusatz', 'Tausch');
                span.addEventListener('click', createRedisplaySortedFunc(keys[j]) );
                span.style.cursor='pointer';
            } else {
                span.innerText = columns[j].replace('AnzahlModul', 'Jede_Woche-Abo').replace('AnzahlZusatz', 'Tausch');
                if (tableName == 'BenutzerBestellungView') {
                    span.innerText = span.innerText.replace('Punkte', 'Punkte-Abzug*');
                }
                span.addEventListener('click', createRedisplaySortedFunc(keys[j]) );
                span.style.cursor='pointer';
            }
        }
        return tr;
    }

    function createRedisplaySortedFunc(sortBy) {
        return function(){sortByColumn2 = sortByColumn1; sortByColumn1 = sortBy; showTable(responseCache, tablePath);}
    }

    function sortResponse(response) {
        if (sortByColumn1) {
            console.log('sorting by ' + sortByColumn1 + (sortByColumn2 ? (', then ' + sortByColumn2) : ''));
            response.sort(rowSortFunc);
        }
    }

    function rowSortFunc(a,b) {
        return a[sortByColumn1]===undefined ? (b[sortByColumn1]===undefined ? 0 : 1) : b[sortByColumn1]===undefined ? -1 :
        	(a[sortByColumn1] < b[sortByColumn1] ? -1 : a[sortByColumn1] > b[sortByColumn1] ? 1 : (sortByColumn2 ? (
    			a[sortByColumn2]===undefined ? (b[sortByColumn2]===undefined ? 0 : 1) : b[sortByColumn2]===undefined ? -1 :
    			(a[sortByColumn2] < b[sortByColumn2] ? -1 : (a[sortByColumn2] > b[sortByColumn2] ? 1 : 0))          ) : 0 )
			);
    }

    function columnSortFunc(a,b){
        return columnWeight[a] && columnWeight[b] ? columnWeight[a] - columnWeight[b] : columnWeight[a] ? -1 : columnWeight[b] ? 1 : a>b ? 1 : a<b ? -1 : 0
    }

    function initColumnWeight() {
        const columnOrder = ['ID'
            ,'KurzName'
            ,'Name'
            ,'MitName'
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
            ,'Kommentar'
            ,'Anteile'
            ,'FleischAnteile'
            ,'AnteileStartWoche'
            ,'StartWoche'
            ,'EndWoche'

            ,'Punkte'
            ,'PunkteStart'
            ,'PunkteStand'
            ,'PunkteWoche'
            ,'Role'
            ,'Role_ID'
            ,'BestellerBenutzer_ID'
            ,'VerwalterBenutzer_ID'
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
            ,'AltName'
            ,'ErstellZeitpunkt'
            ,'AenderZeitpunkt'
            ,'AenderBenutzer_ID'
            ];

        for (var i = 0; i < columnOrder.length; i++) {
            columnWeight[columnOrder[i]] = i+1;
        }
    }

    initColumnWeight();
    return pub;
}

