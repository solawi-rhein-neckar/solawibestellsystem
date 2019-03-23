/*
Please create instances of this prototype with

    var weekSelect = Object.create(WeekSelect, {year: 2019, table: 'KorbInhaltWoche'});
    weekSelect.year = 2020;
    weekSelect.tableName = 'KorbInhaltWoche/KorbInhalt_ID/1',
    weekSelect.postData = {KorbInhalt_ID: 1, Woche: ''},

as last, supply the parent element:

    weekSelect.addTo(htmlElement);

The weekSelect will at itself as a child to this element, make api calls and display selectedWeeks
*/
var WeekSelect = {
    year: 2019,
    tableName: 'KorbInhaltWoche/KorbInhalt_ID/1',
    postData: {KorbInhalt_ID: 1, Woche: '2019.01'},

    addTo: function(pElem) {
        this.elem = pElem;
        getAjax(this.tableName, this.init.bind(this));
    },

    refresh: function() {
        getAjax(this.tableName, this.init.bind(this));
    },

    init: function(result, tablePath) {
        var weeks = {};
        for (var i = 0; i < result.length; i++) {
            var w = result[i].Woche-this.year;
            if (w > 0 && w < 1) {
                weeks[Math.round(w*100)]=1;
            }
        }

        console.log('init week select');
        console.log(this);
        var handler = this.handleSelect.bind(this);

        if (!this.htmlTable) {
            this.htmlTable = document.createElement('TABLE');
        } else {
            this.htmlTable.innerHTML = '';
        }
        this.elem.appendChild(this.htmlTable);
        this.htmlTable.className="weektable";

        var tr = document.createElement('TR');
        this.htmlTable.appendChild(tr);
        for (var i = 1; i<= 12; i++) {
            td = this.createCell(tr, '', handler)
            td.dataMultiWeeks = 'c'+i;
            td.style.height='.3em';
        }
        tr = document.createElement('TR');
        this.htmlTable.appendChild(tr);
        var weekCount = window.weekCount(this.year);
        for (var i = 1; i<= weekCount; i++) {
            td = this.createCell(tr, i < 10 ? '0' + i : i, handler);
            if (weeks[i]) {
                td.className='active';
            }
            td.dataWeek = i;
            if (i % 12 == 0) {
                tr = document.createElement('TR');
                this.htmlTable.appendChild(tr);
            }
        }

        td = this.createCell(tr, '', handler);
        td.colSpan = weekCount > 52 ? 3 : 4;
        td.className = '';
        td.style.paddingLeft = 0;
        td.style.paddingRight = 0;
        for (var q = 1; q <= 4; q++) {
            var span = document.createElement('SPAN');
            span.dataMultiWeeks = span.innerText = 'Q' + q;
            span.style.paddingLeft = q > 1 && weekCount <= 52 ? '3px' : 0;
            td.appendChild(span);
        }

        td = this.createCell(tr, '', handler);
        td.style.fontWeight = 'bold';
        td.colSpan = '4';
        td.className = '';
        var span = document.createElement('SPAN');
        span.innerText = '<< ';
        span.dataYear = this.year - 1;
        td.appendChild(span);
        span = document.createElement('SPAN');
        span.innerText=this.year;
        span.dataYear = this.year;
        td.appendChild(span);
        span = document.createElement('SPAN');
        span.innerText = ' >>';
        span.dataYear = this.year + 1;
        td.appendChild(span);

    },

    createCell: function(tr, text, onclick) {
        td = document.createElement('TD');
        tr.appendChild(td);
        td.innerText= text;
        td.addEventListener('click', onclick);
        td.className='inactive';
        tr.appendChild(td);
        return td;
    },

    handleSelect: function(event) {
        console.log('weekSelect click w' + event.target.dataWeek + ', c' + event.target.dataColumn + ', q' + event.target.dataQuartal + ', y' + event.target.dataYear);
        if (event.target.dataWeek) {
            this.toggleSingle(event.target);
        } else if (event.target.dataYear) {
            if (event.target.dataYear != this.year) {
                this.year=event.target.dataYear;
                this.refresh();
            } else if (confirm('Willst Du wirklich alle 52 Wochen des GANZEN JAHRES auf einmal aktivieren/deaktivieren?')) {
                this.toggleMulti();
            }
        } else if (event.target.dataMultiWeeks && (Object.keys(this.multiWeeks[event.target.dataMultiWeeks]).length <= 5 || confirm('Willst Du wirklich EIN GANZES QUARTAL auf einmal aktivieren/deaktivieren?'))) {
            this.toggleMulti(this.multiWeeks[event.target.dataMultiWeeks]);
        }
    },

    toggleSingle: function(elem) {
        if (this.tableName && this.postData) {
            this.postData.Woche = this.year + (elem.dataWeek <= 9 ? '.0' : '.') + elem.dataWeek;
            if (elem.className.match(/inactive/)) {
                postAjax(this.tableName.match(/[^\/]*/)[0], this.postData, (function(result) { if (result.result) elem.className = 'active'; else this.refresh();}).bind(this) );
            } else {
                deleteAjax(this.tableName + '/Woche/' + this.postData.Woche, (function(result) { if (result.result) elem.className = 'inactive'; else this.refresh();}).bind(this) );
            }
        }
    },

    toggleMulti: function(weeks) {
        var mode = '';
        for (var i = 0; i < this.htmlTable.children.length; i++) {
            var row = this.htmlTable.children[i];
            for (var j = 0; j < row.children.length; j++) {
                var cell = row.children[j];
                if ( cell.dataWeek && ((!weeks) || weeks[cell.dataWeek] == 1) ) {
                    if (cell.className.match(/inactive/)) {
                        if (mode == 'activate' || mode == '') {
                            mode = 'activate';
                            this.toggleSingle(cell);
                        }
                    } else {
                        if (mode == 'deactivate' || mode == '') {
                            mode = 'deactivate';
                            this.toggleSingle(cell);
                        }
                    }
                }
            }
        }
    },

    multiWeeks: {
        Q1: {1:1, 2:1, 3:1, 4:1, 5:1, 6:1, 7:1, 8:1, 9:1, 10:1, 11:1, 12:1, 13:1},
        Q2: {14:1, 15:1, 16:1, 17:1, 18:1, 19:1, 20:1, 21:1, 22:1, 23:1, 24:1, 25:1, 26:1},
        Q3: {27:1, 28:1, 29:1, 30:1, 31:1, 32:1, 33:1, 34:1, 35:1, 36:1, 37:1, 38:1, 39:1},
        Q4: {40:1, 41:1, 42:1, 43:1, 44:1, 45:1, 46:1, 47:1, 48:1, 49:1, 50:1, 51:1, 52:1, 53:1},
        c1: {1:1, 13:1, 25:1, 37:1, 49:1},
        c2: {2:1, 14:1, 26:1, 38:1, 50:1},
        c3: {3:1, 15:1, 27:1, 39:1, 51:1},
        c4: {4:1, 16:1, 28:1, 40:1, 52:1},
        c5: {5:1, 17:1, 29:1, 41:1, 53:1},
        c6: {6:1, 18:1, 30:1, 42:1},
        c7: {7:1, 19:1, 31:1, 43:1},
        c8: {8:1, 20:1, 32:1, 44:1},
        c9: {9:1, 21:1, 33:1, 45:1},
        c10: {10:1, 22:1, 34:1, 46:1},
        c11: {11:1, 23:1, 35:1, 47:1},
        c12: {12:1, 24:1, 36:1, 48:1}
    }


};



