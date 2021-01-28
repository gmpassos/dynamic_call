import 'dart:async';

import 'package:dynamic_call/dynamic_call.dart';
import 'package:json_object_mapper/json_object_mapper.dart';
import 'package:swiss_knife/swiss_knife.dart';

typedef DataTransformerTo<T> = T Function(dynamic o);
typedef DataTransformerToList<T> = List<T> Function(dynamic o);

List<T> doTransformToList<T>(dynamic o, DataTransformerTo<T> transformerTo,
    DataTransformerToList<T> transformerToList) {
  if (transformerToList != null) {
    return transformerToList(o);
  }

  if (o == null) return [];

  if (o is List) {
    if (o.isEmpty) return [];
    return o.map((e) => doTransformTo(e, transformerTo)).toList();
  } else {
    return [doTransformTo(o, transformerTo)];
  }
}

T doTransformTo<T>(dynamic o, DataTransformerTo<T> transformerTo) {
  if (transformerTo == null) {
    return o;
  }
  return transformerTo(o);
}

typedef DataTransformerFrom<T> = dynamic Function(T data);
typedef DataTransformerFromList<T> = dynamic Function(List<T> dataList);

dynamic doTransformFrom<T>(T data, DataTransformerFrom<T> transformerFrom) {
  if (transformerFrom == null) {
    return data;
  }
  return transformerFrom(data);
}

dynamic doTransformFromList<T>(
    List<T> list,
    DataTransformerFrom<T> transformerFrom,
    DataTransformerFromList<T> transformerFromList) {
  if (transformerFromList != null) {
    return transformerFromList(list);
  }

  if (list == null || list.isEmpty) return null;
  return list.map((e) => doTransformFrom(e, transformerFrom)).toList();
}

/// Base class for [DataSource] and [DataReceiver].
abstract class DataHandler<T> {
  static final EventStream<DataHandler> onRegister = EventStream();

  static void register(DataHandler instance) {
    if (instance is DataRepository) {
      DataRepository.register(instance);
    } else if (instance is DataSource) {
      DataSource.register(instance);
    } else if (instance is DataReceiver) {
      DataReceiver.register(instance);
    } else {
      throw StateError(
          "Can't handle type: ${instance != null ? instance.runtimeType : null}");
    }
  }

  static DataHandler<T> byName<T>(String domain, String name) {
    return DataHandler.byID(normalizeID(domain, name));
  }

  static DataHandler<T> byID<T>(String id) {
    if (id == null) return null;

    var instance = DataRepository.byID(id) as DataHandler<T>;
    if (instance != null) return instance;

    instance = DataSource.byID(id) as DataHandler<T>;
    if (instance != null) return instance;

    instance = DataReceiver.byID(id) as DataHandler<T>;
    return instance;
  }

  final String id;
  final String domain;
  final String name;

  DataHandler(this.domain, this.name,
      {bool register = true,
      DataTransformerTo<T> transformerTo,
      DataTransformerToList<T> transformerToList,
      DataTransformerFrom<T> transformerFrom,
      DataTransformerFromList<T> transformerFromList})
      : id = normalizeID(domain, name),
        _transformerTo = transformerTo,
        _transformerToList = transformerToList,
        _transformerFrom = transformerFrom,
        _transformerFromList = transformerFromList {
    _check(this);

    register ??= true;

    if (register) {
      DataHandler.register(this);
    }
  }

  static void _check(DataHandler dataHandler) {
    if (isEmptyObject(dataHandler.domain)) {
      throw ArgumentError(
          '${dataHandler.runtimeType}[${dataHandler.domain}:${dataHandler.name}]: null (domain)');
    }
    if (isEmptyObject(dataHandler.name)) {
      throw ArgumentError(
          '${dataHandler.runtimeType}[${dataHandler.domain}:${dataHandler.name}]: null (name)');
    }

    if (isEmptyObject(dataHandler.id)) {
      throw ArgumentError(
          '${dataHandler.runtimeType}[${dataHandler.domain}:${dataHandler.name}]: null (id)');
    }

    var idParts = splitID(dataHandler.id);

    if (idParts == null ||
        idParts.length != 2 ||
        idParts[0].isEmpty ||
        idParts[1].isEmpty) {
      throw ArgumentError(
          '${dataHandler.runtimeType}[${dataHandler.domain}:${dataHandler.name}]: Invalid id: ${dataHandler.id}');
    }
  }

  static String normalizeID(String domain, String name) {
    if (domain == null || name == null) return null;
    domain = domain.toLowerCase();
    name = name.toLowerCase();
    return '$domain:$name';
  }

  static List<String> splitID(String id) {
    var parts = split(id, ':', 2);
    return parts.length == 2 ? parts : null;
  }

  DataTransformerTo<T> _transformerTo;

  DataTransformerTo<T> get transformerTo => _transformerTo;

  set transformerTo(DataTransformerTo<T> value) {
    _transformerTo = value;
  }

  DataTransformerToList<T> _transformerToList;

  DataTransformerToList<T> get transformerToList => _transformerToList;

  set transformerToList(DataTransformerToList<T> value) {
    _transformerToList = value;
  }

  DataTransformerFrom<T> _transformerFrom;

  DataTransformerFrom<T> get transformerFrom => _transformerFrom;

  set transformerFrom(DataTransformerFrom<T> value) {
    _transformerFrom = value;
  }

  T transformTo(dynamic o) => doTransformTo(o, _transformerTo);

  List<T> transformToList(dynamic o) =>
      doTransformToList(o, _transformerTo, _transformerToList);

  DataTransformerFromList<T> _transformerFromList;

  DataTransformerFromList<T> get transformerFromList => _transformerFromList;

  set transformerFromList(DataTransformerFromList<T> value) {
    _transformerFromList = value;
  }

  dynamic transformFrom(T data) => doTransformFrom(data, _transformerFrom);

