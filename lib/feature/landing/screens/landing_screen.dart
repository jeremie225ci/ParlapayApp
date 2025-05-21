import 'package:flutter/material.dart';
import 'package:mk_mesenger/common/utils/colors.dart';
import 'package:mk_mesenger/common/widgets/custom_button.dart';
import 'package:mk_mesenger/feature/auth/screens/login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({Key? key}) : super(key: key);

  void navigateToLogin(BuildContext context) {
    Navigator.pushNamed(context, LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            SizedBox(height: size.height / 8),
            Flexible(
              child: Image.asset('assets/images/parlapay_launch2.png'),
            ),
            SizedBox(height: size.height / 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Read our Privacy Policy. Tap "Agree and continue" to accept the Terms of Service.',
                textAlign: TextAlign.center,
                style: TextStyle(color: unselectedItemColor),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: size.width * 0.8,
              child: CustomButton(
                text: 'AGREE AND CONTINUE',
                onPressed: () => navigateToLogin(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
