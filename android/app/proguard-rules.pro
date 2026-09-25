# Project-specific R8/ProGuard rules.
#
# Keep this file focused on rules demonstrated to be necessary by a signed
# release build. The Flutter engine and the current sqflite_android and
# url_launcher_android plugins use normal static plugin registration and do
# not provide evidence that broad package-wide keep rules are needed.
#
# Package-wide keeps for those plugins would prevent meaningful shrinking.
# Add only narrow, reproducibly justified rules here when a real signed
# release build demonstrates that one is required.
