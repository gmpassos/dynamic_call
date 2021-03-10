import 'package:dynamic_call/dynamic_call.dart';

class Sys {
  /// Defines a call with input field `query`, output as `STRING` and allows
  /// retries in case of errors.
  ///
  /// NOTE: the execution of this call can be of any type.
  final DynCall<dynamic, String> callSearch = DynCall<dynamic, String>(
      ['query'], DynCallType.STRING,
      allowRetries: true);

  /// Normal method to do the search. Parameter [query] will be
  /// passed to [callSearch] as input field `query`.
  Future<String?> doSearch(String query) {
    return callSearch.call({'query': query});
  }
}

void main() async {
  var sys = Sys();

  var httpClient = HttpClient('https://www.google.com/');

  var executorFactory = DynCallHttpExecutorFactory(httpClient);

  // Defines the executor of `sys.callSearch` as a HTTP request with a validator
  // that check fo `<html` tag at response.
  //
  // GET: https://www.google.com/search?q=$query
  executorFactory.call(sys.callSearch).executor(HttpMethod.GET,
      path: 'search',
      parametersMap: {'query': 'q'},
      outputValidator: (r, p, rp) => r != null && r.contains('<html'));

  var response = await sys.doSearch('dart dynamic_call');

  print(response);
}
