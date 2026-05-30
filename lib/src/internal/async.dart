import 'dart:async';
import 'dart:isolate';

class _SendPortResponse<T> {
  final int id;
  final T result;

  const _SendPortResponse(this.id, this.result);
}

class _SendFuncData<A, R> {
  final int id;
  final R Function(A args) func;
  final A args;

  _SendFuncData(this.id, this.args, this.func);
}

int _nextRequestId = 0;
final Map<int, Completer> _sendRequests = <int, Completer>{};

Future<SendPort>? _sendPort;

Future<SendPort> generateSendPort() {
  _sendPort ??= () async {
    final Completer<SendPort> completer = Completer<SendPort>();
    print("Creating send port");

    final ReceivePort receivePort = ReceivePort()
      ..listen((data) {
        print("Receiving on receivePort: ${data}");
        if (data is SendPort) {
          completer.complete(data);
          return;
        }
        if (data is _SendPortResponse) {
          print("Received response from isolate");
          // The helper isolate sent us a response to a request we sent.
          final completer = _sendRequests[data.id]!;
          _sendRequests.remove(data.id);
          completer.complete(data.result);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    await Isolate.spawn((SendPort sendPort) async {
      final ReceivePort helperReceivePort = ReceivePort()
        ..listen((dynamic data) {
          print("helper received any data $data");
          // On the helper isolate listen to requests and respond to them.
          if (data is _SendFuncData) {
            print("Received send func data");
            dynamic response = data.func(data.args);
            print("called and recieved reponse =)");
            sendPort.send(_SendPortResponse(data.id, response));
            return;
          }
          throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
        });

      print("Sending helper receive port");
      // Send the port to the main isolate on which we can receive requests.
      sendPort.send(helperReceivePort.sendPort);
    }, receivePort.sendPort);

    return completer.future;
  }();
  return _sendPort!;
}

Future<R> callAsync<A, R>(A args, R Function(A args) func) async {
  print("About to generate send port");
  final SendPort helperIsolateSendPort = await generateSendPort();
  print("Received send port");
  final int requestId = _nextRequestId++;
  final data = _SendFuncData(requestId, args, func);
  final completer = Completer<R>();
  _sendRequests[requestId] = completer;
  print("Sending data $data");
  helperIsolateSendPort.send(data);
  print("Sent data!");
  return completer.future;
}

// This doesn't work because cannot send a Pointer over a socket.
// Future<void> async_crypto_wipe(Pointer<Void> secret, int size) {
//   return callAsync((secret, size), (args) => crypto_wipe(args.$1, args.$2));
// }

////// EXAMPLE:
// /// A longer lived native function, which occupies the thread calling it.
// ///
// /// Do not call these kind of native functions in the main isolate. They will
// /// block Dart execution. This will cause dropped frames in Flutter applications.
// /// Instead, call these native functions on a separate isolate.
// ///
// /// Modify this to suit your own use case. Example use cases:
// ///
// /// 1. Reuse a single isolate for various different kinds of requests.
// /// 2. Use multiple helper isolates for parallel execution.
// Future<int> sumAsync(int a, int b) async {
//   final SendPort helperIsolateSendPort = await _helperIsolateSendPort;
//   final int requestId = _nextSumRequestId++;
//   final _SumRequest request = _SumRequest(requestId, a, b);
//   final Completer<int> completer = Completer<int>();
//   _sumRequests[requestId] = completer;
//   helperIsolateSendPort.send(request);
//   return completer.future;
// }
//
// /// A request to compute `sum`.
// ///
// /// Typically sent from one isolate to another.
// class _SumRequest {
//   final int id;
//   final int a;
//   final int b;
//
//   const _SumRequest(this.id, this.a, this.b);
// }
//
// /// A response with the result of `sum`.
// ///
// /// Typically sent from one isolate to another.
// class _SumResponse {
//   final int id;
//   final int result;
//
//   const _SumResponse(this.id, this.result);
// }
//
// /// Counter to identify [_SumRequest]s and [_SumResponse]s.
// int _nextSumRequestId = 0;
//
// /// Mapping from [_SumRequest] `id`s to the completers corresponding to the correct future of the pending request.
// final Map<int, Completer<int>> _sumRequests = <int, Completer<int>>{};
//
// class SendPortResponse<T> {
//   final int id;
//   final T result;
//
//   const SendPortResponse(this.id, this.result);
// }
//
// class SendFuncData<A, R> {
//   final int id;
//   final R Function(A args) func;
//   final A args;
//
//   SendFuncData(this.id, this.args, this.func);
// }
//
// /// The SendPort belonging to the helper isolate.
// Future<SendPort> _helperIsolateSendPort = () async {
//   // The helper isolate is going to send us back a SendPort, which we want to
//   // wait for.
//   final Completer<SendPort> completer = Completer<SendPort>();
//
//   // Receive port on the main isolate to receive messages from the helper.
//   // We receive two types of messages:
//   // 1. A port to send messages on.
//   // 2. Responses to requests we sent.
//   final ReceivePort receivePort = ReceivePort()
//     ..listen((dynamic data) {
//       if (data is SendPort) {
//         // The helper isolate sent us the port on which we can sent it requests.
//         completer.complete(data);
//         return;
//       }
//       if (data is _SumResponse) {
//         // The helper isolate sent us a response to a request we sent.
//         final Completer<int> completer = _sumRequests[data.id]!;
//         _sumRequests.remove(data.id);
//         completer.complete(data.result);
//         return;
//       }
//       throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
//     });
//
//   // Start the helper isolate.
//   await Isolate.spawn((SendPort sendPort) async {
//     final ReceivePort helperReceivePort = ReceivePort()
//       ..listen((dynamic data) {
//         // On the helper isolate listen to requests and respond to them.
//         if (data is _SumRequest) {
//           final int result = _bindings.sum_long_running(data.a, data.b);
//           final _SumResponse response = _SumResponse(data.id, result);
//           sendPort.send(response);
//           return;
//         }
//         throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
//       });
//
//     // Send the port to the main isolate on which we can receive requests.
//     sendPort.send(helperReceivePort.sendPort);
//   }, receivePort.sendPort);
//
//   // Wait until the helper isolate has sent us back the SendPort on which we
//   // can start sending requests.
//   return completer.future;
// }();
