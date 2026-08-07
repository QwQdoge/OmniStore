## What
Added an `AnimatedSwitcher` to the "Sign In" button on the Account Page to provide a smooth transition between the interactive text state and the loading state.

## Why
To align with the Conductor agent guidelines for improving motion and interaction clarity by replacing abrupt layout jumps with subtle MD3 implicit motion during loading transitions.

## Result
When the user clicks the Sign In button, the button now smoothly cross-fades between the label text and the `CircularProgressIndicator` instead of snapping instantly.
