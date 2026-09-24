import 'package:test/test.dart';
import 'package:music_hub/practice_loop.dart';

void main() {
  test('region validation and original/clip coordinate conversion', () {
    const region = PracticeLoop(2000, 4000);
    expect(region.validFor(10000), true);
    expect(region.toAbsolute(1000), 3000);
    expect(region.toAbsolute(9999), 4000);
    expect(region.toRelative(500), 0);
    expect(region.toRelative(3000), 1000);
    expect(region.toRelative(5000), 2000);
    expect(const PracticeLoop(100, 200).validFor(10000), false);
    expect(const PracticeLoop(-1, 1000).validFor(10000), false);
    expect(region.validFor(3000), false);
    expect(preciseTime(62450), '1:02.45');
  });
}
