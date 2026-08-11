import 'dart:convert';

import '../model/exit.dart';
import '../settings/knobs.dart';
import '../store/locker.dart';
import 'tagged_client.dart';

// ============================================================
// SERVER ASK — POST the request body, cache an approved URL
// ============================================================
// The backend owns the routing decision. On approval we cache the URL
// and its expiry so returning launches can skip the network. Any
// failure (HTTP error, timeout, malformed body) yields a denied reply,
// which the switchboard turns into a game (or no-net) exit.
// ============================================================

class ServerAsk {
  ServerAsk(this._locker);

  final Locker _locker;

  Future<ServerReply> ask(Map<String, dynamic> body) async {
    final String endpoint = Knobs.serverUrl;
    if (endpoint.isEmpty) return const ServerReply.denied('no_endpoint');

    try {
      final dynamic res = await taggedClient
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: Knobs.serverTimeoutSeconds));

      if (res.statusCode != 200) {
        return ServerReply.denied('http_${res.statusCode}');
      }
      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map) return const ServerReply.denied('malformed');

      final ServerReply reply =
          ServerReply.fromMap(Map<String, dynamic>.from(decoded));
      if (reply.pointsSomewhere) {
        await _locker.stashDest(reply.url!, reply.expiry);
      }
      return reply;
    } catch (e) {
      return ServerReply.denied('net:$e');
    }
  }
}
