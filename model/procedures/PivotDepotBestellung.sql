DROP PROCEDURE `PivotDepotBestellung`;
CREATE PROCEDURE `PivotDepotBestellung`(
	IN `pWoche` DECIMAL(6,2),
	IN `pDepot` INT
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('SUM(IF(Produkt = \'', Name, '\', IF(AnzahlZusatz is not null AND AnzahlZusatz <> 0, Anzahl + 0.001, Anzahl), 0)) AS `', IF((Nr*2) < 10,'0', ''), Nr*2, '.', Name, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('
	SELECT Benutzer as `00.',
		   pWoche, ' ',
		   (SELECT Name FROM Depot WHERE ID = pDepot),'`,
		   SUM( IF(Produkt = \'Milch, 0.5L\', cast(IF(AnzahlZusatz is not null AND AnzahlZusatz <> 0, Anzahl/2 + 0.0001, Anzahl/2) as decimal(9,4)), 0) ) AS `12.Milch`,',
		   @query, ',
		   SUM(Urlaub) as `99.',pWoche, ' Urlaub`,
		   GROUP_CONCAT(`subq`.Kommentar SEPARATOR \'; \') as `96.Kommentar`
	FROM
		(Select `BenutzerBestellungenTemp`.`Benutzer` AS `Benutzer`,
		     `BenutzerBestellungenTemp`.`Benutzer_ID` AS `Benutzer_ID`,
		     `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,
		     `BenutzerBestellungenTemp`.`Depot` AS `Depot`,
		     IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`) AS `Produkt`,
		     `BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,
		     `BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,
		     `BenutzerBestellungenTemp`.`Menge` AS `Menge`,
		     `BenutzerBestellungenTemp`.`Woche` AS `Woche`,
			 sum(`BenutzerBestellungenTemp`.`Anzahl`) AS `Anzahl`,
		     sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`,
		     sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,
		     sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
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
							else concat(\' \',Produkt) end, \': \', `BenutzerBestellungenTemp`.`Kommentar`)
		         END
		      ) SEPARATOR \', \' ) AS `Kommentar`
		From `BenutzerBestellungenTemp`
		Group By
		    IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`),
		    `BenutzerBestellungenTemp`.`Woche`,
		    `BenutzerBestellungenTemp`.`Benutzer_ID`,
		    `BenutzerBestellungenTemp`.`Depot_ID`
		Order By
		    `BenutzerBestellungenTemp`.`Benutzer_ID`, `BenutzerBestellungenTemp`.`Depot`, IFNULL(BenutzerBestellungenTemp.Modul,`BenutzerBestellungenTemp`.`Produkt`)
	) subq
	WHERE Woche = ', pWoche ,'
	AND Depot_ID = ',pDepot,'
	GROUP BY Benutzer WITH ROLLUP
');

CALL BenutzerBestellung(pWoche, FALSE);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END