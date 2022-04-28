PRAGMA writable_schema = 1;
DELETE FROM sqlite_master WHERE type IN ("table", "index", "trigger");
PRAGMA writable_schema = 0;
VACUUM;
PRAGMA INTEGRITY_CHECK;
