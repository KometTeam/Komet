import 'package:flutter/material.dart';

class ProfileHeroAvatar extends StatelessWidget {
  const ProfileHeroAvatar({
    super.key,
    required this.tag,
    required this.size,
    required this.child,
  });

  final Object? tag;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    if (tag == null) return child;
    return Hero(
      tag: ('profile-avatar', tag),
      flightShuttleBuilder: _buildFlyingAvatar,
      child: _AvatarHeroChild(size: size, child: child),
    );
  }

  static Widget _buildFlyingAvatar(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = _AvatarHeroChild.of(fromHeroContext);
    final to = _AvatarHeroChild.of(toHeroContext);
    final sharpest = from.size >= to.size ? from : to;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox.square(dimension: sharpest.size, child: sharpest.child),
    );
  }
}

class ProfileHeroName extends StatelessWidget {
  const ProfileHeroName({
    super.key,
    required this.tag,
    required this.text,
    required this.style,
    required this.child,
  });

  final Object? tag;
  final String text;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tag = this.tag;
    if (tag == null) return child;
    return Hero(
      tag: ('profile-name', tag),
      flightShuttleBuilder: _buildFlyingName,
      child: _NameHeroChild(text: text, style: style, child: child),
    );
  }

  static Widget _buildFlyingName(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = _NameHeroChild.of(fromHeroContext);
    final to = _NameHeroChild.of(toHeroContext);
    final push = direction == HeroFlightDirection.push;
    final style = TextStyleTween(
      begin: push ? from.style : to.style,
      end: push ? to.style : from.style,
    ).animate(animation);
    return OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
      child: DefaultTextStyleTransition(
        style: style,
        softWrap: false,
        maxLines: 1,
        child: Text(to.text),
      ),
    );
  }
}

class _AvatarHeroChild extends StatelessWidget {
  const _AvatarHeroChild({required this.size, required this.child});

  final double size;
  final Widget child;

  static _AvatarHeroChild of(BuildContext heroContext) =>
      (heroContext.widget as Hero).child as _AvatarHeroChild;

  @override
  Widget build(BuildContext context) => child;
}

class _NameHeroChild extends StatelessWidget {
  const _NameHeroChild({
    required this.text,
    required this.style,
    required this.child,
  });

  final String text;
  final TextStyle style;
  final Widget child;

  static _NameHeroChild of(BuildContext heroContext) =>
      (heroContext.widget as Hero).child as _NameHeroChild;

  @override
  Widget build(BuildContext context) => child;
}
