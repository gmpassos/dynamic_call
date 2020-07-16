import 'package:dynamic_call/dynamic_call.dart';

typedef DataTransformerTo<T> = T Function(dynamic o);
typedef DataTransformerToList<T> = List<T> Function(dynamic o);

typedef DataTransformerFrom<T> = dynamic Function(T data);
typedef DataTransformerFromList<T> = dynamic Function(List<T> dataList);

/// Base class for [DataSource] and [DataReceiver].
abstract class DataHandler<T> {
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

  static DataHandler<T> byName<T>(String name) {
    var instance = DataRepository.byName(name) as DataHandler<T>;
    if (instance != null) return instance;

    instance = DataSource.byName(name) as DataHandler<T>;
    if (instance != null) return instance;

    instance = DataReceiver.byName(name) as DataHandler<T>;
    return instance;
  }

  final String name;

  DataHandler(this.name, {bool register = true}) {
    register ??= true;

    if (register && hasName) {
      DataHandler.register(this);
    }
  }

  bool get hasName => name != null && name.isNotEmpty;

  DataTransformerTo<T> _transformerTo;

  DataTransformerTo<T> get transformerTo => _transformerTo;

  set transformerTo(DataTransformerTo<T> value) {
    _transformerTo = value;
  }

  T transformTo(dynamic o) {
    if (_transformerTo == null) {
      return o;
    }
    return _transformerTo(o);
  }

  DataTransformerToList<T> _transformerToList;

  DataTransformerToList<T> get transformerToList => _transformerToList;

  set transformerToList(DataTransformerToList<T> value) {
    _transformerToList = value;
  }

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

  DataTransformerFrom<T> _transformerFrom;

  DataTransformerFrom<T> get transformerFrom => _transformerFrom;

  set transformerFrom(DataTransformerFrom<T> value) {
    _transformerFrom = value;
  }

  DataTransformerFromList<T> _transformerFromList;

  DataTransformerFromList<T> get transformerFromList => _transformerFromList;

  set transformerFromList(DataTransformerFromList<T> value) {
    _transformerFromList = value;
  }

  dynamic transformFrom(T data) {
    if (_transformerFrom == null) {
      return data;
    }
    return _transformerFrom(data);
  }

  dynamic transformFromList(List<T> list) {
    if (_transformerFromList != null) {
      return _transformerFromList(list);
    }

    if (list == null || list.isEmpty) return null;
    return list.map(transformFrom).toList();
  }
}

/// Represents a Data source
abstract class DataSource<T> extends DataHandler<T> {
  static final Map<String, DataSource> instances = {};

  static void register(DataSource instance) {
    if (instance == null) return;
    if (instance is DataRepository) {
      DataRepository.register(instance);
    } else {
      var name = instance.name;
      var prev = instances[name];
      if (identical(prev, instance)) return;
      instances[name] = instance;
    }
  }

  static DataSource<T> byName<T>(String name) {
    if (name == null) return null;
    var instance = instances[name];
    instance ??= DataRepository.byName(name);
    return instance;
  }

  DataSource(String name, {bool register = true})
      : super(name, register: register);

  Future getImpl(Map<String, dynamic> parameters);

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
    return get(parametersFindByID(id));
  }

  /// Finds data by ID range.
  Future<List<T>> findByIDRange(dynamic fromID, dynamic toID) async {
    return get(parametersFindByIDRange(fromID, toID));
  }

  /// Finds data by [filter].
  Future<List<T>> find(Map<String, dynamic> filter) async {
    return get(parametersFind(filter));
  }
}

/// Represents a data receiver, that can store or process data.
abstract class DataReceiver<T> extends DataHandler<T> {
  static final Map<String, DataReceiver> instances = {};

  static void register(DataReceiver instance) {
    if (instance == null) return;
    if (instance is DataRepository) {
      DataRepository.register(instance);
    } else {
      var name = instance.name;
      var prev = instances[name];
      if (identical(prev, instance)) return;
      instances[name] = instance;
    }
  }

  static DataReceiver<T> byName<T>(String name) {
    if (name == null) return null;
    var instance = instances[name];
    instance ??= DataRepository.byName(name);
    return instance;
  }

  DataReceiver(String name, {bool register = true})
      : super(name, register: register);

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
  static final Map<String, DataRepository> instances = {};

  static void register(DataRepository instance) {
    if (instance == null) return;
    var name = instance.name;
    var prev = instances[name];
    if (identical(prev, instance)) return;
    instances[name] = instance;
  }

