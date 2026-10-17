-- DDL SQLite para o MVP de AR Graffiti
-- Nota: O SQLAlchemy cria automaticamente estas tabelas ao iniciar a API (Base.metadata.create_all)

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    hashed_password TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS graffitis (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL, -- png, jpg, jpeg, gif
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    surface_type TEXT NOT NULL, -- vertical_wall, horizontal_floor, horizontal_ceiling
    status TEXT DEFAULT 'active' NOT NULL, -- active, overwritten, expired, flagged_hidden
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    protection_until TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    reports_count INTEGER DEFAULT 0 NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_graffitis_lat_lon ON graffitis(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_graffitis_status ON graffitis(status);
CREATE INDEX IF NOT EXISTS idx_graffitis_expires ON graffitis(expires_at);

CREATE TABLE IF NOT EXISTS graffiti_reports (
    id TEXT PRIMARY KEY,
    graffiti_id TEXT NOT NULL,
    reporter_id TEXT NOT NULL,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    UNIQUE(graffiti_id, reporter_id),
    FOREIGN KEY(graffiti_id) REFERENCES graffitis(id) ON DELETE CASCADE,
    FOREIGN KEY(reporter_id) REFERENCES users(id) ON DELETE CASCADE
);
