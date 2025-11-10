DROP PROCEDURE IF EXISTS PivotGesamtBestellungWoche2025;
CREATE PROCEDURE PivotGesamtBestellungWoche2025()
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN
DECLARE pWoche INT Default  27;
DECLARE pYear INT Default  2024;

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \'', Name, '\', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt WHERE Nr <= 900 ORDER BY Nr);

SET @query = CONCAT('
	SELECT Woche,
		   SUM( IF(Produkt = \'Milch, 0.5L\', cast(Anzahl/2 as decimal(5,1)), 0) ) AS `06.Milch`,',
		   @query, ',
		   SUM(IF(NOT (Produkt LIKE \'Gemuese\'),0, Urlaub)) as `99.year2025 Urlauber`,
		  SUM(IF((NOT (Produkt LIKE \'Gemuese\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Count(*) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `97.Mitglieder`,
		  SUM(IF((NOT (Produkt LIKE \'Gemuese\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `98.Anteile`,
		  SUM(IF((NOT (Produkt LIKE \'Gemuese\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `01.Anteile`,
		  GROUP_CONCAT(`subq`.Kommentar SEPARATOR \', \') as `96.Kommentar`
	FROM
		(Select `GesamtBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
			 `GesamtBestellungenTemp`.`Depot` AS `Depot`,
			 IFNULL(GesamtBestellungenTemp.Modul,`GesamtBestellungenTemp`.`Produkt`) AS `Produkt`,
			 `GesamtBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
			 `GesamtBestellungenTemp`.`Einheit` AS `Einheit`,
			 `GesamtBestellungenTemp`.`Menge` AS `Menge`,
			 `GesamtBestellungenTemp`.`Woche` AS `Woche`,
			 GREATEST(0, sum(`GesamtBestellungenTemp`.`Anzahl`)) AS `Anzahl`,
			 sum(`GesamtBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
			 sum(`GesamtBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
			 sum(`GesamtBestellungenTemp`.`Urlaub`) AS `Urlaub`,
			 GesamtBestellungenTemp.Benutzer_ID as BenutzerId,
 			 GROUP_CONCAT( (
	         	CASE WHEN(`GesamtBestellungenTemp`.`Kommentar` is NULL
						or TRIM(`GesamtBestellungenTemp`.`Kommentar`) = \'\'
						or TRIM(`GesamtBestellungenTemp`.`Kommentar`) = \'-\'
					    or TRIM(`GesamtBestellungenTemp`.`Kommentar`) like \'Tausch\') THEN NULL
				ELSE concat((select name from Benutzer where Benutzer.ID = GesamtBestellungenTemp.Benutzer_ID),
	            			case when Produkt is null
								   or TRIM(Produkt) = \'\'
								   or TRIM(Produkt) = \'-\'
								   or TRIM(Produkt) = \'Kommentar\'
							then \'\'
							else concat(\' \', Produkt) end, \': \', `GesamtBestellungenTemp`.`Kommentar`)
	         	END
	      	 ) SEPARATOR \', \') AS `Kommentar`
	    From `GesamtBestellungenTemp`
	    Group By
			IFNULL(GesamtBestellungenTemp.Modul,`GesamtBestellungenTemp`.`Produkt`),
	   		`GesamtBestellungenTemp`.`Woche`,
	   		`GesamtBestellungenTemp`.`Depot_ID`,
	   		BenutzerId
	    Order By
			`GesamtBestellungenTemp`.`Depot`, IFNULL(GesamtBestellungenTemp.Modul,`GesamtBestellungenTemp`.`Produkt`)
	) subq

	GROUP BY Woche WITH ROLLUP
');

   DROP TEMPORARY TABLE IF EXISTS GesamtBestellungenTemp;

   WHILE pYear != 2025 or pWoche != 27 DO
         IF pWoche = 53 THEN SET pWoche=1; SET pYear=pYear+1; END IF;

         CALL BenutzerBestellung( CONCAT(pYear,IF(pWoche < 10, '.0', '.'), pWoche), TRUE);

		IF pYear = 2024 AND pWoche = 27 THEN   CREATE TEMPORARY TABLE IF NOT EXISTS GesamtBestellungenTemp  CHARACTER SET utf8mb4 AS (SELECT `Benutzer_ID`, `Benutzer`,`Depot_ID`,`Depot`,Modul,Produkt_ID,Produktname,Produkt,`Beschreibung`,`Einheit`,`Menge`,`Nr`,`Woche`,Kommentar,`Anzahl`,`AnzahlModul`,`AnzahlZusatz`,`Punkte`,Gutschrift,`Urlaub` FROM BenutzerBestellungenTemp); END IF;

		IF pWoche <> 27 or pYear <> 2024 THEN   INSERT INTO GesamtBestellungenTemp SELECT `Benutzer_ID`, `Benutzer`,`Depot_ID`,`Depot`,Modul,Produkt_ID,Produktname,Produkt,`Beschreibung`,`Einheit`,`Menge`,`Nr`,`Woche`,Kommentar,`Anzahl`,`AnzahlModul`,`AnzahlZusatz`,`Punkte`,Gutschrift,`Urlaub` FROM BenutzerBestellungenTemp;    	END IF;

		SET pWoche=pWoche+1;
   END WHILE;

   PREPARE stt FROM @query; EXECUTE stt; DEALLOCATE PREPARE stt;
END

