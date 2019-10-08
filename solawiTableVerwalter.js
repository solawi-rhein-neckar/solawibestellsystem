/*
 * Requires: solawiTableValidator
 *
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    This file is meant to be used by solawiTable.
*/
function SolawiTableVerwalter(pSbs, pSolawiTable) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    		enhanceDataCell: enhanceDataCell,
    		addColumnHeaders: addColumnHeaders,
    		addColumnCells: addColumnCells,
    		onEntitySaved: onEntitySaved,
    		setResponse : function(){}
    };

    /* private vars */
    var sbs = pSbs;
    var solawiTable = pSolawiTable;
    var alleLieferungen = [];
    var alleBestellungen = [];
    var alleAbos = [];
    var viewLieferungTables = {};
    var editBestellungenTables = {};
    var editAboTables = {};
    var weekSelects = {}

/**** public ****/
    function addColumnHeaders(tr) {
        if (solawiTable.getTableName() == 'Benutzer') {
            var wtd = document.createElement("TD");
            wtd.className='col_Lieferung';
            wtd.innerText='Lieferung';
            tr.insertBefore(wtd, tr.childNodes[6]);

            wtd = document.createElement("TD");
            wtd.className='col_Bestellung';
            wtd.innerText='Zusatzbestellung';
            tr.insertBefore(wtd, tr.childNodes[7]);

            wtd = document.createElement("TD");
            wtd.className='col_BenutzerAbo';
            wtd.innerText='Module';
            tr.insertBefore(wtd, tr.childNodes[8]);

            wtd = document.createElement("TD");
            wtd.className='col_Urlaub';
            wtd.innerText='Urlaub';
            tr.insertBefore(wtd, tr.childNodes[9]);

            viewLieferungTables = {};
            editBestellungenTables = {};
            editAboTables = {};

            getAjax('BenutzerBestellView/Woche/'+sbs.selectedWeek, createShowFilteredResultsFunction(viewLieferungTables));
            getAjax('BenutzerZusatzBestellung/Woche/'+sbs.selectedWeek, createShowFilteredResultsFunction(editBestellungenTables));
            getAjax('BenutzerModulAbo/Bis/'+sbs.selectedWeek, createShowFilteredResultsFunction(editAboTables));
            getAjax('BenutzerUrlaub/', createShowFilteredResultsFunction(weekSelects));
    	}
    }

    function addColumnCells(tr, row) {
        if (solawiTable.getTableName() == 'Benutzer') {
            var td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[6]);
            td.className='col_Lieferung';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editLieferungLabel'+row['ID'];
            var table = document.createElement("TABLE");
            table.id='editLieferungTable'+row['ID'];
            td.appendChild(table);
            td.appendChild(span);
            var viewLieferung = SolawiTable(sbs, 'editLieferungTable'+row['ID'], 'editLieferungLabel'+row['ID'], false, false);
            viewLieferung.setSortBy('Anzahl');
            viewLieferung.setSortBy('Produkt_ID');
            viewLieferung.columns = ['Produkt', 'Anzahl', 'Kommentar'];
            viewLieferungTables[row['ID']] = viewLieferung;



            td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[7]);
            td.className='col_BenutzerAbo';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editBestellungLabel'+row['ID'];
            var table = document.createElement("TABLE");
            table.id='editBestellungTable'+row['ID'];
            td.appendChild(table);
            td.appendChild(span);
            var editBestellung = SolawiTable(sbs, 'editBestellungTable'+row['ID'], 'editBestellungLabel'+row['ID'], true, false);
            editBestellung.setSortBy('Anzahl');
            editBestellung.setSortBy('Produkt_ID');
            editBestellung.editorDefault['Benutzer_ID'] = row['ID'];
            editBestellung.columns = ['Produkt_ID', 'Anzahl', 'Kommentar', 'Woche'];
            editBestellungenTables[row['ID']] = editBestellung;
            var editBestellungReload = editBestellung.reload;
            editBestellung.reload = function() {editBestellungReload(); viewLieferung.reload();};


        	td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[8]);
            td.className='col_BenutzerAbo';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editAboLabel'+row['ID'];
            var table = document.createElement("TABLE");
            table.id='editAboTable'+row['ID'];
            td.appendChild(table);
            td.appendChild(span);
            var editAbo = SolawiTable(sbs, 'editAboTable'+row['ID'], 'editAboLabel'+row['ID'], true, false);
            editAbo.setSortBy('StartWoche');
            editAbo.setSortBy('Modul_ID');
            editAbo.editorDefault['Benutzer_ID'] = row['ID'];
            editAbo.columns = ['Modul_ID', 'Anzahl', 'Kommentar', 'StartWoche', 'EndWoche'];
            editAboTables[row['ID']] = editAbo;
            var editAboReload = editAbo.reload;
            editAbo.reload = function() {editAboReload(); viewLieferung.reload();};

            td = document.createElement("TD");
            td.className='col_Urlaub';
            tr.insertBefore(td, tr.childNodes[9]);
            var weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + row['ID'],
            weekSelect.postData = {Benutzer_ID: row['ID'], Woche: sbs.selectedWeek},
            weekSelect.allowMulti = false;
            weekSelect.setElem(td);
            weekSelects[row['ID']] = weekSelect;
        }
    }

    function enhanceDataCell() {}

    function onEntitySaved(result, path, data) {
    	var modules = sbs && sbs.tableCache ? sbs.tableCache['Modul'] : null;
    	if (path == 'Benutzer' && result && result.type == 'insert' && result.id && modules) {
    		var userId = result.id;
    		for (var i = 0; i < modules.length; i++) {
    			if (modules[i] && modules[i].ID && (modules[i].AnzahlProAnteil || modules[i].ID == 2)) {
    	    		var anteile = modules[i].ID == 4 ? (data.FleischAnteile === '' ? 1 : data.FleischAnteile) : (data.Anteile === '' ? 1 : data.Anteile);
    	    		if (anteile) {
    					postAjax('BenutzerModulAbo', {Benutzer_ID: userId, Modul_ID: modules[i].ID, Anzahl: anteile*(!modules[i].AnzahlProAnteil && modules[i].ID == 2 ? 3 : modules[i].AnzahlProAnteil), StartWoche: sbs.selectedWeek, EndWoche: '9999.99'}, createReloadFunction(userId));
    				}
    			}
    		}

    	}

    }

    function createReloadFunction(userId) {
    	return function() {
    		if (editAboTables && editAboTables[userId] && editAboTables[userId].reload) editAboTables[userId].reload();
    		if (viewLieferungTables && viewLieferungTables[userId] && viewLieferungTables[userId].reload) viewLieferungTables[userId].reload();
    	};
    }

    function createShowFilteredResultsFunction(tables) {
    	return function(result, path){
        	var keys = Object.keys(tables);
        	for (var i = 0; i < keys.length; i++) {
        		var filtered = [];
        		for (var j = 0; j < result.length; j++) {
        			if (result[j] && result[j]['Benutzer_ID'] == keys[i]) {
        				filtered.push(result[j]);
        			}
        		}
        		if (tables[keys[i]].showTable)
        			tables[keys[i]].showTable(filtered, path.replace(/\//, '/Benutzer_ID/'+keys[i]+'/'));
        		else if (tables[keys[i]].init) {
        			tables[keys[i]].init(filtered);
        		}
        	}
    	}
    }

    return pub;
}
