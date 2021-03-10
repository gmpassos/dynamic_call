import 'package:dynamic_call/dynamic_call.dart';
import 'package:test/test.dart';

class UserLogin {
  int? id;

  String? username;

  UserLogin(this.id, this.username);

  UserLogin.parse(dynamic json) {
    id = int.parse(json['id'].toString());
    username = json['username'];
  }
}

void main() {
  group('System Call', () {
    setUp(() {});

    test('callLogin', () async {
      var callLogin = DynCall<Map, UserLogin>(
          ['username', 'password'], DynCallType.JSON,
          outputFilter: (Map? userJson) => UserLogin.parse(userJson));

      callLogin.executor =
          DynCallStaticExecutor<Map>({'id': 101, 'username': 'joe'});

      var user = await callLogin.call({'username': 'joe', 'password': '123'});

      expect(user != null, isTrue);

      expect(user!.id, equals(101));
      expect(user.username, equals('joe'));
    });

    test('callLogout', () async {
      var callLogout = DynCall<bool, bool>([], DynCallType.BOOL);

      callLogout.executor = DynCallStaticExecutor<bool>(true);

      var ok = await callLogout.call();

      expect(ok, isTrue);
    });
  });
}
