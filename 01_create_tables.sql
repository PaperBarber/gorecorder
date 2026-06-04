-- ============================================================
-- GoRecorder Database – Physical Design
-- CNG 352 | Spring 25/26 | Group 12
-- Eda İslam (2585081) | Eray Erkut (2637718)
-- DBMS: MySQL 8.0+ 111
-- ============================================================

DROP DATABASE IF EXISTS gorecorder;
CREATE DATABASE gorecorder CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gorecorder;

-- 1. USER
CREATE TABLE User (
    userID      INT             AUTO_INCREMENT PRIMARY KEY,
    email       VARCHAR(255)    NOT NULL UNIQUE,
    name        VARCHAR(100)    NOT NULL,
    country     VARCHAR(100)    NOT NULL,
    date_joined DATE            NOT NULL DEFAULT (CURRENT_DATE),

    CONSTRAINT chk_user_email CHECK (email LIKE '%@%.%')
);

-- 2. ADMIN  (specialisation of User)
CREATE TABLE Admin (
    userID  INT  PRIMARY KEY,

    CONSTRAINT fk_admin_user FOREIGN KEY (userID)
        REFERENCES User(userID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- 3. CLUB
--    created_by FK to Player is added after Player is created
CREATE TABLE Club (
    clubID      INT             AUTO_INCREMENT PRIMARY KEY,
    clubName    VARCHAR(150)    NOT NULL,
    created_by  INT             NOT NULL
);

-- 4. PLAYER  (specialisation of User)
CREATE TABLE Player (
    userID  INT             PRIMARY KEY,
    `rank`    VARCHAR(10)     NOT NULL
                            COMMENT 'Go rank, e.g. 5k, 3d, 9p',
    clubID  INT             DEFAULT NULL
                            COMMENT 'NULL if not a member of any club',

    CONSTRAINT fk_player_user FOREIGN KEY (userID)
        REFERENCES User(userID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_player_club FOREIGN KEY (clubID)
        REFERENCES Club(clubID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_rank_format CHECK (
        `rank` REGEXP '^[1-9][0-9]?[kdp]$'
    )
);

-- Deferred FK: Club.created_by -> Player
ALTER TABLE Club
    ADD CONSTRAINT fk_club_creator FOREIGN KEY (created_by)
        REFERENCES Player(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE;

CREATE TABLE Tournament (
    tournamentID        INT             AUTO_INCREMENT PRIMARY KEY,
    tournament_name     VARCHAR(200)    NOT NULL,
    location            VARCHAR(200)    NOT NULL DEFAULT 'online',
    start_date          DATE            NOT NULL,
    end_date            DATE            DEFAULT NULL,
    max_players         INT             NOT NULL,
    matchmaking_type    VARCHAR(50)     NOT NULL,
    tournament_userID   INT             NOT NULL,

    CONSTRAINT fk_tournament_organiser FOREIGN KEY (tournament_userID)
        REFERENCES User(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_dates       CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_max_players CHECK (max_players > 0),
    CONSTRAINT chk_matchmaking CHECK (
        matchmaking_type IN (
            'round-robin', 'single-elimination',
            'double-elimination', 'swiss', 'mcmahon'
        )
    )
);

CREATE TABLE Sponsored_Tournament (
    tournamentID    INT             PRIMARY KEY,
    adminID         INT             NOT NULL,
    amount          DECIMAL(12,2)   NOT NULL,

    CONSTRAINT fk_st_tournament FOREIGN KEY (tournamentID)
        REFERENCES Tournament(tournamentID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_st_admin FOREIGN KEY (adminID)
        REFERENCES Admin(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_amount CHECK (amount >= 0)
);

CREATE TABLE Sponsor (
    sponsorID   INT             AUTO_INCREMENT PRIMARY KEY,
    sponsorName VARCHAR(200)    NOT NULL
);


CREATE TABLE Has_Sponsor (
    sponsorID               INT NOT NULL,
    sponsored_tournament_ID INT NOT NULL,

    PRIMARY KEY (sponsorID, sponsored_tournament_ID),

    CONSTRAINT fk_hs_sponsor FOREIGN KEY (sponsorID)
        REFERENCES Sponsor(sponsorID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_hs_st FOREIGN KEY (sponsored_tournament_ID)
        REFERENCES Sponsored_Tournament(tournamentID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE `Match` (
    matchID             INT             AUTO_INCREMENT PRIMARY KEY,
    komi                DECIMAL(4,1)    NOT NULL DEFAULT 6.5,
    board_size          TINYINT         NOT NULL DEFAULT 19,
    handicap            TINYINT         NOT NULL DEFAULT 0,
    rule                ENUM('chinese','japanese') NOT NULL,
    evidencePng         LONGBLOB        DEFAULT NULL
                                        COMMENT 'Binary image of the board position',
    evidenceLink        VARCHAR(500)    DEFAULT NULL,
    tournamentID        INT             DEFAULT NULL,
    plays_black_userID  INT             NOT NULL,
    plays_white_userID  INT             NOT NULL,
    won_by_userID       INT             NOT NULL,

    CONSTRAINT fk_match_tournament FOREIGN KEY (tournamentID)
        REFERENCES Tournament(tournamentID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT fk_match_black FOREIGN KEY (plays_black_userID)
        REFERENCES Player(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_match_white FOREIGN KEY (plays_white_userID)
        REFERENCES Player(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_match_winner FOREIGN KEY (won_by_userID)
        REFERENCES Player(userID)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_board_size        CHECK (board_size IN (9, 13, 19)),
    CONSTRAINT chk_handicap          CHECK (handicap BETWEEN 0 AND 9),
    CONSTRAINT chk_komi              CHECK (komi >= 0),
    CONSTRAINT chk_evidence          CHECK (
        evidencePng IS NOT NULL OR evidenceLink IS NOT NULL
    )
    -- Note: chk_different_players and chk_winner are enforced at
    -- the application level due to MySQL 9.6 FK + CHECK restriction.
);

CREATE TABLE Attend (
    tournamentID    INT         NOT NULL,
    attend_userID   INT         NOT NULL,
    position        INT         DEFAULT NULL
                                COMMENT 'Final standing; NULL while ongoing',

    PRIMARY KEY (tournamentID, attend_userID),

    CONSTRAINT fk_attend_tournament FOREIGN KEY (tournamentID)
        REFERENCES Tournament(tournamentID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_attend_player FOREIGN KEY (attend_userID)
        REFERENCES Player(userID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT chk_position CHECK (position IS NULL OR position > 0)
);

-- INDEXES  (based on workload analysis)

-- Most frequent: fetch all matches of a player
CREATE INDEX idx_match_black    ON `Match`(plays_black_userID);
CREATE INDEX idx_match_white    ON `Match`(plays_white_userID);
CREATE INDEX idx_match_winner   ON `Match`(won_by_userID);

-- Fetch matches inside a tournament
CREATE INDEX idx_match_tourn    ON `Match`(tournamentID);

-- Find all players in a club
CREATE INDEX idx_player_club    ON Player(clubID);

-- Query upcoming / past tournaments quickly
CREATE INDEX idx_tourn_dates    ON Tournament(start_date, end_date);

-- Tournaments organised by a specific user
CREATE INDEX idx_tourn_user     ON Tournament(tournament_userID);

-- Sponsored tournaments by admin
CREATE INDEX idx_st_admin       ON Sponsored_Tournament(adminID);
