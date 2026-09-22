// lib/screens/auth/signup_screen.dart
//
// Registro de cuenta. Igual que Login, es un mockup navegable: el botón
// "CREAR CUENTA" no persiste nada todavía, solo lleva a Home.

import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../theme/nexus_theme.dart';
import '../../widgets/nexus_bottom_nav.dart';
import '../../widgets/nexus_widgets.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexusColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    'CREAR CUENTA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Regístrate en la central de operaciones de compra\ndigital NEXUS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, height: 1.5, color: NexusColors.textDim),
                  ),
                  const SizedBox(height: 24),
                  const NexusFieldLabel('NOMBRE'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: 'Tu nombre completo'),
                  const SizedBox(height: 16),
                  const NexusFieldLabel('EMAIL'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: 'tu@correo.nexus'),
                  const SizedBox(height: 16),
                  const NexusFieldLabel('CONTRASEÑA'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: '••••••••••••', obscure: true),
                  const SizedBox(height: 16),
                  const NexusFieldLabel('CONFIRMAR CONTRASEÑA'),
                  const SizedBox(height: 6),
                  const NexusTextField(hint: '••••••••••••', obscure: true),
                  const SizedBox(height: 22),
                  NexusPrimaryButton(
                    label: 'CREAR CUENTA',
                    onPressed: () {
                      // Mockup: aún no hay persistencia real contra la BD.
                      Navigator.of(context).pushReplacementNamed(NexusRoutes.home);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Ya tienes cuenta? ',
                        style: TextStyle(fontSize: 11, color: NexusColors.textDim),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pushReplacementNamed(NexusRoutes.login),
                        child: const Text(
                          'Ingresar',
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