  static DataRepository<T> byName<T>(String name) {
    if (name == null) return null;
    return instances[name];
  }

  @override
  final String name;

  DataRepository(this.name, {bool register = true}) {
    register ??= true;

    if (register && hasName) {
      DataHandler.register(this);
    }
  }

  @override
  bool get hasName => name != null && name.isNotEmpty;

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

  DataRepositoryWrapper(String name, this.source, this.receiver,
      {bool register = true})
      : super(name, register: register);

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

  DataSourceDynCall(String name, this.call) : super(name);

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

  DataReceiverDynCall(String name, this.call) : super(name);

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

  DataSourceExecutor(String name, DynCallExecutor<E> executor) : super(name) {
    _call = DynCall<E, List<T>>([], DynCallType.JSON,
        allowRetries: true,
        outputFilter: (o) => transformToList(o is List ? o : [o]));

    _call.executor = executor;
  }

  @override
  Future getImpl(Map<String, dynamic> parameters) async {
    var response = await _call.executor.call(_call, parameters);
    return response;
  }
}

/// A [DataReceiver] based in a [DynCallExecutor] for requests.
class DataReceiverExecutor<E, T> extends DataReceiver<T> {
  DynCall<E, List<T>> _call;

  DynCallExecutor get executor => _call.executor;

  DataReceiverExecutor(String name, DynCallExecutor<E> executor) : super(name) {
    _call = DynCall<E, List<T>>([], DynCallType.JSON,
        allowRetries: true,
        outputFilter: (o) => transformToList(o is List ? o : [o]));

    _call.executor = executor;
  }

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) async {
    var response = await _call.executor.call(_call, parameters);
    return response;
  }
}

/// Represents a [HttpCall] to request data.
class DataCallHttp extends HttpCall {
  DataCallHttp(
      {String baseURL,
      HttpClient client,
      HttpMethod method,
      String path,
      bool fullPath,
      dynamic body,
      int maxRetries})
      : super(
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

  @override
  Future<HttpResponse> requestHttpClient(HttpClient client, HttpMethod method,
      String path, bool fullPath, Map<String, dynamic> parameters, body) {
    Map<String, String> queryParameters;

    if (parameters != null) {
      var findByID = parameters.remove('--id');
      if (findByID != null) {
        path = _appendPath(path, findByID);
        queryParameters = toQueryParameters(parameters);
      } else {
        var findFromID = parameters.remove('--fromID');
        var findToID = parameters.remove('--toID');

        if (findFromID != null && findToID != null) {
          path = _appendPath(path, '$findFromID..$findToID');
          queryParameters = toQueryParameters(parameters);
        } else {
          var filter = parameters.remove('--filter');
          if (filter != null && filter is Map) {
            queryParameters = toQueryParameters(filter);
          } else {
            queryParameters = toQueryParameters(parameters);
          }
        }
      }
    }

    return super.requestHttpClient(
        client, method, path, fullPath, queryParameters, body);
  }
}

/// A [DataSource] based in a [DataCallHttp] for requests.
class DataSourceHttp<T> extends DataSource<T> {
  final DataCallHttp httpConfig;

  DataSourceHttp(String name,
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
            maxRetries: 3),
        super(name);

  @override
  Future getImpl(Map<String, dynamic> parameters) {
    return httpConfig.callAndResolve(parameters);
  }
}

/// A [DataReceiver] based in a [DataCallHttp] for requests.
class DataReceiverHttp<T> extends DataReceiver<T> {
  final DataCallHttp httpConfig;

  DataReceiverHttp(String name,
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
        super(name);

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) {
    return httpConfig.callAndResolve(parameters, body: payload);
  }
}

/// A [DataRepository] based in a [DataCallHttp] for requests.
class DataRepositoryHttp<T> extends DataRepository<T> {
  final DataCallHttp httpConfigSource;

  final DataCallHttp httpConfigReceiver;

  DataRepositoryHttp(String name,
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
        super(name);

  DataRepositoryHttp.fromConfig(
      String name, HttpCall httpConfigSource, HttpCall httpConfigReceiver)
      : httpConfigSource = DataCallHttp.from(httpConfigSource),
        httpConfigReceiver = DataCallHttp.from(httpConfigReceiver),
        super(name);

  @override
  Future getImpl(Map<String, dynamic> parameters) {
    return httpConfigSource.callAndResolve(parameters);
  }

  @override
  Future putImpl(Map<String, dynamic> parameters, dynamic payload) {
    return httpConfigReceiver.callAndResolve(parameters, body: payload);
  }
}
