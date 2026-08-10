import 'package:flutter/material.dart';

import '../core/app_assets.dart';

class _Cloud {
  const _Cloud(
    this.asset,
    this.top,
    this.widthFactor,
    this.speed,
    this.offset,
    this.opacity,
  );

  final String asset;
  final double top;
  final double widthFactor;
  final double speed;
  final double offset;
  final double opacity;
}

/// Shared painted sky with slowly drifting clouds and the city skyline strip.
class SkyBackground extends StatefulWidget {
  const SkyBackground({
    super.key,
    this.showCity = true,
    this.scrim = 0.18,
    this.cityHeightFactor = 0.22,
  });

  final bool showCity;
  final double scrim;
  final double cityHeightFactor;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  static const List<_Cloud> _clouds = <_Cloud>[
    _Cloud(AppAssets.cloudLarge, 0.06, 0.62, 1.0, 0.10, 0.95),
    _Cloud(AppAssets.cloudSmall, 0.20, 0.44, 1.55, 0.55, 0.80),
    _Cloud(AppAssets.cloudSmall, 0.35, 0.30, 0.75, 0.85, 0.55),
    _Cloud(AppAssets.cloudLarge, 0.47, 0.36, 1.25, 0.32, 0.42),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(AppAssets.sky, fit: BoxFit.cover),
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) {
                return Stack(
                  children: <Widget>[
                    for (final _Cloud cloud in _clouds)
                      _buildCloud(cloud, width, height),
                  ],
                );
              },
            ),
            if (widget.showCity)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Image.asset(
                  AppAssets.city,
                  fit: BoxFit.cover,
                  height: height * widget.cityHeightFactor,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            if (widget.scrim > 0)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: widget.scrim * 0.9),
                      Colors.transparent,
                      Colors.black.withValues(alpha: widget.scrim * 1.4),
                    ],
                    stops: const <double>[0, 0.42, 1],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCloud(_Cloud cloud, double width, double height) {
    final double cloudWidth = width * cloud.widthFactor;
    final double travel = width + cloudWidth;
    final double raw = (_controller.value * cloud.speed + cloud.offset) % 1.0;
    return Positioned(
      top: height * cloud.top,
      left: raw * travel - cloudWidth,
      width: cloudWidth,
      child: Opacity(
        opacity: cloud.opacity,
        child: Image.asset(cloud.asset, fit: BoxFit.contain),
      ),
    );
  }
}
