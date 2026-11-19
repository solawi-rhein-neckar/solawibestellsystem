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
    var tabTitle;
    var lieferTitle;
    var solawiTableLiefer;
    var weekSelect;
    var solawiSeriesEditor;
    var seriesBtn;
    var holiday;
    var stornoCtnr;
    var weekSelector;
    var dataIdGetter;
    var zugangCtnr;
    var onEntitySaved = pOnEntitySaved;

	/*public*/
	function saveToDb(tableName, id, sendData, onEntitySaved) {
        var keys = Object.keys(sendData);
        var sendDataDB = {};
        var hasDb = false;
        var sendDataWP = {};
        var hasWp = false;
        for (var i = 0; i < keys.length; i++) {
            if (keys && keys[i] && keys[i].match && keys[i].match(/^wp.*$/) && (!keys[i].match(/^wp(Mit|Mit[0-9])?ID$/))) {
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
            /* Mailadressen für die Anmeldung (BenutzerZugang): nur Orga und Admin, die dürfen sie in resql.pl auch schreiben */
            var btn4 = null;
            if (sbs.user && sbs.user.Role_ID >= 4) {
                btn4 = document.createElement("BUTTON");
                btn4.innerText="Mailadressen";
                tabPane.appendChild(btn4);
            }

            tabTitle = document.createElement("DIV");
            tabTitle.innerText = 'Lieferung';
            tabTitle.style.fontWeight = 'bold';
            tabTitle.style.marginTop = '10px';
			info.appendChild(tabTitle);

            holiday = document.createElement("DIV");
            holiday.style['margin-bottom'] = '10px';
            holiday.style.display = 'inline-block';
            info.appendChild(holiday);
            weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + dataIdGetter();
            weekSelect.postData = {Benutzer_ID: dataIdGetter(), Woche: sbs.selectedWeek},
            weekSelect.allowMulti = false;
            weekSelect.setElem(holiday);

            zugangCtnr = document.createElement("DIV");
            zugangCtnr.id = 'benutzerZugang' + editorSuffix;
            zugangCtnr.style.display = 'none';
            info.appendChild(zugangCtnr);

            var table = document.createElement("TABLE");
            info.appendChild(table);
            table.id='benutzerEditorValidTable';
            var span = document.createElement("DIV");
            span.id='benutzerEditorValidLabel';
            span.style.color='#999';
            info.appendChild(span);
            table = document.createElement("TABLE");
            table.style.marginTop = '10px';
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
            solawiTableLiefer.showSum = 'top';
            var stvrf = solawiTableValid.reload;
            solawiTableValid.reload=function() {stvrf(); solawiTableLiefer.reload();};
            var stvrf2 = solawiTableEdit.reload;
            solawiTableEdit.reload=function() {stvrf2(); solawiTableLiefer.reload();};
            btn.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';tabTitle.innerText='Abos';lieferTitle.innerText='Lieferung';seriesBtn.style.display='inline-block';
                getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter() + "/Bis/" + sbs.week, solawiTableValid.showTable)
                getAjax('BenutzerZusatzBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableEdit.showTable)
                solawiTableLiefer.columns = ['Produkt', 'Anzahl', 'AnzahlModul', 'Kommentar', 'Punkte', 'Gutschrift', 'Saldo'];
                getAjax('BenutzerBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableLiefer.showTable)
            };
            btn1.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';tabTitle.innerText='Alle Tausche';lieferTitle.innerText='';seriesBtn.style.display='none';
                getAjax('BenutzerZusatzBestellungView/Benutzer_ID/' + dataIdGetter(), solawiTableEdit.showTable)
            };
            btn2.onclick=function() {if(confirm('ACHTUNG! Hier können Abos RÜCKWIRKEND verändert werden! Bitte nur zur Fehlerkorrektur. Normalerweise sollte unter "Abos" das bestehende Abo beendet werden (EndWoche = Jetzt) und danach ein neues Abo ab heute angelegt werden!')){
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';tabTitle.innerText='Abos rückwirkend manipulieren, Vorsicht!';lieferTitle.innerText='';seriesBtn.style.display='none';
                getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter(), function(a1,a2,a3) {solawiTableEdit.showTable(a1,a2,a3);document.getElementById('benutzerEditorLabel').innerText='ACHTUNG! Hier können Abos RÜCKWIRKEND verändert werden! Bitte nur zur Fehlerkorrektur. Normalerweise sollte unter "Abos" das bestehende Abo beendet werden (EndWoche = Jetzt) und danach ein neues Abo ab heute angelegt werden!';})
            }};
            btn3.onclick=function() {
                solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';tabTitle.innerText='Urlaub';lieferTitle.innerText='Punkte Vorjahr (2023)';seriesBtn.style.display='none';
                getAjax('BenutzerPunkte/' + dataIdGetter(), solawiTableView.showTable);
                solawiTableLiefer.columns = ['Woche', 'Benutzer', 'Abzug', 'Gutschrift', 'Subtotal', 'Total'];
                getAjax('BenutzerPunkteView/2023/' + dataIdGetter(), solawiTableLiefer.showTable);
                weekSelect.tableName = 'BenutzerUrlaub/Benutzer_ID/' + dataIdGetter();
                weekSelect.postData = {Benutzer_ID: dataIdGetter(), Woche: sbs.selectedWeek};
                weekSelect.refresh();
            };
            if (btn4) {
                btn4.onclick=function() {
                    solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';tabTitle.innerText='Mailadressen für die Anmeldung';lieferTitle.innerText='';seriesBtn.style.display='none';
                    zeigeZugang('');
                };
            }
            [btn, btn1, btn2, btn3].forEach(function(b) { b.addEventListener('click', versteckeZugang); });

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
	        versteckeZugang();
	        solawiTableEdit.reset();solawiTableValid.reset();solawiTableView.reset();solawiTableLiefer.reset();holiday.innerHTML = '';
	        solawiTableValid.editorDefault['Benutzer_ID'] = dataIdGetter();
	        solawiTableEdit.editorDefault['Benutzer_ID'] = dataIdGetter();
	        tabTitle.innerText='Abos';
	        lieferTitle.innerText = 'Lieferung';
	        seriesBtn.style.display='inline-block';
	        getAjax('BenutzerModulAbo/Benutzer_ID/' + dataIdGetter() + "/Bis/" + sbs.week, solawiTableValid.showTable)
	        getAjax('BenutzerZusatzBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableEdit.showTable)
            solawiTableLiefer.columns = ['Produkt', 'Anzahl', 'AnzahlModul', 'Kommentar', 'Punkte', 'Gutschrift','Saldo'];
	        getAjax('BenutzerBestellungView/Benutzer_ID/' + dataIdGetter() + "/Woche/" + sbs.selectedWeek, solawiTableLiefer.showTable)
	        btnCtnr.appendChild(stornoCtnr);
            btnCtnr.style.textAlign = 'left';
        }
    }

	/*private*/
	function versteckeZugang() {
		if (zugangCtnr) {
			zugangCtnr.style.display = 'none';
			zugangCtnr.innerHTML = '';
		}
	}

	/*private: wie SolawiSitzung::email_normal in cgi-bin (der Server prüft noch einmal), hier nur für eine schnelle Rückmeldung */
	function emailNormal(roh) {
		var e = String(roh || '').trim().toLowerCase();
		var atom = "[a-z0-9!#$%&*+/=?^_`{|}~-]+";
		var muster = new RegExp('^(' + atom + '(?:\\.' + atom + ')*)@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$');
		var treffer = e.length <= 254 ? e.match(muster) : null;
		return treffer && treffer[1].length <= 64 ? e : '';
	}

	/*private: Mailadressen des Anteils (BenutzerZugang) zeigen und pflegen; meldung steht unter der Liste */
	function zeigeZugang(meldung) {
		var benutzerId = dataIdGetter();
		zugangCtnr.style.display = 'block';
		zugangCtnr.innerHTML = '';
		var hinweis = document.createElement('P');
		hinweis.innerText = 'Mit diesen Adressen meldet sich das Mitglied per Mail-Link an (Website und Bestellsystem). '
			+ 'Eine Adresse gehört immer zu genau einem Anteil.';
		zugangCtnr.appendChild(hinweis);
		var tabelle = document.createElement('TABLE');
		tabelle.style.width = '100%';
		var kopf = document.createElement('TR');
		['Mailadresse', 'Bezeichnung', ''].forEach(function(text) {
			var th = document.createElement('TH');
			th.innerText = text;
			th.style.textAlign = 'left';
			kopf.appendChild(th);
		});
		tabelle.appendChild(kopf);
		zugangCtnr.appendChild(tabelle);
		var ausgabe = document.createElement('DIV');
		ausgabe.className = 'zugangMeldung';
		ausgabe.style.marginTop = '8px';
		ausgabe.style.fontWeight = 'bold';
		ausgabe.innerText = meldung || '';
		zugangCtnr.appendChild(ausgabe);
		getAjax('BenutzerZugang/Benutzer_ID/' + benutzerId, function(zeilen) {
			if (benutzerId != dataIdGetter() || zugangCtnr.style.display == 'none') {
				return; /* inzwischen anderer Anteil oder anderer Knopf */
			}
			if (!zeilen || !zeilen.forEach) {
				ausgabe.innerText = 'Die Adressen konnten nicht geladen werden.';
				return;
			}
			zeilen.forEach(function(z) { tabelle.appendChild(zugangZeile(z, ausgabe)); });
			tabelle.appendChild(zugangZeile(null, ausgabe));
		});
	}

	/*private: eine Zeile mit Adresse und Bezeichnung; z == null: leere Zeile zum Hinzufügen */
	function zugangZeile(z, ausgabe) {
		var tr = document.createElement('TR');
		var email = document.createElement('INPUT');
		email.type = 'email';
		email.maxLength = 254;
		email.placeholder = 'neue Mailadresse';
		email.className = 'inp_ZugangEmail';
		email.value = z ? z.Email : '';
		var bez = document.createElement('INPUT');
		bez.maxLength = 100;
		bez.placeholder = 'z. B. Mit-Mitglied';
		bez.className = 'inp_ZugangBezeichnung';
		bez.value = z && z.Bezeichnung ? z.Bezeichnung : '';
		[email, bez].forEach(function(inp) {
			inp.style.width = '100%';
			inp.style.boxSizing = 'border-box';
		});
		var speichern = document.createElement('BUTTON');
		speichern.innerText = z ? 'Speichern' : 'Hinzufügen';
		speichern.onclick = function() {
			var wert = emailNormal(email.value);
			if (!wert) {
				ausgabe.innerText = 'Bitte eine gültige Mailadresse eingeben.';
				return;
			}
			var daten = z ? {} : {Benutzer_ID: dataIdGetter()};
			if (!z || wert != z.Email) {
				daten.Email = wert;
			}
			if (!z || bez.value.trim() != (z.Bezeichnung || '')) {
				daten.Bezeichnung = bez.value.trim();
			}
			if (Object.keys(daten).length == 0) {
				ausgabe.innerText = 'Nichts geändert.';
				return;
			}
			postAjax('BenutzerZugang' + (z ? '/' + z.ID : ''), daten, function(r) {
				if (r && r.result == 1) {
					zeigeZugang(z ? 'Gespeichert.' : 'Hinzugefügt.');
				} else {
					ausgabe.innerText = (r && r.reason) || 'Nicht gespeichert.'; /* Eingabe bleibt stehen */
				}
			});
		};
		var weiter = function(evt) { if (evt.keyCode == 13) { speichern.click(); } };
		email.addEventListener('keypress', weiter);
		bez.addEventListener('keypress', weiter);
		[[email, '50%'], [bez, '28%']].forEach(function(feld) {
			var td = document.createElement('TD');
			td.style.width = feld[1];
			td.appendChild(feld[0]);
			tr.appendChild(td);
		});
		var td = document.createElement('TD');
		td.style.whiteSpace = 'nowrap';
		td.appendChild(speichern);
		tr.appendChild(td);
		if (z) {
			var entfernen = document.createElement('BUTTON');
			entfernen.innerText = 'Entfernen';
			entfernen.onclick = function() {
				if (confirm('Adresse entfernen? Mit ihr ist dann keine Anmeldung mehr möglich, Geräte, die mit ihr angemeldet sind, werden abgemeldet.')) {
					deleteAjax('BenutzerZugang/' + z.ID, function(r) {
						if (r && r.result == 1) {
							zeigeZugang('Entfernt.');
						} else {
							ausgabe.innerText = (r && r.reason) || 'Nicht entfernt.';
						}
					});
				}
			};
			td.appendChild(entfernen);
		}
		return tr;
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
    	    		var anteile = (data.Anteile === '' ? 1 : data.Anteile);
    	    		if (anteile) {
    					postAjax('BenutzerModulAbo', {Benutzer_ID: userId, Modul_ID: modules[i].ID, Anzahl: anteile*(modules[i].AnzahlProAnteil), StartWoche: data.AnteileStartWoche ? data.AnteileStartWoche : sbs.selectedWeek, EndWoche: '9999.99', BezahltesModul: modules[i].ID == 4}, changeWeekEditor);
    				}
    			}
    		}
    	}
    }


    return pub;
}
