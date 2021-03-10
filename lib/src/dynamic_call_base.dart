import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

enum DynCallType { BOOL, STRING, INTEGER, DECIMAL, JSON }

typedef SysCallOutputFilter<O, E> = O Function(E output);

/// Callback function.
typedef SysCallCallback<O> = void Function(
    O output, Map<String, dynamic> parameters);

/// Progress function.
typedef SysProgressListener<O> = void Function(
    int loaded, int total, double ratio, bool upload);

/// A Dynamic Call specification
class DynCall<E, O> {
  /// Input fields of the call.
  final List<String> input;

  /// Type of the output.
  final DynCallType outputType;

  /// Output filter, to transform from [E] to [O].
  final SysCallOutputFilter<O, E> outputFilter;

  final bool _allowRetries;

  DynCall(this.input, this.outputType, {this.outputFilter, bool allowRetries})
      : _allowRetries = allowRetries ?? false;

  /// If [true] allows retries of the call. Recommended only for call that
  /// won't make changes to the system.
  bool get allowRetries => _allowRetries ?? false;

  DynCallExecutor<E> executor;

  /// Returns the [call] URI, without perform a [call].
  String buildURI([Map<String, dynamic> inputParameters]) {
    if (executor == null) return null;
    var callParameters = buildCallParameters(inputParameters);
    return executor.buildURI(this, callParameters);
  }

  /// Executes the call using [inputParameters] (with fields specified at [input]) and calling [callback] after.
  Future<O> call(
      [Map<String, dynamic> inputParameters,
      SysCallCallback<O> callback,
      SysProgressListener onProgress]) {
    if (executor == null) {
      var out = parseOutput(null);

      if (callback != null) {
        try {
          callback(out, inputParameters);
        } catch (e) {
          print(e);
        }
      }

      return Future.value(out);
    }

    var callParameters = buildCallParameters(inputParameters);

    var call = executor.call(this, callParameters, onProgress);
    var calMapped = call.then(mapOutput);

    if (callback == null) return calMapped;

    return calMapped.then((out) {
      try {
        callback(out, inputParameters);
      } catch (e) {
        print(e);
      }
      return out;
    });
  }

  /// Build call parameters using [inputParameters].
  Map<String, String> buildCallParameters(
      Map<String, dynamic> inputParameters) {
    // ignore: omit_local_variable_types
    Map<String, String> callParameters = {};

    if (inputParameters == null || inputParameters.isEmpty) {
      return callParameters;
    }

    for (var k in input) {
      var val = inputParameters[k];
      if (val != null) {
        callParameters[k] = '$val';
      }
    }

    return callParameters;
  }

  /// Parses the output of the call to the [outputType] and applying [outputFilter] if needed.
  O parseOutput(Object /*?*/ value) {
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

  /// Parses a value to the [outputType].
  E parseExecution(Object /*?*/ value) {
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

  bool parseOutputBOOL(Object /*?*/ value) {
    if (value == null) return false;
    if (value is bool) return value;

    if (value is num) {
      var n = value.toInt();
      return n >= 1;
    }

    var s = '$value'.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 't' || s == 'y';
  }

  String parseOutputSTRING(Object /*?*/ value) {
    if (value == null) return null;
    if (value is String) return value;

    var s = '$value';
    return s;
  }

  int parseOutputINTEGER(Object /*?*/ value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.parse('$value');
  }

  double parseOutputDECIMAL(Object /*?*/ value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.parse('$value');
  }

  dynamic parseOutputJSON(Object /*?*/ value) {
    if (value == null) return null;
    if (value is String) return jsonDecode(value);
    if (value is Map) return value;
    if (value is List) return value;
    if (value is num) return value;
    if (value is bool) return value;
    return jsonDecode('$value');
  }
}

/// Abstract class for credentials.
abstract class DynCallCredential {
  bool applyCredential(DynCallExecutor executor);
}

/// A HTTP Credential.
class DynCallCredentialHTTP extends DynCallCredential {
  final Credential credential;

  DynCallCredentialHTTP(this.credential);

  factory DynCallCredentialHTTP.fromJSONToken(Object /*?*/ json) {
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
      executor.httpClient.authorization =
          Authorization.fromCredential(credential);
      return true;
    }

    return false;
  }
}

typedef DynCallCredentialParser<E> = DynCallCredential Function(
    String output,
    String outputFiltered,
    Map<String, String> parameters,
    Map<String, String> requestParameters);

/// Abstract class for the executor implementation.
abstract class DynCallExecutor<E> {
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> parameters,
      SysProgressListener onProgress);

