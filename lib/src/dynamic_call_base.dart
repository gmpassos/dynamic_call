import 'dart:convert' show jsonDecode;

import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

enum DynCallType { BOOL, STRING, INTEGER, DECIMAL, JSON }

typedef SysCallOutputFilter<O, E> = O Function(E output);

typedef SysCallCallback<O> = void Function(
    O output, Map<String, dynamic> parameters);

class DynCall<E, O> {
  final List<String> input;

  final DynCallType outputType;

  final SysCallOutputFilter<O, E> outputFilter;

  final bool _allowRetries;

  DynCall(this.input, this.outputType, [this.outputFilter, this._allowRetries]);

  bool get allowRetries => _allowRetries ?? false;

  DynCallExecutor<E> executor;

  Future<O> call(
      [Map<String, dynamic> parameters, SysCallCallback<O> callback]) {
    if (executor == null) {
      var out = parseOutput(null);

      if (callback != null) {
        try {
          callback(out, parameters);
        } catch (e) {
          print(e);
        }
      }

      return Future.value(out);
    }

    var callParameters = buildCallParameters(parameters);

    var call = executor.call(this, callParameters);
    var calMapped = call.then(mapOutput);

    if (callback == null) return calMapped;

    return calMapped.then((out) {
      try {
        callback(out, parameters);
      } catch (e) {
        print(e);
      }
      return out;
    });
  }

  Map<String, String> buildCallParameters(Map<String, dynamic> parameters) {
    // ignore: omit_local_variable_types
    Map<String, String> callParameters = {};

    if (parameters == null || parameters.isEmpty) return callParameters;

    for (var k in input) {
      var val = parameters[k];
      if (val != null) {
        callParameters[k] = '$val';
      }
    }

    return callParameters;
  }

  O parseOutput(dynamic value) {
    var out = parseExecution(value);

    return mapOutput(out);
  }

  O mapOutput(E out) {
    if (outputFilter != null) {
      return outputFilter(out);
    } else {
      return out as O;
    }
  }

  E parseExecution(dynamic value) {
    switch (outputType) {
      case DynCallType.BOOL:
        return parseOutputBOOL(value) as E;
      case DynCallType.STRING:
        return parseOutputSTRING(value) as E;
      case DynCallType.INTEGER:
        return parseOutputINTEGER(value) as E;
      case DynCallType.DECIMAL:
        return parseOutputDECIMAL(value) as E;
      case DynCallType.JSON:
        return parseOutputJSON(value) as E;

      default:
        throw StateError("Can't handle type: $outputType");
    }
  }

  bool parseOutputBOOL(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;

    if (value is num) {
      var n = value.toInt();
      return n >= 1;
    }

    var s = '$value'.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 't' || s == 'y';
  }

  String parseOutputSTRING(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;

    var s = '$value';
    return s;
  }

  int parseOutputINTEGER(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }

  double parseOutputDECIMAL(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.parse('$value');
  }

  dynamic parseOutputJSON(dynamic value) {
    if (value == null) return null;
    if (value is String) return jsonDecode(value);
    if (value is Map) return value;
    if (value is List) return value;
    if (value is num) return value;
    if (value is bool) return value;
    return jsonDecode('$value');
  }
}

////////////////////////////////////////////////////////////////////////////////

abstract class DynCallCredential {
  bool applyCredential(DynCallExecutor executor);
}

class DynCallCredentialHTTP extends DynCallCredential {
  final Credential credential;

  DynCallCredentialHTTP(this.credential);

  factory DynCallCredentialHTTP.fromJSONToken(dynamic json) {
    if (json is Map) {
      var bearerCredential = BearerCredential.fromJSONToken(json);
      return bearerCredential != null
          ? DynCallCredentialHTTP(bearerCredential)
          : null;
    }
    return null;
  }

  @override
  bool applyCredential(DynCallExecutor executor) {
    if (credential == null) return false;

    if (executor is DynCallHttpExecutor) {
      executor.httpClient.authorization = credential;
      return true;
    }

    return false;
  }
}

typedef DynCallCredentialParser<E> = DynCallCredential Function(
    String output, String outputFiltered, Map<String, String> parameters);

