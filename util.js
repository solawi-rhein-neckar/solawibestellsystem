/*
Test objects without NEW --> works fine, only 'this' is not available (points to window)

var Obj = function() {
    var pub = {
        val: 1,
        print: print,
        set: setPriv
    }

    var priv = 2;

    function print() {
        console.log('Obj.priv = ' + priv + ', val = ' + pub.val);
    }

    function setPriv(val) {
        priv = val;
    }

    return pub;
}

var a = Obj();
var b = Obj();
a.val = 3;
a.set(4);
a.print();
b.print();
b.val = 5;
b.set(6);

var c = Obj();
a.print();
b.print();
c.print();
console.log(a);
console.log(b);
console.log(c);
*/
/*
Objects with Object.create AND (to avoid that the javascript enging has to  re-create the private functions again and again for each instance): closure

var template = (function() {
    const pub = {
        myVar: 1,
        myProp: 'text',
        myFunc: function() {return this.myProp;},
        myFunc2: privFunc,
        getStat: function(){return stat;}
    }
    var stat = 1;
    function privFunc() {stat -= 1; return "hello " + this.myVar + " static " + stat;}
    return pub;
})();

var inst1 = Object.create(template);

var inst2 = Object.create(template);

console.log(inst1 === inst2);

console.log(inst1.myFunc === inst2.myFunc);

console.log(inst1.myFunc2 === inst2.myFunc2);

inst2.myProp = 'text2';

console.log(inst1.myFunc());

console.log(inst2.myFunc());

inst2.myVar = '2';

console.log(inst1.myFunc2());

console.log(inst2.myFunc2());

console.log(inst1.getStat());
console.log(inst2.getStat());

console.log(inst1);

console.log(inst2);
*/
/*
Objects with new

var struct = {
    name: 'foo',
    id: 2,
    print: function() { console.log('nr. ' + id + ' is called ' + struct.name); }
}

ObjectDef = function() {
    return function(pName, pId) {
        //public interface
        this.name = pName;
        this.id = pId;
        this.getPrivateVar = function() { return myPrivateVar; }
        this.setPrivateVar = function(pText) { myPrivateVar = pText; }
        this.myFunc = myPrivateFunc;

        this.stat = struct;

        this.publicFunc = function() {
            myPrivateFunc();
            console.log('however I can be called from a public func of objectDef');
        }
    }

    //private stuff below
    var myPrivateVar = 'private '+ pName;

    function myPrivateFunc() {
        console.log('I am only visible inside the objectDef ');
    }
}();

var objectInstance1 = new ObjectDef('obj1', 1);

ObjectDef.prototype.staticProperty = 'I am available in all instances of ObjectDef';
ObjectDef.prototype.prototypeFunction = function() {return 'I am available everywhere, but I am not static: I can access ' + this.name + ' as well as ' + this.staticProperty;}

// prototypes are ONLY usefull for INHERITANCE (but not for static)

var objectInstance2 = new ObjectDef('obj2', 2);

console.log("o1 pubF " + objectInstance1.publicFunc());
console.log("o1 priV " + objectInstance1.getPrivateVar());
console.log("o2 priV " + objectInstance2.getPrivateVar());
objectInstance2.setPrivateVar('bla');
console.log("o1 priV " + objectInstance1.getPrivateVar());
console.log("o2 priV " + objectInstance2.getPrivateVar());

objectInstance1.staticProperty = 'overwritten static Prop :(';

console.log("o1 proP " + objectInstance1.staticProperty);
console.log("o2 proP " + objectInstance2.staticProperty);

console.log("o1 proF " + objectInstance1.prototypeFunction());
console.log("o2 proF " + objectInstance2.prototypeFunction());


console.log(objectInstance1);
console.log(objectInstance2);

// the functions defined in the constructor will be duplicated in memory for each instance :(
// thats why its probably better to define functions in the prototype instead of constructor
console.log(objectInstance1.getPrivateVar === objectInstance2.getPrivateVar);
console.log(objectInstance1.myFunc === objectInstance2.myFunc);
console.log(objectInstance1.stat === objectInstance2.stat);
objectInstance1.stat.bla = 'A';
console.log(objectInstance2.stat.bla);*/

window.activeAjaxRequestCount = 0;

function postAjax(path, data, success, method) {
    var xhr = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject('Microsoft.XMLHTTP');
    xhr.open(method || (data ? 'POST' : 'GET'), 'http://' + (document.location.host || 'www.solawi.fairtrademap.de') + (path.match(/^\//) ? path : ('/cgi-bin/resql.pl/' + path)) );
    xhr.onreadystatechange = function() {
        window.activeAjaxRequestCount--;
        if (window.activeAjaxRequestCount <= 0) {
            window.activeAjaxRequestCount = 0;
            hide('blockui_get');
            hide('blockui_post');
        }
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
    xhr.withCredentials = true;
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
    xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
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