/*
 * Requires: solawiValidator
 *
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

*/
function MemberEditor(pSbs, pEditorSuffix, pOnEntitySaved) {
    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    	enhanceEditor: enhanceEditor,
    	saveToDb: saveToDb,
    	addCopyBtn: addCopyBtn
    };

    /* private vars */
    var editorSuffix = pEditorSuffix;
	var sbs = pSbs;
    var solawiTableEdit;
    var solawiTableValid;
    var solawiTableView;
    var lieferTitle;
    var solawiTableLiefer;
    var weekSelect;
    var solawiSeriesEditor;
    var seriesBtn;
    var holiday;
    var stornoCtnr;
    var weekSelector;
    var dataIdGetter;
    var onEntitySaved = pOnEntitySaved;

	/*public*/
	function saveToDb(tableName, id, sendData, onEntitySaved) {
        var keys = Object.keys(sendData);
        var sendDataDB = {};
        var hasDb = false;
        var sendDataWP = {};
        var hasWp = false;
        for (var i = 0; i < keys.length; i++) {
            if (keys && keys[i] && keys[i].match && keys[i].match(/^wp.*$/) && (!keys[i].match(/^wp(Mit)?ID$/))) {
                sendDataWP[keys[i].replace(/^wp/, '')] = sendData[keys[i]];
                hasWp = true;
            } else {
                sendDataDB[keys[i]] = sendData[keys[i]];
                hasDb = true;
            }
        }
        if (hasWp) {
            if (hasDb) {
                postAjax('/cgi-bin/wp.pl/user_meta/' + id, sendDataWP, function() {
                    postAjax(tableName + (id ? '/'+id : ''), sendDataDB, onEntitySaved);
                });
            } else {
                postAjax('/cgi-bin/wp.pl/user_meta/' + id, sendDataWP, onEntitySaved);
            }
        } else if (hasDb) {
            postAjax(tableName + (id ? '/'+id : ''), sendDataDB, function(result, path, data) {
		    	if (path == 'Benutzer' && result && result.type == 'insert' && result.id) {
	            	addModulAbos(result.id, data);
            	}
            	onEntitySaved(result, path, data);
        	});
        }
	}

	/*public*/
    function addCopyBtn(tr, dataRow, createAddFunc,tableName){
        if (dataRow['wpID'] && dataRow['Name'] == 'onlyWP' && dataRow['ID'] == -1) {
	        var btn = document.createElement('BUTTON');
	        tr.firstChild.innerHTML = '';
	        tr.firstChild.appendChild(btn);
	        var depotId = null;
	        if (dataRow['wpDepot'] && sbs && sbs.tableCache['Depot']) {
	        	for (var k = 0; k<sbs.tableCache['Depot'].length; k++) {
	        		if (sbs.tableCache['Depot'][k] && (sbs.tableCache['Depot'][k].wpName == dataRow['wpDepot'] || (dataRow['wpDepot'] == 'Hofteam' && sbs.tableCache['Depot'][k].wpName == 'Selbstabholer')) ){
						depotId = sbs.tableCache['Depot'][k].ID;
	        		}
	        	}
	        }
	        btn.addEventListener('click', createAddFunc(tableName, {wpID: dataRow['wpID'], Name: dataRow['wpdisplay_name'], Depot_ID: depotId}));
	        btn.innerText = 'Kopie_aus_WP';
	        btn.style.paddingLeft = '0';
	        btn.style.paddingRight = '0';
	        btn.className='btn_plus'
        }
    }

	/*public*/
    function enhanceEditor(edit, btnCtnr, pDataIdGetter, createInputDateSelect) {
    	sbs.selectedWeek = sbs.week;
    	window.changeWeek(0);
    	dataIdGetter = pDataIdGetter;
        var info = document.getElementById('benutzerEditor'+editorSuffix);
        if (!info) {
            info = document.createElement("DIV");
            info.id='benutzerEditor'+editorSuffix;
            info.style.width = '61%';
            info.style.height = '650px';
            info.style.overflow = 'auto';
            info.style.textAlign = 'left';
            edit.parentNode.insertBefore(info, btnCtnr);

            var tabPane = document.createElement("DIV");
            info.appendChild(tabPane);
            var btn = document.createElement("BUTTON");
            btn.innerText="Abos | Tausch | Lieferung";
            tabPane.appendChild(btn);
            var btn1 = document.createElement("BUTTON");
            btn1.innerText="Alle Tausche";
            tabPane.appendChild(btn1);
            var btn2 = document.createElement("BUTTON");
            btn2.innerText="Abo Korrektur";
            tabPane.appendChild(btn2);
            var btn3 = document.createElement("BUTTON");
            btn3.innerText="Urlaub u. Punkte";
            tabPane.appendChild(btn3);

            holiday = document.createElement("div");
            holiday.style['margin-bottom'] = '15px';
            holiday.style.display = 'inline-block';
            info.appendChild(holiday);
            weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + dataIdGetter();
            weekSelect.postData = {Benutzer_ID: dataIdGetter(), Woche: sbs.selectedWeek},
            weekSelect.allowMulti = false;
            weekSelect.setElem(holiday);

            var table = document.createElement("TABLE");
            info.appendChild(table);
            table.id='benutzerEditorValidTable';
            var span = document.createElement("DIV");
            span.id='benutzerEditorValidLabel';
            span.style.color='#999';
            info.appendChild(span);
            table = document.createElement("TABLE");
            table.style.marginTop = '15px';
            info.appendChild(table);
            table.id='benutzerEditorTable';
            span = document.createElement("DIV");
            span.id='benutzerEditorLabel';
            span.style.color='#999';
            info.appendChild(span);

            seriesBtn = document.createElement("BUTTON");
            seriesBtn.onclick=function(){solawiSeriesEditor.showForBatchOrder({Benutzer_ID: dataIdGetter()});};
            seriesBtn.style.marginTop="15px";
            seriesBtn.innerText='Serien-Tausch';
            info.appendChild(seriesBtn);
            lieferTitle = document.createElement("DIV");
            lieferTitle.innerText = 'Lieferung';
            lieferTitle.style.fontWeight = 'bold';
            lieferTitle.style.marginTop = '15px';
            info.appendChild(lieferTitle);
            table = document.createElement("TABLE");
            info.appendChild(table);
            table.id='benutzerLieferTable';
            span = document.createElement("DIV");
            span.id='benutzerLieferLabel';
            span.style.color='#999';
            info.appendChild(span);


            solawiSeriesEditor = SolawiEditor(sbs, function() {solawiTableEdit.reload();solawiTableLiefer.reload();}, false);
            solawiSeriesEditor.setKeys(['Benutzer_ID','Produkt_ID','Anzahl','Woche','Kommentar']);
            solawiTableValid = SolawiTable(sbs, 'benutzerEditorValidTable', 'benutzerEditorValidLabel', true, true);
            solawiTableEdit = SolawiTable(sbs, 'benutzerEditorTable', 'benutzerEditorLabel', true, false);
            solawiTableView = SolawiTable(sbs, 'benutzerEditorTable', 'benutzerEditorLabel', false, false);
            solawiTableLiefer = SolawiTable(sbs, 'benutzerLieferTable', 'benutzerLieferLabel', false, false);
            solawiTableLiefer.columns = ['Produkt', 'Anzahl', 'AnzahlModul', 'Kommentar', 'Punkte', 'Gutschrift'];
            var stvrf = solawiTableValid.reload;
            solawiTableValid.reload=function() {stvrf(); solawiTableLiefer.reload();};
            var stvrf2 = solawiTableEdit.reload;
            solawiTableEdit.reload=function() {stvrf2(); solawiTableLiefer.reload();};
            btn.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';lieferTitle.innerText='Lieferung';seriesBtn.style.display='inline-block';
                getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter() + "/Bis/" + sbs.week, solawiTableValid.showTable)
                getAjax('BenutzerZusatzBestellung/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableEdit.showTable)
                getAjax('BenutzerBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableLiefer.showTable)
            };
            btn1.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';lieferTitle.innerText='';seriesBtn.style.display='none';
                getAjax('BenutzerZusatzBestellung/Benutzer_ID/' + dataIdGetter(), solawiTableEdit.showTable)
            };
            btn2.onclick=function() {if(confirm('ACHTUNG! Hier können Abos RÜCKWIRKEND verändert werden! Bitte nur zur Fehlerkorrektur. Normalerweise sollte unter "Abos" das bestehende Abo beendet werden (EndWoche = Jetzt) und danach ein neues Abo ab heute angelegt werden!')){
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';lieferTitle.innerText='';seriesBtn.style.display='none';
                getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter(), function(a1,a2,a3) {solawiTableEdit.showTable(a1,a2,a3);document.getElementById('benutzerEditorLabel').innerText='ACHTUNG! Hier können Abos RÜCKWIRKEND verändert werden! Bitte nur zur Fehlerkorrektur. Normalerweise sollte unter "Abos" das bestehende Abo beendet werden (EndWoche = Jetzt) und danach ein neues Abo ab heute angelegt werden!';})
            }};
            btn3.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';lieferTitle.innerText='';seriesBtn.style.display='none';
                getAjax('BenutzerPunkte/' + dataIdGetter(), solawiTableView.showTable);
                var title = document.createElement("div");
                title.style.padding = '3px';
                title.innerText = 'Urlaub';
                title.style.fontWeight = 'bold';
                holiday.appendChild(title);
                weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + dataIdGetter();
                weekSelect.postData = {Benutzer_ID: dataIdGetter(), Woche: sbs.selectedWeek};
                weekSelect.refresh();
            };

            stornoCtnr = document.createElement("SPAN");
            stornoCtnr.id= "stornoCtnr"+editorSuffix;
            stornoCtnr.style.float = 'right';
            stornoCtnr.display='inline-block';

            var weekLabel = document.createElement("SPAN");
            weekLabel.innerText="Woche f. Tausch / Lieferung (oben) oder Kündigung: ";
            stornoCtnr.appendChild(weekLabel);

            weekSelector = createInputDateSelect();
            weekSelector.value = sbs.selectedWeek;
            weekSelector.onchange=changeWeekEditor;
            stornoCtnr.appendChild(weekSelector);

            var stornoBtn = document.createElement("BUTTON");
            stornoBtn.innerText = "kündigen";
            stornoBtn.onclick = stornoUser;
            stornoCtnr.appendChild(stornoBtn);

	        if (window.changeWeek && !window.changeWeekOrig) {
				window.changeWeekOrig = window.changeWeek;
				window.changeWeek = function(count) {
					window.changeWeekOrig(count);
					weekSelector.value = sbs.selectedWeek;
		            changeWeekEditor();
				}
	        }
        }

		if(! dataIdGetter()) {
			info.style.display = 'none';
            btnCtnr.style.textAlign = 'center';
		} else {
            info.style.display='inline-block';
	        solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';
	        solawiTableValid.editorDefault['Benutzer_ID'] = dataIdGetter();
	        solawiTableEdit.editorDefault['Benutzer_ID'] = dataIdGetter();
	        lieferTitle.innerText = 'Lieferung';
	        seriesBtn.style.display='inline-block';
	        getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter() + "/Bis/" + sbs.week, solawiTableValid.showTable)
	        getAjax('BenutzerZusatzBestellung/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableEdit.showTable)
	        getAjax('BenutzerBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableLiefer.showTable)
	        btnCtnr.appendChild(stornoCtnr);
            btnCtnr.style.textAlign = 'left';
        }
    }

	/*private*/
	function changeWeekEditor(evt) {
		  if (evt && evt.target && evt.target.value) {
          	sbs.selectedWeek=evt.target.value;
          }
          if (window.changeWeekOrig) {
          	window.changeWeekOrig(0);
          }
          var ele = document.getElementById('blockui_edit'+editorSuffix);
          if (ele && ele.style && ele.style.display != 'none') {
          	  if (evt && evt.type && evt.type == 'insert' && solawiTableValid.getTablePath()) {
		        getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter() + "/Bis/" + sbs.week, solawiTableValid.showTable);
	          }
	          if (solawiTableEdit.getTablePath() && solawiTableEdit.getTablePath().match(/BenutzerZusatzBestellung.*Woche.*/)) {
	              getAjax('BenutzerZusatzBestellung/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableEdit.showTable)
	          }
	          if (solawiTableLiefer.getTablePath() && solawiTableLiefer.getTablePath().match(/BenutzerBestellungView.*Woche.*/)) {
	              getAjax('BenutzerBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableLiefer.showTable)
	          }
          }
	}

	/*private*/
    function stornoUser() {
        if (confirm('Benutzer wirklich kündigen? Hierdurch ENDEN alle Modul-Abos zur gewählten Woche ' + sbs.selectedWeek +
                '(= letzte Lieferung in dieser Woche!). Außerdem werden alle Tausch-Bestellungen nach dieser Woche gelöscht. ' +
                'Außerdem werden die Anteile und FleischAnteile JETZT SOFORT auf 0 gesetzt. ' +
                (sbs.selectedWeek < sbs.week ? 'BENUTZER WIRD INS DEPOT "Geloescht" VERSCHOBEN!' : '') )) {

            getAjax('BenutzerModulAbo/Benutzer_ID/'+dataIdGetter(), function(result) {
                if (result) {
                    for (var i = 0; i < result.length; i++) {
                        if (result[i].EndWoche > sbs.selectedWeek) {
                            postAjax('BenutzerModulAbo/'+result[i].ID, {EndWoche: sbs.selectedWeek}, function(){});
                        }
                    }
                }
            });
            getAjax('BenutzerZusatzBestellung/Benutzer_ID/'+dataIdGetter(), function(result) {
                if (result) {
                    for (var i = 0; i < result.length; i++) {
                        if (result[i].Woche > sbs.selectedWeek) {
                            deleteAjax('BenutzerZusatzBestellung/'+result[i].ID, function(){});
                        }
                    }
                }
            });

            if (sbs.selectedWeek < sbs.week) {
	            postAjax('Benutzer/'+dataIdGetter(), {Anteile: 0, FleischAnteile: 0, Depot_ID: 0}, function(){});
            } else {
	            postAjax('Benutzer/'+dataIdGetter(), {Anteile: 0, FleischAnteile: 0}, function(){});
            }

             reloadWhenReady();
        }
    }

	/*private*/
    function reloadWhenReady() {
        if (window.activeAjaxRequestCount) {
            window.setTimeout(reloadWhenReady, 333);
        } else {
            hide('blockui_edit'+editorSuffix);onEntitySaved();
        }
    }

	/*private*/
    function addModulAbos(userId, data) {
    	var modules = sbs && sbs.tableCache ? sbs.tableCache['Modul'] : null;
    	if (modules && userId) {
    		for (var i = 0; i < modules.length; i++) {
    			if (modules[i] && modules[i].ID && (modules[i].AnzahlProAnteil || modules[i].ID == 2)) {
    	    		var anteile = modules[i].ID == 4 ? (data.FleischAnteile === '' ? 1 : data.FleischAnteile) : (data.Anteile === '' ? 1 : data.Anteile);
    	    		if (anteile) {
    					postAjax('BenutzerModulAbo', {Benutzer_ID: userId, Modul_ID: modules[i].ID, Anzahl: anteile*(!modules[i].AnzahlProAnteil && modules[i].ID == 2 ? 3 : modules[i].AnzahlProAnteil), StartWoche: data.PunkteWoche ? data.PunkteWoche : sbs.selectedWeek, EndWoche: '9999.99'}, changeWeekEditor);
    				}
    			}
    		}
    	}
    }


    return pub;
}