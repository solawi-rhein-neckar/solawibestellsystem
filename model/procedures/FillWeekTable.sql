DROP PROCEDURE IF EXISTS `FillWeekTable`;
CREATE PROCEDURE `FillWeekTable` ()
READS SQL DATA
SQL SECURITY INVOKER
BEGIN
 DECLARE pWoche DECIMAL(6,2);

  DECLARE day DATETIME DEFAULT '2018-01-04 12:00';

  WHILE day <= '2068-01-01 00:00' DO
    SET pWoche = cast(yearweek((day - interval 3 day),1)/100 as decimal(6,2));

    INSERT INTO Woche(Woche,Jahr,Kalenderwoche,Donnerstag,DonnerstagMonat,DonnerstagDesMonats) VALUES (pWoche,year(day),weekofyear(day),day(day),month(day),FLOOR((DayOfMonth(day)-1)/7)+1);


    SET day = date_add(day, interval 7 day);

  END WHILE;
END