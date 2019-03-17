function postAjax(path, data, success, method) {
	var xhr = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject('Microsoft.XMLHTTP');
	xhr.open(method || (data ? 'POST' : 'GET'), '/cgi-bin/resql.pl/' + path);
	xhr.onreadystatechange = function() {
		hide('blockui_get');
		hide('blockui_post');
		if (xhr.readyState>3 && xhr.status==200) { 
			var result = JSON.parse(xhr.responseText);
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
			success(result, path); 
		}
	};
	xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
	xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
	if (data) {
		show('blockui_post');
		xhr.send(JSON.stringify(data));
	} else  {
		show('blockui_get');
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
function hide(id) {
	var ele = document.getElementById(id);
	if (ele) ele.style.display='none';
}
function setContent(id, text) {
	var ele = document.getElementById(id);
	if (ele) ele.innerText=text;
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

function addWeek(pWeek, count) {
	year = Math.floor(pWeek);
	week = (pWeek * 100 + count);
	if (week % 100 > weekCount(year)) {
		week += 101 - (week % 100);
	} else if (week % 100 == 0) {
		week -= 100 - weekCount(year -1 );
	}
	week = week / 100;
	return week.toFixed(2);
}
	
function weekCount(year) {
	date = new Date(year, 11 /*month index 0 based - dec = 11*/, 31, 12 /*mid of day*/, 0);
	return date.getWeek() != 53 ? 52 : 53;
}