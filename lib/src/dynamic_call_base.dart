
import 'dart:convert' show jsonDecode ;
import 'package:mercury_client/mercury_client.dart';

enum DynCallType {
  BOOL,
  STRING,
  INTEGER,
  DECIMAL,
  JSON
}

typedef O SysCallOutputFilter<O,E>(E output) ;

typedef void SysCallCallback<O>(O output) ;

class DynCall<E,O> {
  final List<String> input ;
  final DynCallType outputType ;
  final SysCallOutputFilter<O,E> outputFilter ;
  final bool _allowRetries ;

  DynCall(this.input, this.outputType, [this.outputFilter, this._allowRetries] ) ;

  bool get allowRetries => _allowRetries != null ? _allowRetries : false ;

  DynCallExecutor<E> executor ;

  Future<O> call( [ Map<String,dynamic> parameters , SysCallCallback<O> callback ] ) {
    if (executor == null) {
      var out = parseOutput(null);

      if (callback != null) {
        try {
          callback(out) ;
        }
        catch (e) {
          print(e) ;
        }
      }

      return Future.value( out ) ;
    }

    Map<String,String> callParameters = buildCallParameters(parameters) ;

    Future<E> call = executor.call(this, callParameters);
    var calMapped = call.then( mapOutput ) ;

    if (callback == null) return calMapped ;

    return calMapped.then( (out) {
      try {
        callback(out) ;
      }
      catch (e) {
        print(e) ;
      }
      return out ;
    } );
  }

  Map<String,String> buildCallParameters(Map<String,dynamic> parameters) {
    Map<String,String> callParameters = {} ;

    if (parameters == null || parameters.isEmpty) return callParameters ;

    for (var k in input) {
      var val = parameters[k] ;
      if (val != null) {
        callParameters[k] = "$val";
      }
    }

    return callParameters ;
  }

  O parseOutput(dynamic value) {
    var out = parseExecution(value) ;

    return mapOutput(out);
  }

  O mapOutput(E out) {
    if (outputFilter != null) {
      return outputFilter(out) ;
    }
    else {
      return out as O ;
    }
  }

  E parseExecution(dynamic value) {
    switch( outputType ) {
      case DynCallType.BOOL: return parseOutputBOOL(value) as E ;
      case DynCallType.STRING: return parseOutputSTRING(value) as E ;
      case DynCallType.INTEGER: return parseOutputINTEGER(value) as E ;
      case DynCallType.DECIMAL: return parseOutputDECIMAL(value) as E ;
      case DynCallType.JSON: return parseOutputJSON(value) as E ;

      default: throw StateError("Can't handle type: $outputType") ;
    }
  }

  bool parseOutputBOOL(dynamic value) {
    if (value == null) return false ;
    if (value is bool) return value ;

    if (value is num) {
      int n = value.toInt() ;
      return n >= 1 ;
    }

    String s = "$value".trim().toLowerCase() ;
    return s == 'true' || s == '1' || s == 'yes' || s == 't' ||  s == 'y' ;
  }

  String parseOutputSTRING(dynamic value) {
    if (value == null) return null ;
    if (value is String) return value ;

    String s = "$value" ;
    return s ;
  }

  int parseOutputINTEGER(dynamic value) {
    if (value == null) return null ;
    if (value is int) return value ;
    if (value is num) return value.toInt() ;
    return int.parse( "$value" ) ;
  }

  double parseOutputDECIMAL(dynamic value) {
    if (value == null) return null ;
    if (value is double) return value ;
    if (value is num) return value.toDouble() ;
    return double.parse( "$value" ) ;
  }

  dynamic parseOutputJSON(dynamic value) {
    if (value == null) return null ;
    if (value is Map) return value ;
    if (value is List) return value ;
    if (value is num) return value ;
    if (value is bool) return value ;
    return jsonDecode( "$value" ) ;
  }

}

////////////////////////////////////////////////////////////////////////////////

abstract class DynCallExecutor<E> {

  Future<E> call<X>( DynCall<E,X> sysCall , Map<String,String> parameters ) ;

}

class DynCallStaticExecutor<E> extends DynCallExecutor<E> {
  final E response ;

  DynCallStaticExecutor(this.response);

  @override
  Future<E> call<X>(DynCall<E, X> sysCall, Map<String, String> parameters) {
    return Future.value(response) ;
  }
}

class DynCallHttpClient extends HttpClient {

  DynCallHttpClient(String baseURL, [HttpClientRequester clientRequester]) : super(baseURL, clientRequester);

