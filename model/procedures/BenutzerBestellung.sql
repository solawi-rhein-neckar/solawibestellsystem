DROP PROCEDURE `BenutzerBestellung`;
CREATE PROCEDURE `BenutzerBestellung` (
   IN `pWoche` DECIMAL(6,2),
   IN `pInhalt` BOOLEAN
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
DROP TEMPORARY TABLE IF EXISTS BenutzerBestellungenTemp;
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp ENGINE=MEMORY AS (
   SELECT
   `u`.`Benutzer_ID` AS `Benutzer_ID`,
   `Benutzer`.`Name` AS `Benutzer`,
   `Depot`.`ID` AS `Depot_ID`,
   `Depot`.`Name` AS `Depot`,
   `u`.Modul AS Modul,
   `Produkt`.`ID` as Produkt_ID,
   `Produkt`.`Produkt` as Produktname,
   `Produkt`.`Name` as Produkt,
   `Produkt`.`Beschreibung`,
   `Produkt`.`Einheit`,
   `Produkt`.`Menge`,
   `u`.`Woche` AS `Woche`,
   `u`.`Kommentar` AS `Kommentar`,
   ( CASE WHEN NOT ISNULL(`BenutzerUrlaub`.`ID`) THEN 0 WHEN pInhalt = TRUE THEN `u`.`Lieferzahl` ELSE `u`.`Anzahl` END ) AS `Anzahl`,
   CASE WHEN(`u`.`Quelle` = 1) THEN `u`.`Anzahl` ELSE 0 END AS `AnzahlModul`,
   CASE WHEN(`u`.`Quelle` = 2) THEN `u`.`Anzahl` ELSE 0 END AS `AnzahlZusatz`,
   case when (`u`.`BezahltesModul` = 0) then (`u`.`Lieferzahl` * `Produkt`.`Punkte`) else 0 end AS `Punkte`,
   `u`.`Gutschrift` * `Produkt`.`Punkte` AS Gutschrift,
   ( `BenutzerUrlaub`.`ID` IS NOT NULL ) AS `Urlaub`
   FROM (
           (SELECT
                 1 AS `Quelle`,
                 `Benutzer`.`ID` AS `Benutzer_ID`,
                 `BenutzerModulAbo`.`Kommentar` AS `Kommentar`,
                  Replace(Replace(`Modul`.`Name`, 'Kräutermodul', 'Kräuter'), 'Quarkmodul' , 'Quark, 400g') AS Modul,
                 ModulInhalt.Produkt_ID,
                 ( IFNULL(`BenutzerModulAbo`.`Anzahl`,0) ) AS `Anzahl`,
                 IFNULL(`BenutzerModulAbo`.`Anzahl`,0) * ModulInhaltWoche.Anzahl * ModulInhalt.Anzahl AS Lieferzahl,
                 ModulInhaltWoche.Anzahl * ModulInhalt.Anzahl * IF(Modul.ID = 4,Benutzer.FleischAnteile,Benutzer.Anteile) * IF(Modul.ID = 2,3,Modul.AnzahlProAnteil) AS Gutschrift,
                 `BenutzerModulAbo`.BezahltesModul,
                 pWoche AS `Woche`
             FROM `Modul`
             JOIN Benutzer
             LEFT JOIN `BenutzerModulAbo`
                 ON `BenutzerModulAbo`.`Modul_ID` = `Modul`.`ID`
                 AND BenutzerModulAbo.Benutzer_ID = Benutzer.ID
                 AND ( ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ( pWoche >= `BenutzerModulAbo`.`StartWoche` ) )
                 AND (  ISNULL(`BenutzerModulAbo`.`EndWoche`)  OR ( pWoche <= `BenutzerModulAbo`.`EndWoche` ) )
             LEFT JOIN ModulInhalt ON pInhalt = TRUE AND ModulInhalt.Modul_ID = Modul.ID
             LEFT JOIN ModulInhaltWoche
             	ON ModulInhaltWoche.Woche = pWoche
             	AND ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID
             	AND ( ISNULL(ModulInhaltWoche.Depot_ID) OR ModulInhaltWoche.Depot_ID = Benutzer.Depot_ID )
             WHERE
                    ( `BenutzerModulAbo`.ID IS NOT NULL )
                 OR ( Modul.ID <> 4 AND ((Modul.AnzahlProAnteil * Benutzer.Anteile) > 0) )
                 OR ( Modul.ID = 4 /*Fleisch*/ AND Benutzer.FleischAnteile > 0 )
                 OR ( Modul.ID = 2 /*Milch*/ AND Benutzer.Anteile > 0 )
           )
           UNION ALL
           (SELECT
                 2 AS `Quelle`,
                 `BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
                 `BenutzerZusatzBestellung`.`Kommentar` AS `Kommentar`,
                 NULL as Modul,
                 `BenutzerZusatzBestellung`.`Produkt_ID`,
                 `BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
                 `BenutzerZusatzBestellung`.`Anzahl` AS `Lieferzahl`,
                 0 as Gutschrift,
                 0 as BezahltesModul,
                 `BenutzerZusatzBestellung`.`Woche` AS `Woche`
             FROM `BenutzerZusatzBestellung`
             WHERE `BenutzerZusatzBestellung`.`Woche` = pWoche
           )
        ) `u`
        JOIN `Benutzer` ON ( ( `u`.`Benutzer_ID` = `Benutzer`.`ID` ) )
        JOIN `Depot` ON ( ( `Benutzer`.`Depot_ID` = `Depot`.`ID` ) )
	    LEFT JOIN `BenutzerUrlaub`
	       	ON `BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
            AND  `BenutzerUrlaub`.`Woche` = `u`.`Woche`
      	LEFT JOIN Produkt on u.Produkt_ID = Produkt.ID
      	WHERE Benutzer.Depot_ID <> 16
);
END