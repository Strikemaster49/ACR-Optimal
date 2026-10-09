PRAGMA application_id=1094931032;
PRAGMA user_version=1;
CREATE TABLE IF NOT EXISTS attempts (
 id INTEGER PRIMARY KEY, profile TEXT NOT NULL, attempt_key TEXT NOT NULL,
 block_token TEXT NOT NULL, run_index INTEGER NOT NULL, stage TEXT NOT NULL, car TEXT NOT NULL,
 raw_hash TEXT NOT NULL, payload_hash TEXT NOT NULL, layout TEXT NOT NULL,
 raw_final REAL NOT NULL CHECK(raw_final>0), first_seen TEXT NOT NULL,
 mode TEXT NOT NULL DEFAULT 'unknown', validity TEXT NOT NULL DEFAULT 'unknown',
 complete INTEGER, sectors_verified INTEGER NOT NULL DEFAULT 0,
 expected_sectors INTEGER, penalty REAL CHECK(penalty>=0), official_final REAL CHECK(official_final>0),
 review_origin TEXT NOT NULL DEFAULT 'none', conflicted INTEGER NOT NULL DEFAULT 0,
 UNIQUE(profile,attempt_key)
);
CREATE TABLE IF NOT EXISTS sectors (
 attempt_id INTEGER NOT NULL REFERENCES attempts(id), sector_index INTEGER NOT NULL CHECK(sector_index>0),
 cumulative REAL NOT NULL CHECK(cumulative>0), duration REAL NOT NULL CHECK(duration>0),
 PRIMARY KEY(attempt_id,sector_index)
);
CREATE TABLE IF NOT EXISTS observations (
 id INTEGER PRIMARY KEY, attempt_id INTEGER NOT NULL REFERENCES attempts(id), export_sha TEXT NOT NULL,
 export_path TEXT NOT NULL, seen_at TEXT NOT NULL, UNIQUE(attempt_id,export_sha)
);
CREATE TABLE IF NOT EXISTS conflicts (
 id INTEGER PRIMARY KEY, attempt_id INTEGER NOT NULL REFERENCES attempts(id),
 incoming_payload_hash TEXT NOT NULL, incoming_raw_hash TEXT NOT NULL,
 export_path TEXT NOT NULL, seen_at TEXT NOT NULL, UNIQUE(attempt_id,incoming_payload_hash)
);
CREATE TABLE IF NOT EXISTS reviews (
 id INTEGER PRIMARY KEY, attempt_id INTEGER NOT NULL REFERENCES attempts(id),
 review_json TEXT NOT NULL, applied_at TEXT NOT NULL
);
CREATE VIEW IF NOT EXISTS eligible_attempts AS
 SELECT a.*, COALESCE(a.official_final,a.raw_final) AS full_time
 FROM attempts a
 WHERE a.mode='TT' AND a.validity='valid' AND a.complete=1 AND a.sectors_verified=1
 AND a.penalty=0 AND a.conflicted=0 AND a.review_origin='user-attested'
 AND a.expected_sectors=(SELECT COUNT(*) FROM sectors s WHERE s.attempt_id=a.id);
