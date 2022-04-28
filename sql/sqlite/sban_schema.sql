CREATE TABLE IF NOT EXISTS players (
    id  INTEGER PRIMARY KEY AUTOINCREMENT
  , ban INTEGER
);

CREATE TABLE IF NOT EXISTS playerdata (
    id         INTEGER
  , name       TEXT
  , ip         TEXT
  , created    INTEGER
  , last_login INTEGER
  , FOREIGN KEY (id) REFERENCES players(id)
);

CREATE TABLE IF NOT EXISTS bans (
    id       INTEGER
  , name     TEXT
  , source   TEXT     -- who did the banning
  , created  INTEGER  -- date
  , reason   TEXT
  , expires  INTEGER
  , u_source TEXT     -- who did the unbanning
  , u_reason TEXT
  , u_date   INTEGER
  , active   INTEGER
  , last_pos TEXT
  , FOREIGN KEY (id) REFERENCES players(id)
);

CREATE TABLE IF NOT EXISTS whitelist (
    name    TEXT
  , source  TEXT
  , created INTEGER
);

CREATE TABLE IF NOT EXISTS version (
    rev TEXT
);