  DynCallHttpExecutor<E> executor<E>( HttpMethod method, String path, { Map<String,String> parametersMap, List<String> authorizationFields, E errorResponse, int errorMaxRetries = 3 } ) {
    return DynCallHttpExecutor(this, method, path, parametersMap: parametersMap, authorizationFields: authorizationFields, errorResponse: errorResponse, errorMaxRetries: 3 ) ;
  }

}

enum OnHttpErrorAnswer {
  NO_CONTENT,
  RETRY,
  ERROR,
}

typedef OnHttpErrorAnswer OnHttpError( HttpError error ) ;

class DynCallHttpExecutor<E> extends DynCallExecutor<E> {

  HttpClient httpClient ;
  HttpMethod method ;
  String path ;
  Map<String,String> parametersMap ;
  List<String> authorizationFields ;
  E errorResponse ;
  int errorMaxRetries ;
  OnHttpError onHttpError ;

  DynCallHttpExecutor(this.httpClient, this.method, this.path, { this.parametersMap, this.authorizationFields, this.errorResponse , this.errorMaxRetries = 3 , this.onHttpError } );

  @override
  Future<E> call<X>(DynCall<E,X> sysCall, Map<String,String> parameters) {
    Map<String,String> requestParameters = buildParameters(parameters) ;
    Credential authorization = buildAuthorization(parameters) ;

    int maxRetries = this.errorMaxRetries != null && this.errorMaxRetries > 0 ? this.errorMaxRetries : 0 ;

    if (maxRetries > 0 && sysCall.allowRetries) {
      return _callWithRetries(sysCall, authorization, requestParameters, maxRetries, []) ;
    }
    else {
      return _callNoRetries(sysCall, authorization, requestParameters) ;
    }
  }

  Future<E> _callNoRetries<X>(DynCall<E,X> sysCall, Credential authorization, Map<String,String> requestParameters) {
    //print("_callNoRetries> maxErrorRetries: $method $path");

    var response = httpClient.request(method, path, authorization: authorization, queryParameters: requestParameters) ;

    return response
        .then( (r) => _processResponse(sysCall, r.body) )
        .catchError( (e) {
          OnHttpError onHttpError = this.onHttpError ?? _onHttpError ;
          OnHttpErrorAnswer errorAnswer = onHttpError( e is HttpError ? e : null ) ;

          if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
            return _processResponse(sysCall, null) ;
          }
          else if (errorAnswer == OnHttpErrorAnswer.ERROR || errorAnswer == OnHttpErrorAnswer.RETRY) {
            return _processError(sysCall, e);
          }
          else {
            throw StateError("Invalid OnHttpErrorResponse: $errorAnswer") ;
          }
        } ) ;
  }

  Future<E> _callWithRetries<X>(DynCall<E,X> sysCall, Credential authorization, Map<String,String> requestParameters, int maxErrorRetries, List<HttpError> errors ) {
    int delay = errors.length <= 2 ? 200 : 500 ;

    if (maxErrorRetries <= 0) {
      if ( errors.isEmpty ) {
        return _callNoRetries(sysCall, authorization, requestParameters);
      }
      else {
        //print("delay... $delay");
        return Future.delayed( Duration( milliseconds: delay ) , () => _callNoRetries(sysCall, authorization, requestParameters) ) ;
      }
    }

    //print("_callWithRetries> $method $path > maxErrorRetries: $maxErrorRetries ; errors: $errors");

    if ( errors.isEmpty ) {
      return _callWithRetriesImpl(sysCall, authorization, requestParameters, maxErrorRetries, errors) ;
    }
    else {
      //print("delay... $delay");
      return Future.delayed( Duration( milliseconds: delay ) , () => _callWithRetriesImpl(sysCall, authorization, requestParameters, maxErrorRetries, errors) ) ;
    }
  }

  Future<E> _callWithRetriesImpl<X>(DynCall<E,X> sysCall, Credential authorization, Map<String,String> requestParameters, int maxErrorRetries, List<HttpError> errors ) {
    //print("_callWithRetriesImpl> $method $path > maxErrorRetries: $maxErrorRetries ; errors: $errors");

    var response = httpClient.request(method, path, authorization: authorization, queryParameters: requestParameters) ;

    return response
        .then( (r) => _processResponse(sysCall, r.body) )
        .catchError( (e) {
          OnHttpError onHttpError = this.onHttpError ?? _onHttpError ;
          OnHttpErrorAnswer errorAnswer = onHttpError( e is HttpError ? e : null ) ;

          if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
            return _processResponse(sysCall, null) ;
          }
          else if (errorAnswer == OnHttpErrorAnswer.RETRY) {
            return _callWithRetries(sysCall, authorization, requestParameters, maxErrorRetries-1, errors..add(e) ) ;
          }
          else if (errorAnswer == OnHttpErrorAnswer.ERROR) {
            return _processError(sysCall, e);
          }
          else {
            throw StateError("Invalid OnHttpErrorResponse: $errorAnswer") ;
          }
        } ) ;
  }

  OnHttpErrorAnswer _onHttpError(HttpError error) {
    if (error == null) return OnHttpErrorAnswer.ERROR ;

    if (error.isStatusNotFound) {
      return OnHttpErrorAnswer.NO_CONTENT ;
    }
    else if (error.isStatusError) {
      return OnHttpErrorAnswer.RETRY ;
    }
    else {
      return OnHttpErrorAnswer.ERROR ;
    }
  }

  E _processResponse<O>(DynCall<E,O> sysCall, String responseContent) {
    return sysCall.parseExecution(responseContent);
  }

  E _processError<O>(DynCall<E,O> sysCall, HttpError error) {
    return sysCall.parseExecution(errorResponse) ;
  }

  Map<String, String> buildParameters(Map<String, String> parameters) {
    if (parametersMap == null) return null ;

    Set<String> processedKeys = {} ;

    Map<String,String> requestParameters = {} ;

    for ( var key in parametersMap.keys ) {
      var key2 = parametersMap[key] ;

      if (key2 == null || key2.isEmpty || key2 == "*") key2 = key ;

      var val = parameters[key] ;
      if (val != null) {
        requestParameters[key2] = val;
        processedKeys.add(key) ;
      }
    }

    if ( parametersMap['*'] == '*' ) {
      for ( var key in parameters.keys ) {
        if ( !processedKeys.contains(key) ) {
          var val = parameters[key] ;
          requestParameters[key] = val;
          processedKeys.add(key) ;
        }
      }
    }

    return requestParameters.isNotEmpty ? requestParameters : null ;
  }

  Credential buildAuthorization(Map<String, String> parameters) {
    if (authorizationFields == null || authorizationFields.isEmpty) return null ;

    var fieldUser = authorizationFields[0] ?? 'username' ;
    var fieldPass = ( authorizationFields.length > 1 ? authorizationFields[1] : null ) ?? 'password' ;

    String user = parameters[ fieldUser ] ;
    String pass = parameters[ fieldPass ] ;

    if (user != null && pass != null) {
      return BasicCredential( user , pass ) ;
    }

    return null ;
  }

}


