/*
 *
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    This file is meant to be used by solawiTable.
*/
function SolawiTableOnClick(pSbs, pSolawiTable, pOnClickFunc) {

    /* public methods, this hash will be returned by this function, see last line: */
    const pub = {
    		enhanceDataCell: enhanceDataCell,
    		addColumnHeaders: addColumnHeaders,
    		addColumnCells: addColumnCells,
    		setResponse: function(pPath, pResponse) {if (solawiEditor) { solawiEditor.setResponse(pPath, pResponse); } }
    };

    /* private vars */
    var sbs = pSbs;
    var solawiTable = pSolawiTable;
    var onClickFunc = pOnClickFunc;


/**** public ****/

    function addColumnHeaders(tr, keys) {

    }

    function addColumnCells(tr, dataRow) {

    }

    function enhanceDataCell(div, key) {
        if ( (solawiTable.getTableName() != 'Benutzer' || div.dataId != '-1')
        	 && key != 'ID'
        	 && key != 'AenderBenutzer_ID'
        	 && key != 'AenderZeitpunkt'
        	 && key != 'ErstellZeitpunkt') {
            div.addEventListener('click', pOnClickFunc);
            div.style.cursor = "pointer";
            div.title = div.title ? div.title + "  -  click to edit!" : "click to edit!";
        }
    }

    return pub;
}
