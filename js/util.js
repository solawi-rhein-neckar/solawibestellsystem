window.activeAjaxRequestCount = 0;

function postAjax(path, data, success, method) {
    var xhr = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject('Microsoft.XMLHTTP');
    xhr.open(method || (data ? 'POST' : 'GET'), 'https://' + (document.location.host || 'solawi-rhein-neckar.org') + (path.match(/^\//) ? path : ('/cgi-bin/resql.pl/' + path)) );
    xhr.onreadystatechange = function() {
    	if (xhr.readyState>3) {
	        window.activeAjaxRequestCount--;
	        if (window.activeAjaxRequestCount <= 0) {
	            window.activeAjaxRequestCount = 0;
	            hide('blockui_get');
	            hide('blockui_post');
	        }
	        console.log('unblock ' + window.activeAjaxRequestCount);
    	}
        if (xhr.readyState>3 && xhr.status==200) {
            var result;
            try {
                result = JSON.parse(xhr.responseText);
            } catch(e) {
                result = {reason: e};
            }
            if (result.reason || result.result) {
                var msgs = document.getElementById('messages');
                var msg = document.createElement("DIV");
                msg.style['white-space']='nowrap';
                msg.style.overflow='hidden';
                msg.style['text-overflow']='ellipsis';
                msg.title = result.reason;
                msg.innerText = (msgs.children.length + 1) + ": (" + result.result + ") " + (result.reason || (result.result ? "success" : "error"));
                msgs.insertBefore(msg, msgs.firstChild);
            }
            success(result, path, data);
        }
    };
    xhr.withCredentials = true;
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
    console.log('block ' + window.activeAjaxRequestCount);
    if (data) {
        show('blockui_post');
        window.activeAjaxRequestCount++;
        xhr.send(JSON.stringify(data));
    } else  {
        show('blockui_get');
        window.activeAjaxRequestCount++;
        xhr.send();
    }
    return xhr;
}
function getAjax(path, success) {
    return postAjax(path, null, success);
}
function deleteAjax(path, success) {
    return postAjax(path, null, success, 'DELETE');
}

function show(id) {
    var ele = document.getElementById(id);
    if (ele) ele.style.display='block';
}
function showInline(id) {
    var ele = document.getElementById(id);
    if (ele) ele.style.display='inline-block';
}
function hide(id) {
    var ele = document.getElementById(id);
    if (ele) ele.style.display='none';
}
function setContent(id, text) {
    var ele = document.getElementById(id);
    if (ele) ele.innerText=text;
}
function setHtmlContent(id, text) {
    var ele = document.getElementById(id);
    if (ele) ele.innerHTML=text;
}
function clearContent(id) {
    if (id == 'table') {
        window.sbsViewTablePath = '';
        window.sbsViewTable = '';
    } else if (id == 'tableEdit') {
        window.sbsEditTablePath = '';
        window.sbsEditTable = '';
    }
    var ele = document.getElementById(id);
    if (ele) {
        ele.innerHTML = '';
    }
}

// This script is released to the public domain and may be used, modified and
// distributed without restrictions. Attribution not necessary but appreciated.
// Source: https://weeknumber.net/how-to/javascript

// Returns the ISO week of the date.
Date.prototype.getWeek = function() {
  var date = new Date(this.getTime());
  date.setHours(0, 0, 0, 0);
  // Thursday in current week decides the year.
  date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7);
  // January 4 is always in week 1.
  var week1 = new Date(date.getFullYear(), 0, 4);
  // Adjust to Thursday in week 1 and count number of weeks from date to week1.
  return 1 + Math.round(((date.getTime() - week1.getTime()) / 86400000
                        - 3 + (week1.getDay() + 6) % 7) / 7);
}

// Returns the four-digit year corresponding to the ISO week of the date.
Date.prototype.getWeekYear = function() {
  var date = new Date(this.getTime());
  date.setDate(date.getDate() + 3 - (date.getDay() + 6) % 7);
  return date.getFullYear();
}

function weekToDate(yearWeekSeparatedByDot, dayOfWeek) {
    var year = Math.floor(yearWeekSeparatedByDot);
    var week = (yearWeekSeparatedByDot - year) * 100;
    var date = new Date(year, 0, 4, 12, 0, 0);
    return new Date(date.getTime() + ((week-1) * 86400000 * 7) + ((dayOfWeek - date.getDay()) * 86400000));
}

function addWeek(yearWeekSeparatedByDot, count) {
    var year = Math.floor(yearWeekSeparatedByDot);
    var week = (yearWeekSeparatedByDot * 100 + count);
    if (week % 100 > weekCount(year)) {
        week += 101 - (week % 100);
    } else if (week % 100 == 0) {
        week -= 100 - weekCount(year -1 );
    }
    week = week / 100;
    return week.toFixed(2);
}

function weekCount(year) {
    var date = new Date(year, 11 /*month index 0 based - dec = 11*/, 31, 12 /*mid of day*/, 0);
    return date.getWeek() != 53 ? 52 : 53;
}

/* the function dowloadWithSheetJs is CURRENTLY NOT USED!! as SheetJs does NOT support styles in XLS / XLSX correctly */
function downloadWithSheetJs() { if (false) {
	  /* convert data to binary string */
	  var data = new Uint8Array(arraybuffer);
	  var arr = new Array();
	  for(var i = 0; i != data.length; ++i) arr[i] = String.fromCharCode(data[i]);
	  var bstr = arr.join("");

	  /* Call XLSX */
		var workbook = XLSX.read(bstr, {type:"binary", cellNF: true, cellStyles:true});

	  /* simpler version with newest sheetJs version
	  var data = new Uint8Array(req.response);
	  var workbook = XLSX.read(data, {type:"array"});*/

	  /* DO SOMETHING WITH workbook HERE */
	  var first_sheet_name = workbook.SheetNames[0];
	  var address_of_cell = 'C6';

	  /* Get worksheet */
	  var worksheet = workbook.Sheets[first_sheet_name];

	  /* Find desired cell */
	  var desired_cell = worksheet[address_of_cell];

	  /* Get the value */
	  desired_cell.v = '2017'

	  /* output format determined by filename */
	  /* bookType can be 'xlsx' or 'xlsm' or 'xlsb' */
	  var wopts = { bookType:'xlsx', bookSST:false, type:'binary' };

	  var wbout = XLSX.write(workbook,wopts);

	  function s2ab(s) {
	    var buf = new ArrayBuffer(s.length);
	    var view = new Uint8Array(buf);
	    for (var i=0; i!=s.length; ++i) view[i] = s.charCodeAt(i) & 0xFF;
		  return buf;
	  }

	  /* the saveAs call downloads a file on the local machine */
	  saveAs(new Blob([s2ab(wbout)],{type:""}), "test.xlsx")
	  /* at this point, out.xlsb will have been downloaded */
	}

	req.send();
}

/* this function (using excelJS - https://cdn.jsdelivr.net/npm/exceljs@1.13.0/dist/exceljs.min.js) is currenlty used to fill in xlsx templates */
function downloadDepotbestellungen(response, path) {
	console.log('downloading...');
	var responseCache = response;

	var url = "xls/Depotbestellungen.xlsx";

	/* set up async GET request */
	var req = new XMLHttpRequest();
	req.open("GET", url, true);
	req.responseType = "arraybuffer";

	req.onload = function(e) {
		var arraybuffer = req.response;
		var workbook = new ExcelJS.Workbook();
	// workbook.xlsx.read(buffer)
	console.log('Depotbestellungen: loading...');

	workbook.xlsx.load(arraybuffer).then(
			function(workbook) {
			console.log('Depotbestellungen: loaded, writing...');
			console.log('loaded, filling...');
			var columns = [];
			var rows = {};
			var lastColumn = 0;
			var worksheet = workbook.getWorksheet(1);

			worksheet.getRow(1).getCell(1).value = 'Lieferung'
			worksheet.getRow(1).getCell(2).value = weekToDate(SBS.selectedWeek, 4).toLocaleDateString();
			worksheet.getRow(1).getCell(4).value = 'Woche';
			worksheet.getRow(1).getCell(5).value = SBS.selectedWeek

			worksheet.eachRow(

				function(row, rowNumber) {
					console.log('Depotbestellungen: Row ' + rowNumber + ' = ' + JSON.stringify(row.values));

					if (row.getCell(2).value == 'Anteile') {
						row.eachCell({ includeEmpty: true },
							function(cell, colNumber) {
								console.log('Depotbestellungen: Cell ' + colNumber + ' = ' + cell.value);
								if (cell.value) {
									columns[colNumber] = cell.value.replace('Anteile', 'Gemüse');
									if (colNumber > lastColumn) {
										lastColumn = colNumber;
									}
								}
							}
						);
					}

					if (row.getCell(1) && row.getCell(1).value) {
						rows[row.getCell(1).value] = rowNumber;
					}
				}
			);

			columns[lastColumn + 1] = 'Kommentar';

			console.log(columns);
			console.log(rows);
			console.log(response);

			var missingRows = {};
			for (var k in rows) {
				missingRows[k] = rows[k];
			}
	        for (var i = 0; i < response.length; i++) {

	        	var depot = response[i]['Depot'];
	        	console.log("Depotbestellungen: " + depot);
	        	console.log(response[i]);

	        	if (depot && rows[depot]) {
	        		var row = worksheet.getRow(rows[depot]);
			        for (var j = 2; j < columns.length; j++) {
			       		if (columns[j]) {
		       				var val = response[i][columns[j]];
		       				if (typeof(val) != 'undefined') {
	       						row.getCell(j).value = (isNaN(val) || val === null || val === '' ? val : val === 0 ? '' : Number(val));
	    			       		missingRows[depot] = false;
		       				} else {
		       					row.getCell(j).value = 'X';
		       				}
			       		}
			        }
	        	}

	        }

			for (var k in missingRows) {
				if (missingRows[k] && missingRows[k] > 3) {
	        		var row = worksheet.getRow(missingRows[k]);
			        for (var j = 2; j < columns.length; j++) {
			        	row.getCell(j).value = 'x';
			        }
				}
			}

			console.log('Depotbestellungen: filled, writing...');
			workbook.xlsx.writeBuffer().then(
				function(buffer) {
					console.log('Depotbestellungen: written, downloading...');
	   				saveAs(new Blob([buffer],{type:""}), "Depotbestellungen_"+SBS.selectedWeek+".xlsx");
	  			}
			);
		}
		);
	};
	req.send();
}


