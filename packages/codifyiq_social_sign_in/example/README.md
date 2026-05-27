# codifyiq_social_sign_in example

```dart
import 'package:codifyiq_social_sign_in/codifyiq_social_sign_in.dart';
import 'package:flutter/material.dart';

Widget buildSignIn(Widget googleLogo, VoidCallback onGoogle) {
  return SocialSignInScreen(
    logo: Image.asset('assets/logo.png'),
    tagline: 'Welcome back',
    signInButtons: [
      SocialSignInButton(
        icon: googleLogo,
        label: 'Continue with Google',
        onPressed: onGoogle,
      ),
    ],
  );
}
```

> Provider logos are trademarked and are not bundled with this package — supply your own per
> each provider's branding guidelines.

A runnable catalog demonstrating every CodifyIQ component lives in the
[`example/` app at the repository root](https://github.com/CodifyIQ/codifyiq-core-components/tree/dev/example).