abstract class DynCallExecutor<E> {
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> parameters);

  void setCredential(DynCallCredential credential) {}
}

class DynCallStaticExecutor<E> extends DynCallExecutor<E> {
  final E response;

  DynCallStaticExecutor(this.response);

  @override
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> parameters) {
    return Future.value(response);
  }
}

class DynCallHttpClient extends HttpClient {
  DynCallHttpClient(String baseURL, [HttpClientRequester clientRequester])
      : super(baseURL, clientRequester);

  DynCallHttpExecutor<E> executor<E>(HttpMethod method, String path,
      {Map<String, String> parametersMap,
      List<String> authorizationFields,
      E errorResponse,
      int errorMaxRetries = 3}) {
    return DynCallHttpExecutor(this, method, path,
        parametersMap: parametersMap,
        authorizationFields: authorizationFields,
        errorResponse: errorResponse,
        errorMaxRetries: 3);
  }
}

enum OnHttpErrorAnswer {
  NO_CONTENT,
  RETRY,
  ERROR,
}

abstract class HTTPOutputInterceptorWrapper<E> {
  HTTPOutputInterceptorWrapper();

  void interceptOutput(
      DynCallExecutor<E> executor,
      String outputOriginal,
      bool outputValid,
      String outputFiltered,
      Map<String, String> callParameters);
}

typedef OnHttpError = OnHttpErrorAnswer Function(HttpError error);

typedef HTTPOutputInterceptor<E> = void Function(
    DynCallExecutor<E> executor,
    String outputOriginal,
    bool outputValid,
    String outputFiltered,
    Map<String, String> callParameters);
typedef HTTPOutputValidator = bool Function(
    String output, Map<String, String> callParameters);
typedef HTTPOutputFilter = String Function(
    String output, Map<String, String> callParameters);

typedef BodyPatternFunctionString = String Function(
    Map<String, String> callParameters);
typedef BodyPatternFunctionDynamic = dynamic Function(
    Map<String, String> callParameters);

typedef BodyPatternFunctionSimpleString = String Function();
typedef BodyPatternFunctionSimpleDynamic = dynamic Function();

class DynCallHttpExecutor<E> extends DynCallExecutor<E> {
  HttpClient httpClient;

  HttpMethod method;

  String path;

  bool fullPath;

  Map<String, String> parametersMap;

  Map<String, String> parametersStatic;

  Credential authorization;

  List<String> authorizationFields;

  dynamic body;

  dynamic bodyPattern;

  String bodyType;

  HTTPOutputValidator outputValidator;

  HTTPOutputFilter outputFilter;

  String outputFilterPattern;

  HTTPOutputInterceptor<E> outputInterceptor;

  E errorResponse;

  int errorMaxRetries;

  OnHttpError onHttpError;

  DynCallHttpExecutor(this.httpClient, this.method, this.path,
      {this.fullPath,
      this.parametersMap,
      this.parametersStatic,
      this.authorization,
      this.authorizationFields,
      this.body,
      this.bodyPattern,
      this.bodyType,
      this.outputValidator,
      this.outputFilter,
      this.outputFilterPattern,
      this.outputInterceptor,
      this.errorResponse,
      this.errorMaxRetries = 3,
      this.onHttpError});

