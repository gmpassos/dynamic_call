import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dynamic_call/dynamic_call.dart';
import 'package:swiss_knife/swiss_knife.dart';
import 'package:test/test.dart';

/*
--------------------------------------------------------------------------------
| HTTP SERVER:
--------------------------------------------------------------------------------
 */

class TestServer {
  io.HttpServer server;

  Completer _serverOpen;

  int get port => server != null ? server.port : -1;

  bool get isOpen => _serverOpen != null ? _serverOpen.isCompleted : false;

  void waitOpen() async {
    if (isOpen) return;
    await _serverOpen.future;
  }

  void open() async {
    _serverOpen = Completer();

    server = await io.HttpServer.bind(
      io.InternetAddress.loopbackIPv4,
      9180,
    );

    print('Server running: $server at port: $port');

    _serverOpen.complete(true);

    await for (io.HttpRequest request in server) {
      var uri = request.uri;
      var path = uri.path;
      var query = uri.queryParameters;
      var contentType = request.headers.contentType;
      var body = await _decodeBody(contentType, request);

      var response;

      var mathFinByID = RegExp(r'get/(\d+)$').allMatches(path);
      var mathFinByIDRange = RegExp(r'get/(\d+)..(\d+)$').allMatches(path);

      if (mathFinByID.isNotEmpty) {
        var id = mathFinByID.first.group(1);
        response = '[$id]';
      } else if (mathFinByIDRange.isNotEmpty) {
        var match = mathFinByIDRange.first;

        var from = int.parse(match.group(1));
        var to = int.parse(match.group(2));

        var list = <int>[];
        for (var i = from; i <= to; i++) {
          list.add(i);
        }

        response = '[' + list.join(',') + ']';
      } else if (path.endsWith('put')) {
        if (body == null) {
          response = 'null';
        } else {
          response = RegExp(r'^\[.*?\]$').hasMatch(body) ? body : '[$body]';
        }
      } else if (query != null && query.isNotEmpty) {
        if (query['name'] == 'joe') {
          response = '[1001]';
        } else if (query['name'] == 'smith') {
          response = '[1002]';
        } else {
          response = 'null';
        }
      } else {
        response = 'null';
      }

      print(
          'TestServer{path: $path ; query: $query ; contentType: $contentType ; body: <$body> ; response: <$response>}');

      request.response.headers.contentType =
          io.ContentType.parse('application/json');

      request.response.write(response);
      await request.response.close();
    }
  }

  Future<String> _decodeBody(
      io.ContentType contentType, io.HttpRequest r) async {
    if (contentType != null) {
      var charset = contentType.charset;

      if (charset != null) {
        charset = charset.trim().toLowerCase();

        if (charset == 'utf8' || charset == 'utf-8') {
          return utf8.decoder.bind(r).join();
        } else if (charset == 'latin1' ||
            charset == 'latin-1' ||
            charset == 'iso-8859-1') {
          return latin1.decoder.bind(r).join();
        }
      }
    }

    return latin1.decoder.bind(r).join();
  }

  void close() async {
    print('Closing server $server');
    await server.close(force: true);
  }
}

/*
--------------------------------------------------------------------------------
| TESTS:
--------------------------------------------------------------------------------
 */

