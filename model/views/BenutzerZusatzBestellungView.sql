SELECT
    `db208674_361`.`BenutzerZusatzBestellung`.`ID` AS `ID`,
    `db208674_361`.`BenutzerZusatzBestellung`.`Benutzer_ID` AS `Benutzer_ID`,
    `db208674_361`.`Produkt`.`Name` AS `Produkt`,
    `db208674_361`.`BenutzerZusatzBestellung`.`Woche` AS `Woche`,
    `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl` AS `Anzahl`,
    (
        CASE WHEN(
            ISNULL(
                `db208674_361`.`BenutzerZusatzBestellung`.`Kommentar`
            ) OR(
                `db208674_361`.`BenutzerZusatzBestellung`.`Kommentar` = ''
            )
        ) THEN `db208674_361`.`Produkt`.`Beschreibung` ELSE `db208674_361`.`BenutzerZusatzBestellung`.`Kommentar`
    END
) AS `Beschreibung`,
(
    `db208674_361`.`BenutzerZusatzBestellung`.`Anzahl` * `db208674_361`.`Produkt`.`Punkte`
) AS `Punkte`,
`db208674_361`.`Produkt`.`AnzahlZusatzBestellungMax` AS `AnzahlZusatzBestellungMax`
FROM
    (
        `db208674_361`.`BenutzerZusatzBestellung`
    JOIN `db208674_361`.`Produkt` ON
        (
            (
                `db208674_361`.`BenutzerZusatzBestellung`.`Produkt_ID` = `db208674_361`.`Produkt`.`ID`
            )
        )
    )