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

/*

Week Table Use Example:

INSERT INTO ModulInhaltWoche (ModulInhalt_ID, Woche, Anzahl, Depot_ID) SELECT ModulInhalt.ID, Woche.Woche, 1, Depot.ID FROM ModulInhalt ,Depot ,Woche WHERE ModulInhalt.ID in (25,26,27,28,29) AND Depot.ID in (2,3,1,7) AND Woche.Woche >= '2023.18' AND Woche.DonnerstagDesMonats=1;
INSERT INTO ModulInhaltWoche (ModulInhalt_ID, Woche, Anzahl, Depot_ID) SELECT ModulInhalt.ID, Woche.Woche, 1, Depot.ID FROM ModulInhalt ,Depot ,Woche WHERE ModulInhalt.ID in (25,26,27,28,29) AND Depot.ID in  (14,17,5,9,18) AND Woche.Woche >= '2023.18' AND Woche.DonnerstagDesMonats=2;
INSERT INTO ModulInhaltWoche (ModulInhalt_ID, Woche, Anzahl, Depot_ID) SELECT ModulInhalt.ID, Woche.Woche, 1, Depot.ID FROM ModulInhalt ,Depot ,Woche WHERE ModulInhalt.ID in (25,26,27,28,29) AND Depot.ID in  (19,12,15,6) AND Woche.Woche >= '2023.18' AND Woche.DonnerstagDesMonats=3;
INSERT INTO ModulInhaltWoche (ModulInhalt_ID, Woche, Anzahl, Depot_ID) SELECT ModulInhalt.ID, Woche.Woche, 1, Depot.ID FROM ModulInhalt ,Depot ,Woche WHERE ModulInhalt.ID in (25,26,27,28,29) AND Depot.ID in  (13,11,4) AND Woche.Woche >= '2023.18' AND Woche.DonnerstagDesMonats=4;

*/