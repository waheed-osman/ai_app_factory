import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_app_factory/services/github_builder.dart';
import 'package:ai_app_factory/services/http_transport.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  _Call(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;
}

class _FakeGitHub implements HttpTransport {
  _FakeGitHub(this.apkZip);

  final Uint8List apkZip;
  final List<_Call> calls = [];
  int _blobCount = 0;

  HttpResult _json(int status, Object data) => HttpResult(
        status,
        const {'content-type': 'application/json'},
        Uint8List.fromList(utf8.encode(jsonEncode(data))),
      );

  @override
  Future<HttpResult> send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? jsonBody,
    bool followRedirects = true,
  }) async {
    calls.add(_Call(method, url, headers ?? const {}, jsonBody));
    final path = url.path;

    if (url.host == 'blob.example.com') {
      return HttpResult(200, const {}, apkZip);
    }
    if (method == 'POST' && path == '/user/repos') {
      return _json(201, {
        'name': 'demo-1',
        'default_branch': 'main',
        'owner': {'login': 'octo'},
      });
    }
    if (method == 'GET' && path == '/repos/octo/demo-1/git/ref/heads/main') {
      return _json(200, {
        'object': {'sha': 'head1'},
      });
    }
    if (method == 'POST' && path.endsWith('/git/blobs')) {
      _blobCount++;
      return _json(201, {'sha': 'blob$_blobCount'});
    }
    if (method == 'POST' && path.endsWith('/git/trees')) {
      return _json(201, {'sha': 'tree1'});
    }
    if (method == 'POST' && path.endsWith('/git/commits')) {
      return _json(201, {'sha': 'commit1'});
    }
    if (method == 'PATCH' && path.endsWith('/git/refs/heads/main')) {
      return _json(200, {});
    }
    if (method == 'GET' && path.endsWith('/actions/runs')) {
      return _json(200, {
        'workflow_runs': [
          {
            'id': 77,
            'status': 'completed',
            'conclusion': 'success',
            'head_sha': 'commit1',
          },
        ],
      });
    }
    if (method == 'GET' && path.endsWith('/actions/runs/77/artifacts')) {
      return _json(200, {
        'artifacts': [
          {'id': 5, 'name': 'apk', 'expired': false},
        ],
      });
    }
    if (method == 'GET' && path.endsWith('/actions/artifacts/5/zip')) {
      return HttpResult(
        302,
        const {'location': 'https://blob.example.com/a.zip'},
        Uint8List(0),
      );
    }
    return _json(404, {'message': 'unexpected $method $path'});
  }
}

Uint8List _zipWithApk(List<int> apkBytes) {
  final archive = Archive()
    ..addFile(ArchiveFile('app-release.apk', apkBytes.length, apkBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('creates a repo, pushes one commit, waits and downloads the APK',
      () async {
    final fake = _FakeGitHub(_zipWithApk([1, 2, 3]));
    final builder = GitHubBuilder(
      token: 'secret-token',
      transport: fake,
      pollInterval: Duration.zero,
      sleep: (_) async {},
    );

    final repo = await builder.createRepo('demo-1');
    expect(repo.owner, 'octo');
    expect(repo.url, 'https://github.com/octo/demo-1');

    final sha = await builder.pushFiles(repo, {
      'pubspec.yaml': 'name: demo_app\n',
      'lib/main.dart': 'void main() {}\n',
    }, 'Initial commit');
    expect(sha, 'commit1');
    expect(fake.calls.where((c) => c.url.path.endsWith('/git/blobs')).length, 2);

    final treeCall =
        fake.calls.firstWhere((c) => c.url.path.endsWith('/git/trees'));
    final tree = (treeCall.body as Map<String, dynamic>)['tree'] as List;
    expect(tree.map((entry) => (entry as Map)['path']),
        ['lib/main.dart', 'pubspec.yaml']);

    final run = await builder.waitForRun(repo, sha);
    expect(run['conclusion'], 'success');

    final apk = await builder.downloadApk(repo, run['id'] as int);
    expect(apk, [1, 2, 3]);
  });

  test('never sends the token to the signed download URL', () async {
    final fake = _FakeGitHub(_zipWithApk([9]));
    final builder = GitHubBuilder(
      token: 'secret-token',
      transport: fake,
      sleep: (_) async {},
    );
    const repo = GitHubRepo('octo', 'demo-1', 'main');

    await builder.downloadApk(repo, 77);

    final blobCall =
        fake.calls.firstWhere((c) => c.url.host == 'blob.example.com');
    expect(blobCall.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')));
    final apiCall = fake.calls.firstWhere((c) => c.url.host == 'api.github.com');
    expect(apiCall.headers['Authorization'], 'Bearer secret-token');
  });
}
