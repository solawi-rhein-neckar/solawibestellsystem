DROP PROCEDURE IF EXISTS `BenutzerBestellungView`;
CREATE  PROCEDURE `BenutzerBestellungView` (
	IN `pWoche` DECIMAL(6,2),
	IN `pBenutzer` INT,
	IN `pDepot` INT
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN
CALL BenutzerBestellung(pWoche, TRUE);

SELECT

   `Benutzer_ID`,
   `Benutzer`,
   `Depot_ID`,
   `Depot`,
   MAX(Modul) AS Modul,
   `Produktname`,
   Produkt,
   Produkt_ID,
   `Beschreibung`,
   `Einheit`,
   `Menge`,
   `Nr`,
   `Woche`,
   CONVERT(GROUP_CONCAT( ( CASE WHEN(TRIM(`Kommentar`) = '') THEN NULL ELSE `Kommentar` END ) SEPARATOR ', ' ),char(255)) AS `Kommentar`,
  GREATEST(0, SUM(`Anzahl`)) AS Anzahl,
   SUM( AnzahlModul ) AS `AnzahlModul`,
   SUM( `AnzahlZusatz` ) AS `AnzahlZusatz`,
   GREATEST(0, sum(Punkte)) AS `Punkte`,
   MAX(IFNULL(Gutschrift,0)) as `Gutschrift`,
   MAX(IFNULL(Gutschrift,0)) - GREATEST(0, sum(Punkte)) as `Saldo`,
    `Urlaub`

FROM `BenutzerBestellungenTemp`

WHERE ((pBenutzer is null) or (Benutzer_ID = pBenutzer))
AND ((pDepot is null) or (Depot_ID = pDepot))

GROUP BY `Benutzer_ID`,
   `Benutzer`,
   `Depot_ID`,
   `Depot`,
   IFNuLL(Produkt,Modul),
   `Woche`,
   `Urlaub`
order by benutzer_ID, modul, produkt;
END