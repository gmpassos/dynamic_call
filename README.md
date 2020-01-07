# Dynamic Call

Dynamic Call framework, including API calls integration (HTTP,REST).

## Usage

A simple usage example:

```dart
import 'package:dynamic_call/dynamic_call.dart';
import 'dart:async' ;

// Entity for logged user:

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

// A generic AppSystem that can be used in many projects:

class AppSystem {

  final DynCall<dynamic,UserLogin> callLogin = DynCall<dynamic,UserLogin>( ['username','pass'] , DynCallType.JSON , (dynamic userJson) => UserLogin.parse(userJson) , true ) ;

  Future<UserLogin> login(String username, String pass, void Function(UserLogin user) onUserLogin) {
    return callLogin.call( {'username': username, 'pass': pass} , onUserLogin)  ;
  }

  final DynCall<bool,bool> callLogout = DynCall<bool,bool>( [] , DynCallType.BOOL , null, true ) ;

  Future<bool> logout() {
    return callLogout.call() ;
  }

  final DynCall<dynamic,UserLogin> callRegister = DynCall<dynamic,UserLogin>( ['name', 'email', 'username', 'password'] , DynCallType.JSON , (dynamic userJson) => UserLogin.parse(userJson) ) ;

  Future<UserLogin> register(String name, String email, String username, String pass, void Function(UserLogin user) onRegisteredUser) {
    return callRegister.call( {'name': name, 'email': email, 'username': username, 'password': pass} , onRegisteredUser) ;
  }

  final DynCall<bool,bool> callChangePassword = DynCall( ['username','currentPass','newPass'] , DynCallType.BOOL) ;

  Future<bool> changePassword(String username, String currentPass, String newPass) {
    return callChangePassword.call( {'username': username, 'currentPass': currentPass, 'newPass': newPass} )  ;
  }

}

// Example of usage of the system and integrate with an WS API:

main() async {
  
  var appSystem = AppSystem() ;

  ///////////////////////////////////////////
  ////// Configure Dynamic Call Executors:

  var httpClient = DynCallHttpClient('https://your.domain') ;

  // DynCallExecutor with HttpClient with base URL: https://your.domain/path/to/api-1
  DynCallHttpExecutorFactory executorFactory = DynCallHttpExecutorFactory( httpClient , "path/to/api-1" ) ;

  // POST https://your.domain/path/to/api-1/login
  // Authorization: Basic BASE64($username:$pass)
  executorFactory.call( appSystem.callLogin ).executor( HttpMethod.POST, path: "login", authorizationFields: ['username', 'pass'] ) ;

  // GET https://your.domain/path/to/api-1/logout
  executorFactory.call( appSystem.callLogout ).executor( HttpMethod.GET, path: "logout" ) ;

  // POST https://your.domain/path/to/api-1/register
  // Content-Type: application/x-www-form-urlencoded; charset=UTF-8
  // name=$name&email=$email&username=$username&password=$password
  executorFactory.call( appSystem.callRegister ).executor( HttpMethod.POST, path: "register", parametersMap: {'*': '*'} ) ;

  // POST https://your.domain/path/to/api-1/changePassword
  // Content-Type: application/x-www-form-urlencoded; charset=UTF-8
  // username=$username&current_password=$currentPass&password=$newPass
  executorFactory.call(  appSystem.callChangePassword ).executor( HttpMethod.POST, path: "changePassword",
      parametersMap: {'*': '*', 'currentPass': 'current_password', 'newPass': 'password'},
      errorResponse: false
  ) ;
  
  ///////////////////////////////////////////
  ////// Usage of AppSystem:

  UserLogin loggedUser = await appSystem.login('joe', 'pass123', (user) => notifyLogin(user) ) ;

  // ... Or register a new user (back-end automatically logins with register user):

  UserLogin loggedUser = await appSystem.register('Joe Smith', 'joe@email.com', 'joe', 'pass123', (user) => notifyLogin(user) ) ;

  //... Change some user password:

  bool changePassOK = await appSystem.changePassword('joe','pass123','pass456') ;
  
  //... Logout current user:
 
  bool logoutOK = await appSystem.logout() ;

}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/dynamic_call/issues

## Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

Dart free & open-source [license](https://github.com/dart-lang/stagehand/blob/master/LICENSE).