  dynamic transformFromList(List<T> list) =>
      doTransformFromList(list, _transformerFrom, _transformerFromList);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataHandler &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Enum for type of [DataSource] operation.
enum DataSourceOperation {
  get,
  find,
  findByID,
  findByIDRange,
  put,
}

/// Returns a [DataSourceOperation] by [name].
DataSourceOperation getDataSourceOperation(String name) {
  if (name == null) return null;
  name = name.trim().toLowerCase();

  switch (name) {
    case 'get':
      return DataSourceOperation.get;
    case 'find':
      return DataSourceOperation.find;
    case 'findbyid':
      return DataSourceOperation.findByID;
    case 'findbyidrange':
      return DataSourceOperation.findByIDRange;
    case 'put':
      return DataSourceOperation.put;
    default:
      return null;
  }
}

String getDataSourceOperationName(DataSourceOperation operation) {
  if (operation == null) return null;
  switch (operation) {
    case DataSourceOperation.get:
      return 'get';
    case DataSourceOperation.find:
      return 'find';
    case DataSourceOperation.findByID:
      return 'findByID';
    case DataSourceOperation.findByIDRange:
      return 'findByIDRange';
    case DataSourceOperation.put:
      return 'put';
    default:
      return null;
  }
}

/// Performs a [DataSourceOperation] over [dataSource] instance.
Future<List<T>> doDataSourceOperation<T>(DataSource<T> dataSource,
    DataSourceOperation operation, Map<String, String> parameters,
    [List<T> dataList]) {
  switch (operation) {
    case DataSourceOperation.get:
      return dataSource.get(parameters);
    case DataSourceOperation.find:
      return dataSource.find(parameters);
    case DataSourceOperation.findByID:
      {
        var id = findKeyValue(parameters, ['id', 'key'], true);
        return dataSource.findByID(id);
      }
    case DataSourceOperation.findByIDRange:
      {
        var fromID = findKeyValue(
            parameters,
            ['fromid', 'from_id', 'from-id', 'fromkey', 'from_key', 'from-key'],
            true);
        var toID = findKeyValue(parameters,
            ['toid', 'to_id', 'to-id', 'tokey', 'to_key', 'to-key'], true);
        return dataSource.findByIDRange(fromID, toID);
      }
    case DataSourceOperation.put:
      {
        var dataReceiver = dataSource as DataReceiver;
        return dataReceiver.put(parameters: parameters, dataList: dataList);
      }
    default:
      return Future.value(null);
  }
}

/// Wrapper to resolve a [DataSource].
class DataSourceResolver<T> {
  final String id;
  DataSource<T> _dataSource;

  DataSourceResolver(DataSource<T> dataSource)
      : id = dataSource.id,
        _dataSource = dataSource;

  DataSourceResolver.byName(String domain, String name)
      : this.byID(DataHandler.normalizeID(domain, name));

  DataSourceResolver.byID(this.id);

  String get domain => DataHandler.splitID(id)[0];

  String get name => DataHandler.splitID(id)[1];

  DataSource<T> resolveDataSource() {
    _dataSource ??= DataSource.byID(id);
    return _dataSource;
  }

  Future<DataSource<T>> resolveDataSourceAsync([Duration timeout]) async {
    var dataSource = resolveDataSource();
    if (dataSource != null) return dataSource;

    timeout ??= Duration(seconds: 2);

    var completer = Completer<DataSource<T>>();

    var listen = DataHandler.onRegister.listen((_) {
      if (!completer.isCompleted && resolveDataSource() != null) {
        completer.complete(resolveDataSource());
      }
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(resolveDataSource());
      }
    });

