-- Zählen vor dem Einspielen (Webteam, 11/2026): Wie viele Anteile gälten als ausgeschieden? Gibt nur Zahlen aus, ändert nichts.
--   mysql db208674_361 < model/BenutzerZugangAusgeschieden.sql
--
-- Dieselbe Regel wie $AUSGESCHIEDEN in cgi-bin/SolawiSitzung.pm: Ausgeschieden ist ein Anteil im Depot „Geloescht“ (Depot_ID 0)
-- oder mit Abos, die alle vor der laufenden Woche geendet haben. Anteile ohne Abos und Orga/Admin (Rolle 4, 5) bleiben drin.
-- Ausgeschiedene Anteile melden sich nicht mehr per Mail-Link an, ihre Sitzungen gelten nicht mehr.
--
--   anteile                    alle Zeilen in Benutzer
--   im_depot_geloescht         Depot „Geloescht“ (davon Orga/Admin: siehe orga_admin_bleiben_drin)
--   abos_alle_beendet          außerhalb von „Geloescht“, Abos vorhanden, keines läuft noch: die eigentliche Änderung.
--                              Ist diese Zahl größer als erwartet (z. B. weil Abos zum Saisonende auslaufen und neu angelegt
--                              werden), bitte nicht einspielen und dem Webteam Bescheid geben.
--   ohne_abos_bleiben_drin     außerhalb von „Geloescht“, ganz ohne Abos
--   orga_admin_bleiben_drin    Rolle 4 oder 5, die sonst als ausgeschieden gälten
--   ausgeschieden_gesamt       so viele Anteile melden sich danach nicht mehr an

SELECT
  COUNT(*) AS anteile,
  SUM(IFNULL(x.Depot_ID, -1) = 0) AS im_depot_geloescht,
  SUM(IFNULL(x.Depot_ID, -1) <> 0 AND x.Role_ID < 4 AND x.abos > 0 AND x.laufend = 0) AS abos_alle_beendet,
  SUM(IFNULL(x.Depot_ID, -1) <> 0 AND x.abos = 0) AS ohne_abos_bleiben_drin,
  SUM(x.Role_ID >= 4 AND (IFNULL(x.Depot_ID, -1) = 0 OR (x.abos > 0 AND x.laufend = 0))) AS orga_admin_bleiben_drin,
  SUM(x.Role_ID < 4 AND (IFNULL(x.Depot_ID, -1) = 0 OR (x.abos > 0 AND x.laufend = 0))) AS ausgeschieden_gesamt
FROM (
  SELECT b.ID, b.Role_ID, b.Depot_ID,
    (SELECT COUNT(*) FROM BenutzerModulAbo a WHERE a.Benutzer_ID = b.ID) AS abos,
    (SELECT COUNT(*) FROM BenutzerModulAbo a WHERE a.Benutzer_ID = b.ID
       AND (a.EndWoche IS NULL OR a.EndWoche >= CAST(DATE_FORMAT(UTC_TIMESTAMP(), '%x.%v') AS DECIMAL(6,2)))) AS laufend
  FROM Benutzer b
) x;
