SELECT
    CONCAT(
        CAST(
            `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl` AS CHAR CHARSET utf8mb4
        ),
        ' x ',
        CAST(
            `db208674_361`.`Produkt`.`ID` AS CHAR CHARSET utf8mb4
        )
    ) AS `ID`,
    `db208674_361`.`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
    `db208674_361`.`Produkt`.`Name` AS `Name`,
    `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
    (
        `db208674_361`.`Produkt`.`Punkte` * `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl`
    ) AS `Punkte`,
    GROUP_CONCAT(
        `db208674_361`.`BenutzerZusatzBestellung`.`Woche` SEPARATOR ','
    ) AS `Wochen`
FROM
    (
        `db208674_361`.`BenutzerZusatzBestellung`
    JOIN `db208674_361`.`Produkt` ON
        (
            (
                `db208674_361`.`Produkt`.`ID` = `db208674_361`.`BenutzerZusatzBestellung`.`Produkt_ID`
            )
        )
    )
WHERE
    (
        `db208674_361`.`BenutzerZusatzBestellung`.`Woche` >= DATE_FORMAT(CURDATE(), '%x.%v'))
    GROUP BY
        `db208674_361`.`BenutzerZusatzBestellung`.`Benutzer_ID`,
        `db208674_361`.`Produkt`.`Name`,
        `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl`,
        `db208674_361`.`Produkt`.`Punkte`