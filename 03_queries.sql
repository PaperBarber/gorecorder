USE gorecorder;

-- ------------------------------------------------------------
-- Q-A  List all matches played by a given player (as black OR
--      white), ordered by matchID (proxy for chronology).
--      Uses UNION to merge both sides.
-- ------------------------------------------------------------
SELECT
    m.matchID,
    'black'                                     AS played_as,
    u_w.name                                    AS opponent,
    CASE WHEN m.won_by_userID = m.plays_black_userID
         THEN 'Win' ELSE 'Loss' END             AS result,
    m.board_size,
    m.rule,
    t.tournament_name
FROM `Match` m
JOIN User u_w ON u_w.userID = m.plays_white_userID
LEFT JOIN Tournament t ON t.tournamentID = m.tournamentID
WHERE m.plays_black_userID = 1           -- :playerID

UNION

SELECT
    m.matchID,
    'white'                                     AS played_as,
    u_b.name                                    AS opponent,
    CASE WHEN m.won_by_userID = m.plays_white_userID
         THEN 'Win' ELSE 'Loss' END             AS result,
    m.board_size,
    m.rule,
    t.tournament_name
FROM `Match` m
JOIN User u_b ON u_b.userID = m.plays_black_userID
LEFT JOIN Tournament t ON t.tournamentID = m.tournamentID
WHERE m.plays_white_userID = 1           -- :playerID

ORDER BY matchID;

-- Q-B  B. Display the total number of wins and losses for a given player.

SELECT
    u.userID,
    u.name,
    p.`rank`,
    COUNT(*) AS total_matches,
    SUM(CASE WHEN m.won_by_userID = u.userID THEN 1 ELSE 0 END) AS wins,
    COUNT(*) - SUM(CASE WHEN m.won_by_userID = u.userID THEN 1 ELSE 0 END)
    AS losses
FROM User u
JOIN Player p ON p.userID = u.userID
JOIN (SELECT plays_black_userID AS uid, won_by_userID FROM `Match`
    UNION ALL
    SELECT plays_white_userID, won_by_userID FROM `Match`) m ON m.uid = u.userID
WHERE u.userID = 1          -- change 1 to any playerID
GROUP BY u.userID, u.name, p.`rank`;


-- Q-D Display all tournaments a given player has attended and their position.
SELECT
    t.tournamentID,
    t.tournament_name,
    t.location,
    t.start_date,
    t.end_date,
    a.position
FROM Attend a
JOIN Tournament t ON t.tournamentID = a.tournamentID
WHERE a.attend_userID = 1         
ORDER BY t.start_date;

-- Q-E List all matches included in a given tournament.
SELECT
    m.matchID,
    u_b.name    AS black_player,
    u_w.name    AS white_player,
    m.komi,
    m.handicap,
    m.board_size,
    m.rule
FROM `Match` m
JOIN User u_b ON u_b.userID = m.plays_black_userID
JOIN User u_w ON u_w.userID = m.plays_white_userID
WHERE m.tournamentID = 1      
ORDER BY m.matchID;

-- G. List all sponsored tournaments with their sponsor names and organizing admins.
SELECT
    t.tournament_name,
    u_admin.name        AS admin_name,
    GROUP_CONCAT(sp.sponsorName ORDER BY sp.sponsorName SEPARATOR ', ') AS sponsors
FROM Sponsored_Tournament st
JOIN Tournament t ON t.tournamentID = st.tournamentID
JOIN Admin a ON a.userID = st.adminID
JOIN User u_admin ON u_admin.userID  = a.userID
JOIN Has_Sponsor hs ON hs.sponsored_tournament_ID = st.tournamentID
JOIN Sponsor sp ON sp.sponsorID = hs.sponsorID
GROUP BY
    t.tournamentID, t.tournament_name, u_admin.name
ORDER BY t.tournament_name;