    return completer.future.then((value) {
      listen.cancel();
      return value;
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceResolver &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          resolveDataSource() == other.resolveDataSource();

  @override
  int get hashCode => id.hashCode;
}

/// Represents a Data source
abstract class DataSource<T> extends DataHandler<T> {
  static final EventStream<DataSource> onRegister = EventStream();

  static final Map<String, DataSource> instances = {};

  static void register(DataSource instance) {
    if (instance == null) return;
    if (instance is DataRepository) {
      DataRepository.register(instance);
    } else {
      var id = instance.id;
      var prev = instances[id];
      if (identical(prev, instance)) return;

      if (prev != instance) {
        instances[id] = instance;
        onRegister.add(instance);
        DataHandler.onRegister.add(instance);
      }
    }
  }

  static DataSource<T> byName<T>(String domain, String name) {
    return byID(DataHandler.normalizeID(domain, name));
  }

  static DataSource<T> byID<T>(String id) {
    if (id == null) return null;
    var instance = instances[id];
    instance ??= DataRepository.byID(id);
    return instance;
  }

  DataSource(String domain, String name,
      {bool register = true,
      DataTransformerTo<T> transformerTo,
      DataTransformerToList<T> transformerToList,
      DataTransformerFrom<T> transformerFrom,
      DataTransformerFromList<T> transformerFromList})
      : super(domain, name,
            register: register,
            transformerTo: transformerTo,
            transformerToList: transformerToList,
            transformerFrom: transformerFrom,
            transformerFromList: transformerFromList);

  bool get isRegistered => DataSource.byID(id) == this;

  Future<List<T>> doOperation(
          DataSourceOperation operation, Map<String, String> parameters,
          [List<T> dataList]) =>
      doDataSourceOperation(this, operation, parameters, dataList);

  /// Gets data using [parameters] as selector.
  Future<List<T>> get([Map<String, dynamic> parameters]) async {
    var result = await getImpl(parameters);
    return transformToList(result);
  }

  static Map<String, dynamic> parametersFindByID(dynamic id) => {'--id': id};

  static Map<String, dynamic> parametersFindByIDRange(fromID, toID) =>
      {'--fromID': fromID, '--toID': toID};

  static Map<String, dynamic> parametersFind(Map<String, dynamic> filter) =>
      {'--filter': filter};

  /// Finds data by ID.
  Future<List<T>> findByID(dynamic id) async {
    return findByIDImpl(parametersFindByID(id));
  }

  /// Finds data by ID range.
  Future<List<T>> findByIDRange(dynamic fromID, dynamic toID) async {
    return get(parametersFindByIDRange(fromID, toID));
  }

  /// Finds data by [filter].
  Future<List<T>> find(Map<String, dynamic> filter) async {
    return get(parametersFind(filter));
  }

  Future getImpl(Map<String, dynamic> parameters);

  Future findByIDImpl(Map<String, dynamic> parameters) => getImpl(parameters);

  Future findByIDRangeImpl(Map<String, dynamic> parameters) =>
      findByIDImpl(parameters);

  Future findImpl(Map<String, dynamic> parameters) => getImpl(parameters);
}

/// Represents a data receiver, that can store or process data.
abstract class DataReceiver<T> extends DataHandler<T> {
  static final EventStream<DataReceiver> onRegister = EventStream();

  static final Map<String, DataReceiver> instances = {};

  static void register(DataReceiver instance) {
    if (instance == null) return;
    if (instance is DataRepository) {
      DataRepository.register(instance);
    } else {
      var name = instance.name;
      var prev = instances[name];
      if (identical(prev, instance)) return;

      if (prev != instance) {
        instances[name] = instance;
        onRegister.add(instance);
        DataHandler.onRegister.add(instance);
      }
    }
  }

  static DataReceiver<T> byName<T>(String domain, String name) {
    return DataReceiver.byID(DataHandler.normalizeID(domain, name));
  }

  static DataReceiver<T> byID<T>(String id) {
    if (id == null) return null;
    var instance = instances[id];
    instance ??= DataRepository.byID(id);
    return instance;
  }

  DataReceiver(String domain, String name, {bool register = true})
      : super(domain, name, register: register);

  Future putImpl(Map<String, dynamic> parameters, dynamic payload);

  /// Puts [dataList] using [parameters].
  Future<List<T>> put(
      {Map<String, dynamic> parameters, List<T> dataList}) async {
    var payload = transformFromList(dataList);
    var result = await putImpl(parameters, payload);
    return transformToList(result);
  }
}

/// Represents simultaneously a [DataSource] and a [DataReceiver].
abstract class DataRepository<T> implements DataSource<T>, DataReceiver<T> {
  static final EventStream<DataRepository> onRegister = EventStream();

  static final Map<String, DataRepository> instances = {};

  static void register(DataRepository instance) {
    if (instance == null) return;
    var id = instance.id;
    var prev = instances[id];
    if (identical(prev, instance)) return;

    if (prev != instance) {
      instances[id] = instance;
      onRegister.add(instance);
      DataHandler.onRegister.add(instance);
    }
  }

  static DataRepository<T> byName<T>(String domain, String name) {
    return byID(DataHandler.normalizeID(domain, name));
  }

  static DataRepository<T> byID<T>(String id) {
    if (id == null) return null;
    return instances[id];
  }

  @override
  final String domain;

  @override
  final String name;

  @override
  String get id => DataHandler.normalizeID(domain, name);

  DataRepository(this.domain, this.name, {bool register = true}) {
    DataHandler._check(this);

    register ??= true;

    if (register) {
      DataHandler.register(this);
    }
  }

  @override
  bool get isRegistered => DataRepository.byName(domain, name) == this;

  @override
  DataTransformerTo<T> _transformerTo;

  @override
  DataTransformerTo<T> get transformerTo => _transformerTo;

  @override
  set transformerTo(DataTransformerTo<T> value) {
    _transformerTo = value;
  }

  @override
  DataTransformerToList<T> _transformerToList;

  @override
  DataTransformerToList<T> get transformerToList => _transformerToList;

  @override
  set transformerToList(DataTransformerToList<T> value) {
    _transformerToList = value;
  }

  @override
  DataTransformerFrom<T> _transformerFrom;

  @override
  DataTransformerFrom<T> get transformerFrom => _transformerFrom;

  @override
  set transformerFrom(DataTransformerFrom<T> value) {
    _transformerFrom = value;
  }

  @override
  DataTransformerFromList<T> _transformerFromList;

  @override
  DataTransformerFromList<T> get transformerFromList => _transformerFromList;

  @override
  set transformerFromList(DataTransformerFromList<T> value) {
    _transformerFromList = value;
  }

  @override
  Future<List<T>> doOperation(
          DataSourceOperation operation, Map<String, String> parameters,
          [List<T> dataList]) =>
      doDataSourceOperation(this, operation, parameters, dataList);

  @override
  Future<List<T>> get([Map<String, dynamic> parameters]) async {
    var result = await getImpl(parameters);
    return transformToList(result);
  }

  @override
  Future<List<T>> put(
      {Map<String, dynamic> parameters, List<T> dataList}) async {
    var payload = transformFromList(dataList);
    var result = await putImpl(parameters, payload);
    return transformToList(result);
  }

  @override
  Future<List<T>> findByID(dynamic id) async {
    return get(DataSource.parametersFindByID(id));
  }

  @override
  Future<List<T>> findByIDRange(dynamic fromID, dynamic toID) async {
    return get(DataSource.parametersFindByIDRange(fromID, toID));
  }

  @override
  Future<List<T>> find(Map<String, dynamic> filter) async {
    return get(DataSource.parametersFind(filter));
  }

  @override
  Future findByIDImpl(Map<String, dynamic> parameters) => getImpl(parameters);

  @override
  Future findByIDRangeImpl(Map<String, dynamic> parameters) =>
      findByIDImpl(parameters);

  @override
  Future findImpl(Map<String, dynamic> parameters) => getImpl(parameters);

  @override
  dynamic transformFrom(T data) {
    if (_transformerFrom == null) {
      return data;
    }
    return _transformerFrom(data);
  }

  @override
  dynamic transformFromList(List<T> list) {
    if (_transformerFromList != null) {
      return _transformerFromList(list);
    }

    if (list == null || list.isEmpty) return null;
    return list.map(transformFrom).toList();
  }

  @override
  T transformTo(o) {
    if (_transformerTo == null) {
      return o;
    }
    return _transformerTo(o);
  }

  @override
  List<T> transformToList(dynamic o) {
    if (_transformerToList != null) {
      return _transformerToList(o);
    }

    if (o == null) return [];

    if (o is List) {
      if (o.isEmpty) return [];
      return o.map(transformTo).toList();
    } else {
      return [transformTo(o)];
    }
  }
}

/// Represents a [DataRepository] that wraps a [DataSource] instance and
/// a [DataReceiver] instance
class DataRepositoryWrapper<T> extends DataRepository<T> {
  final DataSource<T> source;

  final DataReceiver<T> receiver;

  DataRepositoryWrapper(String domain, String name, this.source, this.receiver,
      {bool register = true})
      : super(domain, name, register: register);

  @override
  Future<List<T>> get([Map<String, dynamic> parameters]) {
    return source.get(parameters);
  }

  @override
  Future getImpl(Map<String, dynamic> parameters) {
    throw UnimplementedError();
  }

  @override
  Future<List<T>> put({Map<String, dynamic> parameters, List<T> dataList}) {
    return receiver.put(parameters: parameters, dataList: dataList);
  }

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) {
    throw UnimplementedError();
  }

  @override
  dynamic transformFrom(T data) {
    if (receiver.transformerFrom != null) {
      return receiver.transformFrom(data);
    } else if (source.transformerFrom != null) {
      return source.transformFrom(data);
    } else {
      return super.transformFrom(data);
    }
  }

  @override
  dynamic transformFromList(List<T> list) {
    if (receiver.transformerFrom != null) {
      return receiver.transformFromList(list);
    } else if (source.transformerFrom != null) {
      return source.transformFromList(list);
    } else {
      return super.transformFromList(list);
    }
  }

  @override
  T transformTo(o) {
    if (receiver.transformerTo != null) {
      return receiver.transformTo(o);
    } else if (source.transformerTo != null) {
      return source.transformTo(o);
    } else {
      return super.transformTo(o);
    }
  }

  @override
  List<T> transformToList(dynamic o) {
    if (receiver.transformerTo != null) {
      return receiver.transformToList(o);
    } else if (source.transformerTo != null) {
      return source.transformToList(o);
    } else {
      return super.transformToList(o);
    }
  }
}

/// A [DataSource] based in a [DynCall] for requests.
class DataSourceDynCall<T> extends DataSource<T> {
  final DynCall<dynamic, List<T>> call;

