
function showTableEditor(response, path) {
	showTable(response, path, true);
}
function showTable(response, path, editable) {
	if (path.match(/^BenutzerBestellView.*$/) && window.sbsDisableUnavailableProducts) {
		//save ZusatzBestellCount into ProductCache, so it can be reused for Validation!
		if (sbsTableCache['Produkt']) {
			for (var i = 0; i < sbsTableCache['Produkt'].length; i++) {
				if (sbsTableCache['Produkt'][i]) {
					sbsTableCache['Produkt'][i]['AnzahlZusatzBestellung'] = 0;
					sbsTableCache['Produkt'][i]['AnzahlBestellung'] = 0;
				}
			}
		}
		for (var i = 0; i<response.length; i++) {
			var row = response[i];
			if (sbsTableCache['Produkt'] && row.Produkt_ID && sbsTableCache['Produkt'][row.Produkt_ID]) {
				sbsTableCache['Produkt'][row.Produkt_ID]['AnzahlZusatzBestellung'] = row.AnzahlZusatz;
				sbsTableCache['Produkt'][row.Produkt_ID]['AnzahlBestellung'] = row.Anzahl;
			}
		}
	}
	
	var table = document.getElementById(editable ? 'tableEdit' : 'table');
	table.innerHTML = '';
	if (editable) {
		window.sbsEditTablePath = path;
		window.sbsEditTable = path.match(/[^\/]*/)[0];
		setContent('tableEditPath', window.sbsEditTablePath);
		table.className = window.sbsEditTable;
	} else {
		window.sbsViewTablePath = path;
		window.sbsViewTable = path.match(/[^\/]*/)[0];
		setContent('tablePath', window.sbsViewTablePath);
		table.className = window.sbsViewTable;
	}
	var keys = null;
	if (response.length == 0 && editable) {
		var tr = document.createElement("TR");
		var td = document.createElement("TD");
		table.appendChild(tr);
		tr.appendChild(td);
		var btn = document.createElement('BUTTON');
		td.appendChild(btn);
		
		btn.addEventListener('click', createFuncAddNew(window.sbsEditTable == 'BenutzerZusatzBestellung' ? ['Benutzer_ID', 'Produkt_ID', 'Anzahl', 'Woche'] : window.sbsEditTable == 'KorbInhaltWoche' ? ['KorbInhalt_ID'] : window.sbsEditTable == 'KorbInhalt' ? ['Korb_ID', 'Produkt_ID'] : ['Name']));
		btn.innerText = window.sbsEditTable == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
	}
	for (var i = 0; i < response.length; i++) {
		if(!keys) {
			keys = Object.keys(response[i]).sort(function(a,b){return sbsColumnWeight[a] && sbsColumnWeight[b] ? sbsColumnWeight[a] - sbsColumnWeight[b] : sbsColumnWeight[a] ? -1 : sbsColumnWeight[b] ? 1 : a>b ? 1 : a<b ? -1 : 0});
			
			var tr = document.createElement("TR");
			table.appendChild(tr);
			for (var j = 0; j < keys.length; j++) {
				var td = document.createElement("TD");
				td.className='col_'+keys[j];
				tr.appendChild(td);
				if (j == 0 && editable) {
					var btn = document.createElement('BUTTON');
					btn.addEventListener('click', createFuncAddNew(keys));
					btn.innerText = window.sbsEditTable == 'BenutzerZusatzBestellung' ? 'BESTELLEN' : 'NEU';
					td.appendChild(btn);
				} else {
					td.innerText = keys[j];
				}
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
				if (relation && sbsTableCache[relation[1]]) {
					var row = sbsTableCache[relation[1]][div.innerText];
					div.dataValue = div.innerText;
					div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
				}
				if ((! window.sbsDisableUnavailableProducts) && editable && keys[j] != 'ID' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && keys[j] != 'ErstellZeitpunkt') {
					div.addEventListener('click', showEditor);
					div.style.cursor = "pointer";
					div.title = "click to edit!";
				}
				div.dataId = response[i]["ID"];
				div.dataKey = keys[j];
				
				td.appendChild(div);
			}
			if (editable) {
				var delTd = document.createElement("TD");
				var delBtn = document.createElement("BUTTON");
				delBtn.innerText='entf.';
				delBtn.dataId = response[i]["ID"];
				delBtn.addEventListener('click', function(event) {
					if (confirm(window.sbsEditTable + "/" + event.target.dataId + ' wirklich löschen?')) {
						deleteAjax(window.sbsEditTable + "/" + event.target.dataId, function(){getAjax(window.sbsEditTablePath, showTableEditor);if (window.sbsViewTablePath)getAjax(window.sbsViewTablePath, showTable);});
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
		var edit = resetEditor("Add new " + window.sbsEditTable);
		for (var j = 0; j < keys.length; j++) {
			if (keys[j] != 'ID' && keys[j] != 'ErstellZeitpunkt' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt') {
				
				var inp = createInput(keys[j]);	
				
				if (keys[j] == 'Benutzer_ID') {
					inp.value = sbsUser.ID;
				} else if (keys[j] == 'Woche' && sbsSelectedWeek) {
					inp.value = sbsSelectedWeek;
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
	if (relation && sbsTableCache[relation[1]]) {
		inp = document.createElement("SELECT");
		for (var k=0; k<sbsTableCache[relation[1]].length; k++) {
			var row = sbsTableCache[relation[1]][k];
			if (row && row.ID) {
				var opt = document.createElement("OPTION");
				opt.value=row.ID;
				opt.innerText=row.Name;
				if (window.sbsDisableUnavailableProducts && (row.AnzahlZusatzBestellungMax < 0 || (row.AnzahlZusatzBestellung > 0 && row.AnzahlZusatzBestellungMax <= row.AnzahlZusatzBestellung) || (row.AnzahlZusatzBestellungMax == 0 && row.AnzahlBestellung <= 0) )) {
					
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
		if (sbsNumberColumnNames[key] ||  key.match(/^(.*)_ID$/)) {
			inp.type="number";
			inp.step=sbsNumberColumnNames[key] || 1;
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
	
		if (window.sbsDisableUnavailableProducts && data['Produkt_ID'] && sbsTableCache['Produkt']) {
			if ((! data['Anzahl']) || data['Anzahl'] == 0) {
				setContent('editError', 'Anzahl muss eingegeben werden!');
				event2.target.disabled='';
				return;
			}
			var row = sbsTableCache['Produkt'][data['Produkt_ID']]
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

	
		postAjax(window.sbsEditTable + (id ? '/'+id : ''), data, function(){getAjax(window.sbsEditTablePath, showTableEditor);if (window.sbsViewTablePath)getAjax(window.sbsViewTablePath, showTable);});
		hide('blockui_edit');
	}
}

function fillCache(tableName) {
	getAjax(tableName, function(resp) { 
		sbsTableCache[tableName] = []; 
		for(var i = 0; i < resp.length; i++) {
			sbsTableCache[tableName][resp[i]['ID']] = resp[i]; 
		}
	});
}


var sbsColumnOrder = ['ID'
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
var sbsColumnWeight = {};
for (var i =0; i < sbsColumnOrder.length; i++) {
	sbsColumnWeight[sbsColumnOrder[i]] = i+1;
}
var sbsNumberColumnNames = {
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