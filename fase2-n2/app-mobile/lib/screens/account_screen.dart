import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../brand.dart';
import '../config.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _trocarSenha(BuildContext context) async {
    final nova = TextEditingController();
    final conf = TextEditingController();
    String? erro;
    bool carregando = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Brand.card,
          title: const Text('Trocar senha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nova,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha (mín. 8 caracteres)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conf,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repita a nova senha'),
              ),
              if (erro != null) ...[
                const SizedBox(height: 10),
                Text(erro!, style: const TextStyle(color: Color(0xFFFF8A80))),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: carregando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: carregando
                  ? null
                  : () async {
                      if (nova.text.length < 8) {
                        setSt(() => erro = 'A senha precisa ter pelo menos 8 caracteres.');
                        return;
                      }
                      if (nova.text != conf.text) {
                        setSt(() => erro = 'As senhas não são iguais.');
                        return;
                      }
                      setSt(() {
                        carregando = true;
                        erro = null;
                      });
                      try {
                        await AuthService.instance.trocarSenha(nova.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Senha alterada com sucesso.')));
                        }
                      } catch (e) {
                        setSt(() {
                          carregando = false;
                          erro = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFF173A26),
                    child: Icon(Icons.storefront, color: Brand.acc, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: AuthService.instance.lojaNome,
                          builder: (_, nome, __) => Text(
                            nome.isEmpty ? 'Sua loja' : nome,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(AuthService.instance.email,
                            style: const TextStyle(color: Brand.mut)),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Brand.acc),
              title: const Text('Trocar senha'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _trocarSenha(context),
            ),
            const Divider(height: 1, color: Brand.line),
            ListTile(
              leading: const Icon(Icons.logout, color: Brand.bad),
              title: const Text('Sair'),
              onTap: () => AuthService.instance.sair(),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        const Center(
          child: Text('PulsoBiz Monitor  •  versão ${Config.versao}',
              style: TextStyle(color: Brand.mut, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('Suporte: fale com a sua equipe PulsoBiz',
              style: TextStyle(color: Brand.mut, fontSize: 12)),
        ),
      ],
    );
  }
}
