DROP PROCEDURE IF EXISTS AbosProDepotUndWoche;
CREATE PROCEDURE AbosProDepotUndWoche()
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN
DECLARE pWoche INT Default  27;
DECLARE pYear INT Default  2024;

SET SESSION group_concat_max_len = 32000;
   DROP TEMPORARY TABLE IF EXISTS GesamtBestellungenTemp;

	WHILE pYear != 2025 or pWoche != 27 DO
		IF pWoche = 53 THEN 
			SET pWoche=1;
			SET pYear=pYear+1;
		END IF;
		
		IF pYear = 2024 AND pWoche = 27 THEN   CREATE TEMPORARY TABLE IF NOT EXISTS GesamtBestellungenTemp  CHARACTER SET utf8mb4 AS (SELECT pYear as Year, pWoche as Woche, Depot.Name as Depot, sum(IF(a.modul_id = 1, a.anzahl, 0)) as gemuese , sum(IF(a.modul_id = 2, a.anzahl, 0)) as milch, sum(IF(a.modul_id = 3, a.anzahl, 0)) as brot, sum(IF(a.modul_id = 4, a.anzahl, 0)) as fleisch, sum(IF(a.modul_id = 5, a.anzahl, 0)) as quark, sum(IF(a.modul_id = 7, a.anzahl, 0)) as schnittkaese, sum(IF(a.modul_id = 8, a.anzahl, 0)) as kartoffeln, sum(IF(a.modul_id = 9, a.anzahl, 0)) as apfelsaft, sum(IF(a.modul_id = 10, a.anzahl, 0)) as joghurt, sum(IF(a.modul_id = 11, a.anzahl, 0)) as ricotta, sum(IF(a.modul_id = 12, a.anzahl, 0)) as weichkaese, sum(IF(a.modul_id = 13, a.anzahl, 0)) as bauernkaese, sum(IF(a.modul_id = 14, a.anzahl, 0)) as hirtenkaese, sum(IF(a.modul_id = 15, a.anzahl, 0)) as grillkaese, sum(IF(a.modul_id = 16, a.anzahl, 0)) as neuerkaese, sum(IF(a.modul_id = 17, a.anzahl, 0)) as Mehl, sum(IF(a.modul_id = 22, a.anzahl, 0)) as KlausFix, sum(IF(a.modul_id = 23, a.anzahl, 0)) as Zwiebeln, sum(IF(a.modul_id = 24, a.anzahl, 0)) as Obst FROM BenutzerModulAbo a Join Benutzer b on a.Benutzer_ID = b.ID JOIN Depot on b.Depot_ID = Depot.ID WHERE a.StartWoche <= CONCAT(pYear,IF(pWoche < 10, '.0', '.'), pWoche) AND a.EndWoche >= CONCAT(pYear,IF(pWoche < 10, '.0', '.'), pWoche)  AND Depot.ID != 0 GROUP BY Depot.Name); END IF;

		IF pWoche <> 27 or pYear <> 2024 THEN   INSERT INTO GesamtBestellungenTemp SELECT pYear as Year, pWoche as Woche, Depot.Name as Depot, sum(IF(a.modul_id = 1, a.anzahl, 0)) as gemuese , sum(IF(a.modul_id = 2, a.anzahl, 0)) as milch, sum(IF(a.modul_id = 3, a.anzahl, 0)) as brot, sum(IF(a.modul_id = 4, a.anzahl, 0)) as fleisch, sum(IF(a.modul_id = 5, a.anzahl, 0)) as quark, sum(IF(a.modul_id = 7, a.anzahl, 0)) as schnittkaese, sum(IF(a.modul_id = 8, a.anzahl, 0)) as kartoffeln, sum(IF(a.modul_id = 9, a.anzahl, 0)) as apfelsaft, sum(IF(a.modul_id = 10, a.anzahl, 0)) as joghurt, sum(IF(a.modul_id = 11, a.anzahl, 0)) as ricotta, sum(IF(a.modul_id = 12, a.anzahl, 0)) as weichkaese, sum(IF(a.modul_id = 13, a.anzahl, 0)) as bauernkaese, sum(IF(a.modul_id = 14, a.anzahl, 0)) as hirtenkaese, sum(IF(a.modul_id = 15, a.anzahl, 0)) as grillkaese, sum(IF(a.modul_id = 16, a.anzahl, 0)) as neuerkaese, sum(IF(a.modul_id = 17, a.anzahl, 0)) as Mehl, sum(IF(a.modul_id = 22, a.anzahl, 0)) as KlausFix, sum(IF(a.modul_id = 23, a.anzahl, 0)) as Zwiebeln, sum(IF(a.modul_id = 24, a.anzahl, 0)) as Obst FROM BenutzerModulAbo a Join Benutzer b on a.Benutzer_ID = b.ID JOIN Depot on b.Depot_ID = Depot.ID  WHERE a.StartWoche <= CONCAT(pYear,IF(pWoche < 10, '.0', '.'), pWoche) AND a.EndWoche >= CONCAT(pYear,IF(pWoche < 10, '.0', '.'), pWoche)  AND Depot.ID != 0 GROUP BY Depot.Name; END IF;
		SET pWoche=pWoche+1;
		
	END WHILE;

	SELECT * FROM GesamtBestellungenTemp ORDER BY Year, Woche, Depot;
END
