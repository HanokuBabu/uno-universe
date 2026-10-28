import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ==========================================
// 1. MODELS & CONSTANTS
// ==========================================

enum CardColor { red, blue, green, yellow, wild }

enum CardValue {
  zero, one, two, three, four, five, six, seven, eight, nine,
  skip, reverse, drawTwo, wild, wildDrawFour
}

class UnoCard {
  final String id;
  final CardColor color;
  final CardValue value;

  const UnoCard({
    required this.id,
    required this.color,
    required this.value,
  });

  bool get isWild => color == CardColor.wild;

  int get scoreValue {
    switch (value) {
      case CardValue.zero: return 0;
      case CardValue.one: return 1;
      case CardValue.two: return 2;
      case CardValue.three: return 3;
      case CardValue.four: return 4;
      case CardValue.five: return 5;
      case CardValue.six: return 6;
      case CardValue.seven: return 7;
      case CardValue.eight: return 8;
      case CardValue.nine: return 9;
      case CardValue.skip:
      case CardValue.reverse:
      case CardValue.drawTwo: return 20;
      case CardValue.wild:
      case CardValue.wildDrawFour: return 50;
    }
  }

  String get symbol {
    switch (value) {
      case CardValue.zero: return '0';
      case CardValue.one: return '1';
      case CardValue.two: return '2';
      case CardValue.three: return '3';
      case CardValue.four: return '4';
      case CardValue.five: return '5';
      case CardValue.six: return '6';
      case CardValue.seven: return '7';
      case CardValue.eight: return '8';
      case CardValue.nine: return '9';
      case CardValue.skip: return '⊘';
      case CardValue.reverse: return '⇄';
      case CardValue.drawTwo: return '+2';
      case CardValue.wild: return '★';
      case CardValue.wildDrawFour: return '+4';
    }
  }
}

class Player {
  final String id;
  final String name;
  final bool isAi;
  final List<UnoCard> hand;
  bool hasDeclaredUno;

  Player({
    required this.id,
    required this.name,
    required this.isAi,
    List<UnoCard>? hand,
    this.hasDeclaredUno = false,
  }) : hand = hand ?? [];

  void addCard(UnoCard card) {
    hand.add(card);
    if (hand.length > 1) {
      hasDeclaredUno = false;
    }
  }
}

// ==========================================
// 2. CORE GAME ENGINE & AI LOGIC
// ==========================================

enum GameDirection { clockwise, counterClockwise }

class UnoGameState {
  final List<Player> players;
  final List<UnoCard> drawPile;
  final List<UnoCard> discardPile;

  int currentPlayerIndex;
  GameDirection direction;
  CardColor activeColor;
  bool isGameOver;
  Player? winner;

  UnoGameState({
    required this.players,
    required this.drawPile,
    required this.discardPile,
    this.currentPlayerIndex = 0,
    this.direction = GameDirection.clockwise,
    required this.activeColor,
    this.isGameOver = false,
    this.winner,
  });

  Player get currentPlayer => players[currentPlayerIndex];
  UnoCard get topDiscardCard => discardPile.last;

  static List<UnoCard> generateStandardDeck() {
    final List<UnoCard> deck = [];
    final colors = [CardColor.red, CardColor.blue, CardColor.green, CardColor.yellow];
    int idCounter = 1;

    for (var color in colors) {
      deck.add(UnoCard(id: '${idCounter++}', color: color, value: CardValue.zero));
      for (int i = 0; i < 2; i++) {
        for (var v = CardValue.one.index; v <= CardValue.nine.index; v++) {
          deck.add(UnoCard(id: '${idCounter++}', color: color, value: CardValue.values[v]));
        }
        deck.add(UnoCard(id: '${idCounter++}', color: color, value: CardValue.skip));
        deck.add(UnoCard(id: '${idCounter++}', color: color, value: CardValue.reverse));
        deck.add(UnoCard(id: '${idCounter++}', color: color, value: CardValue.drawTwo));
      }
    }

    for (int i = 0; i < 4; i++) {
      deck.add(UnoCard(id: '${idCounter++}', color: CardColor.wild, value: CardValue.wild));
      deck.add(UnoCard(id: '${idCounter++}', color: CardColor.wild, value: CardValue.wildDrawFour));
    }

    deck.shuffle(Random());
    return deck;
  }

  static UnoGameState initializeMatch(List<String> names) {
    final deck = generateStandardDeck();
    final players = names.asMap().entries.map((e) {
      return Player(id: 'p_${e.key}', name: e.value, isAi: e.key != 0);
    }).toList();

    for (var p in players) {
      for (int i = 0; i < 7; i++) {
        p.addCard(deck.removeLast());
      }
    }

    UnoCard topCard = deck.removeLast();
    while (topCard.value == CardValue.wildDrawFour) {
      deck.insert(0, topCard);
      topCard = deck.removeLast();
    }

    return UnoGameState(
      players: players,
      drawPile: deck,
      discardPile: [topCard],
      activeColor: topCard.isWild ? CardColor.red : topCard.color,
    );
  }

