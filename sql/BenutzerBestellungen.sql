BEGIN
DROP TEMPORARY TABLE IF EXISTS BenutzerBestellungenTemp;
CREATE TEMPORARY TABLE IF NOT EXISTS BenutzerBestellungenTemp ENGINE=MEMORY AS (SELECT
    `u`.`Benutzer_ID` AS `Benutzer_ID`,
    `db208674_361`.`Benutzer`.`Name` AS `Benutzer`,
    `db208674_361`.`Depot`.`ID` AS `Depot_ID`,
    `db208674_361`.`Depot`.`Name` AS `Depot`,
   `u`.`Produkt`,
   `u`.`Produktname`,
   `u`.`Beschreibung`,
     `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche` AS `Woche`,
    CONVERT(GROUP_CONCAT(
        (
            CASE WHEN(TRIM(`u`.`Kommentar`) = '') THEN NULL ELSE `u`.`Kommentar`
        END
    ) SEPARATOR ', '
), char(255)) AS `Kommentar`,
    (
        CASE WHEN ISNULL(`db208674_361`.`BenutzerUrlaub`.`ID`) THEN SUM(`u`.`Anzahl`) ELSE 0
    END
) AS `Anzahl`,
SUM(
    (
        CASE WHEN(`u`.`Quelle` = 1) THEN `u`.`Anzahl` ELSE 0
    END
)
) AS `AnzahlModul`,
SUM(
    (
        CASE WHEN(`u`.`Quelle` = 2) THEN `u`.`Anzahl` ELSE 0
    END
)
) AS `AnzahlZusatz`,
(
    `db208674_361`.`BenutzerUrlaub`.`ID` IS NOT NULL
) AS `Urlaub`
                                                                                FROM
    (
        (
            (
                (
                    (
                        (
                        SELECT
                            1 AS `Quelle`,
                            `db208674_361`.`BenutzerModulAbo`.`Benutzer_ID` AS `Benutzer_ID`,
 `db208674_361`.`BenutzerModulAbo`.`Kommentar` AS `Kommentar`,
						    Replace(Replace(`db208674_361`.`Modul`.`Name`, 'Kräutermodul', 'Kräuter'), 'Quarkmodul' , 'Quark, 400g')  AS `Produkt`,
						    Replace(Replace(Replace(`db208674_361`.`Modul`.`Name`, 'Kräutermodul', 'Kräuter'), 'Quarkmodul' , 'Quark'), 'Quark, 400g', 'Quark')  AS `Produktname`,
						    `db208674_361`.`Modul`.`Beschreibung` AS `Beschreibung`,
						    '' AS `Einheit`,
						    `db208674_361`.`Modul`.`AnzahlProAnteil` AS `Menge`,
						    (
                                `db208674_361`.`BenutzerModulAbo`.`Anzahl`
                            ) AS `Anzahl`,
                            pWoche AS `Woche`
                        FROM
                           `db208674_361`.`BenutzerModulAbo`
		                JOIN `db208674_361`.`Modul` ON
		                    (
		                        (
		                            `BenutzerModulAbo`.`Modul_ID` = `db208674_361`.`Modul`.`ID`
		                        )
		                    )                                   WHERE
                               (
                                            ISNULL(
                                                `db208674_361`.`BenutzerModulAbo`.`StartWoche`
                                            ) OR(
                                                 pWoche >= `db208674_361`.`BenutzerModulAbo`.`StartWoche`
                                            )
                                        ) AND(
                                            ISNULL(
                                                `db208674_361`.`BenutzerModulAbo`.`EndWoche`
                                            ) OR(
                                                pWoche <= `db208674_361`.`BenutzerModulAbo`.`EndWoche`
                                            )
                                        )
                                    )
                UNION ALL
                    (
                    SELECT
                        2 AS `Quelle`,
                        `db208674_361`.`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
                        `db208674_361`.`BenutzerZusatzBestellung`.`Kommentar` AS `Kommentar`,
						    `db208674_361`.`Produkt`.`Name` AS `Produkt`,
						    `db208674_361`.`Produkt`.`Produkt` AS `Produktname`,
						    `db208674_361`.`Produkt`.`Beschreibung` AS `Beschreibung`,
						    `db208674_361`.`Produkt`.`Einheit` AS `Einheit`,
						    `db208674_361`.`Produkt`.`Menge` AS `Menge`,
                            `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
                        `db208674_361`.`BenutzerZusatzBestellung`.`Woche` AS `Woche`
                    FROM
                        `db208674_361`.`BenutzerZusatzBestellung`
		                JOIN `db208674_361`.`Produkt` ON
		                    (
		                        (
		                            `BenutzerZusatzBestellung`.`Produkt_ID` = `db208674_361`.`Produkt`.`ID`
		                        )
		                    )
		                  WHERE    `db208674_361`.`BenutzerZusatzBestellung`.`Woche` = pWoche
                    )
                ) `u`

                )
            JOIN `db208674_361`.`Benutzer` ON
                (
                    (
                        `u`.`Benutzer_ID` = `db208674_361`.`Benutzer`.`ID`
                    )
                )
            )
        JOIN `db208674_361`.`Depot` ON
            (
                (
                    `db208674_361`.`Benutzer`.`Depot_ID` = `db208674_361`.`Depot`.`ID`
                )
            )
        )
    LEFT JOIN `db208674_361`.`BenutzerUrlaub` ON
        (
            (
                (
                    `db208674_361`.`BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
                ) AND(
                    `db208674_361`.`BenutzerUrlaub`.`Woche` = `u`.`Woche`
                )
            )
        )
    )
GROUP BY
    `u`.`Benutzer_ID`,
    `db208674_361`.`Benutzer`.`Name`,
    `db208674_361`.`Depot`.`ID`,
    `db208674_361`.`Depot`.`Name`,
    `u`.`Produkt`,
    `u`.`Produktname`,
    `u`.`Beschreibung`,
    `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche`,
    `db208674_361`.`BenutzerUrlaub`.`ID`);
END