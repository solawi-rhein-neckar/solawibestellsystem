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
    		setResponse : function(){}
    };

    /* private vars */
    var sbs = pSbs;
    var solawiTable = pSolawiTable;

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
            var div = document.createElement("DIV");
            div.id='editLieferungTable'+row['ID'];
            td.appendChild(div);
            td.appendChild(span);
            var viewLieferung = SolawiTable(sbs, 'editLieferungTable'+row['ID'], 'editLieferungLabel'+row['ID'], false, false);
            viewLieferung.setSortBy('Anzahl');
            viewLieferung.setSortBy('Produkt_ID');
            viewLieferung.columns = ['Produkt', 'Anzahl', 'Kommentar'];
            getAjax('BenutzerBestellView/Benutzer_ID/'+row['ID']+'/Woche/'+sbs.selectedWeek, viewLieferung.showTable);

            
            td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[7]);
            td.className='col_BenutzerAbo';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editBestellungLabel'+row['ID'];
            var div = document.createElement("DIV");
            div.id='editBestellungTable'+row['ID'];
            td.appendChild(div);
            td.appendChild(span);
            var editBestellung = SolawiTable(sbs, 'editBestellungTable'+row['ID'], 'editBestellungLabel'+row['ID'], true, false);
            editBestellung.setSortBy('Anzahl');
            editBestellung.setSortBy('Produkt_ID');
            editBestellung.editorDefault['Benutzer_ID'] = row['ID'];
            editBestellung.columns = ['Produkt_ID', 'Anzahl', 'Kommentar', 'Woche'];
            var editBestellungReload = editBestellung.reload;
            editBestellung.reload = function() {editBestellungReload(); viewLieferung.reload();};
            getAjax('BenutzerZusatzBestellung/Benutzer_ID/'+row['ID']+'/Woche/'+sbs.selectedWeek, editBestellung.showTable);

        	
        	td = document.createElement("TD");
            tr.insertBefore(td, tr.childNodes[8]);
            td.className='col_BenutzerAbo';
            var span = document.createElement("SPAN");
            span.style.display = 'none';
            span.id='editAboLabel'+row['ID'];
            var div = document.createElement("DIV");
            div.id='editAboTable'+row['ID'];
            td.appendChild(div);
            td.appendChild(span);
            var editAbo = SolawiTable(sbs, 'editAboTable'+row['ID'], 'editAboLabel'+row['ID'], true, false);
            editAbo.setSortBy('StartWoche');
            editAbo.setSortBy('Modul_ID');
            editAbo.editorDefault['Benutzer_ID'] = row['ID'];
            editAbo.columns = ['Modul_ID', 'Anzahl', 'Kommentar', 'StartWoche', 'EndWoche'];
            var editAboReload = editAbo.reload;
            editAbo.reload = function() {editAboReload(); viewLieferung.reload();};
            getAjax('BenutzerModulAbo/Benutzer_ID/'+row['ID']+'/Bis/'+sbs.selectedWeek, editAbo.showTable);
            
            td = document.createElement("TD");
            td.className='col_Urlaub';
            tr.insertBefore(td, tr.childNodes[9]);
            var weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + row['ID'],
            weekSelect.postData = {Benutzer_ID: row['ID'], Woche: sbs.selectedWeek},
            weekSelect.allowMulti = false;
            weekSelect.addTo(td);
        }
    }
    
    function enhanceDataCell() {}

    return pub;
}