  DataSourceDynCall(String domain, String name, this.call)
      : super(domain, name);

  @override
  Future getImpl(Map<String, dynamic> parameters) async {
    var response = await call.call(parameters);
    if (response == null) return [];
    if (response is List) return response;
    return [response];
  }
}

/// A [DataReceiver] based in a [DynCall] for requests.
class DataReceiverDynCall<T> extends DataReceiver<T> {
  final DynCall<dynamic, List<T>> call;

  DataReceiverDynCall(String domain, String name, this.call)
      : super(domain, name);

  @override
  Future<List> putImpl(Map<String, dynamic> parameters, dynamic payload) async {
    var response = await call.call(parameters);
    if (response == null) return [];
    if (response is List) return response;
    return [response];
  }
}

/// A [DataSource] based in a [DynCallExecutor] for requests.
class DataSourceExecutor<E, T> extends DataSource<T> {
  DynCall<E, List<T>> _call;

  DynCallExecutor get executor => _call.executor;

  DataSourceExecutor(String domain, String name, DynCallExecutor<E> executor)
      : super(domain, name) {
    _call = DynCall<E, List<T>>([], DynCallType.JSON,
        allowRetries: true,
        outputFilter: (o) => transformToList(o is List ? o : [o]));

    _call.executor = executor;
  }

  @override
  Future getImpl(Map<String, dynamic> parameters) async {
    var response = await _call.executor.call(_call, parameters, null);
    return response;
  }
}

/// A [DataReceiver] based in a [DynCallExecutor] for requests.
class DataReceiverExecutor<E, T> extends DataReceiver<T> {
  DynCall<E, List<T>> _call;

  DynCallExecutor get executor => _call.executor;

  DataReceiverExecutor(String domain, String name, DynCallExecutor<E> executor)
      : super(domain, name) {
    _call = DynCall<E, List<T>>([], DynCallType.JSON,
        allowRetries: true,
        outputFilter: (o) => transformToList(o is List ? o : [o]));

    _call.executor = executor;
  }

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) async {
    var response = await _call.executor.call(_call, parameters, null);
    return response;
  }
}

/// Represents a [HttpCall] to request data.
class DataCallHttp extends HttpCall {
  static Map<String, String> toParametersPattern(dynamic parametersPattern) {
    if (parametersPattern == null) return null;
    if (parametersPattern is String) {
      return decodeQueryString(parametersPattern);
    } else if (parametersPattern is Map) {
      return HttpCall.toQueryParameters(parametersPattern);
    } else if (parametersPattern is List) {
      parametersPattern.removeWhere((e) => isEmptyObject(e));
      if (parametersPattern.isEmpty) return null;

      var parameters = toParametersPattern(parametersPattern.first);
      var extraParameters = parametersPattern.sublist(1);

      for (var params in extraParameters) {
        var map = toParametersPattern(params);
        if (map != null) {
          parameters.addAll(map);
        }
      }

      return parameters;
    } else {
      return null;
    }
  }

  final Map<String, String> parametersPattern;

