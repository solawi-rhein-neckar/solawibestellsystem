SELECT
    `u`.`Benutzer_ID` AS `Benutzer_ID`,
    `d02dbcf8`.`Benutzer`.`Name` AS `Benutzer`,
    `d02dbcf8`.`Depot`.`ID` AS `Depot_ID`,
    `d02dbcf8`.`Depot`.`Name` AS `Depot`,
   `u`.`Produkt`,
   `u`.`Beschreibung`,
     `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche` AS `Woche`,
    (
        CASE WHEN ISNULL(`d02dbcf8`.`BenutzerUrlaub`.`ID`) THEN SUM(`u`.`Anzahl`) ELSE 0
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
    `d02dbcf8`.`BenutzerUrlaub`.`ID` IS NOT NULL
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
                            `d02dbcf8`.`BenutzerModulAbo`.`Benutzer_ID` AS `Benutzer_ID`,
						    `d02dbcf8`.`Modul`.`Name` AS `Produkt`,
						    `d02dbcf8`.`Modul`.`Beschreibung` AS `Beschreibung`,
						    '' AS `Einheit`,
						    `d02dbcf8`.`Modul`.`AnzahlProAnteil` AS `Menge`,                            
						    (
                                `d02dbcf8`.`BenutzerModulAbo`.`Anzahl`
                            ) AS `Anzahl`,
                            pWoche AS `Woche`
                        FROM
                           `d02dbcf8`.`BenutzerModulAbo` 
		                JOIN `d02dbcf8`.`Modul` ON
		                    (
		                        (
		                            `BenutzerModulAbo`.`Modul_ID` = `d02dbcf8`.`Modul`.`ID`
		                        )
		                    )                                   WHERE 
                               (
                                            ISNULL(
                                                `d02dbcf8`.`BenutzerModulAbo`.`StartWoche`
                                            ) OR(
                                                 pWoche >= `d02dbcf8`.`BenutzerModulAbo`.`StartWoche`
                                            )
                                        ) AND(
                                            ISNULL(
                                                `d02dbcf8`.`BenutzerModulAbo`.`EndWoche`
                                            ) OR(
                                                pWoche <= `d02dbcf8`.`BenutzerModulAbo`.`EndWoche`
                                            )
                                        )
                                    )
                UNION ALL
                    (
                    SELECT
                        2 AS `Quelle`,
                        `d02dbcf8`.`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
						    `d02dbcf8`.`Produkt`.`Name` AS `Produkt`,
						    `d02dbcf8`.`Produkt`.`Beschreibung` AS `Beschreibung`,
						    `d02dbcf8`.`Produkt`.`Einheit` AS `Einheit`,
						    `d02dbcf8`.`Produkt`.`Menge` AS `Menge`,
                            `d02dbcf8`.`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
                        `d02dbcf8`.`BenutzerZusatzBestellung`.`Woche` AS `Woche`
                    FROM
                        `d02dbcf8`.`BenutzerZusatzBestellung`
		                JOIN `d02dbcf8`.`Produkt` ON
		                    (
		                        (
		                            `BenutzerZusatzBestellung`.`Produkt_ID` = `d02dbcf8`.`Produkt`.`ID`
		                        )
		                    )
		                  WHERE    `d02dbcf8`.`BenutzerZusatzBestellung`.`Woche` = pWoche             
                    )
                ) `u`

                )
            JOIN `d02dbcf8`.`Benutzer` ON
                (
                    (
                        `u`.`Benutzer_ID` = `d02dbcf8`.`Benutzer`.`ID`
                    )
                )
            )
        JOIN `d02dbcf8`.`Depot` ON
            (
                (
                    `d02dbcf8`.`Benutzer`.`Depot_ID` = `d02dbcf8`.`Depot`.`ID`
                )
            )
        )
    LEFT JOIN `d02dbcf8`.`BenutzerUrlaub` ON
        (
            (
                (
                    `d02dbcf8`.`BenutzerUrlaub`.`Benutzer_ID` = `u`.`Benutzer_ID`
                ) AND(
                    `d02dbcf8`.`BenutzerUrlaub`.`Woche` = `u`.`Woche`
                )
            )
        )
    )
GROUP BY
    `u`.`Benutzer_ID`,
    `d02dbcf8`.`Benutzer`.`Name`,
    `d02dbcf8`.`Depot`.`ID`,
    `d02dbcf8`.`Depot`.`Name`,
    `u`.`Produkt`,
    `u`.`Beschreibung`,
    `u`.`Einheit`,
    `u`.`Menge`,
    `u`.`Woche`,
    `d02dbcf8`.`BenutzerUrlaub`.`ID`