import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../net/tagged_client.dart';
import '../store/locker.dart';

// ============================================================
// PUSH CENTER — Firebase Messaging + local notifications
// ============================================================
// Cold-start taps (app killed) stash the URL in the locker for the
// boot pipeline. Warm taps (background/foreground) deliver through
// [onUrl] and are not persisted. The channel id must match the
// AndroidManifest default channel id.
// ============================================================

const String kChannelId = 'cc_signals';
const String kChannelName = 'Citadel Updates';
const String _statIcon = '@drawable/ic_stat_flame';

@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage message) async {
  // The OS draws the tray notification; the tap is handled on resume.
}

class PushCenter {
  PushCenter(this._locker);

  final Locker _locker;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _ready = false;

  /// Warm-tap URL delivery — load this in the open WebView.
  void Function(String url)? onUrl;

  /// FCM rotated the token — the switchboard re-POSTs the config.
  void Function(String token)? onToken;

  /// Fired when a tap arrives but no [onUrl] listener is attached
  /// (typical case: user is deep in the game and taps a push, so
  /// [SiteShell] is not mounted). The URL has already been stashed
  /// as a cold URL; the app should reroute through WarmupScreen so
  /// the boot pipeline picks it up.
  void Function()? onOrphanTap;

  String? get token => _token;

  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_onBackground);

      await _initLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _token = t;
        onToken?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      // Await the stash so Switchboard's post-boot re-check sees it.
      if (initial != null) await _onColdTap(initial);

      _ready = true;
    } catch (_) {
      // Firebase not wired yet — push stays dormant, boot continues.
    }
  }

  Future<void> _initLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_statIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) _deliverTap(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? plugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: 'News, rewards and updates',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records a hard denial so the invite
  /// screen stops reappearing.
  Future<bool> requestPermission() async {
    if (_fm == null) return false;
    final NotificationSettings s = await _fm!.requestPermission();
    final AuthorizationStatus status = s.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _locker.setPushGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _locker.setPushHardDenied();
    }
    return granted;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? image = n.android?.imageUrl;
    if (image != null && image.isNotEmpty) {
      final Uint8List? bytes = await _grabImage(image);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _statIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    details ??= const AndroidNotificationDetails(
      kChannelId,
      kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _statIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  Future<void> _onColdTap(RemoteMessage message) async {
    final String? url = message.data['url'] as String?;
    if (url == null || url.isEmpty) return;
    await _locker.holdColdUrl(url);
  }

  Future<void> _onWarmTap(RemoteMessage message) async {
    final String? url = message.data['url'] as String?;
    if (url == null || url.isEmpty) return;
    await _deliverTap(url);
  }

  /// Route a live tap: if [SiteShell] is up, hand the URL to it directly;
  /// otherwise stash the URL as a cold URL and ask the app to bounce
  /// through WarmupScreen so the boot pipeline picks it up.
  Future<void> _deliverTap(String url) async {
    final void Function(String)? live = onUrl;
    if (live != null) {
      live(url);
      return;
    }
    await _locker.holdColdUrl(url);
    onOrphanTap?.call();
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final dynamic res = await taggedClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
