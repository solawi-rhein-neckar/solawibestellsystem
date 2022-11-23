DROP PROCEDURE IF EXISTS `PivotSolawiBestellung`;
CREATE PROCEDURE `PivotSolawiBestellung`(
	IN `pWoche` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \'', Name, '\', Anzahl, 0)) AS `', IF(Nr < 10,'0', ''), Nr, '.', Name, '`' ))  FROM Produkt WHERE Nr <= 900 ORDER BY Nr);

SET @query = CONCAT('
	SELECT Depot as `00.',pWoche,'`,
		   SUM( IF(Produkt = \'Milch, 0.5L\', cast(Anzahl/2 as decimal(5,1)), 0) ) AS `06.Milch`,',
		   @query, ',
		   SUM(IF(NOT (Produkt LIKE \'Gem_se\'),0, Urlaub)) as `99.', pWoche,' Urlauber`,
		  SUM(IF((NOT (Produkt LIKE \'Gem_se\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Count(*) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `97.Mitglieder`,
		  SUM(IF((NOT (Produkt LIKE \'Gem_se\')) OR BenutzerId <> (SELECT Min(ID) FROM Benutzer Where Benutzer.Depot_ID = subq.Depot_ID),0, (SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`))) as `98.Anteile`,
		  GROUP_CONCAT(`subq`.Kommentar SEPARATOR \', \') as `96.Kommentar`
	FROM
		(Select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
			 `BenutzerBestellungenTemp`.`Depot` AS `Depot`,
			 IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`) AS `Produkt`,
			 `BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
			 `BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,
			 `BenutzerBestellungenTemp`.`Menge` AS `Menge`,
			 `BenutzerBestellungenTemp`.`Woche` AS `Woche`,
			 GREATEST(0, sum(`BenutzerBestellungenTemp`.`Anzahl`)) AS `Anzahl`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
			 sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
			 sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
			 BenutzerBestellungenTemp.Benutzer_ID as BenutzerId,
 			 GROUP_CONCAT( (
	         	CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'\'
						or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'-\'
					    or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \'Tausch\') THEN NULL
				ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID),
	            			case when Produkt is null
								   or TRIM(Produkt) = \'\'
								   or TRIM(Produkt) = \'-\'
								   or TRIM(Produkt) = \'Kommentar\'
							then \'\'
							else concat(\' \', Produkt) end, \': \', `BenutzerBestellungenTemp`.`Kommentar`)
	         	END
	      	 ) SEPARATOR \', \') AS `Kommentar`
	    From `BenutzerBestellungenTemp`
	    Group By
			IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`),
	   		`BenutzerBestellungenTemp`.`Woche`,
	   		`BenutzerBestellungenTemp`.`Depot_ID`,
	   		BenutzerId
	    Order By
			`BenutzerBestellungenTemp`.`Depot`, IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`)
	) subq
	WHERE Woche = ', pWoche ,'
	GROUP BY Depot WITH ROLLUP
');

CALL BenutzerBestellung(pWoche, FALSE);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END