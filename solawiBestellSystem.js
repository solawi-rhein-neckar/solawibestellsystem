/*
    Defined as (closure-)function, because we don't want to put all our private variables into the global namespace.
    The new operator is not required! (We do not use 'this' anywhere in the code).

    Its expected to create max. 1 instance!

    var SBS = SolawiBestellSytem();  // no need to use 'new' or Object.create!
*/
function SolawiBestellSystem() {
   const pub = {
        fillCache: fillCache,
        saveOrdersIntoProductCache: saveOrdersIntoProductCache
    };
    /* public fields */
    pub.date = new Date();
    pub.day = 4;
    pub.week = pub.date.getWeekYear() + (pub.date.getWeek() > (pub.date.getDay() == 0 || pub.date.getDay() > pub.day ? 8 : 9 ) ? "." : ".0") +  (pub.date.getDay() == 0 || pub.date.getDay() > pub.day ? pub.date.getWeek() + 1 : pub.date.getWeek());
    pub.selectedWeek = pub.week;
    pub.disableUnavailableProducts = 0;
    pub.user = null;

    /* private constants */
    const tableCache = {'Modul':[],'Role':[],'Depot':[],'Produkt':[]};
    pub.tableCache = tableCache;

    /* public */
    function fillCache(tableName) {
        getAjax(tableName, function(resp) {
            tableCache[tableName] = [];
            // convert response (array) into hash (by ID)
            for(var i = 0; i < resp.length; i++) {
                tableCache[tableName][resp[i]['ID']] = resp[i];
            }
        });
    }

    function saveOrdersIntoProductCache(response) {
        //save ZusatzBestellCount into ProductCache, so it can be reused for Validation!
        if (tableCache['Produkt']) {
            // first reset for all products. Because response will not contain orders for products that are NOT ordered
            for (var i = 0; i < tableCache['Produkt'].length; i++) {
                if (tableCache['Produkt'][i]) {
                    tableCache['Produkt'][i]['AnzahlZusatzBestellung'] = 0;
                    tableCache['Produkt'][i]['AnzahlBestellung'] = 0;
                }
            }
        }
        for (var i = 0; i<response.length; i++) {
            var row = response[i];
            if (tableCache['Produkt'] && (row.Produkt_ID || row.Produkt_ID === 0) && tableCache['Produkt'][row.Produkt_ID]) {
                tableCache['Produkt'][row.Produkt_ID]['AnzahlZusatzBestellung'] = row.AnzahlZusatz;
                tableCache['Produkt'][row.Produkt_ID]['AnzahlBestellung'] = row.Anzahl;
            }
        }
    }

    return pub;
}