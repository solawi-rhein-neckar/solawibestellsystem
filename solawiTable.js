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
    var sortByColumn1 = null;
    var sortByColumn2 = null;
    var tableEditor = SolawiTableEditor(sbs, pub, editable, disableUnavailableProducts);

    /* private constants */
    const columnWeight = {};
    
/**** public ****/
    function showTable(response, path) {
    	console.log('show table ' + path);

        sortResponse(response);
        
        responseCache = response;
        tableEditor.setResponse(path, responseCache);

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
        	tableEditor.addCreateButton(td, keys);
        }
        for (var i = 0; i < response.length; i++) {
            if(!keys) {
                keys = Object.keys(response[i]).sort(columnSortFunc);
                addColumnHeaderRow(table, keys);
            }
            var dataRow = response[i];
            for (var j = 0; j < keys.length; j++) {
                var tr = document.createElement("TR");
                table.appendChild(tr);
                for (var j = 0; j < keys.length; j++) {
                	var div = addDataCell(keys[j], dataRow[keys[j]], tr);
                    div.dataId = dataRow["ID"];
                    div.id = "span_" + tablePath + "_" + i + "_" + j;
                }
                tableEditor.addWeekSelectCell(tr, dataRow["ID"]);
                tableEditor.addDeleteButtonCell(tr, dataRow);
            }
        }
    }

/**** private ****/

    function addDataCell(key, value, tr) {
        var td = document.createElement("TD");
        td.className='col_'+key;
        tr.appendChild(td);

        var div = document.createElement("DIV");
        div.innerText = value === undefined || value === null || value === '' ? '-' : value;
        
        /* foreign key lookup in sbs.tableCache */
        var relation = key.match(/^(?:Besteller|Verwalter)?(.*)_ID$/);
        if (relation && sbs.tableCache[relation[1]]) {
            var row = sbs.tableCache[relation[1]][div.innerText];
            div.dataValue = div.innerText;
            div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
        }
        
        /* if disableUnavailableProducts ist true, only certain columns are editable, else all columns (except audit metadata) are editable. */
        if ( ((! disableUnavailableProducts) || key == 'Kommentar' || key == 'EndWoche') && editable && key != 'ID' && key != 'AenderBenutzer_ID' && key != 'AenderZeitpunkt' && key != 'ErstellZeitpunkt') {
            div.addEventListener('click', tableEditor.showEditor);
            div.style.cursor = "pointer";
            if (disableUnavailableProducts) {
            	div.style['border-bottom'] = "1px dotted black";
            }
            div.title = "click to edit!";
        }
        
        div.dataKey = key;
        td.appendChild(div);    	
        return div;
    }    

    function addColumnHeaderRow(table, keys) {
        var tr = document.createElement("TR");
        table.appendChild(tr);
        for (var j = 0; j < keys.length; j++) {
            var td = document.createElement("TD");
            td.className='col_'+keys[j];
            tr.appendChild(td);
            if (j == 0 && editable) {
            	tableEditor.addCreateButton(td, keys);
            } else if (keys[j].match(/^[0-9][0-9][.].*/) ) {
                td.innerText = keys[j].substr(3);
            } else {
                td.innerText = keys[j];
                td.addEventListener('click', createRedisplaySortedFunc(keys[j]) );
                td.style.cursor='pointer';
            }
        }
        tableEditor.addWeekSelectColumnHeader(tr);
        tableEditor.addDeleteButtonColumnHeader(tr);
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
    	return a[sortByColumn1] < b[sortByColumn1] ? -1 : a[sortByColumn1] > b[sortByColumn1] ? 1 : (sortByColumn2 ? (a[sortByColumn2] < b[sortByColumn2] ? -1 : a[sortByColumn2] > b[sortByColumn2]) : 0);
    }

    function columnSortFunc(a,b){
    	return columnWeight[a] && columnWeight[b] ? columnWeight[a] - columnWeight[b] : columnWeight[a] ? -1 : columnWeight[b] ? 1 : a>b ? 1 : a<b ? -1 : 0
	}

    function initColumnWeight() {
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
            ,'Kommentar'
            ,'Anteile'
            ,'StartWoche'
            ,'EndWoche'

            ,'Punkte'
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
