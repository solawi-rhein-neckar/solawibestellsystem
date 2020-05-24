BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(Produkt = \'', Produkt, '\', Anzahl, 0)) AS `', Produkt, '`' ))  FROM Produkt ORDER BY Nr);

SET @query = CONCAT('SELECT Depot, MAX(IF(Produkt = \'Milch, 0.5L\', Anzahl / 2, 0)) AS `Milch`,', @query, ' , MAX(Urlaub) as `Urlauber`,
(SELECT Sum(Anteile) FROM Benutzer where Benutzer.Depot_ID = `subq`.`Depot_ID`) as `Anteile`,GROUP_CONCAT(`subq`.Kommentar SEPARATOR \', \') as `Kommentar` FROM

(select `BenutzerBestellungenTemp`.`Depot_ID` AS `Depot_ID`,`BenutzerBestellungenTemp`.`Depot` AS `Depot`,
`BenutzerBestellungenTemp`.`Produktname` AS `Produkt`
,`BenutzerBestellungenTemp`.`Beschreibung` AS `Beschreibung`,`BenutzerBestellungenTemp`.`Einheit` AS `Einheit`,`BenutzerBestellungenTemp`.`Menge` AS `Menge`
,`BenutzerBestellungenTemp`.`Woche` AS `Woche`,sum(`BenutzerBestellungenTemp`.`Anzahl`) AS `Anzahl`,sum(`BenutzerBestellungenTemp`.`AnzahlModul`) AS `AnzahlModul`
,sum(`BenutzerBestellungenTemp`.`AnzahlZusatz`) AS `AnzahlZusatz`,sum(`BenutzerBestellungenTemp`.`Urlaub`) AS `Urlaub`,
		 GROUP_CONCAT(
		        (
		             CASE WHEN(`BenutzerBestellungenTemp`.`Kommentar` is NULL or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) = \'-\' or TRIM(`BenutzerBestellungenTemp`.`Kommentar`) like \'Tausch\') THEN NULL
		 				ELSE concat((select name from Benutzer where Benutzer.ID = BenutzerBestellungenTemp.Benutzer_ID),
					 case when Produkt is null or TRIM(Produkt) = \'\' or TRIM(Produkt) = \'-\' or TRIM(Produkt) = \'Kommentar\' THEN \'\' ELSE concat(\' \', Produkt) end,
					 \': \', `BenutzerBestellungenTemp`.`Kommentar`)
		        END
		    ) SEPARATOR \', \'
		) AS `Kommentar`
from `db208674_361`.`BenutzerBestellungenTemp` group by
	`BenutzerBestellungenTemp`.`Produktname`,`BenutzerBestellungenTemp`.`Woche`,`BenutzerBestellungenTemp`.`Depot_ID`
order by `BenutzerBestellungenTemp`.`Depot`,`BenutzerBestellungenTemp`.`Produkt`) subq

 WHERE Woche = ', pWoche ,' GROUP BY Depot_ID');

CALL BenutzerBestellungen(pWoche);

PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END