-- ------------------------------------------------------------
-- Q-J  All players whose rank falls within a given range.
--      Rank is mapped to a numeric scale:
--        25k = 1 ... 1k = 25, 1d = 26 ... 9d = 34, 1p = 35 ... 9p = 43
-- ------------------------------------------------------------
SELECT
    u.userID,
    u.name,
    u.country,
    p.`rank`,
    CASE
        WHEN p.`rank` REGEXP '[0-9]+k' THEN
            26 - CAST(SUBSTRING(p.`rank`, 1, CHAR_LENGTH(p.`rank`)-1) AS UNSIGNED)
        WHEN p.`rank` REGEXP '[0-9]+d' THEN
            25 + CAST(SUBSTRING(p.`rank`, 1, CHAR_LENGTH(p.`rank`)-1) AS UNSIGNED)
        WHEN p.`rank` REGEXP '[0-9]+p' THEN
            34 + CAST(SUBSTRING(p.`rank`, 1, CHAR_LENGTH(p.`rank`)-1) AS UNSIGNED)
    END AS rank_numeric
FROM Player p
JOIN User u ON u.userID = p.userID
HAVING rank_numeric BETWEEN 25 AND 35    -- e.g. 1k to 1d range
ORDER BY rank_numeric DESC;


-- ------------------------------------------------------------
-- Q-K  Head-to-head record between two given players.
--      Uses UNION ALL + GROUP BY to count wins per player.
-- ------------------------------------------------------------
SELECT
    u.name                                          AS player,
    COUNT(*)                                        AS h2h_wins
FROM (
    SELECT won_by_userID
    FROM `Match`
    WHERE (plays_black_userID = 1 AND plays_white_userID = 3)   -- :p1, :p2
       OR (plays_black_userID = 3 AND plays_white_userID = 1)
) h2h
JOIN User u ON u.userID = h2h.won_by_userID
GROUP BY u.userID, u.name;


-- ------------------------------------------------------------
-- Q-N  Matches with a handicap greater than zero, showing
--      how many stones the weaker player received.
-- ------------------------------------------------------------
SELECT
    m.matchID,
    u_b.name    AS black_player,
    u_w.name    AS white_player,
    m.handicap,
    m.board_size,
    m.rule,
    u_w.name    AS winner      -- handicap given to black, so white often wins
FROM `Match` m
JOIN User u_b ON u_b.userID = m.plays_black_userID
JOIN User u_w ON u_w.userID = m.plays_white_userID
WHERE m.handicap > 0
ORDER BY m.handicap DESC, m.matchID;


-- ------------------------------------------------------------
-- Q-P  Total matches played by each player (aggregate).
-- ------------------------------------------------------------
SELECT
    u.userID,
    u.name,
    p.`rank`,
    COUNT(*) AS total_matches
FROM (
    SELECT plays_black_userID AS uid FROM `Match`
    UNION ALL
    SELECT plays_white_userID          FROM `Match`
) all_matches
JOIN Player p ON p.userID = all_matches.uid
JOIN User   u ON u.userID = all_matches.uid
GROUP BY u.userID, u.name, p.`rank`
ORDER BY total_matches DESC;


-- ------------------------------------------------------------
-- Q-Q  Matches that have an evidencePng uploaded.
-- ------------------------------------------------------------
SELECT
    m.matchID,
    u_b.name    AS black_player,
    u_w.name    AS white_player,
    m.board_size,
    m.rule
FROM `Match` m
JOIN User u_b ON u_b.userID = m.plays_black_userID
JOIN User u_w ON u_w.userID = m.plays_white_userID
WHERE m.evidencePng IS NOT NULL;


-- ------------------------------------------------------------
-- Q-T  Each sponsor and the number of tournaments they have
--      sponsored, ordered by most active sponsor.
-- ------------------------------------------------------------
SELECT
    sp.sponsorID,
    sp.sponsorName,
    COUNT(hs.sponsored_tournament_ID)   AS tournaments_sponsored,
    SUM(st.amount)                      AS total_prize_contributed
FROM Sponsor sp
LEFT JOIN Has_Sponsor hs           ON hs.sponsorID = sp.sponsorID
LEFT JOIN Sponsored_Tournament st  ON st.tournamentID = hs.sponsored_tournament_ID
GROUP BY sp.sponsorID, sp.sponsorName
ORDER BY tournaments_sponsored DESC;
