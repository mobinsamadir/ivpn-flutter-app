// lib/providers/home_provider.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/server_model.dart';
import '../services/ping_service.dart';
import '../services/storage_service.dart';
import '../services/speed_test_service.dart';

class HomeProvider extends ChangeNotifier {
  // --- Services ---
  final StorageService _storageService;
  final PingService _pingService;
  final SpeedTestService _speedTestService;

  // --- State ---
  bool _isLoading = true;
  bool _isConnected = false;
  Server? _connectedServer;
  List<Server> _servers = [];
  Server? _manualSelectedServer;
  List<Server> _recentServers = [];
  final Map<String, Timer> _pingTimers = {};
  List<String> _favoriteIds = [];
  List<String> _theBestIds = [];
  List<String> _obsoleteIds = [];
  bool _disposed = false;

  // --- A central timer to safely update the UI periodically ---
  Timer? _uiUpdateTimer;

  // --- Public Getters ---
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get statusMessage => _isConnected
      ? "Connected to ${_connectedServer?.name ?? ''}"
      : "Disconnected";
  Server? get manualSelectedServer => _manualSelectedServer;
  Server? get connectedServer => _connectedServer;
  List<Server> get recentServers => _recentServers;
  List<Server> get ivpnConfigs =>
      _servers.where((s) => s.type == ServerType.ivpn).toList();
  List<Server> get customConfigs =>
      _servers.where((s) => s.type == ServerType.custom).toList();
  List<Server> get favoriteServers =>
      _servers.where((s) => s.isFavorite).toList();
  List<Server> get theBestServers =>
      _servers.where((s) => _theBestIds.contains(s.id)).toList();
  List<Server> get obsoleteServers =>
      _servers.where((s) => _obsoleteIds.contains(s.id)).toList();

  Server? get bestPerformingServer {
    final onlineServers = _servers
        .where(
          (s) => s.status == PingStatus.good || s.status == PingStatus.medium,
        )
        .toList();
    if (onlineServers.isEmpty) return null;
    onlineServers.sort((a, b) => a.ping.compareTo(b.ping));
    return onlineServers.first;
  }

  Server? get serverToDisplay {
    if (_manualSelectedServer != null) return _manualSelectedServer;
    return bestPerformingServer;
  }

  HomeProvider({required StorageService storageService})
    : _storageService = storageService,
      _pingService = PingService(),
      _speedTestService = SpeedTestService() {
    initializeApp();
  }

  @override
  void dispose() {
    _disposed = true;
    _uiUpdateTimer?.cancel();
    _stopAllPinging();
    super.dispose();
  }

