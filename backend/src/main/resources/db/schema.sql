-- =================================================================
-- SoF4-Games — Database Schema
-- PostgreSQL 16 (Neon.tech)
-- Convention: snake_case, plural table names
--
-- Groups:
--   1. Authentication & User Profile
--   2. Games Catalog
--   3. Social
--   4. Commerce
--   5. Future Growth
--   6. Indexes
-- =================================================================


-- =================================================================
-- GROUP 1: Authentication & User Profile
-- =================================================================

CREATE TABLE users (
                       id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
                       email           VARCHAR(255)    NOT NULL UNIQUE,
                       password_hash   VARCHAR(255)    NOT NULL,
                       is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
                       created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                       updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Separated from users: public profile info, managed independently from credentials.
-- Spring Security only needs the users table to authenticate.
CREATE TABLE user_profiles (
                               id              UUID            PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                               display_name    VARCHAR(100),
                               username        VARCHAR(50)     UNIQUE,     -- vanity URL, e.g. /profile/raiksha
                               bio             TEXT,
                               avatar_url      TEXT,
                               location        VARCHAR(100),               -- e.g. "Santiago, Chile" (shown in profile page)
                               updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);


-- =================================================================
-- GROUP 2: Games Catalog
-- =================================================================

-- Collection enum: the three sets defined in the catalog strategy.
-- indie_latam  → 65 most popular Latin American indie games
-- indie_global → 35 most popular global indie games
-- top_steam    → 100 most popular games on Steam overall
CREATE TYPE game_collection AS ENUM ('indie_latam', 'indie_global', 'top_steam');

CREATE TABLE games (
                       id                      BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                       steam_appid             INTEGER         NOT NULL UNIQUE,
                       collection              game_collection NOT NULL DEFAULT 'top_steam',

    -- Basic info
                       name                    VARCHAR(255)    NOT NULL,
                       short_description       TEXT,
                       detailed_description    TEXT,           -- full plain-text description (no HTML)
                       website                 VARCHAR(255),
                       is_free                 BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Pricing (amounts in cents, e.g. 1050000 = CLP$ 10.500)
    -- Formatted strings stored for display performance (avoids formatting on every render)
                       price_initial           INTEGER         NOT NULL DEFAULT 0,
                       price_final             INTEGER         NOT NULL DEFAULT 0,
                       discount_percent        INTEGER         NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
                       currency                VARCHAR(10)     NOT NULL DEFAULT 'CLP',
                       price_initial_formatted VARCHAR(30),    -- e.g. 'CLP$ 10.500'
                       price_final_formatted   VARCHAR(30),    -- e.g. 'CLP$ 5.250'

    -- Images (Steam CDN URLs)
                       header_image            TEXT,           -- 600×338 — used in cards
                       capsule_image           TEXT,           -- 231×87  — used in small cards
                       background_raw          TEXT,           -- page background (not used in hero)

    -- Release
                       release_date            DATE,
                       coming_soon             BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Classification
                       required_age            INTEGER         NOT NULL DEFAULT 0,
                       supported_languages     TEXT,           -- comma-separated, e.g. 'Inglés, Español, Francés'
                       controller_support      VARCHAR(20),    -- 'full', 'partial', or NULL

    -- Platform availability
                       platform_windows        BOOLEAN         NOT NULL DEFAULT FALSE,
                       platform_mac            BOOLEAN         NOT NULL DEFAULT FALSE,
                       platform_linux          BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Reviews & ratings
                       review_score_desc       VARCHAR(100),   -- e.g. 'Abrumadoramente positivas'
                       total_positive          INTEGER         NOT NULL DEFAULT 0,
                       total_negative          INTEGER         NOT NULL DEFAULT 0,
                       recommendations_total   INTEGER         NOT NULL DEFAULT 0,

    -- Metacritic (nullable — many games don't have a score)
                       metacritic_score        INTEGER         CHECK (metacritic_score BETWEEN 0 AND 100),
                       metacritic_url          TEXT,

    -- Achievements
                       achievements_total      INTEGER         NOT NULL DEFAULT 0,

    -- System requirements stored as structured JSON:
    -- { "pc": { "minimum": "...", "recommended": "..." },
    --   "mac": { "minimum": "...", "recommended": null },
    --   "linux": { "minimum": "...", "recommended": "..." } }
                       system_requirements     JSONB,

                       created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                       updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- User-defined Steam tags (up to 10 per game, ordered by vote count)
-- Stored as a simple ordered array rather than a separate table,
-- since tags are read-only catalog data (never queried individually by tag in MVP).
CREATE TABLE game_tags (
                           game_id     BIGINT          NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                           tag         VARCHAR(100)    NOT NULL,
                           sort_order  INTEGER         NOT NULL DEFAULT 0,  -- 0 = highest vote count
                           PRIMARY KEY (game_id, tag)
);

-- Genre catalog using Steam's own IDs (e.g. 1=Action, 25=Adventure)
CREATE TABLE genres (
                        id      INTEGER         PRIMARY KEY,    -- Steam's genre ID
                        name    VARCHAR(100)    NOT NULL
);

-- N:M between games and genres
CREATE TABLE game_genres (
                             game_id     BIGINT      NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                             genre_id    INTEGER     NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
                             PRIMARY KEY (game_id, genre_id)
);

-- Category catalog using Steam's own IDs (e.g. 2=Single-player, 1=Multi-player)
CREATE TABLE categories (
                            id      INTEGER         PRIMARY KEY,    -- Steam's category ID
                            name    VARCHAR(100)    NOT NULL
);

-- N:M between games and categories
CREATE TABLE game_categories (
                                 game_id         BIGINT      NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                                 category_id     INTEGER     NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
                                 PRIMARY KEY (game_id, category_id)
);

CREATE TABLE developers (
                            id      BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                            name    VARCHAR(255)    NOT NULL UNIQUE
);

-- N:M between games and developers (one game can have multiple devs)
CREATE TABLE game_developers (
                                 game_id         BIGINT  NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                                 developer_id    BIGINT  NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
                                 PRIMARY KEY (game_id, developer_id)
);

CREATE TABLE publishers (
                            id      BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                            name    VARCHAR(255)    NOT NULL UNIQUE
);

-- N:M between games and publishers
CREATE TABLE game_publishers (
                                 game_id         BIGINT  NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                                 publisher_id    BIGINT  NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
                                 PRIMARY KEY (game_id, publisher_id)
);

-- Screenshots per game, preserving Steam's original display order.
-- path_full used in hero carousel and GamePage gallery viewer.
-- path_thumbnail used in GamePage gallery thumbnails.
CREATE TABLE screenshots (
                             id              BIGINT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                             game_id         BIGINT  NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                             steam_id        INTEGER NOT NULL,       -- Steam's own screenshot ID
                             path_thumbnail  TEXT    NOT NULL,       -- 600×338
                             path_full       TEXT    NOT NULL,       -- 1920×1080
                             display_order   INTEGER NOT NULL DEFAULT 0,
                             UNIQUE (game_id, steam_id)
);


-- =================================================================
-- GROUP 3: Social
-- =================================================================

-- A single row represents the full friendship relationship.
-- requester_id: who sent the request.
-- addressee_id: who received it.
-- To get all friends of user X: WHERE (requester_id = X OR addressee_id = X) AND status = 'ACCEPTED'
CREATE TABLE friendships (
                             id              BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                             requester_id    UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                             addressee_id    UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                             status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING'
                                 CHECK (status IN ('PENDING', 'ACCEPTED', 'BLOCKED')),
                             created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                             updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                             UNIQUE (requester_id, addressee_id),
                             CHECK (requester_id != addressee_id)
    );


-- =================================================================
-- GROUP 4: Commerce
-- =================================================================

-- Represents completed purchases (the user's library).
-- ON DELETE RESTRICT on game_id: a game cannot be deleted if any user has purchased it.
-- This protects purchase history integrity.
CREATE TABLE purchases (
                           id              BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                           user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                           game_id         BIGINT      NOT NULL REFERENCES games(id) ON DELETE RESTRICT,
                           price_paid      INTEGER     NOT NULL DEFAULT 0,         -- in cents at time of purchase
                           currency_paid   VARCHAR(10) NOT NULL DEFAULT 'CLP',
                           purchased_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                           UNIQUE (user_id, game_id)   -- a user cannot purchase the same game twice
);

-- Active shopping cart. Cleared on checkout (rows deleted, purchases inserted — in one transaction).
-- ON DELETE CASCADE on game_id: if a game is removed, it is automatically cleared from all carts.
CREATE TABLE cart_items (
                            id          BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                            user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                            game_id     BIGINT      NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                            added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                            UNIQUE (user_id, game_id)
);


-- =================================================================
-- GROUP 5: Future Growth
-- =================================================================

-- Wishlist: not required for MVP but shown in GamePage wireframe (Lista de deseos button).
CREATE TABLE wishlists (
                           id          BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                           user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                           game_id     BIGINT      NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                           added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                           UNIQUE (user_id, game_id)
);

-- Reviews: shown in GamePage wireframe (Reseñas tab).
-- Not implemented in Sprint 1 but schema is ready to avoid future migrations.
CREATE TABLE reviews (
                         id          BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                         user_id     UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                         game_id     BIGINT          NOT NULL REFERENCES games(id) ON DELETE CASCADE,
                         rating      INTEGER         NOT NULL CHECK (rating BETWEEN 1 AND 5),
                         body        TEXT,
                         created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                         updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
                         UNIQUE (user_id, game_id)   -- one review per user per game
);


-- =================================================================
-- GROUP 6: Indexes
-- =================================================================

-- users
CREATE INDEX idx_users_email ON users(email);

-- user_profiles
CREATE INDEX idx_user_profiles_username ON user_profiles(username);

-- games — columns commonly used for filtering, sorting and searching
CREATE INDEX idx_games_steam_appid     ON games(steam_appid);
CREATE INDEX idx_games_collection      ON games(collection);
CREATE INDEX idx_games_name            ON games(name);
CREATE INDEX idx_games_is_free         ON games(is_free);
CREATE INDEX idx_games_price_final     ON games(price_final);
CREATE INDEX idx_games_discount        ON games(discount_percent);
CREATE INDEX idx_games_release_date    ON games(release_date);
CREATE INDEX idx_games_review_score    ON games(review_score_desc);
CREATE INDEX idx_games_total_positive  ON games(total_positive);

-- Full-text search on game name and description (for search bar)
CREATE INDEX idx_games_fts ON games USING GIN (
    to_tsvector('spanish', coalesce(name, '') || ' ' || coalesce(short_description, ''))
    );

-- screenshots — always queried by game
CREATE INDEX idx_screenshots_game_id    ON screenshots(game_id);
CREATE INDEX idx_screenshots_order      ON screenshots(game_id, display_order);

-- game_tags — queried by game
CREATE INDEX idx_game_tags_game_id ON game_tags(game_id);

-- friendships — queried in both directions + by status
CREATE INDEX idx_friendships_requester  ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee  ON friendships(addressee_id);
CREATE INDEX idx_friendships_status     ON friendships(status);

-- purchases — most common query: "what has this user bought?"
CREATE INDEX idx_purchases_user_id      ON purchases(user_id);
CREATE INDEX idx_purchases_game_id      ON purchases(game_id);
CREATE INDEX idx_purchases_purchased_at ON purchases(purchased_at);

-- cart
CREATE INDEX idx_cart_items_user_id ON cart_items(user_id);

-- wishlists
CREATE INDEX idx_wishlists_user_id ON wishlists(user_id);

-- reviews
CREATE INDEX idx_reviews_game_id  ON reviews(game_id);
CREATE INDEX idx_reviews_user_id  ON reviews(user_id);
CREATE INDEX idx_reviews_rating   ON reviews(rating);