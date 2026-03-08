require 'sqlite3'

# Camada de acesso ao banco de dados SQLite.
# Gerencia usuários, histórico de partidas e leaderboard.
#
# Tabelas:
#   users   → id, username, password_hash, created_at
#   matches → id, user_id, won, score, duration_seconds, played_at
#
# @author Jurandir Neto
class DatabaseManager
  DB_FILE = 'battleship.db'.freeze

  def initialize
    @db = SQLite3::Database.new(DB_FILE)
    @db.results_as_hash = true
    setup_tables
  end

  # Fecha a conexão com o banco de dados.
  def close
    @db.close rescue nil
  end

  # Cria um novo usuário. Retorna o user hash ou nil se o nome já existe.
  # @param username [String]
  # @param password [String] senha em texto puro (armazenada com hash simples)
  # @return [Hash, nil]
  def create_user(username, password)
    return nil if username.strip.empty?
    return nil if find_user_by_name(username)

    @db.execute(
      "INSERT INTO users (username, password_hash, created_at) VALUES (?, ?, ?)",
      [username.strip, hash_password(password), Time.now.to_s]
    )
    find_user_by_name(username)
  rescue SQLite3::Exception
    nil
  end

  # Autentica um usuário. Retorna o user hash ou nil.
  # @param username [String]
  # @param password [String]
  # @return [Hash, nil]
  def authenticate(username, password)
    user = find_user_by_name(username)
    return nil unless user
    return nil unless user['password_hash'] == hash_password(password)
    user
  end

  # Busca usuário pelo nome (case-insensitive).
  # @return [Hash, nil]
  def find_user_by_name(username)
    @db.get_first_row(
      "SELECT * FROM users WHERE LOWER(username) = LOWER(?)",
      [username.strip]
    )
  end

  #Partidas

  # Registra o resultado de uma partida.
  # @param user_id  [Integer]
  # @param won      [Boolean]
  # @param score    [Integer]
  # @param duration [Integer] segundos
  def save_match(user_id:, won:, score:, duration:)
    @db.execute(
      "INSERT INTO matches (user_id, won, score, duration_seconds, played_at)
       VALUES (?, ?, ?, ?, ?)",
      [user_id, won ? 1 : 0, score, duration, Time.now.to_s]
    )
  end

  # Retorna o histórico de partidas de um usuário pelos mais recentes.
  # @param user_id [Integer]
  # @param limit   [Integer]
  # @return [Array<Hash>]
  def match_history(user_id, limit: 10)
    @db.execute(
      "SELECT * FROM matches WHERE user_id = ?
       ORDER BY played_at DESC LIMIT ?",
      [user_id, limit]
    )
  end

  # Leaderboard
  # Top N jogadores por pontuação total de vitórias.
  # @param limit [Integer]
  # @return [Array<Hash>] chaves: username, total_score, wins, losses
  def leaderboard(limit: 10)
    @db.execute(
      "SELECT u.username,
              COALESCE(SUM(m.score), 0)          AS total_score,
              COALESCE(SUM(m.won), 0)             AS wins,
              COALESCE(COUNT(m.id) - SUM(m.won), 0) AS losses
       FROM users u
       LEFT JOIN matches m ON m.user_id = u.id
       GROUP BY u.id
       ORDER BY total_score DESC, wins DESC
       LIMIT ?",
      [limit]
    )
  end

  # Campanha

  # Retorna o estágio de campanha salvo de um usuário (1-3).
  # @param user_id [Integer]
  # @return [Integer]
  def get_campaign_stage(user_id)
    row = @db.get_first_row(
      "SELECT stage FROM campaign_progress WHERE user_id = ?",
      [user_id]
    )
    row ? row['stage'].to_i : 1
  end

  # Salva o estágio de campanha de um usuário.
  # @param user_id [Integer]
  # @param stage   [Integer]
  def set_campaign_stage(user_id, stage)
    @db.execute(
      "INSERT INTO campaign_progress (user_id, stage)
       VALUES (?, ?)
       ON CONFLICT(user_id) DO UPDATE SET stage = excluded.stage",
      [user_id, stage]
    )
  end

  private

  # Hash simples via XOR + Base64.
  def hash_password(password)
    require 'digest'
    Digest::SHA256.hexdigest("battleship_salt_#{password}")
  end

  def setup_tables
    @db.execute_batch(<<~SQL)
      CREATE TABLE IF NOT EXISTS users (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        username      TEXT    NOT NULL UNIQUE,
        password_hash TEXT    NOT NULL,
        created_at    TEXT    NOT NULL
      );

      CREATE TABLE IF NOT EXISTS matches (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          INTEGER NOT NULL,
        won              INTEGER NOT NULL DEFAULT 0,
        score            INTEGER NOT NULL DEFAULT 0,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        played_at        TEXT    NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      );

      CREATE TABLE IF NOT EXISTS campaign_progress (
        user_id INTEGER PRIMARY KEY,
        stage   INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users(id)
      );
    SQL
  end
end