  Future<void> initializeApp() async {
    _servers = await _storageService.loadServers();
    _recentServers = await _storageService.loadRecentServers();
    _favoriteIds = await _storageService.loadFavoriteIds();
    _theBestIds = await _storageService.loadTheBestIds();
    _obsoleteIds = await _storageService.loadObsoleteIds();
    _enrichServersWithMetadata();

    _isLoading = false;
    _startPingingAllServers();

    // Start the single, safe UI update timer. It runs every second.
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      notifyListeners();
    });
  }

  void _enrichServersWithMetadata() {
    _servers = _servers.map((server) {
      return server.copyWith(isFavorite: _favoriteIds.contains(server.id));
    }).toList();
  }

  Future<void> loadServersFromUrl() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    final url = Uri.parse(
      'https://raw.githubusercontent.com/mobinsamadir/ivpn-servers/main/servers.txt',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final lines = utf8.decode(response.bodyBytes).split('\n');
        final networkServers = lines
            .map(
              (l) => Server.fromConfigString(l.trim(), type: ServerType.ivpn),
            )
            .whereType<Server>()
            .toList();

        if (networkServers.isNotEmpty) {
          _stopAllPinging();
          _servers.removeWhere((s) => s.type == ServerType.ivpn);
          _servers.addAll(networkServers);
          await _storageService.saveServers(_servers);
          await _storageService.saveLastUpdateTimestamp();
          _enrichServersWithMetadata();
          _startPingingAllServers();
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addServersFromUserInput(String userInput) async {
    int addedCount = 0;
    if (userInput.trim().startsWith('http')) {
      _isLoading = true;
      notifyListeners();
      addedCount = await _loadServersFromSubscription(userInput);
      _isLoading = false;
    } else {
      final configs = userInput
          .split('\n')
          .where((line) => line.trim().isNotEmpty);
      for (final config in configs) {
        final newServer = Server.fromConfigString(
          config,
          type: ServerType.custom,
        );
        if (newServer != null && !_servers.any((s) => s.id == newServer.id)) {
          _servers.insert(0, newServer);
          _schedulePing(newServer);
          addedCount++;
        }
      }
    }
    if (addedCount > 0) {
      await _storageService.saveServers(_servers);
      _enrichServersWithMetadata();
    }
    notifyListeners();
  }

  Future<int> _loadServersFromSubscription(String subUrl) async {
    int addedCount = 0;
    try {
      final response = await http.get(Uri.parse(subUrl));
      if (response.statusCode == 200) {
        String decodedContent;
        try {
          // First, try to decode from Base64
          decodedContent = utf8.decode(base64Decode(response.body));
        } catch (e) {
          // If Base64 decoding fails, assume it's plain text
          print("Could not decode from Base64, assuming plain text. Error: $e");
          decodedContent = response.body;
        }

        final configs = decodedContent
            .split('\n')
            .where((line) => line.trim().isNotEmpty);
        for (final config in configs) {
          final newServer = Server.fromConfigString(
            config,
            type: ServerType.custom,
          );
          if (newServer != null && !_servers.any((s) => s.id == newServer.id)) {
            _servers.add(newServer);
            _schedulePing(newServer);
            addedCount++;
          }
        }
      }
    } catch (e) {
      print("Error loading subscription: $e");
      // TODO: Show an error message to the user here!
    }
    return addedCount;
  }

  void _startPingingAllServers() {
    _stopAllPinging();
    final List<Server> pingingOrder = [];
    final Set<String> addedIds = {};
    void addToList(List<Server> list) {
      for (var server in list) {
        if (!addedIds.contains(server.id)) {
          pingingOrder.add(server);
          addedIds.add(server.id);
        }
      }
    }

    addToList(favoriteServers);
    addToList(theBestServers);
    addToList(obsoleteServers);
    addToList(_servers);
    for (int i = 0; i < pingingOrder.length; i++) {
      _schedulePing(
        pingingOrder[i],
        isInitial: true,
        initialDelay: Duration(milliseconds: i * 100),
      );
    }
  }

  void _stopAllPinging() {
    _pingTimers.forEach((_, timer) => timer.cancel());
    _pingTimers.clear();
  }

  void _schedulePing(
    Server server, {
    bool isInitial = false,
    Duration? initialDelay,
  }) {
    _pingTimers[server.id]?.cancel();
    final delay =
        initialDelay ??
        (isInitial
            ? Duration(milliseconds: _servers.indexOf(server) * 100)
            : Duration.zero);
    _pingTimers[server.id] = Timer(delay, () => _executePing(server));
  }

  /// This method now ONLY updates the data in memory. It does NOT notify the UI.
  Future<void> _executePing(Server server) async {
    if (!_pingTimers.containsKey(server.id) || _disposed) return;
    final ping = await _pingService.getPing(server.ip, server.port);
    PingStatus newStatus;
    if (ping < 700)
      newStatus = PingStatus.good;
    else if (ping < PingService.failedPingValue)
      newStatus = PingStatus.medium;
    else
      newStatus = PingStatus.bad;

    _updateServerStateInMemory(server.id, ping: ping, status: newStatus);
    _manageSpecialLists(server.id, ping, newStatus);

    final nextPingDelay = server.isConnected
        ? const Duration(seconds: 5)
        : const Duration(seconds: 30);
    _schedulePing(server, initialDelay: nextPingDelay);
  }

  /// A helper method that updates state without notifying listeners.
  void _updateServerStateInMemory(
    String serverId, {
    int? ping,
    PingStatus? status,
    bool? isFavorite,
    double? downloadSpeed,
    bool? isTestingSpeed,
  }) {
    final index = _servers.indexWhere((s) => s.id == serverId);
    if (index != -1) {
      _servers[index] = _servers[index].copyWith(
        ping: ping,
        status: status,
        isFavorite: isFavorite,
        downloadSpeed: downloadSpeed,
        isTestingSpeed: isTestingSpeed,
      );
    }
  }

  Future<void> cleanupServers({required bool removeSlow}) async {
    _servers.removeWhere(
      (s) => removeSlow
          ? (s.status != PingStatus.good)
          : (s.status == PingStatus.bad),
    );
    await _storageService.saveServers(_servers);
    notifyListeners();
  }

  Future<void> toggleFavorite(Server server) async {
    final isCurrentlyFavorite = _favoriteIds.contains(server.id);
    if (isCurrentlyFavorite) {
      _favoriteIds.remove(server.id);
    } else {
      _favoriteIds.add(server.id);
    }
    await _storageService.saveFavoriteIds(_favoriteIds);
    _updateServerStateInMemory(server.id, isFavorite: !isCurrentlyFavorite);
    notifyListeners();
  }

  Future<void> deleteServer(Server server) async {
    _stopPingForServer(server);
    _servers.removeWhere((s) => s.id == server.id);
    _favoriteIds.remove(server.id);
    _theBestIds.remove(server.id);
    _obsoleteIds.remove(server.id);
    _recentServers.removeWhere((s) => s.id == server.id);
    await _storageService.saveServers(_servers);
    await _storageService.saveFavoriteIds(_favoriteIds);
    await _storageService.saveTheBestIds(_theBestIds);
    await _storageService.saveObsoleteIds(_obsoleteIds);
    await _storageService.saveRecentServers(_recentServers);
    notifyListeners();
  }

  void handleConnection() {
    if (_isConnected) {
      _isConnected = false;
      if (_connectedServer != null) {
        final oldConnectedServer = _connectedServer!;
        _connectedServer = null;
        _schedulePing(oldConnectedServer.copyWith(isConnected: false));
      }
    } else {
      final targetServer = serverToDisplay;
      if (targetServer != null) {
        _isConnected = true;
        _connectedServer = targetServer.copyWith(isConnected: true);
        _schedulePing(_connectedServer!);
        _addServerToRecents(targetServer);
      }
    }
    notifyListeners();
  }

  void selectServer(Server? server) {
    _manualSelectedServer = server;
    notifyListeners();
  }

  Future<void> handleSpeedTest(Server server) async {
    if (server.isTestingSpeed) return;
    _updateServerStateInMemory(server.id, isTestingSpeed: true);
    final speed = await _speedTestService.testDownloadSpeed();
    _updateServerStateInMemory(
      server.id,
      downloadSpeed: speed,
      isTestingSpeed: false,
    );
  }

  void _addServerToRecents(Server server) {
    _recentServers.removeWhere((s) => s.id == server.id);
    _recentServers.insert(0, server);
    if (_recentServers.length > 5) {
      _recentServers = _recentServers.sublist(0, 5);
    }
    _storageService.saveRecentServers(_recentServers);
  }

  void _manageSpecialLists(String serverId, int ping, PingStatus newStatus) {
    // This logic can be refined, but it's a good starting point.
    bool listsChanged = false;
    if (_theBestIds.contains(serverId) && newStatus == PingStatus.bad) {
      _theBestIds.remove(serverId);
      if (!_obsoleteIds.contains(serverId)) {
        _obsoleteIds.add(serverId);
      }
      listsChanged = true;
    }
    if (newStatus == PingStatus.good &&
        ping < 150 &&
        !_theBestIds.contains(serverId) &&
        !_obsoleteIds.contains(serverId)) {
      _theBestIds.add(serverId);
      listsChanged = true;
    }
    if (listsChanged) {
      _storageService.saveTheBestIds(_theBestIds);
      _storageService.saveObsoleteIds(_obsoleteIds);
    }
  }

  void _stopPingForServer(Server server) {
    _pingTimers[server.id]?.cancel();
    _pingTimers.remove(server.id);
  }
}