  bool isValidMove(UnoCard card) {
    if (card.isWild) return true;
    if (card.color == activeColor) return true;
    if (card.value == topDiscardCard.value) return true;
    return false;
  }

  void recycleDiscardPileIfNeeded() {
    if (drawPile.isEmpty && discardPile.length > 1) {
      final top = discardPile.removeLast();
      drawPile.addAll(discardPile);
      discardPile.clear();
      drawPile.shuffle(Random());
      discardPile.add(top);
    }
  }

  UnoCard drawCard(Player player) {
    recycleDiscardPileIfNeeded();
    if (drawPile.isEmpty) {
      throw StateError("Deck exhausted");
    }
    final card = drawPile.removeLast();
    player.addCard(card);
    return card;
  }

  void advanceTurn({int steps = 1}) {
    final shift = direction == GameDirection.clockwise ? steps : -steps;
    currentPlayerIndex = (currentPlayerIndex + shift) % players.length;
    if (currentPlayerIndex < 0) {
      currentPlayerIndex += players.length;
    }
  }

  void playCard({
    required Player player,
    required UnoCard card,
    CardColor? declaredWildColor,
  }) {
    if (!isValidMove(card)) throw ArgumentError("Invalid move");

    player.hand.remove(card);
    discardPile.add(card);

    if (card.isWild) {
      activeColor = declaredWildColor ?? CardColor.red;
    } else {
      activeColor = card.color;
    }

    if (player.hand.isEmpty) {
      isGameOver = true;
      winner = player;
      return;
    }

    switch (card.value) {
      case CardValue.skip:
        advanceTurn(steps: 2);
        break;
      case CardValue.reverse:
        if (players.length == 2) {
          advanceTurn(steps: 2);
        } else {
          direction = direction == GameDirection.clockwise
              ? GameDirection.counterClockwise
              : GameDirection.clockwise;
          advanceTurn(steps: 1);
        }
        break;
      case CardValue.drawTwo:
        advanceTurn(steps: 1);
        drawCard(currentPlayer);
        drawCard(currentPlayer);
        advanceTurn(steps: 1);
        break;
      case CardValue.wildDrawFour:
        advanceTurn(steps: 1);
        for (int i = 0; i < 4; i++) {
          drawCard(currentPlayer);
        }
        advanceTurn(steps: 1);
        break;
      default:
        advanceTurn(steps: 1);
    }
  }
}

// ==========================================
// 3. STATE MANAGEMENT (RIVERPOD NOTIFIER)
// ==========================================

class GameUiState {
  final UnoGameState gameState;
  final bool isAiThinking;
  final String statusMessage;

  const GameUiState({
    required this.gameState,
    this.isAiThinking = false,
    this.statusMessage = 'Your turn! Match color, number, or play a Wild.',
  });