class DynCallHttpExecutorFactory {

  final HttpClient httpClient ;

  String _basePath ;

  DynCallHttpExecutorFactory(this.httpClient, [String basePath]) {
    this._basePath = _normalizePath(basePath) ;
  }

  String _normalizePath(String basePath) => basePath != null ? basePath.trim() : null;

  String get basePath => _basePath ;

  DynCallHttpExecutor<E> create<E>( HttpMethod method, { String path, Map<String,String> parametersMap, List<String> authorizationFields, E errorResponse , int errorMaxRetries = 3 } ) {
    path = _normalizePath(path) ;
    String callPath = _basePath != null && _basePath.isNotEmpty ? "$_basePath$path" : path ;
    
    DynCallHttpExecutor<E> executor = DynCallHttpExecutor(httpClient, method, callPath, parametersMap: parametersMap, authorizationFields: authorizationFields, errorResponse: errorResponse, errorMaxRetries: errorMaxRetries );
    return executor ;
  }

  DynCallHttpExecutor<E> define<E,O>( DynCall<E,O> call , HttpMethod method, { String path, Map<String,String> parametersMap, List<String> authorizationFields, E errorResponse , int errorMaxRetries = 3 } ) {
    DynCallHttpExecutor<E> executor = create(method, path: path, parametersMap: parametersMap, authorizationFields: authorizationFields, errorResponse: errorResponse, errorMaxRetries: errorMaxRetries );
    call.executor = executor ;
    return executor ;
  }

  DynCallHttpExecutorFactory_builder<E,O> call<E,O>( DynCall<E,O> call ) => DynCallHttpExecutorFactory_builder<E,O>( this , call ) ;

}

class DynCallHttpExecutorFactory_builder<E,O> {

  final DynCallHttpExecutorFactory factory ;
  final DynCall<E,O> call ;

  DynCallHttpExecutorFactory_builder(this.factory, this.call);

  DynCallHttpExecutor<E> executor( HttpMethod method, { String path, Map<String,String> parametersMap, List<String> authorizationFields, E errorResponse , int errorMaxRetries = 3 } ) {
    return factory.define( call, method, path: path, parametersMap: parametersMap, authorizationFields: authorizationFields, errorResponse: errorResponse, errorMaxRetries: errorMaxRetries ) ;
  }

}