  @override
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> callParameters) {
    var requestParameters = buildParameters(callParameters);
    var authorization = buildAuthorization(callParameters);
    var body = buildBody(callParameters);
    var bodyType = buildBodyType(body);

    var maxRetries =
        errorMaxRetries != null && errorMaxRetries > 0 ? errorMaxRetries : 0;

    if (maxRetries > 0 && dynCall.allowRetries) {
      return _callWithRetries(dynCall, callParameters, authorization,
          requestParameters, body, bodyType, maxRetries, []);
    } else {
      return _callNoRetries(dynCall, callParameters, authorization,
          requestParameters, body, bodyType);
    }
  }

  @override
  void setCredential(DynCallCredential credential) {
    if (credential is DynCallCredentialHTTP) {
      var httpCredential = credential.credential;
      authorization = httpCredential;
      httpClient.authorization = httpCredential;
    }
  }

  Future<E> _callNoRetries<X>(
      DynCall<E, X> dynCall,
      Map<String, String> callParameters,
      Credential authorization,
      Map<String, String> requestParameters,
      dynamic body,
      String bodyType) {
    var response = httpClient.request(method, path,
        fullPath: fullPath,
        authorization: authorization,
        queryParameters: requestParameters,
        body: body,
        contentType: bodyType);

    return response
        .then((r) => _processResponse(dynCall, callParameters, r.body))
        .catchError((e) {
      var httpError = e is HttpError ? e : null;

      var onHttpError = this.onHttpError ?? _onHttpError;
      var errorAnswer = onHttpError(httpError);

      if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
        return _processResponse(dynCall, callParameters, null);
      } else if (errorAnswer == OnHttpErrorAnswer.ERROR ||
          errorAnswer == OnHttpErrorAnswer.RETRY) {
        return _processError(dynCall, httpError);
      } else {
        throw StateError('Invalid OnHttpErrorResponse: $errorAnswer');
      }
    });
  }

  Future<E> _callWithRetries<X>(
      DynCall<E, X> dynCall,
      Map<String, String> callParameters,
      Credential authorization,
      Map<String, String> requestParameters,
      dynamic body,
      String bodyType,
      int maxErrorRetries,
      List<HttpError> errors) {
    var delay = errors.length <= 2 ? 200 : 500;

    if (maxErrorRetries <= 0) {
      if (errors.isEmpty) {
        return _callNoRetries(dynCall, callParameters, authorization,
            requestParameters, body, bodyType);
      } else {
        //print("delay... $delay");
        return Future.delayed(
            Duration(milliseconds: delay),
            () => _callNoRetries(dynCall, callParameters, authorization,
                requestParameters, body, bodyType));
      }
    }

    //print("_callWithRetries> $method $path > maxErrorRetries: $maxErrorRetries ; errors: $errors");

    if (errors.isEmpty) {
      return _callWithRetriesImpl(dynCall, callParameters, authorization,
          requestParameters, body, bodyType, maxErrorRetries, errors);
    } else {
      //print("delay... $delay");
      return Future.delayed(
          Duration(milliseconds: delay),
          () => _callWithRetriesImpl(dynCall, callParameters, authorization,
              requestParameters, body, bodyType, maxErrorRetries, errors));
    }
  }

  Future<E> _callWithRetriesImpl<X>(
      DynCall<E, X> dynCall,
      Map<String, String> callParameters,
      Credential authorization,
      Map<String, String> requestParameters,
      dynamic body,
      String bodyType,
      int maxErrorRetries,
      List<HttpError> errors) {
    var response = httpClient.request(method, path,
        fullPath: fullPath,
        authorization: authorization,
        queryParameters: requestParameters,
        body: body,
        contentType: bodyType);

    return response
        .then((r) => _processResponse(dynCall, callParameters, r.body))
        .catchError((e, s) {
      var httpError = e is HttpError ? e : null;

      if (httpError == null) {
        print(e);
        print(s);
      }

      var onHttpError = this.onHttpError ?? _onHttpError;
      var errorAnswer = onHttpError(httpError);

      if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
        return _processResponse(dynCall, callParameters, null);
      } else if (errorAnswer == OnHttpErrorAnswer.RETRY) {
        return _callWithRetries(
            dynCall,
            callParameters,
            authorization,
            requestParameters,
            body,
            bodyType,
            maxErrorRetries - 1,
            errors..add(e));
      } else if (errorAnswer == OnHttpErrorAnswer.ERROR) {
        return _processError(dynCall, httpError);
      } else {
        throw StateError('Invalid OnHttpErrorResponse: $errorAnswer');
      }
    });
  }

  OnHttpErrorAnswer _onHttpError(HttpError error) {
    if (error == null) return OnHttpErrorAnswer.ERROR;

    if (error.isStatusNotFound) {
      return OnHttpErrorAnswer.NO_CONTENT;
    } else if (error.isStatusError) {
      return OnHttpErrorAnswer.RETRY;
    } else {
      return OnHttpErrorAnswer.ERROR;
    }
  }

  E _processResponse<O>(DynCall<E, O> dynCall,
      Map<String, String> callParameters, String responseContent) {
    if (outputValidator != null) {
      var valid = outputValidator(responseContent, callParameters);
      if (!valid) {
        _callOutputInterceptor(
            responseContent, false, responseContent, callParameters);
        return null;
      }
    }

    var responseContentOriginal = responseContent;

    if (outputFilter != null) {
      responseContent = outputFilter(responseContent, callParameters);
    } else if (outputFilterPattern != null) {
      var json;
      if (dynCall.outputType == DynCallType.JSON) {
        json = jsonDecode(responseContent);
      }

      if (json is Map) {
        responseContent =
            buildStringPattern(outputFilterPattern, callParameters, [json]);
      } else {
        responseContent =
            buildStringPattern(outputFilterPattern, callParameters);
      }
    }

    _callOutputInterceptor(
        responseContentOriginal, true, responseContent, callParameters);

    return dynCall.parseExecution(responseContent);
  }

  void _callOutputInterceptor(String outputOriginal, bool outputValid,
      String outputFiltered, Map<String, String> callParameters) {
    if (outputInterceptor != null) {
      try {
        outputInterceptor(
            this, outputOriginal, outputValid, outputFiltered, callParameters);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }
  }

  E _processError<O>(DynCall<E, O> dynCall, HttpError error) {
    return dynCall.parseExecution(errorResponse);
  }

  Map<String, String> buildParameters(Map<String, String> parameters) {
    if (parametersMap == null && parametersStatic == null) return null;

    // ignore: omit_local_variable_types
    Set<String> processedKeys = {};

    // ignore: omit_local_variable_types
    Map<String, String> requestParameters = {};

    if (parametersStatic != null && parametersStatic.isNotEmpty) {
      requestParameters.addAll(parametersStatic);
    }

    for (var key in parametersMap.keys) {
      var key2 = parametersMap[key];

      if (key2 == null || key2.isEmpty || key2 == '*') key2 = key;

      var val = parameters[key];
      if (val != null) {
        requestParameters[key2] = val;
        processedKeys.add(key);
      }
    }

    if (parametersMap['*'] == '*') {
      for (var key in parameters.keys) {
        if (!processedKeys.contains(key)) {
          var val = parameters[key];
          requestParameters[key] = val;
          processedKeys.add(key);
        }
      }
    }

    return requestParameters.isNotEmpty ? requestParameters : null;
  }

  Credential buildAuthorization(Map<String, String> parameters) {
    if (authorization != null) {
      return authorization;
    } else {
      return buildAuthorizationWithFields(parameters);
    }
  }

  Credential buildAuthorizationWithFields(Map<String, String> parameters) {
    if (authorizationFields == null || authorizationFields.isEmpty) return null;

    var fieldUser = authorizationFields[0] ?? 'username';
    var fieldPass =
        (authorizationFields.length > 1 ? authorizationFields[1] : null) ??
            'password';

    var user = parameters[fieldUser];
    var pass = parameters[fieldPass];

    if (user != null && pass != null) {
      return BasicCredential(user, pass);
    }

    return null;
  }

  dynamic buildBody(Map<String, String> parameters) {
    if (body != null) return body;
    if (bodyPattern == null) return null;

    if (bodyPattern is String) {
      return buildStringPattern(bodyPattern, parameters);
    } else if (bodyPattern is BodyPatternFunctionString) {
      return bodyPattern(parameters);
    } else if (bodyPattern is BodyPatternFunctionDynamic) {
      return bodyPattern(parameters);
    } else if (bodyPattern is BodyPatternFunctionSimpleString) {
      return bodyPattern(parameters);
    } else if (bodyPattern is BodyPatternFunctionSimpleDynamic) {
      return bodyPattern(parameters);
    } else {
      return null;
    }
  }

  String buildBodyType(String body) {
    if (this.bodyType == null || body == null) return null;

    var bodyType = this.bodyType.trim();
    if (bodyType.isEmpty) return null;

    var bodyTypeLC = bodyType.toLowerCase();

    if (bodyTypeLC == 'json') return 'application/json';
    if (bodyTypeLC == 'jpeg') return 'image/jpeg';
    if (bodyTypeLC == 'png') return 'image/png';
    if (bodyTypeLC == 'text') return 'text/plain';
    if (bodyTypeLC == 'html') return 'text/html';

    return bodyType;
  }
}

