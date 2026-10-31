import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/session_provider.dart';
import '../../../account/domain/services/account_auth_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({required this.sessionProvider, super.key});

  final SessionProvider sessionProvider;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _linkStarted = false;
  bool _changePasswordMode = false;
  String? _message;
  String? _error;
  late final Future<SupabaseClient?> _clientFuture;

  @override
  void initState() {
    super.initState();
    _clientFuture = widget.sessionProvider.client.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SupabaseClient?>(
      future: _clientFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cuenta')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final client = snapshot.data;
        if (client == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Cuenta')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'La cuenta no está disponible sin conexión a Supabase.'),
              ),
            ),
          );
        }
        return _accountScaffold(client);
      },
    );
  }

  Widget _accountScaffold(SupabaseClient client) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: SafeArea(
        child: StreamBuilder<AuthState>(
          stream: client.auth.onAuthStateChange,
          initialData: AuthState(
            AuthChangeEvent.initialSession,
            client.auth.currentSession,
          ),
          builder: (context, snapshot) {
            final user =
                snapshot.data?.session?.user ?? client.auth.currentUser;
            if (user == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo iniciar la sesión. Revisá la conexión para acceder a tus datos guardados.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          widget.sessionProvider.resetAnonymousSignIn();
                          await widget.sessionProvider.ensureUserId();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final anonymous = user.isAnonymous;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  anonymous ? 'Sesión anónima' : 'Cuenta registrada',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(anonymous
                    ? 'Tus viajes se guardan en esta sesión. Si perdés el acceso a este dispositivo, podrías no recuperarlos. Agregá un correo para protegerlos.'
                    : 'Tu correo permite recuperar tus viajes desde otros dispositivos.'),
                if (user.email != null) ...[
                  const SizedBox(height: 10),
                  Text('Correo: ${user.email}'),
                ],
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        sessionProvider: widget.sessionProvider,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Editar perfil personal'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                if ((anonymous && !_linkStarted) ||
                    (!anonymous && _changePasswordMode)) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: anonymous ? 'Contraseña' : 'Nueva contraseña',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
                const SizedBox(height: 16),
                if (anonymous) ...[
                  FilledButton(
                    onPressed: _busy || _linkStarted
                        ? null
                        : () => _linkAnonymous(client),
                    child: Text(_linkStarted
                        ? 'Enviar de nuevo el correo'
                        : 'Proteger mis viajes'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => _signIn(client),
                    child: const Text('Ya tengo una cuenta · Iniciar sesión'),
                  ),
                ],
                TextButton(
                  onPressed: _busy ? null : () => _sendRecovery(client),
                  child: const Text('Recuperar contraseña'),
                ),
                if (!anonymous) ...[
                  if (_changePasswordMode)
                    FilledButton(
                      onPressed: _busy ? null : () => _changePassword(client),
                      child: const Text('Guardar contraseña'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _changePasswordMode = true;
                        _message = null;
                      }),
                      child: const Text('Cambiar contraseña'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => _signOut(client),
                    child: const Text('Cerrar sesión'),
                  ),
                ],
                if (anonymous) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'La verificación conserva esta sesión y su UUID. Si el correo ya pertenece a otra cuenta, iniciá sesión con esa cuenta; sus datos no se combinarán automáticamente.',
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _linkAnonymous(SupabaseClient client) async {
    await _run(() async {
      final email = _email.text.trim();
      if (email.isEmpty) throw const AuthException('Escribí tu correo.');
      if (_password.text.length < 8) {
        throw const AuthException(
            'La contraseña debe tener al menos 8 caracteres.');
      }
      await _auth(client).convertAnonymousAccount(
        email: email,
        password: _password.text,
      );
      setState(() {
        _linkStarted = true;
        _message =
            'Te enviamos un correo para verificar la dirección. Abrí el enlace para terminar de proteger esta misma cuenta.';
      });
    }, conflictAware: true);
  }

  Future<void> _signIn(SupabaseClient client) async {
    await _run(() async {
      final oldUserId = client.auth.currentUser?.id;
      final signedInUserId = await _auth(client).signInExistingAccount(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (oldUserId != null && oldUserId != signedInUserId) {
        setState(() => _message =
            'Iniciaste sesión en la cuenta existente. Los datos de la sesión anónima anterior no se transfirieron.');
      }
    }, conflictAware: true);
  }

  Future<void> _sendRecovery(SupabaseClient client) async {
    await _run(() async {
      final email = _email.text.trim();
      if (email.isEmpty) {
        throw const AuthException('Escribí el correo de tu cuenta.');
      }
      await _auth(client).requestPasswordRecovery(email);
      setState(() => _message =
          'Si existe una cuenta con ese correo, recibirás un enlace para recuperar el acceso.');
    });
  }

  Future<void> _changePassword(SupabaseClient client) async {
    await _run(() async {
      if (_password.text.length < 8) {
        throw const AuthException(
            'La contraseña debe tener al menos 8 caracteres.');
      }
      await _auth(client).setPassword(_password.text);
      _password.clear();
      setState(() {
        _changePasswordMode = false;
        _message = 'Contraseña actualizada.';
      });
    });
  }

  Future<void> _signOut(SupabaseClient client) async {
    await _run(() async {
      await _auth(client).signOut();
      widget.sessionProvider.resetAnonymousSignIn();
      await widget.sessionProvider.ensureUserId();
      if (mounted) {
        setState(() => _message =
            'Sesión cerrada. Se inició una sesión nueva; los datos de la cuenta anterior se conservan y no se transfieren.');
      }
    });
  }

  AccountAuthService _auth(SupabaseClient client) =>
      AccountAuthService(SupabaseAccountAuthGateway(client));

  Future<void> _run(Future<void> Function() action,
      {bool conflictAware = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      final text = error.toString();
      setState(() => _error = conflictAware &&
              (text.toLowerCase().contains('already') ||
                  text.toLowerCase().contains('registered') ||
                  text.toLowerCase().contains('exists'))
          ? 'Ese correo ya pertenece a otra cuenta. Iniciá sesión con esa cuenta; no vamos a mezclar ni sobrescribir sus datos.'
          : _readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readableError(Object error) {
    if (error is AuthException) return error.message;
    return 'No se pudo completar la operación. Revisá tu conexión e intentá de nuevo.';
  }
}
