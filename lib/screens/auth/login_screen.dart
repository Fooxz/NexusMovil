// lib/screens/auth/login_screen.dart
//
// Pantalla de inicio de sesión. Es un mockup navegable: el botón
// "INGRESAR" no valida nada contra un backend todavía (eso vendrá cuando
// se conecte la autenticación real), solo simula el paso a Home para que
// el flujo se pueda recorrer de punta a punta.

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_auth_header.dart';
import '../../widgets/nexus_widgets.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: NexusColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const NexusAuthHeader(
                    title: 'INICIA SESIÓN',
                    subtitle: 'Accede a tu cuenta de operador para continuar\ncon la tienda tech.',
                  ),
                  const SizedBox(height: 24),
                  const NexusFieldLabel('EMAIL'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: 'correo@operador.nexus'),
                  const SizedBox(height: 16),
                  const NexusFieldLabel('CONTRASEÑA'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: '••••••••••••', obscure: true),
                  const SizedBox(height: 22),
                  NexusPrimaryButton(
                    label: 'INGRESAR',
                    onPressed: () {
                      // Mockup: aún no hay autenticación real contra la BD.
                      Navigator.of(context)
                          .pushReplacementNamed(NexusRoutes.home);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta? ',
                        style: TextStyle(
                          fontSize: 11,
                          color: NexusColors.textDim,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.of(context).pushNamed(NexusRoutes.signup),
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: NexusColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const NexusBottomNav(currentIndex: 4),
    );
  }
}
