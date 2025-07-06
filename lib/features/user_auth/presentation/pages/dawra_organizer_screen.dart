import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_drawer.dart';
import 'package:confetti/confetti.dart';

class DawraOrganizerScreen extends StatefulWidget {
  @override
  _DawraOrganizerScreenState createState() => _DawraOrganizerScreenState();
}

class _DawraOrganizerScreenState extends State<DawraOrganizerScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _games = [
    'Ping Pong',
    'Billiard Table',
    'PlayStation',
    'Connect Four'
  ];
  final Map<String, IconData> _gameIcons = {
    'Ping Pong': Icons.sports_tennis,
    'Billiard Table': Icons.workspaces_sharp,
    'PlayStation': Icons.videogame_asset,
    'Connect Four': Icons.grid_4x4,
  };

  String? selectedGame;
  TextEditingController playerNameController = TextEditingController();
  Map<String, List<String>> gamePlayers = {};
  Map<String, List<List<String>>> gamePairings = {};
  Map<String, String> lastWinners = {};
  List<String> currentPlayers = [];
  List<String> roundWinners = [];
  List<List<String>> completedRounds = [];
  bool isDawraStarted = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 2));
    _loadGameData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    playerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    setState(() {
      for (var key in keys) {
        if (key.startsWith('players_')) {
          String game = key.replaceFirst('players_', '');
          gamePlayers[game] = prefs.getStringList(key) ?? [];
        } else if (key.startsWith('pairings_')) {
          String game = key.replaceFirst('pairings_', '');
          gamePairings[game] = prefs
                  .getStringList(key)
                  ?.map((pair) => pair.split(',').toList())
                  .toList() ??
              [];
        } else if (key.startsWith('winner_')) {
          String game = key.replaceFirst('winner_', '');
          lastWinners[game] = prefs.getString(key) ?? '';
        }
      }
    });
  }

  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    for (var game in gamePlayers.keys) {
      prefs.setStringList('players_$game', gamePlayers[game]!);
    }
    for (var game in gamePairings.keys) {
      prefs.setStringList('pairings_$game',
          gamePairings[game]!.map((pair) => pair.join(',')).toList());
    }
    for (var game in lastWinners.keys) {
      prefs.setString('winner_$game', lastWinners[game]!);
    }
  }

  void _checkNextRound() {
    if (currentPlayers.isEmpty) {
      if (roundWinners.length == 1) {
        setState(() {
          lastWinners[selectedGame!] = roundWinners[0];
          _saveGameData();
        });
        _showFinalWinnerDialog(roundWinners[0]);
      } else {
        setState(() {
          currentPlayers = List.from(roundWinners);
          roundWinners = [];
          gamePairings[selectedGame!] = _generatePairings(currentPlayers);
          completedRounds = [];
        });
      }
    } else if (currentPlayers.length == 1 && roundWinners.isNotEmpty) {
      setState(() {
        currentPlayers.add(roundWinners.removeAt(0));
        gamePairings[selectedGame!] = _generatePairings(currentPlayers);
      });
    }
  }

  List<List<String>> _generatePairings(List<String> players) {
    List<List<String>> pairings = [];
    for (int i = 0; i < players.length; i += 2) {
      if (i + 1 < players.length) {
        pairings.add([players[i], players[i + 1]]);
      } else {
        pairings.add([players[i]]);
      }
    }
    return pairings;
  }

  void _showWinnerDialog(String player1, String player2) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Select Winner',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayerButton(player1, player2),
              SizedBox(height: 12),
              _buildPlayerButton(player2, player1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerButton(String player, String opponent) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            roundWinners.add(player);
            completedRounds.add([player, opponent]);
            currentPlayers.remove(player);
            currentPlayers.remove(opponent);
          });
          Navigator.pop(context);
          _checkNextRound();
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          player,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showFinalWinnerDialog(String winner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              SizedBox(width: 8),
              Text(
                'Ultimate Winner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Color(0xFF3A3A3A)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.white : Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  winner,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Winner of the Dawra! 🏆',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    gamePlayers[selectedGame!] = [];
                    gamePairings[selectedGame!] = [];
                    currentPlayers = [];
                    roundWinners = [];
                    completedRounds = [];
                    isDawraStarted = false;
                    _saveGameData();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start New Dawra',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Add this method to determine the round name
  String _getRoundName(int totalPlayers, int currentRoundPlayers) {
    if (currentRoundPlayers <= 2) {
      return 'Final';
    } else if (currentRoundPlayers <= 4) {
      return 'Semi-Final';
    } else if (currentRoundPlayers <= 8) {
      return 'Quarter-Final';
    } else if (currentRoundPlayers <= 16) {
      return 'Round of 16';
    } else if (currentRoundPlayers <= 32) {
      return 'Round of 32';
    } else {
      return 'Round of ${currentRoundPlayers}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Dawra'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      drawer: user != null ? AppDrawer(user: user) : null,
      body: Stack(
        children: [
          // Background Image with low opacity
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/crosses_bg.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Simple overlay for better contrast
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
          ),
          SafeArea(
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 16),
                          _buildGameButtons(),
                          SizedBox(height: 24),
                          if (!isDawraStarted) _buildPlayerInput(),
                          SizedBox(height: 24),
                          if (lastWinners[selectedGame] != null)
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Color(0xFF2A2A2A)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.emoji_events, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Last Winner: ${lastWinners[selectedGame]}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 16),
                          if (!isDawraStarted &&
                              (gamePlayers[selectedGame]?.isNotEmpty ?? false))
                            ..._buildPlayerList(),
                          if (gamePairings[selectedGame]?.isNotEmpty ?? false)
                            _buildPairingTable(),
                          SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Color(0xFF1A1A1A) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: _buildStartDawraButton(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _games.length,
        itemBuilder: (context, index) {
          final game = _games[index];
          final isSelected = selectedGame == game;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedGame = game;
                  currentPlayers = List.from(gamePlayers[game] ?? []);
                  roundWinners = [];
                  completedRounds = [];
                  isDawraStarted = false;
                });
              },
              child: Container(
                width: 90,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent
                      : isDark
                          ? Color(0xFF2A2A2A)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _gameIcons[game],
                      size: 28,
                      color: isSelected ? Colors.white : Colors.blueAccent,
                    ),
                    SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        game,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isDark
                                  ? Colors.white
                                  : Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: playerNameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Player Name',
              labelStyle:
                  TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              hintText: 'Enter player name',
              hintStyle:
                  TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: Icon(Icons.person,
                  color: isDark ? Colors.white70 : Colors.black87),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addPlayer,
            icon: Icon(Icons.add),
            label: Text('Add Player'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addPlayer() {
    if (playerNameController.text.isNotEmpty && selectedGame != null) {
      setState(() {
        if (gamePlayers[selectedGame!] == null) {
          gamePlayers[selectedGame!] = [];
        }
        gamePlayers[selectedGame!]!.add(playerNameController.text);
        playerNameController.clear();
        _saveGameData();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a player name and select a game.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ));
    }
  }

  List<Widget> _buildPlayerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return [
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Players',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: gamePlayers[selectedGame]?.length ?? 0,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 0,
                  color: isDark ? Color(0xFF3A3A3A) : Colors.white,
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade200,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    title: Text(
                      gamePlayers[selectedGame!]![index],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: Colors.red.shade300),
                      onPressed: () {
                        setState(() {
                          gamePlayers[selectedGame!]!.removeAt(index);
                          _saveGameData();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildPairingTable() {
    final pairings = gamePairings[selectedGame] ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate total players in current round
    int totalPlayersInRound = currentPlayers.length + roundWinners.length;
    String roundName = _getRoundName(
        gamePlayers[selectedGame]?.length ?? 0, totalPlayersInRound);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                roundName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${totalPlayersInRound} Players',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...pairings.map((pair) {
            String player1 = pair[0];
            String? player2 = pair.length > 1 ? pair[1] : null;
            bool isPairCompleted = completedRounds.any((completedRound) =>
                completedRound.contains(player1) &&
                (player2 == null || completedRound.contains(player2)));

            return Card(
              elevation: 0,
              color: isDark ? Color(0xFF3A3A3A) : Colors.white,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isPairCompleted
                      ? (isDark ? Colors.grey[700]! : Colors.grey.shade300)
                      : Colors.blueAccent.withOpacity(0.3),
                ),
              ),
              child: ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(
                  isPairCompleted ? Icons.check_circle : Icons.sports_esports,
                  color: isPairCompleted ? Colors.green : Colors.blueAccent,
                ),
                title: Text(
                  player2 != null
                      ? '$player1 vs $player2'
                      : '$player1 is waiting',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isPairCompleted
                        ? (isDark ? Colors.grey[400] : Colors.grey)
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: player2 != null && !isPairCompleted
                    ? Text(
                        'Tap to select winner',
                        style: TextStyle(color: Colors.blueAccent),
                      )
                    : null,
                onTap: () {
                  if (!isPairCompleted) {
                    if (player2 != null) {
                      _showWinnerDialog(player1, player2);
                    } else {
                      setState(() {
                        roundWinners.add(player1);
                        currentPlayers.remove(player1);
                      });
                      _checkNextRound();
                    }
                  }
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStartDawraButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (selectedGame != null &&
              (gamePlayers[selectedGame]?.length ?? 0) >= 2) {
            setState(() {
              gamePairings[selectedGame!] = [];
              completedRounds = [];
              roundWinners = [];
              currentPlayers = List.from(gamePlayers[selectedGame]!);
              currentPlayers.shuffle(Random());
              gamePairings[selectedGame!] = _generatePairings(currentPlayers);
              isDawraStarted = true;
              _saveGameData();
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Please select a game and ensure there are at least 2 players.'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Start Dawra',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
