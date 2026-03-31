-- Repair legacy gv_updates tracking rows so the updater recognizes
-- already-applied files after restart.
--
-- If your module uses a custom schema name via GuildVillage.Database.Name,
-- change @SCHEMA before running this migration.
SET @SCHEMA := 'customs';
SET @MODULE := 'mod-guild-village';
SET @GV_UPDATES := CONCAT('`', REPLACE(@SCHEMA, '`', '``'), '`.`gv_updates`');

-- Ensure the module column exists for older installs that skipped
-- the earlier gv_updates migration.
SET @has_module := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA=@SCHEMA
      AND TABLE_NAME='gv_updates'
      AND COLUMN_NAME='module'
);

SET @sql := IF(
    @has_module = 0,
    CONCAT('ALTER TABLE ', @GV_UPDATES, ' ADD COLUMN `module` VARCHAR(64) NOT NULL DEFAULT '''' AFTER `id`'),
    'DO 0'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Normalize blank module names to the current module.
SET @sql := CONCAT(
    'UPDATE ', @GV_UPDATES,
    ' SET `module` = ', QUOTE(@MODULE),
    ' WHERE `module` = '''''
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Normalize path separators before comparing filenames.
SET @sql := CONCAT(
    'UPDATE ', @GV_UPDATES,
    ' SET `filename` = REPLACE(`filename`, CHAR(92), ''/'')'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Remove duplicate tracker rows that collapse to the same normalized key.
SET @sql := CONCAT(
    'DELETE `older` FROM ', @GV_UPDATES, ' AS `older` ',
    'JOIN ', @GV_UPDATES, ' AS `newer` ',
    '  ON `older`.`module` = `newer`.`module` ',
    ' AND (',
    '        CASE ',
    '            WHEN `older`.`filename` LIKE ''base/base/%'' ',
    '                THEN CONCAT(''base/'', SUBSTRING(`older`.`filename`, 11)) ',
    '            WHEN `older`.`filename` LIKE ''include/include/%'' ',
    '                THEN CONCAT(''include/'', SUBSTRING(`older`.`filename`, 17)) ',
    '            WHEN `older`.`filename` LIKE ''updates/updates/%'' ',
    '                THEN CONCAT(''updates/'', SUBSTRING(`older`.`filename`, 17)) ',
    '            ELSE `older`.`filename` ',
    '        END',
    '     ) = (',
    '        CASE ',
    '            WHEN `newer`.`filename` LIKE ''base/base/%'' ',
    '                THEN CONCAT(''base/'', SUBSTRING(`newer`.`filename`, 11)) ',
    '            WHEN `newer`.`filename` LIKE ''include/include/%'' ',
    '                THEN CONCAT(''include/'', SUBSTRING(`newer`.`filename`, 17)) ',
    '            WHEN `newer`.`filename` LIKE ''updates/updates/%'' ',
    '                THEN CONCAT(''updates/'', SUBSTRING(`newer`.`filename`, 17)) ',
    '            ELSE `newer`.`filename` ',
    '        END',
    '     ) ',
    ' AND `older`.`id` < `newer`.`id`'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Rewrite remaining rows to the normalized key format expected by
-- the runtime updater.
SET @sql := CONCAT(
    'UPDATE ', @GV_UPDATES,
    ' SET `filename` = CASE ',
    '    WHEN `filename` LIKE ''base/base/%'' ',
    '        THEN CONCAT(''base/'', SUBSTRING(`filename`, 11)) ',
    '    WHEN `filename` LIKE ''include/include/%'' ',
    '        THEN CONCAT(''include/'', SUBSTRING(`filename`, 17)) ',
    '    WHEN `filename` LIKE ''updates/updates/%'' ',
    '        THEN CONCAT(''updates/'', SUBSTRING(`filename`, 17)) ',
    '    ELSE `filename` ',
    'END'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- Ensure the module-aware unique index exists after normalization.
SET @old_idx := (
    SELECT INDEX_NAME
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA=@SCHEMA
      AND TABLE_NAME='gv_updates'
      AND INDEX_NAME='uq_filename'
    LIMIT 1
);

SET @sql := IF(
    @old_idx IS NOT NULL,
    CONCAT('ALTER TABLE ', @GV_UPDATES, ' DROP INDEX `uq_filename`'),
    'DO 0'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @new_idx := (
    SELECT INDEX_NAME
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA=@SCHEMA
      AND TABLE_NAME='gv_updates'
      AND INDEX_NAME='uq_module_file'
    LIMIT 1
);

SET @sql := IF(
    @new_idx IS NULL,
    CONCAT('ALTER TABLE ', @GV_UPDATES, ' ADD UNIQUE INDEX `uq_module_file` (`module`,`filename`)'),
    'DO 0'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