  DataCallHttp(
      {String baseURL,
      HttpClient client,
      HttpMethod method,
      String path,
      bool fullPath,
      dynamic parametersPattern,
      dynamic body,
      int maxRetries})
      : parametersPattern = toParametersPattern(parametersPattern),
        super(
            baseURL: baseURL,
            client: client,
            method: method,
            path: path,
            fullPath: fullPath,
            body: body,
            maxRetries: maxRetries);

  factory DataCallHttp.from(HttpCall config) {
    if (config == null) {
      return null;
    } else if (config is DataCallHttp) {
      return config;
    } else {
      return DataCallHttp(
          client: config.client,
          method: config.method,
          path: config.path,
          fullPath: config.fullPath,
          body: config.body,
          maxRetries: config.maxRetries);
    }
  }

  String _appendPath(String path, dynamic append) {
    if (!path.endsWith('/')) {
      path += '/';
    }
    path += '$append';
    return path;
  }

  String _resolvePattern(String s, Map<String, String> parameters) {
    if (s == null) return '';
    if (s.contains('{{')) {
      return buildStringPattern(s, parameters);
    } else {
      return s;
    }
  }

  @override
  Future<HttpResponse> requestHttpClient(HttpClient client, HttpMethod method,
      String path, bool fullPath, Map parameters, body) {
    if (parametersPattern != null && parametersPattern.isNotEmpty) {
      parameters ??= {};
      var queryParameters = HttpCall.toQueryParameters(parameters);
      for (var entry in parametersPattern.entries) {
        var k = _resolvePattern(entry.key, queryParameters);
        var v = _resolvePattern(entry.value, queryParameters);
        parameters[k] = v;
      }
    }

    if (parameters != null) {
      var findByID = parameters.remove('--id');
      if (findByID != null) {
        path = _appendPath(path, findByID);
        parameters = HttpCall.toQueryParameters(parameters);
      } else {
        var findFromID = parameters.remove('--fromID');
        var findToID = parameters.remove('--toID');

        if (findFromID != null && findToID != null) {
          path = _appendPath(path, '$findFromID..$findToID');
          parameters = HttpCall.toQueryParameters(parameters);
        } else {
          var filter = parameters.remove('--filter');
          if (filter != null && filter is Map) {
            parameters = HttpCall.toQueryParameters(filter);
          } else {
            parameters = HttpCall.toQueryParameters(parameters);
          }
        }
      }
    }

    return super
        .requestHttpClient(client, method, path, fullPath, parameters, body);
  }
}

String DEFAULT_DATA_SOURCE_BASE_URL;

String resolveDataSourceBaseURL(String url) {
  var baseURL = DEFAULT_DATA_SOURCE_BASE_URL;
  if (isEmptyString(baseURL, trim: true)) {
    baseURL = null;
  }
  return resolveURL(url, baseURL: baseURL);
}

class DataSourceOperationHttp<T> {
  final DataSourceOperation operation;

  String baseURL;
  String baseURLProxy;

  HttpClient client;
  HttpMethod method;
  String path;
  bool fullPath;
  dynamic parameters;
  dynamic body;

  DataTransformerTo<T> transformResponse;
  JSONTransformer jsonTransformer;

  Map<String, dynamic> samples;

  DataSourceOperationHttp(this.operation,
      {this.baseURL,
      this.baseURLProxy,
      this.client,
      this.method,
      this.path,
      this.fullPath = false,
      this.parameters,
      this.body,
      this.transformResponse,
      dynamic jsonTransformer,
      this.samples})
      : jsonTransformer = JSONTransformer.from(jsonTransformer);

  Map toJsonMap() {
    return removeNullEntries({
      'operation': getDataSourceOperationName(operation),
      'baseURL': baseURL,
      if (isNotEmptyString(baseURLProxy)) 'baseURLProxy': baseURLProxy,
      'method': getHttpMethodName(method),
      'path': path,
      'fullPath': fullPath,
      if (isNotEmptyObject(parameters)) 'parameters': parameters,
      'body': body,
      if (jsonTransformer != null)
        'jsonTransformer': jsonTransformer.toString(),
      if (samples != null) 'samples': samples
    });
  }

  String toJson([bool withIndent]) {
    return encodeJSON(toJsonMap(), withIndent: withIndent);
  }

  factory DataSourceOperationHttp.from(dynamic config) {
    if (config == null) return null;

    if (config is String) {
      config = parseJSON(config);
    }

    if (config is Map) {
      var operation = getDataSourceOperation(
          parseString(findKeyValue(config, ['operation', 'op'], true)));

      var baseURL = parseString(findKeyValue(config, ['baseurl', 'url'], true));
      baseURL = resolveDataSourceBaseURL(baseURL);

      var baseURLProxy =
          parseString(findKeyValue(config, ['baseurlproxy', 'urlproxy'], true));
      baseURLProxy = resolveDataSourceBaseURL(baseURLProxy);

      var method =
          getHttpMethod(parseString(findKeyValue(config, ['method'], true)));
      var path = parseString(findKeyValue(config, ['path'], true));
      var fullPath = parseBool(findKeyValue(config, ['fullPath'], true));
      var parameters =
          findKeyValue(config, ['parameters', 'args', 'properties'], true);
      var body = findKeyValue(config, ['body', 'content', 'payload'], true);

      var jsonTransformer = findKeyValue(
          config,
          ['jsonTransformer', 'transformResponse', 'transform', 'transformer'],
          true);

      var samples = findKeyValue(config, ['samples'], true);

      Map<String, dynamic> samplesMap;
      if (samples is Map) {
        samplesMap = Map<String, dynamic>.fromEntries(
            samples.entries.map((e) => MapEntry('${e.key}', e.value)));
      }

      return DataSourceOperationHttp(operation,
          baseURL: baseURL,
          baseURLProxy: baseURLProxy,
          method: method,
          path: path,
          fullPath: fullPath,
          parameters: parameters,
          body: body,
          jsonTransformer: jsonTransformer,
          samples: samplesMap);
    }

    return null;
  }

