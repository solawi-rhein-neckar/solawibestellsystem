DROP PROCEDURE IF EXISTS `PivotModulInhalt`;
CREATE PROCEDURE `PivotModulInhalt`(
	IN `pWoche` DECIMAL(6,2)
)
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('(SELECT ModulInhaltWoche.Anzahl From ModulInhaltWoche WHERE ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID AND ModulInhaltWoche.Depot_ID = ', sub.ID, ' AND ModulInhaltWoche.WOCHE = ', pWoche, ') AS `', sub.KurzName, '_ID_', sub.ID  , '`' ))  FROM (Select * From Depot Where ID <> 0 ORDER BY Name) as sub);

SET @query = CONCAT('
	SELECT ModulInhalt.ID AS `_ID`, ', pWoche, ' AS `:Date`,
		   Modul.Name AS `:Modul`,
		   ModulInhalt.Anzahl AS `:P#`,
           Produkt.Name AS `:Produkt`,
		   (SELECT Anzahl From ModulInhaltWoche WHERE ModulInhaltWoche.ModulInhalt_ID = ModulInhalt.ID AND ((ModulInhaltWoche.Depot_ID IS NULL) OR ModulInhaltWoche.Depot_ID = 0) AND ModulInhaltWoche.WOCHE = ', pWoche, ') AS `ALLE_ID_0`, ',
		   @query, '
	FROM
		ModulInhalt
		Join Modul on ModulInhalt.Modul_ID = Modul.ID
		join Produkt on ModulInhalt.Produkt_ID = Produkt.ID ORDER BY Modul.Name, Produkt.Nr');


PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;

END