  GameUiState copyWith({
    UnoGameState? gameState,
    bool? isAiThinking,
    String? statusMessage,
  }) {
    return GameUiState(
      gameState: gameState ?? this.gameState,
      isAiThinking: isAiThinking ?? this.isAiThinking,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class GameNotifier extends StateNotifier<GameUiState> {
  GameNotifier()
      : super(GameUiState(
          gameState: UnoGameState.initializeMatch(['You', 'Bot Alex', 'Bot Sam', 'Bot Maya']),
        ));

  void startNewGame() {
    state = GameUiState(
      gameState: UnoGameState.initializeMatch(['You', 'Bot Alex', 'Bot Sam', 'Bot Maya']),
      statusMessage: "New game started. Your turn!",
    );
  }

  void playPlayerCard(UnoCard card, {CardColor? chosenColor}) {
    if (state.isAiThinking || state.gameState.isGameOver) return;
    final human = state.gameState.players.first;
    if (state.gameState.currentPlayer.id != human.id) return;

    if (!state.gameState.isValidMove(card)) {
      state = state.copyWith(statusMessage: "Illegal move! Color or value must match.");
      return;
    }

    state.gameState.playCard(
      player: human,
      card: card,
      declaredWildColor: chosenColor,
    );

    _verifyUnoDeclarations(human);
    _checkWinOrAdvance();
  }

  void drawPlayerCard() {
    if (state.isAiThinking || state.gameState.isGameOver) return;
    final human = state.gameState.players.first;
    if (state.gameState.currentPlayer.id != human.id) return;

    final drawn = state.gameState.drawCard(human);
    state = state.copyWith(statusMessage: "You drew ${drawn.color.name.toUpperCase()} ${drawn.symbol}");

    if (!state.gameState.isValidMove(drawn)) {
      state.gameState.advanceTurn();
      _checkWinOrAdvance();
    }
  }

  void declareUno(String playerId) {
    final player = state.gameState.players.firstWhere((p) => p.id == playerId);
    if (player.hand.length == 1) {
      player.hasDeclaredUno = true;
      state = state.copyWith(statusMessage: "${player.name} yelled UNO!");
    }
  }

  void catchMissedUno(String targetId) {
    final player = state.gameState.players.firstWhere((p) => p.id == targetId);
    if (player.hand.length == 1 && !player.hasDeclaredUno) {
      state.gameState.drawCard(player);
      state.gameState.drawCard(player);
      state = state.copyWith(statusMessage: "Caught ${player.name} not saying UNO! (+2 cards penalty)");
    }
  }

  void _checkWinOrAdvance() {
    if (state.gameState.isGameOver) {
      state = state.copyWith(
        statusMessage: "Round Over! ${state.gameState.winner?.name} won the game!",
      );
      return;
    }

    state = state.copyWith(
      gameState: state.gameState,
      statusMessage: "${state.gameState.currentPlayer.name}'s turn",
    );

    if (state.gameState.currentPlayer.isAi) {
      _executeAiTurn();
    }
  }

  Future<void> _executeAiTurn() async {
    state = state.copyWith(isAiThinking: true);

    await Future.delayed(const Duration(milliseconds: 1000));

    final ai = state.gameState.currentPlayer;
    final validCards = ai.hand.where((c) => state.gameState.isValidMove(c)).toList();

    if (validCards.isNotEmpty) {
      validCards.sort((a, b) => b.scoreValue.compareTo(a.scoreValue));
      final chosen = validCards.first;

      CardColor? wildColor;
      if (chosen.isWild) {
        wildColor = _getMostCommonColor(ai.hand);
      }

      state.gameState.playCard(player: ai, card: chosen, declaredWildColor: wildColor);
      _verifyUnoDeclarations(ai);
    } else {
      final drawn = state.gameState.drawCard(ai);
      if (state.gameState.isValidMove(drawn)) {
        state.gameState.playCard(
          player: ai,
          card: drawn,
          declaredWildColor: drawn.isWild ? CardColor.red : null,
        );
        _verifyUnoDeclarations(ai);
      } else {
        state.gameState.advanceTurn();
      }
    }

    state = state.copyWith(isAiThinking: false);
    _checkWinOrAdvance();
  }

  CardColor _getMostCommonColor(List<UnoCard> hand) {
    final counts = {CardColor.red: 0, CardColor.blue: 0, CardColor.green: 0, CardColor.yellow: 0};
    for (var c in hand) {
      if (c.color != CardColor.wild) counts[c.color] = (counts[c.color] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  void _verifyUnoDeclarations(Player p) {
    if (p.hand.length == 1 && p.isAi) {
      if (Random().nextDouble() < 0.9) {
        p.hasDeclaredUno = true;
        state = state.copyWith(statusMessage: "${p.name} shouted UNO!");
      }
    }
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameUiState>((ref) {
  return GameNotifier();
});

// ==========================================
// 4. UI WIDGETS & GAME TABLE
// ==========================================

class UnoColors {
  static const tableBg = Color(0xFF111726);
  static const red = Color(0xFFE71D36);
  static const blue = Color(0xFF0D47A1);
  static const green = Color(0xFF2EC4B6);
  static const yellow = Color(0xFFFF9F1C);
  static const wild = Color(0xFF212529);
}

class UnoCardWidget extends StatelessWidget {
  final UnoCard card;
  final bool isPlayable;
  final VoidCallback? onTap;
  final bool isFaceDown;
  final double width;
  final double height;

  const UnoCardWidget({
    super.key,
    required this.card,
    this.isPlayable = false,
    this.onTap,
    this.isFaceDown = false,
    this.width = 68,
    this.height = 104,
  });

  Color _resolveColor(CardColor color) {
    switch (color) {
      case CardColor.red: return UnoColors.red;
      case CardColor.blue: return UnoColors.blue;
      case CardColor.green: return UnoColors.green;
      case CardColor.yellow: return UnoColors.yellow;
      case CardColor.wild: return UnoColors.wild;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isFaceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2638),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(2, 2))],
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: UnoColors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'UNO',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final baseColor = _resolveColor(card.color);

    return GestureDetector(
      onTap: isPlayable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isPlayable ? -8 : 0, 0),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPlayable ? Colors.amberAccent : Colors.white70,
            width: isPlayable ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlayable ? Colors.amberAccent.withOpacity(0.5) : Colors.black38,
              blurRadius: isPlayable ? 10 : 3,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 3,
                  left: 4,
                  child: Text(
                    card.symbol,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      width: width * 0.72,
                      height: height * 0.44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.elliptical(45, 26)),
                      ),
                      child: Center(
                        child: Text(
                          card.symbol,
                          style: TextStyle(
                            color: baseColor == UnoColors.wild ? Colors.deepPurple : baseColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 3,
                  right: 4,
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: Text(
                      card.symbol,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnoGameScreen extends ConsumerWidget {
  const UnoGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final state = game.gameState;
    final human = state.players.first;
    final opponents = state.players.sublist(1);

    return Scaffold(
      backgroundColor: UnoColors.tableBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Status Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black26,
                  child: Row(
                    children: [
                      const Text('UNO LEGENDS', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.amber)),
                      const Spacer(),
                      Expanded(
                        flex: 3,
                        child: Text(
                          game.statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: () => ref.read(gameProvider.notifier).startNewGame(),
                      ),
                    ],
                  ),
                ),

                // Opponents Avatars
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: opponents.map((opp) {
                      final isTurn = state.currentPlayer.id == opp.id;
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isTurn ? Colors.amberAccent : Colors.transparent, width: 2.5),
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blueGrey.shade800,
                              child: Text(opp.name[0], style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(opp.name, style: TextStyle(fontSize: 11, color: isTurn ? Colors.amberAccent : Colors.white70)),
                          Text('${opp.hand.length} cards', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const Spacer(),

                // Center Board: Draw Deck & Discard Pile
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Draw Pile
                    UnoCardWidget(
                      card: const UnoCard(id: 'deck', color: CardColor.wild, value: CardValue.zero),
                      isFaceDown: true,
                      isPlayable: state.currentPlayer.id == human.id && !game.isAiThinking,
                      onTap: () => ref.read(gameProvider.notifier).drawPlayerCard(),
                    ),
                    const SizedBox(width: 30),
                    // Discard Pile with Active Color Aura
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _resolveColor(state.activeColor).withOpacity(0.6),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: UnoCardWidget(
                        card: state.topDiscardCard,
                        isPlayable: false,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // UNO Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (human.hand.length <= 2)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UnoColors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => ref.read(gameProvider.notifier).declareUno(human.id),
                          child: const Text('UNO!', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                        )
                      else
                        const SizedBox.shrink(),

                      // Catch Bot Missed UNO
                      ...opponents.where((o) => o.hand.length == 1 && !o.hasDeclaredUno).map((o) {
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                          onPressed: () => ref.read(gameProvider.notifier).catchMissedUno(o.id),
                          child: Text('CATCH ${o.name}!', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                        );
                      }),
                    ],
                  ),
                ),

                // Player Hand Scrollable List
                Container(
                  height: 125,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: human.hand.length,
                    itemBuilder: (context, index) {
                      final card = human.hand[index];
                      final isPlayable = state.isValidMove(card) &&
                          state.currentPlayer.id == human.id &&
                          !game.isAiThinking;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: UnoCardWidget(
                          card: card,
                          isPlayable: isPlayable,
                          onTap: () {
                            if (card.isWild) {
                              _showColorDialog(context, ref, card);
                            } else {
                              ref.read(gameProvider.notifier).playPlayerCard(card);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Game Over Modal
            if (state.isGameOver)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
                        const SizedBox(height: 12),
                        Text(
                          '${state.winner?.name} Won!',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: UnoColors.green),
                          onPressed: () => ref.read(gameProvider.notifier).startNewGame(),
                          child: const Text('PLAY AGAIN', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _resolveColor(CardColor color) {
    switch (color) {
      case CardColor.red: return UnoColors.red;
      case CardColor.blue: return UnoColors.blue;
      case CardColor.green: return UnoColors.green;
      case CardColor.yellow: return UnoColors.yellow;
      case CardColor.wild: return Colors.purple;
    }
  }

  void _showColorDialog(BuildContext context, WidgetRef ref, UnoCard card) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2638),
        title: const Text('Choose Wild Color', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorBtn(ctx, ref, card, CardColor.red, UnoColors.red),
            _colorBtn(ctx, ref, card, CardColor.blue, UnoColors.blue),
            _colorBtn(ctx, ref, card, CardColor.green, UnoColors.green),
            _colorBtn(ctx, ref, card, CardColor.yellow, UnoColors.yellow),
          ],
        ),
      ),
    );
  }

  Widget _colorBtn(BuildContext ctx, WidgetRef ref, UnoCard card, CardColor color, Color displayColor) {
    return GestureDetector(
      onTap: () {
        Navigator.of(ctx).pop();
        ref.read(gameProvider.notifier).playPlayerCard(card, chosenColor: color);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle),
      ),
    );
  }
}

// ==========================================
// 5. APPLICATION ENTRY POINT
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: UnoLegendsApp()));
}

class UnoLegendsApp extends StatelessWidget {
  const UnoLegendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNO Legends',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: UnoColors.tableBg,
      ),
      home: const UnoGameScreen(),
    );
  }
}