void main() {
  group('DataRepository', () {
    TestServer testServer;

    setUp(() {
      testServer = TestServer();
      testServer.open();
    });

    tearDown(() {
      testServer.close();
    });

    test('DynCall', () async {
      var callGet = DynCall<String, List<int>>([], DynCallType.STRING,
          outputFilter: (s) => parseIntsFromInlineList(s));

      callGet.executor = DynCallStaticExecutor<String>('1,2,3,4,5,6');

      var callPut = DynCall<String, List<int>>([], DynCallType.STRING,
          outputFilter: (s) => parseIntsFromInlineList(s));

      callPut.executor = DynCallStaticExecutor<String>('10,11,12');

      DataSource<int> source = DataSourceDynCall('foo', 'test', callGet);
      DataReceiver<int> receiver = DataReceiverDynCall('foo', 'test', callPut);

      var repository =
          DataRepositoryWrapper('foo', 'dynCall', source, receiver);

      var got = await repository.get();

      expect(got, equals([1, 2, 3, 4, 5, 6]));

      var put = await repository.put(dataList: [10, 11, 12]);

      expect(put, equals([10, 11, 12]));
    });

    test('DataRepositoryWrapper(StaticExecutor)', () async {
      DataSource<int> source = DataSourceExecutor<String, int>(
          'foo', 'test', DynCallStaticExecutor<String>('1,2,3,4,5,6'))
        ..transformerToList = (o) => parseIntsFromInlineList(o);

      DataReceiver<int> receiver = DataReceiverExecutor<String, int>(
          'foo', 'test', DynCallStaticExecutor<String>('10,11,12'))
        ..transformerToList = (o) {
          return parseIntsFromInlineList(o);
        }
        ..transformerFromList = (l) {
          return l == null ? '' : l.join(',');
        };

      var repository =
          DataRepositoryWrapper('foo', 'staticExecutor', source, receiver);

      var got = await repository.get();

      expect(got, equals([1, 2, 3, 4, 5, 6]));

      var put = await repository.put(dataList: [10, 11, 12]);

      expect(put, equals([10, 11, 12]));
    });

    test('DataRepositoryWrapper(FunctionExecutor)', () async {
      DataSource<int> source = DataSourceExecutor<String, int>(
          'foo',
          'test',
          DynCallFunctionExecutor<String, dynamic>(
              (d, p) async => '1,2,3,4,5,6'))
        ..transformerToList = (o) => parseIntsFromInlineList(o);

      DataReceiver<int> receiver = DataReceiverExecutor<List<int>, int>(
          'foo',
          'test',
          DynCallFunctionExecutor<List<int>, dynamic>(
              (d, p) async => [10, 11, 12]));

      var repository =
          DataRepositoryWrapper('foo', 'functionExecutor', source, receiver);

      var got = await repository.get();

      expect(got, equals([1, 2, 3, 4, 5, 6]));

      var put = await repository.put(dataList: [10, 11, 12]);

      expect(put, equals([10, 11, 12]));
    });

    test('DataRepositoryWrapper(Http)', () async {
      testServer.waitOpen();

      var baseURL = 'http://localhost:${testServer.port}/tests';
      var client = HttpClient(baseURL);

      DataSource<int> source = DataSourceHttp('foo', 'test',
          baseURL: baseURL,
          opGet: DataSourceOperationHttp(DataSourceOperation.get, path: 'get'))
        ..transformerToList = (o) {
          return parseIntsFromInlineList(o);
        }
        ..transformerFromList = (l) {
          return l == null ? '' : l.join(',');
        };
      DataReceiver<int> receiver = DataReceiverHttp('foo', 'test',
          client: client, method: HttpMethod.POST, path: 'put')
        ..transformerToList = (o) {
          return parseIntsFromInlineList(o);
        }
        ..transformerFromList = (l) {
          return l == null ? '' : l.join(',');
        };

      var repository =
          DataRepositoryWrapper('foo', 'api_src_rcv', source, receiver);

      var findByID = await repository.findByID(123);
      expect(findByID, equals([123]));

      var findByIDRange = await repository.findByIDRange(10, 20);
      expect(
          findByIDRange, equals([10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]));

      var find = await repository.find({'name': 'joe'});
      expect(find, equals([1001]));

      var put = await repository.put(dataList: [1, 2, 3]);
      expect(put, equals([1, 2, 3]));
    });

    test('DataRepositoryHttp', () async {
      testServer.waitOpen();

      var client = HttpClient('http://localhost:${testServer.port}/tests');

      var repository = DataRepositoryHttp(
        'foo',
        'api_http',
        client: client,
        sourcePath: 'get',
        receiverPath: 'put',
      );

      var findByID = await repository.findByID(110);
      expect(findByID, equals([110]));

      var findByIDRange = await repository.findByIDRange(1, 10);
      expect(findByIDRange, equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

      var find = await repository.find({'name': 'smith'});
      expect(find, equals([1002]));

      var put = await repository.put(dataList: [1, 2, 3, 4, 5]);
      expect(put, equals([1, 2, 3, 4, 5]));
    });
  });
}