  String buildURI<X>(DynCall<E, X> dynCall, Map<String, String> parameters);

  void setCredential(DynCallCredential credential) {}
}

/// Static [DynCallExecutor], with predefined results.
class DynCallStaticExecutor<E> extends DynCallExecutor<E> {
  final E response;

  DynCallStaticExecutor(this.response);

  @override
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> parameters,
      SysProgressListener onProgress) {
    if (onProgress != null) {
      try {
        onProgress(1, 1, 1.0, false);
      } catch (e, s) {
        print(e);
        print(s);
      }
    }

    return Future.value(response);
  }

  @override
  String buildURI<X>(
      DynCall<E, X> dynCall, Map<String, String> callParameters) {
    throw UnsupportedError('No URI for static calls!');
  }
}

typedef DynCallFunction<R, T> = Future<R> Function(
    DynCall<R, T> dynCall, Map<String, String> parameters);

/// A [DynCallExecutor] that calls a [DynCallFunction] for results.
class DynCallFunctionExecutor<R, T> extends DynCallExecutor<R> {
  final DynCallFunction<R, T> function;

  DynCallFunctionExecutor(this.function);

  @override
  Future<R> call<X>(DynCall<R, X> dynCall, Map<String, String> parameters,
      SysProgressListener onProgress) {
    var dynCallCast = dynCall as DynCall<R, T>;

    if (onProgress != null) {
      return function(dynCallCast, parameters).then((value) {
        try {
          onProgress(1, 1, 1.0, false);
        } catch (e, s) {
          print(e);
          print(s);
        }

        return value;
      });
    } else {
      return function(dynCallCast, parameters);
    }
  }

  @override
  String buildURI<X>(
      DynCall<R, X> dynCall, Map<String, String> callParameters) {
    throw UnsupportedError('No URI for function calls!');
  }
}

/// A HTTP Client for DynCallHttpExecutor calls.
class DynCallHttpClient extends HttpClient {
  DynCallHttpClient(String baseURL, [HttpClientRequester clientRequester])
      : super(baseURL, clientRequester);

  DynCallHttpExecutor<E> executor<E>(HttpMethod method, String path,
      {Map<String, String> parametersMap,
      String queryString,
      List<String> authorizationFields,
      E errorResponse,
      int errorMaxRetries = 3}) {
    return DynCallHttpExecutor(this, method, path,
        parametersMap: parametersMap,
        queryString: queryString,
        authorizationFields: authorizationFields,
        errorResponse: errorResponse,
        errorMaxRetries: 3);
  }
}

/// Specify an HTTP error.
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
      Map<String, String> callParameters,
      Map<String, String> requestParameters);
}

typedef OnHttpError = OnHttpErrorAnswer Function(HttpError error);

typedef HTTPOutputInterceptor<E> = void Function(
    DynCallExecutor<E> executor,
    String outputOriginal,
    bool outputValid,
    String outputFiltered,
    Map<String, String> callParameters,
    Map<String, String> requestParameters);
typedef HTTPOutputValidator = bool Function(String output,
    Map<String, String> callParameters, Map<String, String> requestParameters);
typedef HTTPOutputFilter = String Function(String output,
    Map<String, String> callParameters, Map<String, String> requestParameters);
typedef HTTPJSONOutputFilter = dynamic Function(Object /*?*/ json,
    Map<String, String> callParameters, Map<String, String> requestParameters);

typedef BodyBuilderFunctionString = String Function(
    Map<String, String> callParameters, Map<String, String> requestParameters);
typedef BodyBuilderFunctionDynamic = dynamic Function(
    Map<String, String> callParameters, Map<String, String> requestParameters);

typedef BodyBuilderFunctionSimpleString = String Function();
typedef BodyBuilderFunctionSimpleDynamic = dynamic Function();

/// A [DynCallExecutor] for HTTP calls.
class DynCallHttpExecutor<E> extends DynCallExecutor<E> {
  /// The HTTP client.
  HttpClient httpClient;

  /// HTTP Method.
  HttpMethod method;

  /// Call path.
  String path;

  /// Call full path (to overwrite client basePath).
  bool fullPath;

  /// Maps input to query parameters.
  Map<String, String> parametersMap;