/*

//below: archived old idea, can probably be deleted

function createWeekSelectLarge(parentElemId, year) {

    var parent = document.getElementById(parentElemId);

    var ctnr = document.createElement('DIV');
    ctnr.className = 'weekYear';

    var start = 0;
    var end = 53;

    var firstDate = new Date(year, 0, 1, 12, 0);
    firstLen = firstDate.getDay() - 1;
    if (firstLen < 0) {firstLen = 6;}
    if (firstLen == 0) {
        start = 1;
    }
    var lastDate = new Date(year, 11, 31, 12, 0);
    lastLen = lastDate.getDay();
    if (lastLen > 0) {
        lastLen = 7 - lastLen;
    }
    if (lastLen == 0) {
        end = weekCount(year);
    }

    for (var week = start; week <= end; week++) {

        ctnr.append(createWeekPlaceholder(week, week == 0 ? firstLen : week == 53 ? lastLen : 7));

    }




    parent.appendChild(ctnr);
}


function createWeekPlaceholder(week, len) {

    var span = document.createElement('A');

    span.innerText = len == 1 ? '\xa0' : len == 2 ? (week < 10 ? '0' + week : week) : len == 3 ? (week < 10 ? 'W0' + week : ('W'+week)) : len == 4 ? (week < 10 ? 'W0'+week+'\xa0' : ('\xa0W'+week)) : len == 5 ? (week < 10 ? '\xa0W0'+week+'\xa0' : ('\xa0W'+week+'\xa0')) : len == 6 ? (week < 10 ? '\xa0W0'+week+' \xa0' : ('\xa0 W'+week+'\xa0')) : ('\xa0 W' + (week < 10 ? '0' : '') + week + ' \xa0');
    span.className='weekWeek';

    return span;

}
*/