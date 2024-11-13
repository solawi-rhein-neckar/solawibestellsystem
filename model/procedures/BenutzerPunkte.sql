DROP PROCEDURE IF EXISTS `BenutzerPunkteBerechnung`;
CREATE PROCEDURE `BenutzerPunkteBerechnung` (
   IN `pBenutzer` int,
   IN `pYear` int,
   INOUT `pWoche` decimal(6,2)
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
	
  DECLARE curdate DATETIME DEFAULT CASE WHEN pWoche is not null THEN STR_TO_DATE(CONCAT(pWoche,' Monday'), '%X.%V %W') ELSE curdate() END;

  DECLARE day DATETIME DEFAULT DATE_ADD(MAKEDATE(pYear - IF(month(curdate) < 11 or (day(curdate) < 7 and month(curdate) < 12), 1, 0) , 7), INTERVAL 10 MONTH);

  DROP TEMPORARY TABLE IF EXISTS BenutzerPunkteTemp;
  DROP TEMPORARY TABLE IF EXISTS BenutzerPunkteTemp2;

  CREATE TEMPORARY TABLE BenutzerPunkteTemp(
   Woche decimal(6,2),
   Benutzer_ID int,
   Benutzer varchar(255),
   Abzug int,
   Gutschrift int,
   Subtotal int,
   Total int);

  CREATE TEMPORARY TABLE BenutzerPunkteTemp2(
   Woche decimal(6,2),
   Benutzer_ID int,
   Benutzer varchar(255),
   Abzug int,
   Gutschrift int,
   Subtotal int,
   Total int);

  WHILE day <= (curdate + interval 4 day) DO
  	SET pWoche = cast(yearweek((day - interval 4 day),1)/100 as decimal(6,2));
  	CALL BenutzerBestellung( pWoche, TRUE);
  	INSERT INTO BenutzerPunkteTemp SELECT pWoche,
  	   b.Benutzer_ID,
  	   b.Benutzer,
       GREATEST(0, sum(b.Punkte)),
       sum(IFNULL(b.Gutschrift,0)),
       sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte)),
       IF(pWoche < Benutzer.AnteileStartWoche AND pWoche >= Benutzer.AnteileStartWoche - '0.01', 0, sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte)))
       + IF(pWoche <= Benutzer.AnteileStartWoche AND pWoche >= Benutzer.AnteileStartWoche - '0.01', Benutzer.PunkteStart,
            IFNULL((Select t.Total FROM BenutzerPunkteTemp2 as t Where t.Benutzer_ID = b.Benutzer_ID),0)  )
     FROM (SELECT Benutzer_ID, Benutzer, GREATEST(0, sum(Punkte)) as Punkte, max(IFNULL(Gutschrift,0)) as Gutschrift FROM `BenutzerBestellungenTemp` GROUP BY `Benutzer_ID`,`Benutzer`,IFNuLL(Produkt,Modul)) as b
     JOIN Benutzer ON Benutzer.ID = Benutzer_ID
     WHERE `pBenutzer` IS NULL OR `pBenutzer` = b.Benutzer_ID
     Group by b.Benutzer_ID;

	TRUNCATE BenutzerPunkteTemp2;
	INSERT INTO BenutzerPunkteTemp2 SELECT * FROM BenutzerPunkteTemp WHERE Woche = pWoche;
    SET day = date_add(day, interval 7 day);

  END WHILE;
END;

DROP PROCEDURE IF EXISTS `BenutzerPunkteView`;
CREATE PROCEDURE `BenutzerPunkteView` (
   IN `pBenutzer` int,
   IN `pYear` int
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE pWoche decimal(6,2);

  CALL BenutzerPunkteBerechnung(pBenutzer, pYear, pWoche);

  SELECT * FROM BenutzerPunkteTemp;
END;

DROP PROCEDURE IF EXISTS `BenutzerPunkte`;
CREATE PROCEDURE `BenutzerPunkte` (
   IN `pBenutzer` int
)
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE pWoche decimal(6,2);

  CALL BenutzerPunkteBerechnung(pBenutzer, year(curdate()), pWoche);

  UPDATE Benutzer SET PunkteStand = (Select Total FROM BenutzerPunkteTemp Where Woche = pWoche And BenutzerPunkteTemp.Benutzer_ID = Benutzer.ID),
                      PunkteWoche = pWoche
          WHERE (Select Total FROM BenutzerPunkteTemp2 Where Woche = pWoche And BenutzerPunkteTemp2.Benutzer_ID = Benutzer.ID) IS NOT NULL;

  SELECT * FROM BenutzerPunkteTemp;
END;

DROP PROCEDURE IF EXISTS `BenutzerPunkteStart`;
CREATE PROCEDURE `BenutzerPunkteStart` (
   IN `pBenutzer` int
)
MODIFIES SQL DATA
SQL SECURITY INVOKER
BEGIN
  DECLARE pWoche decimal(6,2) DEFAULT CONCAT(year(curdate()) + '.43');

  CALL BenutzerPunkteBerechnung(pBenutzer, year(curdate()), pWoche);

  UPDATE Benutzer SET PunkteHistory=LEFT(CONCAT(AnteileStartWoche,':',PunkteStart,', ',PunkteHistory),254), PunkteStart = (Select CASE WHEN Total > 480 THEN 480 ELSE Total END FROM BenutzerPunkteTemp Where Woche = pWoche And BenutzerPunkteTemp.Benutzer_ID = Benutzer.ID),
                      AnteileStartWoche = CONCAT(year(curdate()) + '.44')
          WHERE ((pBenutzer is not null AND Benutzer.ID = pBenutzer) OR (pBenutzer is null AND Benutzer.Anteile is not null AND Benutzer.Anteile > 0 AND Benutzer.Depot_ID is not null and Benutzer.Depot_ID > 0 AND AnteileStartWoche <= pWoche) OR (pBenutzer is null AND Benutzer.FleischAnteile is not null AND Benutzer.FleischAnteile > 0 AND Benutzer.Depot_ID is not null and Benutzer.Depot_ID > 0 AND AnteileStartWoche <= pWoche)) AND (Select Total FROM BenutzerPunkteTemp2 Where Woche = pWoche And BenutzerPunkteTemp2.Benutzer_ID = Benutzer.ID) IS NOT NULL;
          
  CALL BenutzerPunkte(pBenutzer);

  SELECT ID, Name, Anteile, FleischAnteile, Depot_ID, PunkteHistory, AnteileStartWoche, PunkteStart, PunkteWoche, PunkteStand FROM Benutzer WHERE (pBenutzer is not null AND Benutzer.ID = pBenutzer) OR (pBenutzer is null AND Benutzer.Anteile is not null AND Benutzer.Anteile > 0 AND Benutzer.Depot_ID is not null and Benutzer.Depot_ID > 0) OR (pBenutzer is null AND Benutzer.FleischAnteile is not null AND Benutzer.FleischAnteile > 0 AND Benutzer.Depot_ID is not null and Benutzer.Depot_ID > 0);
END;