typedef ExecutorWrapper = DynCallExecutor Function(DynCallExecutor executor);

class DynCallHttpExecutorFactory {
  final HttpClient httpClient;

  String _basePath;

  DynCallHttpExecutorFactory(this.httpClient, [String basePath]) {
    _basePath = _normalizePath(basePath);
  }

  String _normalizePath(String path) => path != null ? path.trim() : null;

  String _notEmpty(String s, [bool trim = false]) =>
      s != null && s.isNotEmpty && (!trim || s.trim().isNotEmpty) ? s : null;

  String get basePath => _basePath;

  DynCallHttpExecutor<E> create<E>(HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Credential authorization,
      List<String> authorizationFields,
      String body,
      String bodyPattern,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      String outputFilterPattern,
      HTTPOutputInterceptor outputInterceptor}) {
    path = _notEmpty(path);
    fullPath = _notEmpty(fullPath);

    var callPath;
    var callFullPath;

    if (fullPath != null) {
      fullPath = _normalizePath(fullPath);
      callPath = fullPath;
      callFullPath = true;
    } else {
      path = _normalizePath(path);
      callPath =
          _basePath != null && _basePath.isNotEmpty ? '$_basePath$path' : path;
      callFullPath = false;
    }

    // ignore: omit_local_variable_types
    DynCallHttpExecutor<E> executor = DynCallHttpExecutor(
        httpClient, method, callPath,
        fullPath: callFullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyPattern: bodyPattern,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        outputFilterPattern: outputFilterPattern,
        outputInterceptor: outputInterceptor);
    return executor;
  }

  DynCallExecutor<E> define<E, O>(DynCall<E, O> call, HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Credential authorization,
      List<String> authorizationFields,
      String body,
      String bodyPattern,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      String outputFilterPattern,
      HTTPOutputInterceptor outputInterceptor,
      ExecutorWrapper executorWrapper}) {
    // ignore: omit_local_variable_types
    DynCallExecutor<E> executor = create(method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyPattern: bodyPattern,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        outputFilterPattern: outputFilterPattern,
        outputInterceptor: outputInterceptor);

    if (executorWrapper != null) {
      var executor2 = executorWrapper(executor) as DynCallExecutor<E>;
      if (executor2 != null) executor = executor2;
    }

    call.executor = executor;
    return executor;
  }

  DynCallHttpExecutorFactory_builder<E, O> call<E, O>(DynCall<E, O> call) =>
      DynCallHttpExecutorFactory_builder<E, O>(this, call);
}

