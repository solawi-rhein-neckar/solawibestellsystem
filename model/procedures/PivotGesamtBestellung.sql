DROP PROCEDURE IF EXISTS `PivotGesamtBestellung`;
CREATE PROCEDURE `PivotGesamtBestellung`(
	IN `pYear` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN
DROP TEMPORARY TABLE IF EXISTS BenutzerBestellungenTemp;
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp  AS (
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
                  Replace(Replace(`Modul`.`Name`, 'utermodul', 'uter'), 'Quarkmodul' , 'Quark') AS Modul,
                 ModulInhalt.Produkt_ID,
                 ( IFNULL(`BenutzerModulAbo`.`Anzahl`,0) ) AS `Anzahl`,
                 IFNULL(`BenutzerModulAbo`.`Anzahl`,0) * IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))  * ModulInhalt.Anzahl AS Lieferzahl,
                 IF(Modul.ID = 4 and ModulInhalt.HauptProdukt, Benutzer.FleischAnteile - IFNULL(`BenutzerModulAbo`.`Anzahl`,0), 0) +
                 	(IF(ISNULL(ModulInhaltWoche.Anzahl) AND ISNULL(ModulInhaltDepot.Anzahl), NULL, IFNULL(ModulInhaltWoche.Anzahl,0) + IFNULL(ModulInhaltDepot.Anzahl, 0))
                 	* ModulInhalt.Anzahl * IF(Modul.ID = 4, 0, Benutzer.Anteile)
             		* IF(Modul.ID = 2 /*Milch*/,4,Modul.AnzahlProAnteil))
                 AS Gutschrift,
                 `BenutzerModulAbo`.BezahltesModul or Modul.ID = 4 AS BezahltesModul,
                 IFNULL(ModulInhaltWoche.Woche,ModulInhaltDepot.Woche) AS `Woche`
             FROM `Modul`
             JOIN Benutzer
             LEFT JOIN `BenutzerModulAbo`
                 ON `BenutzerModulAbo`.`Modul_ID` = `Modul`.`ID`
                 AND BenutzerModulAbo.Benutzer_ID = Benutzer.ID
                 AND ( ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ( pWoche >= `BenutzerModulAbo`.`StartWoche` ) )
                 AND (  ISNULL(`BenutzerModulAbo`.`EndWoche`)  OR ( pWoche <= `BenutzerModulAbo`.`EndWoche` ) )
             LEFT JOIN ModulInhalt ON pInhalt = TRUE AND ModulInhalt.Modul_ID = Modul.ID
             LEFT JOIN ModulInhaltWoche
             	ON ((pWoche is null
             		 AND (ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ModulInhaltWoche.Woche >= `BenutzerModulAbo`.`StartWoche`)
             		 AND (ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ModulInhaltWoche.Woche >= `BenutzerModulAbo`.`StartWoche`)
             	   ) OR ModulInhaltWoche.Woche = pWoche)
             	AND ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID
             	AND (ModulInhaltWoche.Anzahl IS NOT NULL)
             	AND ( ISNULL(ModulInhaltWoche.Depot_ID) OR ModulInhaltWoche.Depot_ID = 0 )
             LEFT JOIN ModulInhaltWoche AS ModulInhaltDepot
				ON ((pWoche is null
             		 AND (ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ModulInhaltDepot.Woche >= `BenutzerModulAbo`.`StartWoche`)
             		 AND (ISNULL(`BenutzerModulAbo`.`StartWoche`) OR ModulInhaltDepot.Woche >= `BenutzerModulAbo`.`StartWoche`)
             	   ) OR ModulInhaltDepot.Woche = pWoche)
             	AND ModulInhaltDepot.ModulInhalt_ID = ModulInhalt.ID
             	AND (ModulInhaltDepot.Anzahl IS NOT NULL)
             	AND ( ModulInhaltDepot.Depot_ID = Benutzer.Depot_ID )
             WHERE
                    (( `BenutzerModulAbo`.ID IS NOT NULL )
                 OR ( Modul.ID <> 4 AND ((Modul.AnzahlProAnteil * Benutzer.Anteile) > 0) )
                 OR ( Modul.ID = 4 /*Fleisch*/ AND Benutzer.FleischAnteile > 0 )
                 OR ( Modul.ID = 2 /*Milch*/ AND Benutzer.Anteile > 0 ))
                 AND (ModulInhalt.ID is null or ModulInhalt.HauptProdukt or ModulInhaltWoche.Anzahl > 0 or ModulInhaltDepot.Anzahl > 0)
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
             WHERE pWoche is null or `BenutzerZusatzBestellung`.`Woche` = pWoche
           )
        ) `u`
        JOIN `Benutzer` ON ( ( `u`.`Benutzer_ID` = `Benutzer`.`ID` ) )
        JOIN `Depot` ON ( ( `Benutzer`.`Depot_ID` = `Depot`.`ID` ) )
	    LEFT JOIN `BenutzerUrlaub`
	       	ON `BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
            AND  `BenutzerUrlaub`.`Woche` = `u`.`Woche`
      	LEFT JOIN Produkt on u.Produkt_ID = Produkt.ID
      	WHERE Benutzer.Depot_ID <> 0
);
END