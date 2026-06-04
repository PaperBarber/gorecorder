import mysql.connector
import os
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()

def get_db_connection():
    host = os.environ.get('DB_HOST', '127.0.0.1')
    user = os.environ.get('DB_USER', 'root')
    password = os.environ.get('DB_PASSWORD', '')
    database = os.environ.get('DB_NAME', 'gorecorder')
    
    return mysql.connector.connect(
        host=host,
        user=user,
        password=password,
        database=database
    )

def create_user(name, email, country, password, rank, club_id=None, is_admin=False):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Check if email exists
        cursor.execute("SELECT * FROM User WHERE email = %s", (email,))
        if cursor.fetchone():
            return False, "Email already exists"
            
        password_hash = generate_password_hash(password)
        
        # Insert User
        cursor.execute("""
            INSERT INTO User (name, email, country, password_hash)
            VALUES (%s, %s, %s, %s)
        """, (name, email, country, password_hash))
        
        user_id = cursor.lastrowid
        
        # Insert as Player
        if club_id and club_id != 'none':
            cursor.execute("""
                INSERT INTO Player (userID, `rank`, clubID)
                VALUES (%s, %s, %s)
            """, (user_id, rank, club_id))
        else:
            cursor.execute("""
                INSERT INTO Player (userID, `rank`)
                VALUES (%s, %s)
            """, (user_id, rank))

        # Insert as Admin if requested
        if is_admin:
            cursor.execute("""
                INSERT INTO Admin (userID)
                VALUES (%s)
            """, (user_id,))
            
        conn.commit()
        return True, "Registration successful"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def authenticate_user(email, password):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM User WHERE email = %s", (email,))
        user = cursor.fetchone()
        
        if user and user['password_hash'] and check_password_hash(user['password_hash'], password):
            # Also check if they are a player
            cursor.execute("SELECT * FROM Player WHERE userID = %s", (user['userID'],))
            player_info = cursor.fetchone()
            if player_info:
                user['rank'] = player_info['rank']
            
            # Check if admin
            cursor.execute("SELECT * FROM Admin WHERE userID = %s", (user['userID'],))
            if cursor.fetchone():
                user['is_admin'] = True
            else:
                user['is_admin'] = False
                
            return True, user
        return False, "Invalid email or password"
    except Exception as e:
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def get_player_stats(user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT u.name, p.`rank`, COUNT(m.uid) AS total_matches,
                   COALESCE(SUM(CASE WHEN m.won_by_userID = u.userID THEN 1 ELSE 0 END), 0) AS wins,
                   COALESCE(SUM(CASE WHEN m.uid IS NOT NULL AND m.won_by_userID != u.userID THEN 1 ELSE 0 END), 0) AS losses
            FROM User u
            JOIN Player p ON p.userID = u.userID
            LEFT JOIN (
                SELECT plays_black_userID AS uid, won_by_userID FROM `Match`
                UNION ALL
                SELECT plays_white_userID AS uid, won_by_userID FROM `Match`
            ) m ON m.uid = u.userID
            WHERE u.userID = %s
            GROUP BY u.userID, u.name, p.`rank`;
        """, (user_id,))
        stats = cursor.fetchone()
        
        # Convert Decimals/Types if needed
        if stats:
            stats['wins'] = int(stats['wins'])
            stats['losses'] = int(stats['losses'])
            
        return stats
    except Exception as e:
        print(e)
        return None
    finally:
        cursor.close()
        conn.close()

def get_player_matches(user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT m.matchID, 'black' AS played_as, u_w.name AS opponent,
                   CASE WHEN m.won_by_userID = m.plays_black_userID THEN 'Win' ELSE 'Loss' END AS result,
                   m.board_size, m.rule, m.komi, m.handicap, m.evidenceLink, t.tournament_name
            FROM `Match` m
            JOIN User u_w ON u_w.userID = m.plays_white_userID
            LEFT JOIN Tournament t ON m.tournamentID = t.tournamentID
            WHERE m.plays_black_userID = %s
            UNION
            SELECT m.matchID, 'white' AS played_as, u_b.name AS opponent,
                   CASE WHEN m.won_by_userID = m.plays_white_userID THEN 'Win' ELSE 'Loss' END AS result,
                   m.board_size, m.rule, m.komi, m.handicap, m.evidenceLink, t.tournament_name
            FROM `Match` m
            JOIN User u_b ON u_b.userID = m.plays_black_userID
            LEFT JOIN Tournament t ON m.tournamentID = t.tournamentID
            WHERE m.plays_white_userID = %s
            ORDER BY matchID DESC LIMIT 10;
        """, (user_id, user_id))
        matches = cursor.fetchall()
        return matches
    except Exception as e:
        print(e)
        return []
    finally:
        cursor.close()
        conn.close()

