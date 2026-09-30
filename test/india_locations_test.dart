import 'package:flutter_test/flutter_test.dart';
import 'package:resumer_app/data/india_locations.dart';

void main() {
  group('IndianLocationData', () {
    test('contains key Indian tech states and union territories', () {
      final stateNames = IndianLocationData.states.map((s) => s.name).toList();

      expect(stateNames, contains('Karnataka'));
      expect(stateNames, contains('Maharashtra'));
      expect(stateNames, contains('Telangana'));
      expect(stateNames, contains('Tamil Nadu'));
      expect(stateNames, contains('Delhi NCR'));
      expect(stateNames, contains('Gujarat'));
      expect(stateNames, contains('West Bengal'));
      expect(stateNames, contains('Kerala'));
      expect(stateNames, contains('Andhra Pradesh'));
    });

    test('Karnataka has Bengaluru Urban and key tech hubs', () {
      final karnataka =
          IndianLocationData.states.firstWhere((s) => s.name == 'Karnataka');
      final districtNames = karnataka.districts.map((d) => d.name).toList();

      expect(districtNames, contains('Bengaluru Urban'));
      expect(districtNames, contains('Mysuru'));
      expect(districtNames, contains('Dakshina Kannada'));

      final blrUrban =
          karnataka.districts.firstWhere((d) => d.name == 'Bengaluru Urban');
      expect(blrUrban.cities, contains('Bengaluru'));
      expect(blrUrban.cities, contains('Electronic City'));
      expect(blrUrban.cities, contains('Whitefield'));
    });

    test('Maharashtra has Mumbai and Pune with Hinjewadi', () {
      final maharashtra =
          IndianLocationData.states.firstWhere((s) => s.name == 'Maharashtra');
      final pune = maharashtra.districts.firstWhere((d) => d.name == 'Pune');

      expect(pune.cities, contains('Pune'));
      expect(pune.cities, contains('Hinjewadi IT Park'));
      expect(pune.cities, contains('Magarpatta City'));
    });

    test('Telangana has Hyderabad with HITEC City', () {
      final telangana =
          IndianLocationData.states.firstWhere((s) => s.name == 'Telangana');
      final hyd = telangana.districts.firstWhere((d) => d.name == 'Hyderabad');

      expect(hyd.cities, contains('Hyderabad'));
      expect(hyd.cities, contains('HITEC City'));
      expect(hyd.cities, contains('Gachibowli'));
    });

    test('universal search finds matching states, districts, and cities', () {
      // Search city
      final blrMatches = IndianLocationData.search('bengaluru');
      expect(blrMatches.any((r) => r.title == 'Bengaluru'), isTrue);
      expect(blrMatches.any((r) => r.type == 'city'), isTrue);

      // Search state
      final karnatakaMatches = IndianLocationData.search('karnataka');
      expect(karnatakaMatches.any((r) => r.type == 'state'), isTrue);

      // Search district
      final puneMatches = IndianLocationData.search('pune');
      expect(puneMatches.any((r) => r.title == 'Pune'), isTrue);

      // Search Kochi
      final kochiMatches = IndianLocationData.search('kochi');
      expect(kochiMatches.any((r) => r.title == 'Kochi'), isTrue);
    });
  });
}