  String get httpConfigBaseURL {
    if (isNotEmptyString(baseURLProxy)) {
      return baseURLProxy.endsWith('/')
          ? '$baseURLProxy$baseURL'
          : '$baseURLProxy/$baseURL';
    } else {
      return baseURL;
    }
  }

  DataCallHttp _httpConfig;

  DataCallHttp get httpConfig {
    _httpConfig ??= DataCallHttp(
        baseURL: httpConfigBaseURL,
        client: client,
        method: method,
        path: path,
        fullPath: fullPath,
        parametersPattern: parameters,
        body: body,
        maxRetries: 3);
    return _httpConfig;
  }

  Future<T> call(Map<String, dynamic> parameters) async {
    var needCall = true;
    dynamic response;

    if (parameters != null && parameters.containsKey('SAMPLE')) {
      var sampleId = parameters['SAMPLE'];
      var sample = samples != null ? samples[sampleId] : null;

      print('SAMPLE: $sampleId');
      print(sample);

      needCall = false;
      response = sample;
    }

    if (needCall) {
      response = await httpConfig.callAndResolve(parameters);
    }

    if (transformResponse != null) {
      response = transformResponse(response);
    }

    if (jsonTransformer != null) {
      print('----------------------------------------------');
      print('jsonTransformer:');
      print(response);
      response = jsonTransformer.transform(response);
      print(response);
      print('----------------------------------------------');
    }

    return response;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceOperationHttp &&
          runtimeType == other.runtimeType &&
          operation == other.operation &&
          baseURL == other.baseURL &&
          method == other.method &&
          path == other.path &&
          fullPath == other.fullPath &&
          isEqualsDeep(parameters, other.parameters) &&
          isEqualsDeep(body, other.body);

  @override
  int get hashCode =>
      operation.hashCode ^
      baseURL.hashCode ^
      method.hashCode ^
      path.hashCode ^
      fullPath.hashCode ^
      deepHashCode(parameters) ^
      deepHashCode(body);
}

/// A [DataSource] based in a [DataCallHttp] for requests.
class DataSourceHttp<T> extends DataSource<T> {
  final String baseURL;
  final String baseURLProxy;
  final dynamic parameters;

  final DataSourceOperationHttp opGet;
  final DataSourceOperationHttp opFind;
  final DataSourceOperationHttp opFindByID;
  final DataSourceOperationHttp opFindByIDRange;

  DataSourceHttp(String domain, String name,
      {this.baseURL,
      this.baseURLProxy,
      this.parameters,
      this.opGet,
      this.opFind,
      this.opFindByID,
      this.opFindByIDRange,
      DataTransformerTo<T> transformerTo,
      DataTransformerToList<T> transformerToList,
      DataTransformerFrom<T> transformerFrom,
      DataTransformerFromList<T> transformerFromList})
      : super(domain, name,
            transformerTo: transformerTo,
            transformerToList: transformerToList,
            transformerFrom: transformerFrom,
            transformerFromList: transformerFromList) {
    _check();
  }

  Map toJsonMap() {
    return removeNullEntries({
      'domain': domain,
      'name': name,
      'baseURL': baseURL,
      if (isNotEmptyString(baseURLProxy)) 'baseURLProxy': baseURLProxy,
      if (isNotEmptyObject(parameters))
        'parameters': HttpCall.toQueryParameters(parameters),
      if (opGet != null) 'opGet': _opToJsonMap(opGet),
      if (opFind != null) 'opFind': _opToJsonMap(opFind),
      if (opFindByID != null) 'opFindByID': _opToJsonMap(opFindByID),
      if (opFindByIDRange != null)
        'opFindByIDRange': _opToJsonMap(opFindByIDRange),
    });
  }

  dynamic _opToJsonMap(DataSourceOperationHttp op) {
    if (op == null) return null;
    var map = deepCopy(op.toJsonMap());

    if (map['baseURL'] == baseURL) {
      map.remove('baseURL');
    }

    if (map['baseURLProxy'] == baseURLProxy) {
      map.remove('baseURLProxy');
    }

    var opParameters = map['parameters'];

    if (opParameters is Map && parameters != null) {
      var params = DataCallHttp.toParametersPattern(parameters);

      for (var entry in params.entries) {
        var key = entry.key;
        if (opParameters[key] == entry.value) {
          opParameters.remove(key);
        }
      }
    }

    return map;
  }

  String toJson([bool withIndent]) {
    return encodeJSON(toJsonMap(), withIndent: withIndent);
  }

  factory DataSourceHttp.from(dynamic config) {
    if (config == null) return null;

    if (config is DataSourceHttp) return config;

    if (config is String) {
      config = parseJSON(config);
    }

    if (config is Map) {
      var id = parseString(findKeyValue(config, ['id'], true));

      String domain;
      String name;

      if (id != null) {
        var parts = DataHandler.splitID(id);
        if (parts != null) {
          domain = parts[0];
          name = parts[1];
        }
      }

      domain = parseString(findKeyValue(config, ['domain'], true), domain);
      name = parseString(findKeyValue(config, ['name'], true), name);

      var baseURL = parseString(findKeyValue(config, ['baseurl', 'url'], true));
      baseURL = resolveDataSourceBaseURL(baseURL);

      var baseURLProxy =
          parseString(findKeyValue(config, ['baseurlproxy', 'urlproxy'], true));
      baseURLProxy = resolveDataSourceBaseURL(baseURLProxy);

      var parameters =
          findKeyValue(config, ['parameters', 'args', 'properties'], true);

      var opGet = DataSourceOperationHttp.from(
          findKeyValue(config, ['opGet', 'get'], true));
      var opFind = DataSourceOperationHttp.from(
          findKeyValue(config, ['opFind', 'find'], true));
      var opFindByID = DataSourceOperationHttp.from(
          findKeyValue(config, ['opFindByID', 'findByID'], true));
      var opFindByIDRange = DataSourceOperationHttp.from(
          findKeyValue(config, ['opFindByIDRange', 'findByIDRange'], true));

      return DataSourceHttp(domain, name,
          baseURL: baseURL,
          baseURLProxy: baseURLProxy,
          parameters: parameters,
          opGet: opGet,
          opFind: opFind,
          opFindByID: opFindByID,
          opFindByIDRange: opFindByIDRange);
    }

    return null;
  }

