function showTableEditor(response, path) {
	showTable(response, path, true);
}
function showTable(response, path, editable) {
	var table = document.getElementById(editable ? 'tableEdit' : 'table');
	table.innerHTML = '';
	if (editable) {
		window.sbsEditTablePath = path;
		window.sbsEditTable = path.match(/[^\/]*/)[0];
	} else {
		window.sbsViewTablePath = path;
		window.sbsViewTable = path.match(/[^\/]*/)[0];

	}
	var keys = null;
	if (response.length == 0 && editable) {
		var tr = document.createElement("TR");
		var td = document.createElement("TD");
		table.appendChild(tr);
		tr.appendChild(td);
		var btn = document.createElement('BUTTON');
		td.appendChild(btn);
		
		btn.addEventListener('click', createFuncAddNew(window.sbsEditTable == 'BenutzerZusatzBestellung' ? ['Benutzer_ID', 'Produkt_ID', 'Woche'] : window.sbsEditTable == 'KorbInhaltWoche' ? ['KorbInhalt_ID'] : window.sbsEditTable == 'KorbInhalt' ? ['Korb_ID', 'Produkt_ID'] : ['Name']));
		btn.innerText = 'ADD';
	}
	for (var i = 0; i < response.length; i++) {
		if(!keys) {
			keys = Object.keys(response[i]).sort(function(a,b){return a == 'ID' ? -1 : b == 'ID' ? 1 : a == b ? 0 : a > b ? 1 : -1});
			
			var tr = document.createElement("TR");
			table.appendChild(tr);
			for (var j = 0; j < keys.length; j++) {
				var td = document.createElement("TD");
				td.className='col_'+keys[j];
				tr.appendChild(td);
				if (j == 0 && editable) {
					var btn = document.createElement('BUTTON');
					btn.addEventListener('click', createFuncAddNew(keys));
					btn.innerText = 'ADD';
					td.appendChild(btn);
				} else {
					td.innerText = keys[j];
				}
			}
			if (editable) {
				var delTd = document.createElement("TD");
				delTd.innerText="del";
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
				div.innerText = response[i][keys[j]] || '-';
				var relation = keys[j].match(/^(.*)_ID$/);
				if (relation && sbsTableCache[relation[1]]) {
					var row = sbsTableCache[relation[1]][div.innerText];
					div.dataValue = div.innerText;
					div.innerText = row == null ? ' (' + div.innerText + ') ' : row.Name;
				}
				if (editable && keys[j] != 'ID' && keys[j] != 'AenderBenutzer_ID' && keys[j] != 'AenderZeitpunkt' && keys[j] != 'ErstellZeitpunkt') {
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
				delBtn.innerText="del";
				delBtn.dataId = response[i]["ID"];
				delBtn.addEventListener('click', function(event) {
					if (confirm('Really delete ' + window.sbsEditTable + "/" + event.target.dataId)) {
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
				var inp;
				
				var relation = keys[j].match(/^(.*)_ID$/);
				if (relation && sbsTableCache[relation[1]]) {
					inp = document.createElement("SELECT");
					for (var k=0; k<sbsTableCache[relation[1]].length; k++) {
						var row = sbsTableCache[relation[1]][k];
						if (row && row.ID) {
							var opt = document.createElement("OPTION");
							opt.value=row.ID;
							opt.innerText=row.Name;
							inp.appendChild(opt);
						}
					}
				} else {
					inp = document.createElement("INPUT");
				}
				
				inp.className = 'editor inp_' + keys[j];
				if (keys[j] == 'Benutzer_ID') {
					inp.value = sbsUser.ID;
				} else if (keys[j] == 'Woche' && sbsSelectedWeek) {
					inp.value = sbsSelectedWeek;
				}
				inp.dataKey = keys[j];
				inp.placeholder = keys[j];
				edit.appendChild(inp);
			}
		}
		finishEditor(edit);
	}
}

function showEditor(event) {
	var edit = resetEditor("ID " + event.target.dataId + ": " + event.target.dataKey + " ");

	var inp;

	var relation = event.target.dataKey.match(/^(.*)_ID$/);
	if (relation && sbsTableCache[relation[1]]) {
		inp = document.createElement("SELECT");
		for (var k=0; k<sbsTableCache[relation[1]].length; k++) {
			var row = sbsTableCache[relation[1]][k];
			if (row && row.ID) {
				var opt = document.createElement("OPTION");
				opt.value=row.ID;
				opt.innerText=row.Name;
				inp.appendChild(opt);
			}
		}
	} else {
		inp = document.createElement("INPUT");
	}
	inp.value = event.target.dataValue || event.target.innerText;
	inp.className = 'editor inp_' + event.target.dataKey;
	inp.dataId = event.target.dataId;
	inp.dataKey = event.target.dataKey;
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
