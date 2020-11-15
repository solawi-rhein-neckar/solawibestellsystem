DROP PROCEDURE IF EXISTS `PivotUsers`;
CREATE PROCEDURE `PivotUsers`()
    READS SQL DATA
    SQL SECURITY INVOKER
BEGIN

SET SESSION group_concat_max_len = 32000;

SET @query := (SELECT GROUP_CONCAT(DISTINCT CONCAT('MAX(IF(meta_key = ''', meta_key, ''', meta_value, NULL)) AS `', meta_key, '`' ))  FROM wp_usermeta ORDER BY meta_key);

SET @query = CONCAT('SELECT wp_users.*, ', @query, ' FROM wp_users join wp_usermeta on wp_users.ID = wp_usermeta.user_id GROUP BY wp_users.id');


PREPARE stt FROM @query;

EXECUTE stt;

DEALLOCATE PREPARE stt;


END