import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/local_avatar_builder.dart';

class _Mounts extends StatefulWidget {
  const _Mounts();

  static int count = 0;

  @override
  State<_Mounts> createState() => _MountsState();
}

class _MountsState extends State<_Mounts> {
  @override
  void initState() {
    super.initState();
    _Mounts.count++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.square(dimension: 10);
}

Widget _host(int userId) => Directionality(
  textDirection: TextDirection.ltr,
  child: LocalAvatarBuilder(
    userId: userId,
    builder: (context, local) => const _Mounts(),
  ),
);

void main() {
  testWidgets('появившийся id собеседника не пересоздаёт аватарку', (
    tester,
  ) async {
    _Mounts.count = 0;
    await tester.pumpWidget(_host(0));
    await tester.pumpWidget(_host(4242));
    await tester.pumpWidget(_host(0));
    expect(_Mounts.count, 1);
  });
}
