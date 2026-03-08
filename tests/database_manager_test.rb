require 'minitest/autorun'
require_relative '../lib/database/database_manager'

class DatabaseManagerTest < Minitest::Test
  def setup
    @test_db_file = "battleship_test_#{Process.pid}_#{rand(9999)}.db"
    # Injeta o arquivo de teste na classe antes de instanciar
    @original_const = DatabaseManager::DB_FILE
    DatabaseManager.send(:remove_const, :DB_FILE)
    DatabaseManager.const_set(:DB_FILE, @test_db_file)
    @db = DatabaseManager.new
  end

  def teardown
    @db.close
    DatabaseManager.send(:remove_const, :DB_FILE)
    DatabaseManager.const_set(:DB_FILE, @original_const)
    File.delete(@test_db_file) if File.exist?(@test_db_file)
  end

  # Usuários

  def test_create_user_success
    user = @db.create_user('Nelson', 'senha123')
    refute_nil user
    assert_equal 'Nelson', user['username']
  end

  def test_create_user_duplicate_returns_nil
    @db.create_user('Nelson', 'senha123')
    result = @db.create_user('Nelson', 'outra')
    assert_nil result
  end

  def test_create_user_empty_name_returns_nil
    assert_nil @db.create_user('', 'senha123')
  end

  def test_authenticate_success
    @db.create_user('Almirante', 'abc123')
    user = @db.authenticate('Almirante', 'abc123')
    refute_nil user
    assert_equal 'Almirante', user['username']
  end

  def test_authenticate_wrong_password
    @db.create_user('Almirante', 'abc123')
    assert_nil @db.authenticate('Almirante', 'errada')
  end

  def test_authenticate_unknown_user
    assert_nil @db.authenticate('Fantasma', 'abc123')
  end

  def test_find_user_case_insensitive
    @db.create_user('Nelson', 'abc')
    user = @db.find_user_by_name('NELSON')
    refute_nil user
    assert_equal 'Nelson', user['username']
  end

  # Partidas

  def test_save_and_retrieve_match
    user = @db.create_user('Marinheiro', 'pw')
    @db.save_match(user_id: user['id'], won: true, score: 1500, duration: 90)

    history = @db.match_history(user['id'])
    assert_equal 1, history.size
    assert_equal 1,    history[0]['won']
    assert_equal 1500, history[0]['score']
    assert_equal 90,   history[0]['duration_seconds']
  end

  def test_match_history_limit
    user = @db.create_user('Cap', 'pw')
    15.times { @db.save_match(user_id: user['id'], won: false, score: 100, duration: 60) }

    history = @db.match_history(user['id'], limit: 10)
    assert_equal 10, history.size
  end

  # Leaderboard

  def test_leaderboard_order_by_score
    u1 = @db.create_user('Capitao', 'pw')
    u2 = @db.create_user('Rookiebot', 'pw')

    @db.save_match(user_id: u1['id'], won: true,  score: 3000, duration: 100)
    @db.save_match(user_id: u2['id'], won: true,  score: 1000, duration: 120)

    board = @db.leaderboard(limit: 5)
    assert_equal 'Capitao',   board[0]['username']
    assert_equal 'Rookiebot', board[1]['username']
  end

  def test_leaderboard_aggregates_wins_losses
    u = @db.create_user('Jogador', 'pw')
    @db.save_match(user_id: u['id'], won: true,  score: 500, duration: 60)
    @db.save_match(user_id: u['id'], won: false, score: 0,   duration: 40)
    @db.save_match(user_id: u['id'], won: true,  score: 800, duration: 70)

    board = @db.leaderboard(limit: 1)
    assert_equal 2,    board[0]['wins']
    assert_equal 1,    board[0]['losses']
    assert_equal 1300, board[0]['total_score']
  end

  def test_leaderboard_empty_when_no_users
    board = @db.leaderboard
    assert_equal [], board
  end
end

