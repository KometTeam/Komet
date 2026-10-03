import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/camera_devices.dart';

void main() {
  test('camera facing is read from platform labels', () {
    expect(
      CameraDevices.facingOf('Camera 1, Facing front, Orientation 270'),
      CameraFacing.front,
    );
    expect(
      CameraDevices.facingOf('Camera 0, Facing back, Orientation 90'),
      CameraFacing.back,
    );
    expect(CameraDevices.facingOf('Rear Camera'), CameraFacing.back);
    expect(CameraDevices.facingOf('Synthetic USB Cam'), CameraFacing.external);
  });

  test('the system camera leaves the choice to WebRTC', () {
    expect(CameraDevices.constraints(null), isTrue);
    expect(CameraDevices.constraints(''), isTrue);
    expect(CameraDevices.constraints('2'), {
      'optional': [
        {'sourceId': '2'},
      ],
    });
  });
}
