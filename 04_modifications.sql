-- ============================================================
-- GoRecorder – Data Modification Commands
-- CNG 352 | Spring 25/26 | Group 12
-- DBMS: MySQL 8.0+
-- Covers INSERT / UPDATE / DELETE from requirements 1.4.1-1.4.2
-- ============================================================

USE gorecorder;

-- ============================================================
-- INSERT COMMANDS
-- ============================================================

-- INSERT 1 Add a new user with userID, name, email, country, and date_joined.
INSERT INTO User (userID, name, email, country, date_joined)
VALUES (11, 'Noah Kim', 'noah.kim@goworld.com', 'Canada', '2025-01-15');

-- INSERT-2  Record a new match with matchID, komi, handicap, board_size, rule, amount, black player, white player, winner, evidencePng, and evidenceLink.
INSERT INTO `Match` (matchID, komi, handicap, board_size, rule, evidencePng, evidenceLink, plays_black_userID, plays_white_userID, won_by_userID)
VALUES (13, 6.5, 0, 19, 'japanese', NULL, 'https://ogs.online/game/999', 7, 1, 1);


-- INSERT-3 Add a new sponsor with sponsorID and sponsorName. 
INSERT INTO Sponsor (sponsorID, sponsorName)
VALUES (5, 'NHK Go TV');


-- INSERT-4  Register a player for a tournament with their position
INSERT INTO Attend (tournamentID, attend_userID, position)
VALUES (4, 1, 5);


-- INSERT-5  Create a new club with clubID, clubName and created_by player
INSERT INTO Club (clubID, clubName, created_by)
VALUES (4, 'Eurasian Go Circle', 5);


-- ============================================================
-- UPDATE COMMANDS
-- ============================================================

-- UPDATE-1 Update a player's rank. 
UPDATE Player
SET `rank` = '3k'
WHERE userID = 6;


-- UPDATE-2 Update the money amount field of a given sponsored tournament.
UPDATE Sponsored_Tournament
SET amount = amount + 10000.00
WHERE tournamentID = 5;


-- UPDATE-3 Update the evidencePng or evidenceLink of a given match.
UPDATE `Match`
SET evidenceLink = 'https://tygem.com/game/302-corrected'
WHERE matchID = 9;

-- ============================================================
-- DELETE COMMANDS
-- ============================================================

-- DELETE-1 Remove a player's registration from a tournament.
DELETE FROM Attend
WHERE tournamentID = 5
  AND attend_userID = (
      SELECT userID FROM User WHERE email = 'noah.kim@goworld.com'
  );


-- DELETE-2  Remove a sponsor that no longer supports any event.
DELETE FROM Sponsor
WHERE sponsorID = 5;

-- DELETE-3 Delete a sponsored tournament organized by a given admin.
DELETE FROM Tournament
WHERE tournamentID = 3
  AND tournament_userID = 9;