  /// Query parameters with static values.
  Map<String, String> parametersStatic;

  /// Query parameters with values from [ParameterProvider].
  Map<String, ParameterProvider> parametersProviders;

  /// Forces the URI query string.
  String queryString;

  /// If [true] will avoid use of `queryString` in request URL.
  bool noQueryString;

  /// The Credential for the HTTP request.
  Credential authorization;

  /// Specify call parameters to use as [authorizationFields].
  List<String> authorizationFields;

  /// Body of the request.
  Object /*?*/ body;

  /// Body pattern for the request.
  Object /*?*/ bodyBuilder;

  /// Body type. Example: JSON.
  String bodyType;

  /// Function to validate if the request output is valid.
  HTTPOutputValidator outputValidator;

  /// Filter for the output (as [String]), to transform the request response to another [String].
  HTTPOutputFilter outputFilter;

  /// Filter for the output (as JSON), to transform the request response to another JSON.
  HTTPJSONOutputFilter jsonOutputFilter;

  /// Filter for the output, to transform the request response using a String pattern.
  /// See: [buildStringPattern].
  String outputFilterPattern;

  /// Function called for any output received. Useful for logs.
  HTTPOutputInterceptor<E> outputInterceptor;

  /// Call response in case of an error.
  E errorResponse;

  /// Maximum number o retries for the call.
  int errorMaxRetries;

  /// In case of error what behavior to follow: [OnHttpErrorAnswer]
  OnHttpError onHttpError;

  DynCallHttpExecutor(this.httpClient, this.method, this.path,
      {this.fullPath,
      this.parametersMap,
      this.parametersStatic,
      this.parametersProviders,
      this.queryString,
      this.noQueryString,
      this.authorization,
      this.authorizationFields,
      this.body,
      this.bodyBuilder,
      this.bodyType,
      this.outputValidator,
      this.outputFilter,
      this.jsonOutputFilter,
      this.outputFilterPattern,
      this.outputInterceptor,
      this.errorResponse,
      this.errorMaxRetries = 3,
      this.onHttpError});

  @override
  Future<E> call<X>(DynCall<E, X> dynCall, Map<String, String> callParameters,
      SysProgressListener onProgress) {
    var requestParameters = buildParameters(callParameters);
    var authorization = buildAuthorization(callParameters);
    var body = buildBody(callParameters, requestParameters);
    var bodyType = buildBodyType(body);

    var maxRetries =
        errorMaxRetries != null && errorMaxRetries > 0 ? errorMaxRetries : 0;

    if (maxRetries > 0 && dynCall.allowRetries) {
      return _callWithRetries(dynCall, callParameters, authorization,
          requestParameters, body, bodyType, maxRetries, [], onProgress);
    } else {
      return _callNoRetries(dynCall, callParameters, authorization,
          requestParameters, body, bodyType, onProgress);
    }
  }

  @override
  void setCredential(DynCallCredential credential) {
    if (credential is DynCallCredentialHTTP) {
      var httpCredential = credential.credential;
      authorization = httpCredential;
      httpClient.authorization = Authorization.fromCredential(httpCredential);
    }
  }