  void _check() {
    if (opGet == null &&
        opFind == null &&
        opFindByID == null &&
        opFindByIDRange == null) {
      throw ArgumentError('All operations are null!');
    }

    if (isNotEmptyObject(baseURL)) {
      _opSetBaseURL(opGet);
      _opSetBaseURL(opFind);
      _opSetBaseURL(opFindByID);
      _opSetBaseURL(opFindByIDRange);
    }

    if (parameters != null) {
      _opSetParametersPattern(opGet);
      _opSetParametersPattern(opFind);
      _opSetParametersPattern(opFindByID);
      _opSetParametersPattern(opFindByIDRange);
    }
  }

  void _opSetBaseURL(DataSourceOperationHttp op) {
    if (op != null) {
      op.baseURL ??= baseURL;
      op.baseURLProxy ??= baseURLProxy;
    }
  }

  void _opSetParametersPattern(DataSourceOperationHttp op) {
    if (op != null) {
      op.parameters =
          DataCallHttp.toParametersPattern([parameters, op.parameters]);
    }
  }

  void _checkOp(DataSourceOperationHttp operationHttp, String op) {
    if (operationHttp == null) {
      throw UnsupportedError('Unsupported DataSourceHttp operation: $op');
    }
  }

  @override
  Future getImpl(Map<String, dynamic> parameters) {
    _checkOp(opGet, 'get');
    return opGet.call(parameters);
  }

  @override
  Future findImpl(Map<String, dynamic> parameters) {
    var op = (opFind ?? opGet);
    _checkOp(op, 'find');
    return op.call(parameters);
  }

  @override
  Future findByIDImpl(Map<String, dynamic> parameters) {
    var op = (opFindByID ?? opGet);
    _checkOp(op, 'findByID');
    return op.call(parameters);
  }

  @override
  Future findByIDRangeImpl(Map<String, dynamic> parameters) {
    var op = (opFindByIDRange ?? opFindByID ?? opGet);
    _checkOp(op, 'findByIDRange');
    return op.call(parameters);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is DataSourceHttp &&
          runtimeType == other.runtimeType &&
          baseURL == other.baseURL &&
          isEqualsDeep(parameters, other.parameters) &&
          opGet == other.opGet &&
          opFind == other.opFind &&
          opFindByID == other.opFindByID &&
          opFindByIDRange == other.opFindByIDRange;

  @override
  int get hashCode =>
      super.hashCode ^
      baseURL.hashCode ^
      (baseURLProxy != null ? baseURLProxy.hashCode : 0) ^
      deepHashCode(parameters) ^
      (opGet != null ? opGet.hashCode : 0) ^
      (opFind != null ? opFind.hashCode : 0) ^
      (opFindByID != null ? opFindByID.hashCode : 0) ^
      (opFindByIDRange != null ? opFindByIDRange.hashCode : 0);
}

/// A [DataReceiver] based in a [DataCallHttp] for requests.
class DataReceiverHttp<T> extends DataReceiver<T> {
  final DataCallHttp httpConfig;

  DataReceiverHttp(String domain, String name,
      {String baseURL,
      HttpClient client,
      HttpMethod method,
      String path,
      bool fullPath,
      dynamic body})
      : httpConfig = DataCallHttp(
            baseURL: baseURL,
            client: client,
            method: method,
            path: path,
            fullPath: fullPath,
            body: body,
            maxRetries: 0),
        super(domain, name);

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) {
    return httpConfig.callAndResolve(parameters, body: payload);
  }
}

/// A [DataRepository] based in a [DataCallHttp] for requests.
class DataRepositoryHttp<T> extends DataRepository<T> {
  final DataCallHttp httpConfigSource;

  final DataCallHttp httpConfigReceiver;

  DataRepositoryHttp(String domain, String name,
      {String baseURL,
      HttpClient client,
      HttpMethod sourceMethod,
      String sourcePath,
      bool sourceFullPath,
      dynamic sourceBody,
      HttpMethod receiverMethod,
      String receiverPath,
      bool receiverFullPath,
      dynamic receiverBody})
      : httpConfigSource = DataCallHttp(
            baseURL: baseURL,
            client: client,
            method: sourceMethod ?? HttpMethod.GET,
            path: sourcePath,
            fullPath: sourceFullPath,
            body: sourceBody,
            maxRetries: 3),
        httpConfigReceiver = DataCallHttp(
            baseURL: baseURL,
            client: client,
            method: receiverMethod ?? HttpMethod.POST,
            path: receiverPath,
            fullPath: receiverFullPath,
            body: receiverBody,
            maxRetries: 0),
        super(domain, name);

  DataRepositoryHttp.fromConfig(String domain, String name,
      HttpCall httpConfigSource, HttpCall httpConfigReceiver)
      : httpConfigSource = DataCallHttp.from(httpConfigSource),
        httpConfigReceiver = DataCallHttp.from(httpConfigReceiver),
        super(domain, name);

  @override
  Future getImpl(Map<String, dynamic> parameters) {
    return httpConfigSource.callAndResolve(parameters);
  }

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) {
    return httpConfigReceiver.callAndResolve(parameters, body: payload);
  }
}

class DataSourceCall<T> {
  static final Map<DataSourceCall, DataSourceCall> _instances = {};