class DynCallHttpExecutorFactory_builder<E, O> {
  final DynCallHttpExecutorFactory factory;

  final DynCall<E, O> call;

  DynCallHttpExecutorFactory_builder(this.factory, this.call);

  DynCallExecutor<E> executor(HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Credential authorization,
      List<String> authorizationFields,
      String body,
      String bodyPattern,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      String outputFilterPattern}) {
    return factory.define(call, method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyPattern: bodyPattern,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        outputFilterPattern: outputFilterPattern);
  }

  DynCallExecutor<E> authorizationExecutor(
      DynCallCredentialParser<E> credentialParser, HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Credential authorization,
      List<String> authorizationFields,
      String body,
      String bodyPattern,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      String outputFilterPattern}) {
    var credentialInterceptor = _CredentialInterceptor(credentialParser);

    return factory.define(call, method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyPattern: bodyPattern,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        outputFilterPattern: outputFilterPattern,
        outputInterceptor: credentialInterceptor.interceptOutput);
  }
}

class _CredentialInterceptor<E> extends HTTPOutputInterceptorWrapper<E> {
  final DynCallCredentialParser<E> _credentialParser;

  _CredentialInterceptor(this._credentialParser) : super();

  @override
  void interceptOutput(
      DynCallExecutor<E> executor,
      String outputOriginal,
      bool outputValid,
      String outputFiltered,
      Map<String, String> callParameters) {
    if (outputValid ?? false) {
      var credential =
          _credentialParser(outputOriginal, outputFiltered, callParameters);

      if (credential != null) {
        executor.setCredential(credential);
      }
    }
  }
}
