DROP PROCEDURE IF EXISTS `BenutzerPunkte`;
CREATE PROCEDURE `BenutzerPunkte` (
   IN `pBenutzer` int
)
READS SQL DATA
SQL SECURITY INVOKER
BEGIN

  DECLARE pWoche decimal(6,2);
  DECLARE day DATETIME DEFAULT MAKEDATE(year(curdate()),1);

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

  WHILE day < curdate() DO
  	SET pWoche = cast(yearweek((day - interval 4 day),1)/100 as decimal(6,2));
  	CALL BenutzerBestellung( pWoche, TRUE);
  	INSERT INTO BenutzerPunkteTemp SELECT pWoche,
  	   b.Benutzer_ID,
  	   b.Benutzer,
       GREATEST(0, sum(b.Punkte)),
       sum(IFNULL(b.Gutschrift,0)),
       sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte)),
       sum(IFNULL(b.Gutschrift,0)) - GREATEST(0, sum(b.Punkte))
       + IF(pWoche < Benutzer.AnteileStartWoche, Benutzer.PunkteStart,
            IFNULL((Select t.Total FROM BenutzerPunkteTemp2 as t Where t.Benutzer_ID = b.Benutzer_ID),0)  )
     FROM `BenutzerBestellungenTemp` as b JOIN Benutzer ON Benutzer.ID = Benutzer_ID
     WHERE `pBenutzer` IS NULL OR `pBenutzer` = b.Benutzer_ID
     Group by b.Benutzer_ID;

	TRUNCATE BenutzerPunkteTemp2;
	INSERT INTO BenutzerPunkteTemp2 SELECT * FROM BenutzerPunkteTemp WHERE Woche = pWoche;
    SET day = date_add(day, interval 7 day);

  END WHILE;

  UPDATE Benutzer SET PunkteStand = (Select Total FROM BenutzerPunkteTemp Where Woche = pWoche And BenutzerPunkteTemp.Benutzer_ID = Benutzer.ID),
                      PunkteWoche = pWoche
          WHERE (Select Total FROM BenutzerPunkteTemp2 Where Woche = pWoche And BenutzerPunkteTemp2.Benutzer_ID = Benutzer.ID) IS NOT NULL;

  SELECT * FROM BenutzerPunkteTemp;

END;