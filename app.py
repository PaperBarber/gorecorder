from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
import os
from werkzeug.utils import secure_filename
from db import (
    create_user, authenticate_user, get_player_stats, get_player_matches, 
    get_all_players, record_match, get_all_clubs,
    get_tournaments, get_user_attendances, join_tournament, create_tournament,
    create_sponsored_tournament, get_sponsors, get_tournament_details, get_joined_tournaments, get_shared_tournaments,
    delete_match, get_match, update_match
)

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'default_secret')
app.config['UPLOAD_FOLDER'] = os.path.join('static', 'uploads')

@app.context_processor
def inject_user():
    return dict(
        user_id=session.get('user_id'),
        user_name=session.get('user_name'),
        is_admin=session.get('is_admin', False)
    )

@app.route('/')
def index():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    user_id = session['user_id']
    stats = get_player_stats(user_id)
    matches = get_player_matches(user_id)
    
    return render_template('dashboard.html', stats=stats, matches=matches)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        
        success, result = authenticate_user(email, password)
        if success:
            session['user_id'] = result['userID']
            session['user_name'] = result['name']
            session['user_email'] = result['email']
            session['is_admin'] = result.get('is_admin', False)
            return redirect(url_for('index'))
        else:
            flash(result, 'error')
            
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        name = request.form.get('name')
        email = request.form.get('email')
        country = request.form.get('country')
        password = request.form.get('password')
        rank = request.form.get('rank')
        club_id = request.form.get('club_id')
        is_admin = request.form.get('is_admin') == 'on'
        
        if is_admin:
            admin_key = request.form.get('admin_key')
            if admin_key != os.environ.get('ADMIN_KEY', 'secret_admin_key'):
                flash('Invalid admin registration key.', 'error')
                return redirect(url_for('register'))
        
        success, message = create_user(name, email, country, password, rank, club_id, is_admin)
        if success:
            flash('Registration successful! Please log in.', 'success')
            return redirect(url_for('login'))
        else:
            flash(message, 'error')
            
    clubs = get_all_clubs()
    return render_template('register.html', clubs=clubs)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/record_match', methods=['GET', 'POST'])
def record_match_route():
    if 'user_id' not in session:
        return redirect(url_for('login'))
        
    user_id = session['user_id']
    
    if request.method == 'POST':
        played_as = request.form.get('played_as')
        opponent_id = request.form.get('opponent_id')
        komi = request.form.get('komi')
        handicap = request.form.get('handicap')
        board_size = request.form.get('board_size')
        rule = request.form.get('rule')
        result = request.form.get('result')
        
        evidenceLink = request.form.get('evidenceLink')
        evidence_file = request.files.get('evidence_file')
        
        if evidence_file and evidence_file.filename != '':
            filename = secure_filename(evidence_file.filename)
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            evidence_file.save(file_path)
            evidenceLink = '/' + file_path.replace('\\', '/')
            
        tournament_id = request.form.get('tournament_id')
        if tournament_id == 'none' or not tournament_id:
            tournament_id = None
        
        plays_black_userID = user_id if played_as == 'black' else opponent_id
        plays_white_userID = opponent_id if played_as == 'black' else user_id
        won_by_userID = user_id if result == 'win' else opponent_id
        
        success, message = record_match(
            plays_black_userID, plays_white_userID, won_by_userID, 
            komi, handicap, board_size, rule, evidenceLink, tournament_id
        )
        
        if success:
            flash(message, 'success')
            return redirect(url_for('index'))
        else:
            flash(message, 'error')
            
    players = get_all_players(exclude_id=user_id)
    joined_tournaments = get_joined_tournaments(user_id)
    return render_template('record_match.html', players=players, joined_tournaments=joined_tournaments)

@app.route('/tournaments', methods=['GET'])
def tournaments():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    tournaments_list = get_tournaments()
    attending = get_user_attendances(session['user_id'])
    sponsors = get_sponsors() if session.get('is_admin') else []
    
    return render_template('tournaments.html', tournaments=tournaments_list, attending=attending, sponsors=sponsors)

@app.route('/tournaments/join', methods=['POST'])
def join_tournament_route():
    if 'user_id' not in session:
        return jsonify({'success': False, 'message': 'Unauthorized'}), 401
        
    data = request.json
    tid = data.get('tournament_id')
    
    success, message = join_tournament(tid, session['user_id'])
    return jsonify({'success': success, 'message': message})

@app.route('/api/tournaments/<int:tournament_id>/details', methods=['GET'])
def api_tournament_details(tournament_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    details = get_tournament_details(tournament_id)
    return jsonify(details)

@app.route('/api/shared_tournaments/<int:user1_id>/<int:user2_id>', methods=['GET'])
def api_shared_tournaments(user1_id, user2_id):
    if 'user_id' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    
    tournaments = get_shared_tournaments(user1_id, user2_id)
    return jsonify(tournaments)

@app.route('/tournaments/create', methods=['POST'])
def create_tournament_route():
    if 'user_id' not in session:
        return redirect(url_for('login'))
        
    name = request.form.get('tournament_name')
    location = request.form.get('location')
    start_date = request.form.get('start_date')
    end_date = request.form.get('end_date')
    max_players = request.form.get('max_players')
    matchmaking = request.form.get('matchmaking_type')
    
    success, message = create_tournament(session['user_id'], name, location, start_date, end_date, max_players, matchmaking)
    if success:
        flash(message, 'success')
    else:
        flash(message, 'error')
    return redirect(url_for('tournaments'))

@app.route('/tournaments/create_sponsored', methods=['POST'])
def create_sponsored_tournament_route():
    if not session.get('is_admin'):
        flash('Unauthorized. Admins only.', 'error')
        return redirect(url_for('tournaments'))
        
    name = request.form.get('tournament_name')
    location = request.form.get('location')
    start_date = request.form.get('start_date')
    end_date = request.form.get('end_date')
    max_players = request.form.get('max_players')
    matchmaking = request.form.get('matchmaking_type')
    amount = request.form.get('amount')
    sponsor_ids = request.form.getlist('sponsor_ids')
    
    success, message = create_sponsored_tournament(
        session['user_id'], name, location, start_date, end_date, 
        max_players, matchmaking, amount, sponsor_ids
    )
    if success:
        flash(message, 'success')
    else:
        flash(message, 'error')
    return redirect(url_for('tournaments'))

@app.route('/match/<int:match_id>/delete', methods=['POST'])
def delete_match_route(match_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    success, message = delete_match(match_id, session['user_id'])
    if success:
        flash(message, 'success')
    else:
        flash(message, 'error')
    return redirect(url_for('index'))

@app.route('/match/<int:match_id>/edit', methods=['GET', 'POST'])
def edit_match_route(match_id):
    if 'user_id' not in session:
        return redirect(url_for('login'))
        
    user_id = session['user_id']
    match = get_match(match_id)
    
    if not match:
        flash('Match not found', 'error')
        return redirect(url_for('index'))
        
    if match['plays_black_userID'] != user_id and match['plays_white_userID'] != user_id:
        flash('Unauthorized: You did not play in this match', 'error')
        return redirect(url_for('index'))
        
    if request.method == 'POST':
        komi = request.form.get('komi')
        handicap = request.form.get('handicap')
        rule = request.form.get('rule')
        evidenceLink = request.form.get('evidenceLink')
        
        success, message = update_match(match_id, user_id, komi, handicap, rule, evidenceLink)
        if success:
            flash(message, 'success')
            return redirect(url_for('index'))
        else:
            flash(message, 'error')
            
    return render_template('edit_match.html', match=match)

if __name__ == '__main__':
    app.run(debug=True)
