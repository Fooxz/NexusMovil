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
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NexusColors.cyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NX',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF04211F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'NEXUS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'INICIA SESIÓN',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Accede a tu cuenta de operador para continuar\ncon la tienda tech.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: NexusColors.textDim),
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
                      Navigator.of(context).pushReplacementNamed(NexusRoutes.home);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta? ',
                        style: TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(NexusRoutes.signup),
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
