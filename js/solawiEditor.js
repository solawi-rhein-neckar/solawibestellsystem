/*
 * Requires: solawiValidator
 *
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

*/
function SolawiEditor(pSbs, pOnEntitySaved, pDisableUnavailableProducts, pEditorSuffix) {

    /*privat var needed inside pub*/
    var editorSuffix = pEditorSuffix === true || !pEditorSuffix ? '' : pEditorSuffix;
    var memberEditor = editorSuffix ? MemberEditor(pSbs, pEditorSuffix, pOnEntitySaved) : null;

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
            showEditorForCell: showEditorForCell,
            showForAdding: showForAdding,
            showForBatchOrder: showForBatchOrder,
            setResponse: function(pPath, pResponse) {
                if (tableValidator) { tableValidator.setResponse(pPath, pResponse); }
                responseCache = pResponse;
            },
            setKeys: setKeys,
            addCopyBtn: memberEditor && memberEditor.addCopyBtn
    };

    /* private vars */
    var tableName; /* needs to be initialized on showing editor */
    var sbs = pSbs;
    var onEntitySaved = pOnEntitySaved;
    var disableUnavailableProducts = pDisableUnavailableProducts;
    var tableValidator = disableUnavailableProducts ? SolawiValidator(sbs) : null;
    var keys;
    var responseCache;
    var dataId;

    const numberColumnNames = {
            'Menge':1
            ,'Anzahl':1
            ,'AnzahlModul':1
            ,'AnzahlZusatz':1
            ,'AnzahlZusatzBestellungMax':1
            ,'MindestAnzahl':1
            ,'MaximalAnzahl':1
            ,'Anteile':1
            ,'FleischAnteile':1
            ,'Punkte':1
            ,'Menge':0.01
        }

    function setKeys(pKeys) {keys = pKeys;}

    function showEditorForCell(pTableName, event) {
        tableName = pTableName;
        var edit = resetEditor(tableName + " | ID " + event.target.dataId + ": ");

        var label = document.createElement('SPAN');
        label.innerText=event.target.dataKey + ": ";
        var inp = createInput(event.target.dataKey);
        inp.dataId = event.target.dataId;
        inp.value = event.target.dataValue || event.target.innerText;
        inp.dataValue = inp.value;
        inp.addEventListener('keypress', saveEditorInputs);
        /*inp.addEventListener('change', saveEditorInputs);*/

        edit.appendChild(label);
        edit.appendChild(inp);
        finishEditor(edit);
    }

    function showForAdding(pTableName, defaults) {
        finishEditor(initForAdding(pTableName, defaults, {'NOTES':1,'ID':1, 'ErstellZeitpunkt':1, 'AenderBenutzer_ID':1, 'AenderZeitpunkt':1}));
    }

    function showForBatchOrder(defaults) {
        finishBatchOrder(initForAdding('BenutzerZusatzBestellung', defaults, {'Woche':1,'ID':1, 'ErstellZeitpunkt':1, 'AenderBenutzer_ID':1, 'AenderZeitpunkt':1}));
    }

    function initForAdding(pTableName, defaults, hiddenFields) {
        tableName = pTableName;
        dataId = defaults && defaults.dataId;
        var edit = resetEditor((defaults && defaults.dataId && responseCache ? "Bearbeiten: " : "Neu hinzufügen: ") + tableName);

        if (defaults['Benutzer_ID'] && !keys.includes('Benutzer_ID')) {
            var inp = createInput('Benutzer_ID');
            inp.value = defaults['Benutzer_ID'];
            edit.appendChild(inp);
        }

        for (var j = 0; j < keys.length; j++) {
            if ((! hiddenFields[keys[j]]) && !(tableName == 'Benutzer' && keys[j].match(/^wp.*$/) && (!keys[j].match(/^wp(Mit)?ID$/)) && !(defaults && defaults.dataId)) ) {

                var inp = createInput(keys[j]);

                if (defaults && defaults.dataId && responseCache) {
                    inp.dataId = defaults.dataId;
                    for (var k = 0; k < responseCache.length; k++) {
                        if (responseCache[k] && responseCache[k].ID == defaults.dataId) {
                            inp.value = responseCache[k][keys[j]] || responseCache[k][keys[j]] === 0 ? responseCache[k][keys[j]] : '';
                            inp.dataValue = inp.value;
                        }
                    }
                } else if (keys[j] == 'Benutzer_ID') {
                    inp.value = defaults['Benutzer_ID'] ? defaults['Benutzer_ID'] : sbs.user.ID;
                } else if (keys[j] == 'Depot_ID') {
                    inp.value = defaults['Depot_ID'] ? defaults['Depot_ID'] : sbs.user.Depot_ID;
                } else if ((keys[j] == 'Woche' || keys[j] == 'PunkteWoche'|| keys[j] == 'AnteileStartWoche') && sbs.selectedWeek) {
                    inp.value = sbs.selectedWeek;
                } else if (keys[j] == 'Anteile' || keys[j] == 'FleischAnteile') {
                    inp.value = 1;
                } else if (keys[j] == 'wpID' && defaults['wpID']) {
                    inp.value = defaults['wpID'];
                } else if (keys[j] == 'Name' && defaults['Name']) {
                    inp.value = defaults['Name'];
                } else if (keys[j] == 'Benutzer_ID') {
                    inp.value = defaults['Benutzer_ID'] ? defaults['Benutzer_ID'] : sbs.user.ID;
                }
                var div = document.createElement('DIV');
                var label = document.createElement('SPAN');
                div.appendChild(label);
                div.appendChild(inp);
                label.innerText=keys[j] + ": ";
                div.style.padding = '2px';
                div.style.textAlign = 'left';
                label.style.display = 'inline-block';
                label.style.width = '150px';
                label.style.overflow = 'hidden';
                div.className = inp.className;
                edit.appendChild(div);


                if (keys[j] == 'Kommentar' && tableName == 'BenutzerZusatzBestellung') {
                    div.style.display = 'none';
                    div.id='inp_kommentar_hidden';
                }
                if (keys[j] == 'Anzahl' && tableName == 'BenutzerZusatzBestellung') {
                    inp.id='inp_anzahl_zusatz';
                }
            }
        }
        return edit;
    }

    function createInput(key) {
        var inp;

        /* foreign key lookup in sbs.tableCache */
        var relation = key.match(/^(?:Besteller|Verwalter)?(.*)_ID$/);
        if (relation && sbs.tableCache[relation[1]]) {
            inp = createInputSelect(sbs.tableCache[relation[1]]);
        } else if (key.match(/^(AnteileStart|Start|End|Punkte)?Woche$/)) {
            inp = createInputDateSelect();
        } else {
            inp = document.createElement("INPUT");
            if (numberColumnNames[key] ||  key.match(/^(.*)_ID$/)) {
                inp.type="number";
                inp.step=numberColumnNames[key] || 1;
                inp.min=key.match(/^(.*)_ID$/) ? "0" : "-10";
                inp.max=key.match(/^(.*)_ID$/) ? "99999" : "999";
            } else if (key.match(/^(Start|End|Punkte)?Woche$/)) {
                inp.pattern="^(2019|2020|2021|2022|9999)[.](0[1-9]|[1-4][0-9]|5[0-3])$"
            } else if (tableName == 'Solawi' && key.match(/^Wert$/)) {
                inp.pattern="^(2019|2020|2021|2022|9999)[.](0[1-9]|[1-4][0-9]|5[0-3])$"
            }
        }
        inp.className = 'editor inp_' + key;
        inp.dataKey = key;
        /*inp.placeholder = key;*/
        return inp;
    }

    /*private*/
    function createInputSelect(response) {
        inp = document.createElement("SELECT");
        var lastOption = null;
        if (response.slice && response.sort && response.length > 0) {
        response = response.slice();
            if ((response[0] && response[0]['Nr']) || (response.length > 1 && response[1] && response[1]['Nr'])) {
                response.sort( function rowSortFunc(a,b) { return a['Nr'] < b['Nr'] ? -1 : a['Nr'] > b['Nr'] ? 1 : 0; } );
            } else {
                response.sort( function rowSortFunc(a,b) { return a['Name'] < b['Name'] ? -1 : a['Name'] > b['Name'] ? 1 : 0; } );
            }
        }
        for (var k=0; k<response.length; k++) {
            var row = response[k];
            if (row && (row.ID || row.ID === 0)  && ((!disableUnavailableProducts) || (!row.Nr) || row.AnzahlZusatzBestellungMax > 0 || row.Nr <= 900)) {
                var opt = document.createElement("OPTION");
                opt.value=row.ID;
                opt.innerText=row.Name;
                if (disableUnavailableProducts && (row.AnzahlZusatzBestellungMax < 0 || (row.AnzahlZusatzBestellung > 0 && row.AnzahlZusatzBestellungMax <= row.AnzahlZusatzBestellung) || (row.AnzahlZusatzBestellungMax == 0 && row.AnzahlBestellung <= 0) )) {

                    opt.disabled='disabled';
                    if (row.AnzahlZusatzBestellungMax <= 0) {
                        opt.innerText+=' (nur abo)';
                    } else {
                        opt.innerText+=' (max. ' + row.AnzahlZusatzBestellungMax + ')';
                    }
                    opt.title='Maximale Zusatz-Bestellmenge überschritten!';
                }
                if (row.ID === 0) {
                    lastOption = opt;
                } else {
                    inp.appendChild(opt);
                }
            }
        }
        if (lastOption) {
            inp.appendChild(lastOption);
            inp.onchange=function(event){
                if (document.getElementById('inp_kommentar_hidden') && document.getElementById('inp_anzahl_zusatz')) {
                    if (event.target.value == '0') {
                        document.getElementById('inp_kommentar_hidden').style.display='block';
                        document.getElementById('inp_anzahl_zusatz').style.display='none';
                        document.getElementById('inp_anzahl_zusatz').value = '1';
                    } else {
                        document.getElementById('inp_kommentar_hidden').style.display='none';
                        document.getElementById('inp_anzahl_zusatz').style.display='inline-block';
                    }
                }
            };
        }
        return inp;
    }

    /*private*/
    function createInputDateSelect() {
        inp = document.createElement("SELECT");
        for (var year=2019; year<=(new Date().getFullYear()) + 3; year++) {
            for (var month=1; month<=weekCount(year); month++) {
                var opt = document.createElement("OPTION");
                opt.value=year + (month < 10 ? '.0' : '.') + month;
                opt.innerText=opt.value;
                if ((!disableUnavailableProducts) || opt.value >= sbs.week) {
                    inp.appendChild(opt);
                }
            }
        }
        var opt = document.createElement("OPTION");
        opt.value='9999.99';
        opt.innerText=opt.value;
        inp.appendChild(opt);
        return inp;
    }

    function resetEditor(pLabel) {
        var edit = document.getElementById('editor'+editorSuffix);
        var label = document.createElement("DIV");
        edit.className = 'edit' + tableName;
        label.innerText = pLabel.replace('BenutzerZusatzBestellung', 'Tausch').replace('BenutzerModulAbo', 'Jede_Woche-Abo');
        label.className = 'editorLabel';
        label.style.fontWeight = 'bold';
        label.style.padding = '0 0 8px 0';
        while (edit.firstChild) edit.removeChild(edit.firstChild);
        edit.appendChild(label);
        setContent('editError'+editorSuffix, '');
        show('blockui_edit'+editorSuffix);
        return edit;
    }

    function finishEditor(edit) {
        var btnCtnr = document.getElementById('editorSaveBtn'+editorSuffix);
        if (btnCtnr) {
            while (btnCtnr.firstChild) btnCtnr.removeChild(btnCtnr.firstChild);
        } else {
            btnCtnr = document.createElement("DIV");
            btnCtnr.id = 'editorSaveBtn'+editorSuffix;
            btnCtnr.style.textAlign = 'center';
            edit.parentNode.appendChild(btnCtnr);
        }
        btnEle = document.createElement("BUTTON");
        btnEle.innerText="Speichern";
        btnEle.style['margin-left'] = '5px';
        btnEle.style['margin-right'] = '10px';
        btnEle.addEventListener('click', saveEditorInputs);

        var btn2 = document.createElement("BUTTON");
        btn2.innerText="Abbrechen";
        btn2.addEventListener('click', function(){if (collectChangedInputData().size == 0 || (tableName == 'BenutzerZusatzBestellung' && !dataId) || confirm('Änderung verwerfen?')){hide('blockui_edit'+editorSuffix);}});
        btnCtnr.appendChild(btnEle);
        btnCtnr.appendChild(btn2);

        if (memberEditor) {
            memberEditor.enhanceEditor(edit, btnCtnr, dataIdGetter, createInputDateSelect);
        } else {
            var info = document.getElementById('benutzerEditor'+editorSuffix);
            if (info) {
                info.parentNode.removeChild(info);
            }
            var stornoBtn = document.getElementById('stornoCtnr'+editorSuffix);
            if (stornoBtn) {
                stornoBtn.parentNode.removeChild(stornoBtn);
            }
        }
    }

    function dataIdGetter() {
        return dataId;
    }

    function saveEditorInputs(event2) {
        validateAndProceed(event2, function(id, sendData) {
            if (memberEditor && Object.keys(sendData)) {
                memberEditor.saveToDb(tableName, id, sendData);
            } else {
                postAjax(tableName + (id ? '/'+id : ''), sendData, onEntitySaved);
            }
            hide('blockui_edit'+editorSuffix);
        });
    }

    function validateAndProceed(event2, onSuccessCallback) {
        if (event2.keyCode == null /*blur*/ || event2.keyCode == 13 /*enter*/) {
            event2.target.disabled='disabled';

            var result = collectChangedInputData();

            if (result.size == 0 || (tableValidator &&   ! tableValidator.validateEditorInput(result.data, result.id) )) {
                if (result.size == 0) {
                    setContent('editError'+editorSuffix, 'Nichts geändert! - Abbrechen clicken');
                }
                event2.target.disabled='';
            } else {
                onSuccessCallback(result.id, result.sendData);
            }
        }

    }

    function collectChangedInputData() {
        var id;
        var data = {};
        var sendData = {};
        var size = 0;
        var editor = document.getElementById('editor'+editorSuffix);
        for (var i = 0; i < editor.children.length; i++) {
            var ele = editor.children[i];
            var inpEle = ele;
            if (ele.tagName == 'DIV') {
                for (var j = 0; j <  ele.children.length; j++) {
                    if (ele.children[j].tagName == 'INPUT' || ele.children[j].tagName == 'SELECT') {
                        inpEle = ele.children[j];
                    }
                }
            }
            if (inpEle.tagName == 'INPUT' || inpEle.tagName == 'SELECT') {
                if ( ((! inpEle.dataValue) && (!(inpEle.dataValue === '')) && !(inpEle.dataValue === 0)) || inpEle.value != inpEle.dataValue) {
                    data[inpEle.dataKey] = inpEle.value;
                    sendData[inpEle.dataKey] = inpEle.value;
                    id = id || inpEle.dataId;
                    size++;
                } else {
                    console.log('not saving unchanged field ' + inpEle.dataKey);
                }
            }
        }
        return {id: id, data: data, sendData: sendData, size: size};
    }

    function finishBatchOrder(edit) {
        var btnCtnr = document.getElementById('editorSaveBtn'+editorSuffix);
        if (btnCtnr) {
            while (btnCtnr.firstChild) btnCtnr.removeChild(btnCtnr.firstChild);
        }
        var linebreak = document.createElement("br")
        var btn = document.createElement("BUTTON");
        btn.innerText="Serien-Bestellung";
        btn.style['margin-left'] = '5px';
        btn.style['margin-right'] = '10px';
        btn.addEventListener('click', showBatchOrderWeekSelect);

        var btn2 = document.createElement("BUTTON");
        btn2.innerText="Schließen";
        btn2.addEventListener('click', function(){hide('blockui_edit'+editorSuffix);onEntitySaved();});
        edit.appendChild(linebreak);
        edit.appendChild(btn);
        edit.appendChild(btn2);

        var dv = document.createElement("DIV");
        dv.innerHTML="Hinweis: Für mehr/weniger Brot, Milch, Käse, Kartoffeln in JEDER Woche -> fragt euren Depot-Besteller!<br/>"
                    +"Serienbestellung nur verwenden, wenn NICHT jede Woche (z.Bsp. alle 2 Wochen) oder für andere Produkte.";
        dv.style['margin-top'] = '10px';
        edit.appendChild(dv);
    }

    function showBatchOrderWeekSelect(event2) {
        validateAndProceed(event2, function(id, sendData) {
            setContent('editError'+editorSuffix, '');
            var editor = document.getElementById('editor'+editorSuffix);
            for (var i = 0; i < editor.children.length; i++) {
                var inpEle = editor.children[i];
                if (inpEle.nodeName == 'INPUT' || inpEle.nodeName == 'SELECT') {
                    inpEle.disabled='disabled';
                }
            }

            var div = document.createElement("DIV");
            div.style.paddingTop="10px";
            div.innerText="Nun nacheinander die Kalender-Wochen anwählen, für welche obige Bestellung gelten soll:";
            editor.appendChild(div);

        div = document.createElement("DIV");
            editor.appendChild(div);

            var weekSelect = Object.create(WeekSelect);
            weekSelect.year = Number(sbs.selectedWeek.match(/[0-9]+/)[0]);
            weekSelect.week = sbs.week;
            weekSelect.label = 'Bestellung';
            weekSelect.labels = 'Bestellungen';
            weekSelect.tableName = 'BenutzerZusatzBestellung/Benutzer_ID/' + (sendData['Benutzer_ID'] ? sendData['Benutzer_ID'] : sbs.user.ID) + '/Produkt_ID/' + sendData['Produkt_ID'] + "/Anzahl/" + sendData['Anzahl'];
            weekSelect.onValidate = disableUnavailableProducts && tableValidator ? function(elem, postData, willDelete) {
                setContent('editError'+editorSuffix, '');
                if (willDelete || ! postData['Woche']) {
                    weekSelect.doSave(elem);
                } else {
                    getAjax('BenutzerBestellungView/Benutzer_ID/MY/Woche/' + postData['Woche'], function(response) {
                        sbs.saveOrdersIntoProductCache(response);
                        if (tableValidator.validateEditorInput(postData)) {
                            weekSelect.doSave(elem);
                        }
                    });
                }
            } : null;
            weekSelect.postData = {
                Benutzer_ID : (sendData['Benutzer_ID'] ? sendData['Benutzer_ID'] : sbs.user.ID),
                Produkt_ID : sendData['Produkt_ID'],
                Anzahl: sendData['Anzahl'],
                Woche : sbs.selectedWeek
            };
            weekSelect.allowMulti = !disableUnavailableProducts;
            weekSelect.allowPast = false;
            weekSelect.addTo(div);

            div = document.createElement("DIV");
            div.style.paddingTop="10px";
            div.innerHTML="Hinweis: schon vorhandene (Serien-)-Bestellungen werden hier nur angezeigt,<br/>wenn exakt die selbe Anzahl haben: Sind in einer Woche schon 2 Stück bestellt,<br/>sieht man dies hier nicht, falls hier 3 als Anzahl ausgewählt wurde.";
            editor.appendChild(div);
        });
    }

    return pub;
}