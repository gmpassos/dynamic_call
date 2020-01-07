import 'package:dynamic_call/dynamic_call.dart';

import 'package:test/test.dart';

class UserLogin {
  int id ;
  String username ;

  UserLogin(this.id, this.username);

  UserLogin.parse(dynamic json) {
    this.id = int.parse( json['id'].toString() ) ;
    this.username = json['username'] ;
  }
}

void main() {
  group('A group of tests', () {
    setUp(() {

    });

    test('callLogin', () async {

      DynCall<Map,UserLogin> callLogin = DynCall<Map,UserLogin>( ['username','password'] , DynCallType.JSON , (Map userJson) => UserLogin.parse(userJson) ) ;

      callLogin.executor = DynCallStaticExecutor<Map>( {'id': 101,'username': 'joe'} ) ;

      UserLogin user = await callLogin.call( {'username': 'joe', 'password': '123'} ) ;

      expect(user != null, isTrue);

      expect(user.id , equals(101));
      expect(user.username , equals("joe"));

    });

    test('callLogout', () async {

      DynCall<bool,bool> callLogout = DynCall<bool,bool>( [] , DynCallType.BOOL ) ;

      callLogout.executor = DynCallStaticExecutor<bool>( true ) ;

      bool ok = await callLogout.call() ;

      expect(ok, isTrue);

    });

  });
}