  static DataSourceCall<T> singleton<T>(DataSourceCall<T> instance) {
    if (instance == null) return null;

    var prev = _instances[instance];
    if (prev != null) return prev;

    _instances[instance] = instance;
    return instance;
  }

  final DataSourceResolver dataSourceResolver;
  final DataSourceOperation operation;
  final Map<String, String> parameters;

  factory DataSourceCall(
      DataSource<T> dataSource, DataSourceOperation operation, Map parameters) {
    var instance = DataSourceCall._(dataSource, operation, parameters);
    return singleton(instance);
  }

  DataSourceCall._(DataSource<T> dataSource, this.operation, Map parameters)
      : dataSourceResolver = DataSourceResolver(dataSource),
        parameters = HttpCall.toQueryParameters(parameters);

  factory DataSourceCall.byDataSourceName(String dataSourceDomain,
      String dataSourceName, DataSourceOperation operation, Map parameters) {
    var instance = DataSourceCall._byDataSourceID(
        DataHandler.normalizeID(dataSourceDomain, dataSourceName),
        operation,
        parameters);
    return singleton(instance);
  }

  factory DataSourceCall.byDataSourceID(
      String dataSourceID, DataSourceOperation operation, Map parameters) {
    var instance =
        DataSourceCall._byDataSourceID(dataSourceID, operation, parameters);
    return singleton(instance);
  }

  DataSourceCall._byDataSourceID(
      String dataSourceID, this.operation, Map parameters)
      : dataSourceResolver = DataSourceResolver.byID(dataSourceID),
        parameters = HttpCall.toQueryParameters(parameters);

  factory DataSourceCall.from(dynamic call) {
    if (call is DataSourceCall) return call;
    if (call is String) return DataSourceCall.parse(call);
    return null;
  }

  static final RegExp CALL_PATTERN =
      RegExp(r'\s*([\w-]+(?:\.[\w-]+)*:\w+)(?:(?:\.(\w+))?\((.*?)\))?\s*');
  static final RegExp PARAMETERS_DELIMITER_PATTERN = RegExp(r'\s*,\s*');

  factory DataSourceCall.parse(String call) {
    if (call == null) return null;

    var match = CALL_PATTERN.firstMatch(call);

    if (match == null) return null;

    var id = match.group(1);

    var operationName = match.group(2) ?? 'get';

    var operation = getDataSourceOperation(operationName);
    if (operation == null) return null;

    var parametersStr = (match.group(3) ?? '').trim();

    var parameters = decodeQueryString(parametersStr) ?? {};

    var dataSourceCall =
        DataSourceCall.byDataSourceID(id, operation, parameters);
    return dataSourceCall;
  }

  DataSource<T> get dataSource => dataSourceResolver.resolveDataSource();

  Future<DataSource<T>> get dataSourceAsync async =>
      dataSourceResolver.resolveDataSourceAsync();

  String get name => dataSourceResolver.name;

  String get operationName => getDataSourceOperationName(operation);

  static final Duration defaultCacheTimeout = Duration(seconds: 10);

  Duration _cacheTimeout = defaultCacheTimeout;

  Duration get cacheTimeout => _cacheTimeout;

  set cacheTimeout(Duration value) {
    _cacheTimeout = value ?? defaultCacheTimeout;

    if (_cacheTimeout.inMilliseconds < 100) {
      _cacheTimeout = Duration(milliseconds: 100);
    }
  }

  DataSourceResponse _lastResponse;

  Future<List<T>> call([List<T> dataList]) async {
    if (_lastResponse != null &&
        !_lastResponse.isExpired(_cacheTimeout.inMilliseconds)) {
      var same = _lastResponse.isSameCall(operation, parameters, dataList);
      if (same) {
        return deepCopy<List<T>>(_lastResponse.result);
      }
    }

    var dataSource = this.dataSource;
    dataSource ??= await dataSourceAsync;

    var result = await dataSource.doOperation(operation, parameters, dataList);
    _lastResponse = DataSourceResponse(operation, parameters, dataList, result);
    return result;
  }

  List<T> cachedCall([List<T> dataList]) {
    if (_lastResponse != null &&
        !_lastResponse.isExpired(_cacheTimeout.inMilliseconds)) {
      var same = _lastResponse.isSameCall(operation, parameters, dataList);
      if (same) {
        return deepCopy<List<T>>(_lastResponse.result);
      }
    }
    return null;
  }

  @override
  String toString() {
    var parametersStr = encodeQueryString(parameters);
    return '$name.$operationName($parametersStr)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceCall &&
          runtimeType == other.runtimeType &&
          dataSourceResolver == other.dataSourceResolver &&
          operation == other.operation &&
          isEqualsDeep(parameters, other.parameters);

  @override
  int get hashCode =>
      dataSourceResolver.hashCode ^
      operation.hashCode ^
      deepHashCode(parameters);
}

class DataSourceResponse<T> {
  final DataSourceOperation operation;
  final Map<String, String> parameters;
  final List<T> dataList;
  final List<T> result;
  final int time;

  DataSourceResponse(
      this.operation, this.parameters, this.dataList, this.result)
      : time = DateTime.now().millisecondsSinceEpoch;

  int get elapsedTime => DateTime.now().millisecondsSinceEpoch - time;

  bool isExpired(int timeout) => elapsedTime > timeout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSourceResponse &&
          runtimeType == other.runtimeType &&
          operation == other.operation &&
          isEqualsDeep(parameters, other.parameters) &&
          isEqualsDeep(dataList, other.dataList) &&
          isEqualsDeep(result, other.result);

  @override
  int get hashCode =>
      operation.hashCode ^
      deepHashCode(parameters) ^
      deepHashCode(dataList) ^
      deepHashCode(result);

  bool isSameCall(DataSourceOperation operation, Map<String, String> parameters,
      List dataList) {
    return operation == this.operation &&
        isEqualsDeep(parameters, this.parameters) &&
        isEqualsDeep(dataList, this.dataList);
  }
}
