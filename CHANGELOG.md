## 2.0.1

- Sound null safety compatibility.
- mercury_client: ^2.0.1
- swiss_knife: ^3.0.6
- json_object_mapper: ^2.0.1 

## 2.0.0-nullsafety.2

- Null Safety adjustments.
- mercury_client: ^2.0.0-nullsafety.3
- swiss_knife: ^3.0.5

## 2.0.0-nullsafety.1

- Dart 2.12.0:
  - Sound null safety compatibility.
  - Update CI dart commands.
  - sdk: '>=2.12.0 <3.0.0'
- swiss_knife: ^3.0.2
- mercury_client: ^2.0.0-nullsafety.2
- json_object_mapper: ^2.0.0
- pedantic: ^1.11.0
- test: ^1.16.7
  
## 1.0.18

- Added `HTTPJSONOutputFilter`.

## 1.0.17

- `DynCall.call`: Added parameter `onProgress`.
- `DynCallHttpExecutor`: Added `queryString`.
- mercury_client: ^1.1.17
- swiss_knife: ^2.5.25

## 1.0.16

- Added parameter `noQueryString`.
- Added `buildURI`, in case you only want the call URI.
- mercury_client: ^1.1.16
- swiss_knife: ^2.5.20

## 1.0.15

- Fix compatibility with the new version of `mercury_client`.
- mercury_client: ^1.1.14
- swiss_knife: ^2.5.19

## 1.0.14

- `DataSourceOperationHttp`:
  - Added `baseURLProxy`.
  - Added `samples`.
- swiss_knife: ^2.5.18
- mercury_client: ^1.1.13
- json_object_mapper: ^1.1.3

## 1.0.13

- pedantic: ^1.9.2
- test: ^1.15.3
- test_coverage: ^0.4.3

## 1.0.12

- 1st working version of `DataSource` framework.
- Added `JSONTransformer` support to `DataSource`.
- mercury_client: ^1.1.10
- swiss_knife: ^2.5.12
- json_object_mapper: ^1.1.2
- CI: dartanalyzer

## 1.0.11

- Added: `DynCallFunctionExecutor`.
- Improved `DynCallHttpExecutor.bodyPattern`: renamed to `bodyBuilder`.
- Added `DataSource`, `DataReceiver` and `DataRepository`.
- mercury_client: ^1.1.9
- swiss_knife: ^2.5.5
- test_coverage: ^0.4.2

## 1.0.10

- Expose `requestParameters` for executor declaration.
- Executors: `parametersProviders` for parameters values from functions.  
- README.md badges.
- mercury_client: ^1.1.8
- swiss_knife: ^2.5.3

## 1.0.9

- Fix README.md

## 1.0.8

- Add example.
- Add API Documentation.
- sdk: '>=2.7.0 <3.0.0'
- dartfmt.
- mercury_client: ^1.1.7
- swiss_knife: ^2.4.1

## 1.0.7

- DynCallHttpExecutor.outputFilterPattern now accepts variables from request response JSON ( if dynCall.outputType == DynCallType.JSON ).
- mercury_client: ^1.1.4
- swiss_knife: ^2.3.9

## 1.0.6

- mercury_client: ^1.1.2

## 1.0.5

- mercury_client: ^1.1.1

## 1.0.4

- DynCallHttpExecutor: dynamic body, dynamic bodyPattern (String or Function), fullPath, outputInterceptor, setCredential(), authorizationFields
- DynCallHttpExecutorFactory: authorizationExecutor(...)
- Update dependencies:
    - mercury_client: 1.0.9
    
## 1.0.3

- DynCallHttpExecutor: body, bodyPattern, bodyType, outputValidator, outputFilter, outputFilterPattern

## 1.0.2

- Update dependencies:
    - Remove swiss_knife and enum_to_string.
    
## 1.0.1

- Add Author and License to README.

## 1.0.0

- Initial version, created by Stagehand
