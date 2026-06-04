-- ============================================================
-- GoRecorder – Sample Data Inserts
-- CNG 352 | Spring 25/26 | Group 12
-- DBMS: MySQL 8.0+
-- ============================================================

USE gorecorder;
-- USERS  (10 users: 8 players + 2 admins)
INSERT INTO User (email, name, country, date_joined) VALUES
('akira.watanabe@mail.jp',      'Akira Watanabe',   'Japan',          '2023-01-10'),
('li.wei@baduk.cn',             'Li Wei',           'China',          '2023-02-14'),
('seo.jinho@kgo.kr',            'Seo Jin-ho',       'South Korea',    '2023-03-05'),
('chen.mei@weiqi.cn',           'Chen Mei',         'China',          '2023-04-20'),
('ivan.petrov@goclub.ru',       'Ivan Petrov',      'Russia',         '2023-05-08'),
('amara.diallo@goafrica.sn',    'Amara Diallo',     'Senegal',        '2023-06-15'),
('emily.clark@ugo.us',          'Emily Clark',      'USA',            '2023-07-22'),
('fatima.al-rashid@goiq.iq',    'Fatima Al-Rashid', 'Iraq',           '2023-08-30'),
('admin.yamada@gorecorder.jp',  'Kenji Yamada',     'Japan',          '2022-11-01'),
('admin.park@gorecorder.kr',    'Park Suji',        'South Korea',    '2022-12-15');

-- ADMINS  (users 9 and 10)
INSERT INTO Admin (userID) VALUES (9), (10);

-- CLUBS  (created_by added after Player rows exist)
-- We insert Club rows first WITHOUT the FK (it was deferred
-- via ALTER TABLE, so we must insert Players first).

-- Temporarily disable FK checks to break the circular dependency
SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO Club (clubName, created_by) VALUES
('Tokyo Go Society',     1),   -- created by Akira (userID 1)
('Beijing Weiqi Club',   2),   -- created by Li Wei (userID 2)
('Seoul Baduk Alliance', 3);   -- created by Seo Jin-ho (userID 3)

SET FOREIGN_KEY_CHECKS = 1;

-- PLAYERS  (users 1-8)
INSERT INTO Player (userID, `rank`, clubID) VALUES
(1, '3d',  1),   -- Akira,   3-dan,  Tokyo Go Society
(2, '5d',  2),   -- Li Wei,  5-dan,  Beijing Weiqi Club
(3, '7d',  3),   -- Seo,     7-dan,  Seoul Baduk Alliance
(4, '2d',  2),   -- Chen,    2-dan,  Beijing Weiqi Club
(5, '1k',  NULL),-- Ivan,    1-kyu,  no club
(6, '5k',  NULL),-- Amara,   5-kyu,  no club
(7, '2k',  1),   -- Emily,   2-kyu,  Tokyo Go Society
(8, '4k',  3);   -- Fatima,  4-kyu,  Seoul Baduk Alliance

-- TOURNAMENTS
INSERT INTO Tournament
    (tournament_name, location, start_date, end_date,
     max_players, matchmaking_type, tournament_userID)
VALUES
('Spring Open 2025',        'Tokyo, Japan',     '2025-03-01', '2025-03-05',  32, 'single-elimination', 1),
('Asia Weiqi Championship', 'Beijing, China',   '2025-04-10', '2025-04-15',  64, 'round-robin',        2),
('Online Blitz Cup',        'online',           '2025-05-01', '2025-05-01',  16, 'swiss',              9),
('Seoul Rapid Masters',     'Seoul, Korea',     '2025-06-20', '2025-06-22',  32, 'mcmahon',            3),
('Global Go League S1',     'online',           '2025-07-01', '2025-09-30', 128, 'round-robin',       10);

-- SPONSORED TOURNAMENTS  (tournamentIDs 3 and 5 are sponsored)
INSERT INTO Sponsored_Tournament (tournamentID, adminID, amount) VALUES
(3, 9,  5000.00),
(5, 10, 25000.00);

-- SPONSORS
INSERT INTO Sponsor (sponsorName) VALUES
('DeepMind'),
('Tygem Go Server'),
('Korean Baduk Association'),
('Fox Weiqi');

-- HAS_SPONSOR
INSERT INTO Has_Sponsor (sponsorID, sponsored_tournament_ID) VALUES
(2, 3),   -- Tygem sponsors Online Blitz Cup
(1, 5),   -- DeepMind sponsors Global Go League
(4, 5);   -- Fox Weiqi also sponsors Global Go League

-- MATCHES  (evidenceLink used as evidence; PNG kept NULL here
--            for brevity; constraint allows either-or)
INSERT INTO `Match`
    (komi, board_size, handicap, rule, evidenceLink,
     tournamentID, plays_black_userID, plays_white_userID, won_by_userID)
VALUES
-- Spring Open 2025 (tournamentID 1)
(6.5, 19, 0, 'japanese', 'https://ogs.online/game/101', 1, 1, 2, 1),
(6.5, 19, 0, 'japanese', 'https://ogs.online/game/102', 1, 3, 4, 3),
(6.5, 19, 0, 'japanese', 'https://ogs.online/game/103', 1, 5, 6, 5),
(6.5, 19, 0, 'japanese', 'https://ogs.online/game/104', 1, 7, 8, 7),
-- Asia Weiqi Championship (tournamentID 2)
(7.5, 19, 0, 'chinese',  'https://foxwq.com/game/201',  2, 2, 3, 3),
(7.5, 19, 0, 'chinese',  'https://foxwq.com/game/202',  2, 4, 1, 1),
(7.5, 19, 0, 'chinese',  'https://foxwq.com/game/203',  2, 6, 7, 7),
-- Online Blitz Cup (tournamentID 3)
(6.5, 13, 0, 'japanese', 'https://tygem.com/game/301',  3, 1, 3, 3),
(6.5, 13, 0, 'japanese', 'https://tygem.com/game/302',  3, 2, 5, 2),
-- Casual / unranked matches (no tournament)
(6.5, 19, 2, 'japanese', 'https://ogs.online/game/401', NULL, 5, 8, 8),
(7.5,  9, 0, 'chinese',  'https://ogs.online/game/402', NULL, 6, 4, 4),
(6.5, 19, 4, 'japanese', 'https://ogs.online/game/403', NULL, 7, 2, 2);

-- ATTEND  (players registered in tournaments)
INSERT INTO Attend (tournamentID, attend_userID, position) VALUES
-- Spring Open 2025
(1, 1, 1), (1, 2, 2), (1, 5, 3), (1, 7, 4),
(1, 3, NULL), (1, 4, NULL), (1, 6, NULL), (1, 8, NULL),
-- Asia Weiqi Championship
(2, 2, 1), (2, 3, 2), (2, 1, 3), (2, 4, 4),
(2, 6, NULL), (2, 7, NULL),
-- Online Blitz Cup
(3, 1, 2), (3, 2, 1), (3, 3, 3), (3, 5, 4),
-- Seoul Rapid Masters
(4, 3, NULL), (4, 4, NULL), (4, 7, NULL), (4, 8, NULL),
-- Global Go League S1
(5, 1, NULL), (5, 2, NULL), (5, 3, NULL), (5, 4, NULL),
(5, 5, NULL), (5, 6, NULL), (5, 7, NULL), (5, 8, NULL);
