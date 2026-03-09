<div align="center">
  <img src="assets/images/logo.png" alt="Battleship Logo" width="320"/>

  # Battleship — Batalha Naval

  > Jogo de Batalha Naval desenvolvido em **Ruby** com a biblioteca **Gosu**, criado para a disciplina de Paradigmas de Linguagens de Programação (PLP).

  ![Ruby](https://img.shields.io/badge/Ruby-3.x-red?logo=ruby)
  ![Gosu](https://img.shields.io/badge/Gosu-0.15+-blue)
  ![SQLite](https://img.shields.io/badge/SQLite-3-lightblue?logo=sqlite)
  ![License](https://img.shields.io/badge/Licença-MIT-green)
</div>

---

## Sumário

- [Sobre o Projeto](#sobre-o-projeto)
- [Funcionalidades](#funcionalidades)
- [Pré-requisitos](#pré-requisitos)
- [Instalação e Execução](#instalação-e-execução)
- [Como Jogar](#como-jogar)
- [Modos de Jogo](#modos-de-jogo)
- [Navios](#navios)
- [Inteligência Artificial](#inteligência-artificial)
- [Conquistas](#conquistas)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Testes](#testes)
- [Autores](#autores)

---

## Sobre o Projeto

Battleship é uma implementação completa do clássico jogo de tabuleiro **Batalha Naval**, com interface gráfica, sistema de contas, ranking global, modo campanha e um sistema de conquistas. O jogador enfrenta diferentes oponentes controlados por IA com níveis de dificuldade progressivos, culminando no temido **Davy Jones** no modo Impossível.

---

## Funcionalidades

- **Login e Cadastro** — sistema de autenticação com persistência em banco de dados SQLite
- **Modo Campanha** — quatro missões desbloqueáveis em sequência
- **Partida Livre** — escolha a dificuldade da IA manualmente
- **Movimentação de Navios** — reposicione seus navios durante o combate
- **Ranking** — placar global com pontuação e histórico de partidas
- **Sistema de Conquistas** — medalhas desbloqueáveis por desempenho
- **Áudio** — trilha sonora e efeitos sonoros com suporte a toggle
- **Animações** — explosões e efeitos visuais nas jogadas
- **Tela cheia** — a janela entra em modo fullscreen após o login

---

## Pré-requisitos

- **Ruby** 3.0 ou superior
- **Bundler** (`gem install bundler`)
- Dependências de sistema para a Gosu (SDL2, OpenGL, etc.)

### Instalando dependências do sistema (Ubuntu/Debian)

```bash
sudo apt install libsdl2-dev libgl1-mesa-dev libopenal-dev \
                 libmpg123-dev libopus-dev libvorbis-dev
```

---

## Instalação e Execução

```bash
# Clone o repositório
git clone https://github.com/Jurandirtvaz/battleship.git
cd battleship

# Instale as gems
bundle install

# Execute o jogo
ruby main.rb
```

---

## Como Jogar

1. **Tela de Login** — crie uma conta ou entre com suas credenciais.
2. **Menu Principal** — escolha entre *Jogar*, *Campanha*, *Ranking*, *Conquistas* ou *Opções*.
3. **Posicionamento** — os navios são distribuídos automaticamente no tabuleiro.
4. **Combate:**
   - Clique em uma célula do tabuleiro inimigo para atirar.
   - **Acerto** → você atira novamente.
   - **Água** → vez da IA.
   - **Movimento** (partida livre) → antes de atirar, você pode mover um navio com as setas do teclado ou pular com `Enter`/`Espaço`.
5. Quem afundar toda a frota inimiga primeiro vence!

### Controles

| Ação | Controle |
|------|----------|
| Atirar | Clique esquerdo no grid inimigo |
| Selecionar navio para mover | Clique esquerdo no seu grid |
| Mover navio | ↑ ↓ ← → |
| Confirmar / Pular movimento | `Enter` ou `Espaço` |
| Pausar | Botão `⏸` ou `Esc` |

---

## Modos de Jogo

### Campanha

Quatro missões desbloqueáveis em sequência. Vencer uma missão desbloqueia a próxima.

| Missão | Título | Dificuldade |
|--------|--------|-------------|
| 1 | Dia de Treinamento | Fácil |
| 2 | O Atlântico | Médio |
| 3 | Chefe Final | Difícil |
| 4 | O Ataque de Davy Jones | **Impossível** |

### Partida Livre

Escolha qualquer dificuldade e jogue sem restrições, com movimentação de navios habilitada.

---

## Navios

| Navio | Tamanho |
|-------|---------|
| Submarino | 1 célula |
| Warship | 3 células |
| Battleship | 4 células |
| Flattop (Porta-Aviões) | 6 células |

---

## Inteligência Artificial

| Dificuldade | Comportamento |
|-------------|---------------|
| **Fácil** | Dispara aleatoriamente no tabuleiro |
| **Médio** | Após acertar, explora células adjacentes |
| **Difícil** | Rastreamento avançado com destruição direcionada de navios |
| **Impossível** | Davy Jones — concede turnos livres ao jogador e depois destrói toda a frota com conhecimento total do tabuleiro |

---

## Conquistas

| Ícone | Conquista | Como desbloquear |
|-------|-----------|------------------|
| ★ | **Almirante** | Vença sem perder nenhum navio |
| ⚓ | **Capitão de Mar e Guerra** | Acerte 8 tiros consecutivos |
| ⚔ | **Capitão** | Acerte navios de 7 tipos diferentes em sequência |
| ⏱ | **Marinheiro** | Vença em menos de 3 minutos |
| ☠ | **Alma Negra** | Derrote Davy Jones no modo Impossível |

---

## Estrutura do Projeto

```
battleship/
├── main.rb                      # Ponto de entrada — inicializa a GameWindow
├── Gemfile                      # Dependências Ruby
├── achievements.json            # Conquistas desbloqueadas (gerado automaticamente)
├── battleship.db                # Banco de dados SQLite (gerado automaticamente)
├── assets/
│   ├── images/                  # Logo, background, crosshair
│   ├── ships/                   # Sprites dos navios
│   ├── musics/                  # Trilha sonora
│   ├── sfx/                     # Efeitos sonoros
│   └── animations/              # Frames de animação
├── lib/
│   ├── database/
│   │   └── database_manager.rb  # Acesso ao SQLite (usuários, partidas, ranking)
│   ├── engine/
│   │   ├── achievement_manager.rb  # Lógica de conquistas
│   │   ├── movement_mechanics.rb   # Movimentação de navios
│   │   ├── shooting_mechanics.rb   # Mecânica de tiros
│   │   └── turn_manager.rb         # Controle de turnos
│   ├── models/
│   │   ├── board.rb             # Tabuleiro 10×10
│   │   ├── player.rb            # Jogador humano
│   │   ├── ai/                  # Bots (easy, medium, hard, impossible)
│   │   └── ships/               # Classes dos navios
│   ├── screens/                 # Telas do jogo (login, menu, game, etc.)
│   └── ui/                      # Componentes visuais (notificações, tema, animações)
└── tests/                       # Testes unitários com Minitest
```

---

## Testes

```bash
# Executar todos os testes
ruby -Ilib -Itests tests/<arquivo>_test.rb

# Exemplo: testar o tabuleiro
ruby -Ilib -Itests tests/board_test.rb
```

Os testes cobrem: `Board`, `Player`, `TurnManager`, `AchievementManager`, `DatabaseManager`, `ShootingMechanics`, `MovementMechanics`, `EasyBot`, `MediumBot` e `HardBot`.

---

## Autores

Desenvolvido por [**Jurandir Neto**](https://github.com/jurandirtvaz), [**João Francisco**](https://github.com/joaofamello) e [**José Gustavo**](https://github.com/gustavo7a) para a disciplina de PLP.

---

<div align="center">
  <sub>☠ Que os mares estejam com você, marinheiro. ☠</sub>
</div>