def get_all_players(exclude_id=None):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        query = "SELECT u.userID, u.name, p.`rank` FROM User u JOIN Player p ON u.userID = p.userID"
        params = ()
        if exclude_id:
            query += " WHERE u.userID != %s"
            params = (exclude_id,)
        cursor.execute(query, params)
        return cursor.fetchall()
    except Exception as e:
        return []
    finally:
        cursor.close()
        conn.close()

def get_all_clubs():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Club")
        return cursor.fetchall()
    except Exception as e:
        return []
    finally:
        cursor.close()
        conn.close()

def get_sponsors():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Sponsor")
        return cursor.fetchall()
    except Exception as e:
        return []
    finally:
        cursor.close()
        conn.close()

def record_match(plays_black_userID, plays_white_userID, won_by_userID, komi, handicap, board_size, rule, evidenceLink, tournamentID=None):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            INSERT INTO `Match` (komi, handicap, board_size, rule, evidenceLink, plays_black_userID, plays_white_userID, won_by_userID, tournamentID)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (komi, handicap, board_size, rule, evidenceLink, plays_black_userID, plays_white_userID, won_by_userID, tournamentID))
        conn.commit()
        return True, "Match recorded successfully"
    except Exception as e:
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def get_match(match_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM `Match` WHERE matchID = %s", (match_id,))
        return cursor.fetchone()
    except Exception as e:
        print(e)
        return None
    finally:
        cursor.close()
        conn.close()

def update_match(match_id, user_id, komi, handicap, rule, evidenceLink):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Check if user is part of the match (black or white)
        cursor.execute("SELECT * FROM `Match` WHERE matchID = %s AND (plays_black_userID = %s OR plays_white_userID = %s)", 
                       (match_id, user_id, user_id))
        if not cursor.fetchone():
            return False, "Unauthorized: You did not play in this match"
            
        cursor.execute("""
            UPDATE `Match` 
            SET komi = %s, handicap = %s, rule = %s, evidenceLink = %s 
            WHERE matchID = %s
        """, (komi, handicap, rule, evidenceLink, match_id))
        conn.commit()
        return True, "Match updated successfully"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def delete_match(match_id, user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Check if user is part of the match
        cursor.execute("SELECT * FROM `Match` WHERE matchID = %s AND (plays_black_userID = %s OR plays_white_userID = %s)", 
                       (match_id, user_id, user_id))
        if not cursor.fetchone():
            return False, "Unauthorized: You did not play in this match"
            
        cursor.execute("DELETE FROM `Match` WHERE matchID = %s", (match_id,))
        conn.commit()
        return True, "Match deleted successfully"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def get_tournaments():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT t.tournamentID, t.tournament_name, t.location, t.start_date, t.end_date, 
                   t.max_players, t.matchmaking_type, u.name AS organizer,
                   COUNT(a.attend_userID) AS current_players,
                   IF(st.amount IS NOT NULL, TRUE, FALSE) AS is_sponsored,
                   st.amount AS sponsor_amount
            FROM Tournament t
            JOIN User u ON t.tournament_userID = u.userID
            LEFT JOIN Attend a ON t.tournamentID = a.tournamentID
            LEFT JOIN Sponsored_Tournament st ON t.tournamentID = st.tournamentID
            GROUP BY t.tournamentID
            ORDER BY t.start_date DESC;
        """)
        return cursor.fetchall()
    except Exception as e:
        print(e)
        return []
    finally:
        cursor.close()
        conn.close()

def get_user_attendances(user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT tournamentID FROM Attend WHERE attend_userID = %s", (user_id,))
        rows = cursor.fetchall()
        return [row['tournamentID'] for row in rows]
    except Exception as e:
        return []
    finally:
        cursor.close()
        conn.close()

def join_tournament(tournament_id, user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Check max players limit
        cursor.execute("SELECT max_players FROM Tournament WHERE tournamentID = %s", (tournament_id,))
        t = cursor.fetchone()
        
        cursor.execute("SELECT COUNT(*) as count FROM Attend WHERE tournamentID = %s", (tournament_id,))
        c = cursor.fetchone()
        
        if t and c and c['count'] >= t['max_players']:
            return False, "Tournament is full"
            
        cursor.execute("""
            INSERT INTO Attend (tournamentID, attend_userID)
            VALUES (%s, %s)
        """, (tournament_id, user_id))
        conn.commit()
        return True, "Joined tournament successfully"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def create_tournament(user_id, name, location, start_date, end_date, max_players, matchmaking):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # If end_date is empty string, set it to None (NULL in DB)
        end_date = end_date if end_date else None
        
        cursor.execute("""
            INSERT INTO Tournament (tournament_name, location, start_date, end_date, max_players, matchmaking_type, tournament_userID)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (name, location, start_date, end_date, max_players, matchmaking, user_id))
        conn.commit()
        return True, "Tournament created successfully"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def create_sponsored_tournament(admin_id, name, location, start_date, end_date, max_players, matchmaking, amount, sponsor_ids):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        end_date = end_date if end_date else None
        
        # 1. Create Tournament
        cursor.execute("""
            INSERT INTO Tournament (tournament_name, location, start_date, end_date, max_players, matchmaking_type, tournament_userID)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (name, location, start_date, end_date, max_players, matchmaking, admin_id))
        tournament_id = cursor.lastrowid
        
        # 2. Create Sponsored_Tournament
        cursor.execute("""
            INSERT INTO Sponsored_Tournament (tournamentID, adminID, amount)
            VALUES (%s, %s, %s)
        """, (tournament_id, admin_id, amount))
        
        # 3. Link Sponsors
        if isinstance(sponsor_ids, list):
            for sid in sponsor_ids:
                cursor.execute("""
                    INSERT INTO Has_Sponsor (sponsorID, sponsored_tournament_ID)
                    VALUES (%s, %s)
                """, (sid, tournament_id))
                
        conn.commit()
        return True, "Sponsored Tournament created successfully"
    except Exception as e:
        conn.rollback()
        return False, str(e)
    finally:
        cursor.close()
        conn.close()

def get_tournament_details(tournament_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # Get Players
        cursor.execute("""
            SELECT u.name, p.`rank`
            FROM Attend a
            JOIN User u ON a.attend_userID = u.userID
            JOIN Player p ON u.userID = p.userID
            WHERE a.tournamentID = %s
        """, (tournament_id,))
        players = cursor.fetchall()
        
        # Get Sponsors
        cursor.execute("""
            SELECT s.sponsorName
            FROM Has_Sponsor hs
            JOIN Sponsor s ON hs.sponsorID = s.sponsorID
            WHERE hs.sponsored_tournament_ID = %s
        """, (tournament_id,))
        sponsors = cursor.fetchall()
        
        return {'players': players, 'sponsors': sponsors}
    except Exception as e:
        print(e)
        return {'players': [], 'sponsors': []}
    finally:
        cursor.close()
        conn.close()

def get_joined_tournaments(user_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT t.tournamentID, t.tournament_name
            FROM Tournament t
            JOIN Attend a ON t.tournamentID = a.tournamentID
            WHERE a.attend_userID = %s
        """, (user_id,))
        return cursor.fetchall()
    except Exception as e:
        print(e)
        return []
    finally:
        cursor.close()
        conn.close()

def get_shared_tournaments(user1_id, user2_id):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT t.tournamentID, t.tournament_name
            FROM Tournament t
            JOIN Attend a1 ON t.tournamentID = a1.tournamentID
            JOIN Attend a2 ON t.tournamentID = a2.tournamentID
            WHERE a1.attend_userID = %s AND a2.attend_userID = %s
        """, (user1_id, user2_id))
        return cursor.fetchall()
    except Exception as e:
        print(e)
        return []
    finally:
        cursor.close()
        conn.close()