  Future<E> _callNoRetries<X>(
      DynCall<E, X> dynCall,
      Map<String, String> callParameters,
      Credential authorization,
      Map<String, String> requestParameters,
      Object /*?*/ body,
      String bodyType,
      SysProgressListener onProgress) {
    var progressListener =
        onProgress != null ? (r, l, t, p, u) => onProgress(l, t, p, u) : null;

    var response = httpClient.request(method, path,
        fullPath: fullPath,
        authorization: authorization,
        parameters: requestParameters,
        queryString: queryString,
        noQueryString: noQueryString,
        body: body,
        contentType: bodyType,
        progressListener: progressListener);

    return response
        .then((r) => _processResponse(
            dynCall, callParameters, requestParameters, r.bodyAsString))
        .catchError((e) {
      var httpError = e is HttpError ? e : null;

      var onHttpError = this.onHttpError ?? _onHttpError;
      var errorAnswer = onHttpError(httpError);

      if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
        return _processResponse(
            dynCall, callParameters, requestParameters, null);
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
      Object /*?*/ body,
      String bodyType,
      int maxErrorRetries,
      List<HttpError> errors,
      SysProgressListener onProgress) {
    var delay = errors.length <= 2 ? 200 : 500;

    if (maxErrorRetries <= 0) {
      if (errors.isEmpty) {
        return _callNoRetries(dynCall, callParameters, authorization,
            requestParameters, body, bodyType, onProgress);
      } else {
        //print("delay... $delay");
        return Future.delayed(
            Duration(milliseconds: delay),
            () => _callNoRetries(dynCall, callParameters, authorization,
                requestParameters, body, bodyType, onProgress));
      }
    }

    //print("_callWithRetries> $method $path > maxErrorRetries: $maxErrorRetries ; errors: $errors");

    if (errors.isEmpty) {
      return _callWithRetriesImpl(
          dynCall,
          callParameters,
          authorization,
          requestParameters,
          body,
          bodyType,
          maxErrorRetries,
          errors,
          onProgress);
    } else {
      //print("delay... $delay");
      return Future.delayed(
          Duration(milliseconds: delay),
          () => _callWithRetriesImpl(
              dynCall,
              callParameters,
              authorization,
              requestParameters,
              body,
              bodyType,
              maxErrorRetries,
              errors,
              onProgress));
    }
  }

  Future<E> _callWithRetriesImpl<X>(
      DynCall<E, X> dynCall,
      Map<String, String> callParameters,
      Credential authorization,
      Map<String, String> requestParameters,
      Object /*?*/ body,
      String bodyType,
      int maxErrorRetries,
      List<HttpError> errors,
      SysProgressListener onProgress) {
    var progressListener =
        onProgress != null ? (r, l, t, p, u) => onProgress(l, t, p, u) : null;

    var response = httpClient.request(method, path,
        fullPath: fullPath,
        authorization: authorization,
        parameters: requestParameters,
        queryString: queryString,
        noQueryString: noQueryString,
        body: body,
        contentType: bodyType,
        progressListener: progressListener);

    return response
        .then((r) => _processResponse(
            dynCall, callParameters, requestParameters, r.bodyAsString))
        .catchError((e, s) {
      var httpError = e is HttpError ? e : null;

      if (httpError == null) {
        print(e);
        print(s);
      }

      var onHttpError = this.onHttpError ?? _onHttpError;
      var errorAnswer = onHttpError(httpError);

      if (errorAnswer == OnHttpErrorAnswer.NO_CONTENT) {
        return _processResponse(
            dynCall, callParameters, requestParameters, null);
      } else if (errorAnswer == OnHttpErrorAnswer.RETRY) {
        return _callWithRetries(
            dynCall,
            callParameters,
            authorization,
            requestParameters,
            body,
            bodyType,
            maxErrorRetries - 1,
            errors..add(e),
            onProgress);
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

  E _processResponse<O>(
      DynCall<E, O> dynCall,
      Map<String, String> callParameters,
      Map<String, String> requestParameters,
      String responseContent) {
    if (outputValidator != null) {
      var valid =
          outputValidator(responseContent, callParameters, requestParameters);
      if (!valid) {
        _callOutputInterceptor(responseContent, false, responseContent,
            callParameters, requestParameters);
        return null;
      }
    }

    var responseContentOriginal = responseContent;

    if (outputFilter != null) {
      responseContent =
          outputFilter(responseContent, callParameters, requestParameters);
    } else if (jsonOutputFilter != null) {
      var json = responseContent != null ? jsonDecode(responseContent) : null;
      var json2 = jsonOutputFilter(json, callParameters, requestParameters);
      responseContent = jsonEncode(json2);
    } else if (outputFilterPattern != null) {
      var json;
      if (dynCall.outputType == DynCallType.JSON) {
        json = jsonDecode(responseContent);
      }

      if (json is Map) {
        responseContent = buildStringPattern(
            outputFilterPattern, callParameters, [json, requestParameters]);
      } else {
        responseContent =
            buildStringPattern(outputFilterPattern, callParameters);
      }
    }

    _callOutputInterceptor(responseContentOriginal, true, responseContent,
        callParameters, requestParameters);

    return dynCall.parseExecution(responseContent);
  }

  void _callOutputInterceptor(
      String outputOriginal,
      bool outputValid,
      String outputFiltered,
      Map<String, String> callParameters,
      Map<String, String> requestParameters) {
    if (outputInterceptor != null) {
      try {
        outputInterceptor(this, outputOriginal, outputValid, outputFiltered,
            callParameters, requestParameters);
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
    var parametersMap = this.parametersMap;
    var parametersStatic = this.parametersStatic;
    var parametersProviders = this.parametersProviders;

    if (parametersMap == null &&
        parametersStatic == null &&
        parametersProviders == null) return null;

    parametersMap ??= {};
    parametersStatic ??= {};
    parametersProviders ??= {};

    if (parametersMap.isEmpty &&
        parametersStatic.isEmpty &&
        parametersProviders.isEmpty) return null;

    var requestParameters = <String, String>{};

    if (parametersStatic != null && parametersStatic.isNotEmpty) {
      requestParameters.addAll(parametersStatic);
    }

    var processedKeys = <String>{};

    for (var key in parametersMap.keys) {
      var key2 = parametersMap[key];
      if (key2 == null || key2.isEmpty || key2 == '*') key2 = key;

      var value = parameters[key];
      if (value != null) {
        requestParameters[key2] = value;
        processedKeys.add(key);
      }
    }

    if (parametersMap['*'] == '*') {
      for (var key in parameters.keys) {
        if (!processedKeys.contains(key)) {
          var value = parameters[key];
          requestParameters[key] = value;
          processedKeys.add(key);
        }
      }
    }

    for (var key in parametersProviders.keys) {
      var provider = parametersProviders[key];
      if (provider == null) continue;

      if (!processedKeys.contains(key)) {
        String value;

        try {
          value = provider(key);
        } catch (e, s) {
          print(e);
          print(s);
        }

        if (requestParameters.containsKey(key)) {
          if (value != null) {
            requestParameters[key] = value;
          }
        } else {
          requestParameters[key] = value;
        }
      }
    }

    return requestParameters.isNotEmpty ? requestParameters : null;
  }

  @override
  String buildURI<X>(
      DynCall<E, X> dynCall, Map<String, String> callParameters) {
    var requestParameters = buildParameters(callParameters);
    var authorization = buildAuthorization(callParameters);

    var authorizationFromCredential = authorization != null
        ? Authorization.fromCredential(authorization)
        : null;

    return httpClient.buildRequestURL(method, path,
        fullPath: fullPath,
        authorization: authorizationFromCredential,
        parameters: requestParameters,
        noQueryString: noQueryString);
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

  Object /*?*/ buildBody(Map<String, String> parameters,
      [Map<String, String> requestParameters]) {
    if (body != null) return body;
    if (bodyBuilder == null) return null;

    if (bodyBuilder is String) {
      return buildStringPattern(bodyBuilder, parameters, [requestParameters]);
    } else if (bodyBuilder is BodyBuilderFunctionString) {
      BodyBuilderFunctionString f = bodyBuilder;
      return f(parameters, requestParameters);
    } else if (bodyBuilder is BodyBuilderFunctionDynamic) {
      BodyBuilderFunctionDynamic f = bodyBuilder;
      return f(parameters, requestParameters);
    } else if (bodyBuilder is BodyBuilderFunctionSimpleString) {
      BodyBuilderFunctionSimpleString f = bodyBuilder;
      return f();
    } else if (bodyBuilder is BodyBuilderFunctionSimpleDynamic) {
      BodyBuilderFunctionSimpleDynamic f = bodyBuilder;
      return f();
    } else {
      return null;
    }
  }

  String buildBodyType(String body) {
    if (this.bodyType == null || body == null) return null;

    var bodyType = this.bodyType.trim();
    if (bodyType.isEmpty) return null;

    return MimeType.parseAsString(bodyType, bodyType);
  }
}

typedef ParameterProvider = String Function(String key);

typedef ExecutorWrapper = DynCallExecutor Function(DynCallExecutor executor);

/// A Factory that helps to define/attach HTTP executors to calls.
class DynCallHttpExecutorFactory {
  /// The HTTP client.
  final HttpClient httpClient;

  /// Base path of the requests.
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
      Map<String, ParameterProvider> parametersProviders,
      String queryString,
      noQueryString = false,
      Credential authorization,
      List<String> authorizationFields,
      Object /*?*/ body,
      Object /*?*/ bodyBuilder,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      HTTPJSONOutputFilter jsonOutputFilter,
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
        parametersProviders: parametersProviders,
        queryString: queryString,
        noQueryString: noQueryString,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyBuilder: bodyBuilder,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        jsonOutputFilter: jsonOutputFilter,
        outputFilterPattern: outputFilterPattern,
        outputInterceptor: outputInterceptor);
    return executor;
  }

  DynCallExecutor<E> define<E, O>(DynCall<E, O> call, HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Map<String, ParameterProvider> parametersProviders,
      String queryString,
      noQueryString = false,
      Credential authorization,
      List<String> authorizationFields,
      Object /*?*/ body,
      Object /*?*/ bodyBuilder,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      HTTPJSONOutputFilter jsonOutputFilter,
      String outputFilterPattern,
      HTTPOutputInterceptor outputInterceptor,
      ExecutorWrapper executorWrapper}) {
    // ignore: omit_local_variable_types
    DynCallExecutor<E> executor = create(method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        parametersProviders: parametersProviders,
        queryString: queryString,
        noQueryString: noQueryString,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyBuilder: bodyBuilder,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        jsonOutputFilter: jsonOutputFilter,
        outputFilterPattern: outputFilterPattern,
        outputInterceptor: outputInterceptor);

    if (executorWrapper != null) {
      var executor2 = executorWrapper(executor) as DynCallExecutor<E>;
      if (executor2 != null) executor = executor2;
    }

    call.executor = executor;
    return executor;
  }

  /// Main method to use in the Factory. Returns a builder.
  DynCallHttpExecutorFactory_builder<E, O> call<E, O>(DynCall<E, O> call) =>
      DynCallHttpExecutorFactory_builder<E, O>(this, call);
}

/// The Builder returned by Factory `call(...)` method.
class DynCallHttpExecutorFactory_builder<E, O> {
  /// The HTTP Executor factory.
  final DynCallHttpExecutorFactory factory;

  /// The call to define the executor.
  final DynCall<E, O> call;

  /// This constructor shouldn't be used. Use the Factory method `call(...)`.
  DynCallHttpExecutorFactory_builder(this.factory, this.call);

  /// Configure and define the call executor.
  /// See [DynCallHttpExecutor] fields documentation.
  DynCallExecutor<E> executor(HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Map<String, ParameterProvider> parametersProviders,
      String queryString,
      noQueryString = false,
      Credential authorization,
      List<String> authorizationFields,
      Object /*?*/ body,
      Object /*?*/ bodyBuilder,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      HTTPJSONOutputFilter jsonOutputFilter,
      String outputFilterPattern}) {
    return factory.define(call, method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        parametersProviders: parametersProviders,
        queryString: queryString,
        noQueryString: noQueryString,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyBuilder: bodyBuilder,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        jsonOutputFilter: jsonOutputFilter,
        outputFilterPattern: outputFilterPattern);
  }

  /// Configure and define the call executor, using an Authorization request.
  /// See [DynCallHttpExecutor] fields documentation.
  DynCallExecutor<E> authorizationExecutor(
      DynCallCredentialParser<E> credentialParser, HttpMethod method,
      {String path,
      String fullPath,
      Map<String, String> parametersMap,
      Map<String, String> parametersStatic,
      Map<String, ParameterProvider> parametersProviders,
      noQueryString = false,
      Credential authorization,
      List<String> authorizationFields,
      Object /*?*/ body,
      Object /*?*/ bodyBuilder,
      String bodyType,
      E errorResponse,
      int errorMaxRetries = 3,
      HTTPOutputValidator outputValidator,
      HTTPOutputFilter outputFilter,
      HTTPJSONOutputFilter jsonOutputFilter,
      String outputFilterPattern}) {
    var credentialInterceptor = _CredentialInterceptor(credentialParser);

    return factory.define(call, method,
        path: path,
        fullPath: fullPath,
        parametersMap: parametersMap,
        parametersStatic: parametersStatic,
        parametersProviders: parametersProviders,
        noQueryString: noQueryString,
        authorization: authorization,
        authorizationFields: authorizationFields,
        body: body,
        bodyBuilder: bodyBuilder,
        bodyType: bodyType,
        errorResponse: errorResponse,
        errorMaxRetries: errorMaxRetries,
        outputValidator: outputValidator,
        outputFilter: outputFilter,
        jsonOutputFilter: jsonOutputFilter,
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
      Map<String, String> callParameters,
      Map<String, String> requestParameters) {
    if (outputValid ?? false) {
      var credential = _credentialParser(
          outputOriginal, outputFiltered, callParameters, requestParameters);

      if (credential != null) {
        executor.setCredential(credential);
      }
    }
  }
}
