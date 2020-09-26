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
    		setResponse : function(){},
    		columnIndex : 4
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
	var solawiEditor = SolawiEditor(sbs, solawiTable.reload, false);

/**** public ****/
    function addColumnHeaders(tr) {
        if (solawiTable.getTableName() == 'Benutzer') {
            var wtd = createHeaderCol('Lieferung');
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex]);

            wtd = createHeaderCol('Bestellung');
            wtd.innerText='Tausch';
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex+1]);

            wtd = createHeaderCol('Serie');
            wtd.className='col_serie';
            wtd.innerText='Serie';
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex+2]);

            wtd = createHeaderCol('BenutzerAbo');
            wtd.innerText='Jede_Woche-Abo';
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex+3]);

            wtd = createHeaderCol('Urlaub');
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex+4]);

        	wtd = document.createElement("TD");
            wtd.className='col_kuendingen';
            wtd.innerText='Kündigen';
            wtd.title='Setzt Anteile + Fleisch-Anteile auf 0, beendet alle Abos, loescht künftige Bestellungen und verschiebt ins unsichtbare Depot "geloescht".';
            tr.insertBefore(wtd, tr.childNodes[pub.columnIndex+5]);

            viewLieferungTables = {};
            editBestellungenTables = {};
            editAboTables = {};

            getAjax('BenutzerBestellungView/Woche/'+sbs.selectedWeek, createShowFilteredResultsFunction(viewLieferungTables));
            getAjax('BenutzerZusatzBestellung/Woche/'+sbs.selectedWeek, createShowFilteredResultsFunction(editBestellungenTables));
            getAjax('BenutzerModulAbo/Bis/'+sbs.selectedWeek, createShowFilteredResultsFunction(editAboTables));
            getAjax('BenutzerUrlaub/', createShowFilteredResultsFunction(weekSelects));
    	}
        if (solawiTable.getTableName() == 'Depot') {
        	var wtd = document.createElement("TD");
            wtd.className='col_Verwaltung';
            wtd.innerText='Benutzer';
            tr.insertBefore(wtd, tr.childNodes[1]);
        	wtd = document.createElement("TD");
            wtd.className='col_PivotBestell';
            wtd.innerText='PivotBestell';
            tr.insertBefore(wtd, tr.childNodes[2]);
        }
    }

    function createHeaderCol(colName) {
    	var wtd = document.createElement("TD");
        wtd.className='col_' + colName;
        wtd.innerText=colName;
        wtd.onclick = function() {
        	var elems = document.getElementsByClassName('col_' + colName);
        	if (elems) {
        		elems[0].style.color = elems[0].style.color == '#999' ? 'black' : '#999';
        		for (var i = 1; i < elems.length; i++) {
        			if (elems[i] && elems[i].firstChild && elems[i].firstChild.style) {
        				elems[i].firstChild.style.display = elems[i].firstChild.style.display == 'none' ? 'table' : 'none';
        			}
        		}
    		}
    	};
        wtd.title="Klicken, um Spalte aus / einzublenden!";
        wtd.style['text-decoration']='underline dotted';
        wtd.style.cursor = 'pointer';
        return wtd;
    }

    function addColumnCells(tr, row) {
        if (solawiTable.getTableName() == 'Benutzer') {
            var td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[pub.columnIndex]);
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
            viewLieferung.columns = ['Produkt', 'Anzahl', 'Kommentar', 'Punkte', 'Gutschrift'];
            viewLieferungTables[row['ID']] = viewLieferung;



            td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[pub.columnIndex+1]);
            td.className='col_Bestellung';
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
            td.className='col_serie';
            tr.insertBefore(td, tr.childNodes[pub.columnIndex+2]);

            var button = document.createElement("BUTTON");
            button.innerText = "serie";
            button.onclick = function() { solawiEditor.showForBatchOrder({Benutzer_ID: row['ID']}) };
            td.appendChild(button);

        	td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[pub.columnIndex+3]);
            td.className='col_BenutzerAbo';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editAboLabel'+row['ID'];
            var table = document.createElement("TABLE");
            table.id='editAboTable'+row['ID'];
            td.appendChild(table);
            td.appendChild(span);
            var editAbo = SolawiTable(sbs, 'editAboTable'+row['ID'], 'editAboLabel'+row['ID'], true, true);
            editAbo.setSortBy('StartWoche');
            editAbo.setSortBy('Modul_ID');
            editAbo.editorDefault['Benutzer_ID'] = row['ID'];
            editAbo.columns = ['Modul_ID', 'Anzahl', 'Kommentar', 'StartWoche', 'EndWoche', 'BezahltesModul'];
            editAboTables[row['ID']] = editAbo;
            var editAboReload = editAbo.reload;
            editAbo.reload = function() {editAboReload(); viewLieferung.reload();};

            td = document.createElement("TD");
            td.className='col_Urlaub';
            tr.insertBefore(td, tr.childNodes[pub.columnIndex+4]);
            var weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + row['ID'],
            weekSelect.postData = {Benutzer_ID: row['ID'], Woche: sbs.selectedWeek},
            weekSelect.allowMulti = false;
            weekSelect.setElem(td);
            weekSelects[row['ID']] = weekSelect;

            td = document.createElement("TD");
            td.className='col_kuendigen';
            tr.insertBefore(td, tr.childNodes[pub.columnIndex+5]);

            var button = document.createElement("BUTTON");
            button.innerText = "kündigen";
            button.onclick = createStornoFunction(row['ID'], sbs.selectedWeek);
            td.appendChild(button);
        }
        if (solawiTable.getTableName() == 'Depot') {
        	var wtd = document.createElement("TD");
            wtd.className='col_Verwaltung';
            var button = document.createElement("BUTTON");
            wtd.appendChild(button);
            button.innerText = 'verwalten';
            button.onclick = function() {getAjax('Benutzer/Depot_ID/'+row['ID'], function(a1,a2,a3) {window.SBTview.reset(); window.SBTmeta.showTable(a1,a2,a3)});};
            tr.insertBefore(wtd, tr.childNodes[1]);

            wtd = document.createElement("TD");
            wtd.className='col_PivotBestell';
            var button = document.createElement("BUTTON");
            wtd.appendChild(button);
            button.innerText = 'liste';
            button.onclick = function() {getAjax('PivotDepotBestellung/Woche/'+sbs.selectedWeek+'/Depot_ID/'+row['ID'], window.SBTview.showTable);};
            tr.insertBefore(wtd, tr.childNodes[2]);
        }
    }

    function createStornoFunction(userId, week) {
    	return function() {
        	if (confirm('Benutzer wirklich kündigen? Hierdurch ENDEN alle Modul-Abos zur gewählten Woche ' + week +
        			'(= letzte Lieferung in dieser Woche!). Außerdem werden alle Tausch-Bestellungen nach dieser Woche gelöscht. ' +
        			'Außerdem werden die Anteile und FleischAnteile JETZT SOFORT auf 0 gesetzt. ' +
        			(week < sbs.week ? 'BENUTZER WIRD INS DEPOT "Geloescht" VERSCHOBEN!' : '') )) {

        		getAjax('BenutzerModulAbo/Benutzer_ID/'+userId, function(result) {
        			if (result) {
        				for (var i = 0; i < result.length; i++) {
        					if (result[i].EndWoche > week) {
        						postAjax('BenutzerModulAbo/'+result[i].ID, {EndWoche: week}, function(){});
        					}
    					}
    				}
        		});
        		getAjax('BenutzerZusatzBestellung/Benutzer_ID/'+userId, function(result) {
        			if (result) {
        				for (var i = 0; i < result.length; i++) {
        					if (result[i].Woche > week) {
        						deleteAjax('BenutzerZusatzBestellung/'+result[i].ID, function(){});
        					}
    					}
    				}
        		});

        		postAjax('Benutzer/'+userId, {Anteile: 0}, function(){});
        		postAjax('Benutzer/'+userId, {FleischAnteile: 0}, function(){});

        		if (week < sbs.week) {
            		postAjax('Benutzer/'+userId, {Depot_ID: 0}, function(){});
        		}

        		 reloadWhenReady();
			}
        }
    }

    function reloadWhenReady() {
        if (window.activeAjaxRequestCount) {
        	window.setTimeout(reloadWhenReady, 333);
        } else {
        	solawiTable.reload();
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
    					postAjax('BenutzerModulAbo', {Benutzer_ID: userId, Modul_ID: modules[i].ID, Anzahl: anteile*(!modules[i].AnzahlProAnteil && modules[i].ID == 2 ? 3 : modules[i].AnzahlProAnteil), StartWoche: data.PunkteWoche ? data.PunkteWoche : sbs.selectedWeek, EndWoche: '9999.99'}, createReloadFunction(userId));
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
