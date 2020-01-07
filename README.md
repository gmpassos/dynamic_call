# Dynamic Call

Dynamic Call framework, including API calls integration (HTTP,REST).

## Usage

A simple usage example:

```dart
import 'package:dynamic_call/dynamic_call.dart';

class UserLogin {

  static UserLogin parse(dynamic json) {
    if ( json is Map ) {
      var username = json['username'] ;

      if (username != null) {
        try {
          String id = json['id'].toString() ;
          String name = json['name'] ;
          return UserLogin(id, username) ;
        }
        catch (e) {
          print(e);
        }
      }
    }

    return null ;
  }

  String _id ;
  String get id => _id ;

  String _username ;
  String get username => _username ;

  UserLogin(this._id, this._username);

}


abstract class AppSystem {

  final DynCall<dynamic,UserLogin> callLogin = DynCall<dynamic,UserLogin>( ['username','pass'] , DynCallType.JSON , (dynamic userJson) => UserLogin.parse(userJson) , true ) ;

  Future<UserLogin> login(String username, String pass, void Function(UserLogin user) onUserLogin) {
    return callLogin.call( {'username': username, 'pass': pass} , (user) => _processLogin(user, onUserLogin) )  ;
  }

  static UserLogin _processLogin(UserLogin user, ProcessLoginFunction processFunction) {
    if ( user != null ) {
      //... notify login successful.
      return user ;
    }
    return null ;
  }

  final DynCall<bool,bool> callLogout = DynCall<bool,bool>( ['username'] , DynCallType.BOOL , null, true ) ;

  Future<bool> logout() {
    String username = GlobalUser.user.username ;
    return callLogout.call( {'username': username} ) ;
  }

  final DynCall<dynamic,UserLogin> callRegister = DynCall<dynamic,UserLogin>( ['name', 'email', 'username', 'password'] , DynCallType.JSON , (dynamic userJson) => UserLogin.parse(userJson) ) ;

  Future<UserLogin> register(String name, String email, String username, String pass, void Function(UserLogin user) onRegisteredUser) {
    return callRegister.call( {'name': name, 'email': email, 'username': username, 'password': pass} , (user) => _processRegister(user) ) ;
  }

  static UserLogin _processRegister(UserLogin user) {
    if (user != null) {
      //... notify new user created.
      return user ;
    }
    return null ;
  }

  final DynCall<bool,bool> callChangePassword = DynCall( ['username','currentPass','newPass'] , DynCallType.BOOL) ;

  Future<bool> changePassword(String username, String currentPass, String newPass) {
    return callChangePassword.call( {'username': username, 'currentPass': currentPass, 'newPass': newPass} )  ;
  }

}

main() {
  
  var httpClient = DynCallHttpClient('https://your.domain') ;

  DynCallHttpExecutorFactory executorFactory = DynCallHttpExecutorFactory( httpClient , "path/to/api-1" ) ;

  executorFactory.call( oceanAppSystem.callLogin ).executor( HttpMethod.POST, path: "login", authorizationFields: ['username', 'pass'] ) ;

  executorFactory.call( oceanAppSystem.callLogout ).executor( HttpMethod.GET, path: "logout" ) ;

  executorFactory.call( oceanAppSystem.callRegister ).executor( HttpMethod.POST, path: "register", parametersMap: {'*': '*'} ) ;

  executorFactory.call(  oceanAppSystem.callChangePassword ).executor( HttpMethod.POST, path: "changePassword",
      parametersMap: {'*': '*', 'currentPass': 'current_password', 'newPass': 'password'},
      errorResponse: false
  ) ;

}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/dynamic_call/issues
