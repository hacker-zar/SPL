import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/session_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.sessionProvider, super.key});

  final SessionProvider sessionProvider;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = await widget.sessionProvider.client;
      final userId = await widget.sessionProvider.currentUserId();
      if (client == null || userId == null) {
        throw StateError(
            'La sesión no está disponible. Conectate e intentá de nuevo.');
      }
      final row =
          await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (row != null) {
        _name.text = row['full_name'] as String? ?? '';
        _phone.text = row['phone'] as String? ?? '';
      }
    } on Object catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      final client = await widget.sessionProvider.client;
      final userId = await widget.sessionProvider.currentUserId();
      if (client == null || userId == null) {
        throw StateError('La sesión no está disponible.');
      }
      await client.from('profiles').upsert({
        'id': userId,
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      }, onConflict: 'id');
      if (mounted) setState(() => _notice = 'Perfil guardado.');
    } on Object catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _message(Object error) {
    if (error is PostgrestException) {
      return 'No se pudo cargar o guardar el perfil. Aplicá la migración de Supabase y revisá la conexión.';
    }
    return error is StateError
        ? error.message
        : 'No se pudo conectar. Intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Perfil personal')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                      'Estos datos se guardan en tu cuenta y no son necesarios para calcular un viaje.'),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Teléfono (opcional)')),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Text(_notice!),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Guardando…' : 'Guardar perfil')),
                ],
              ),
      );
}
