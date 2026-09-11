import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// Raw Firebase auth state.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Convenience: current uid or null.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// Realtime profile document for the signed-in user (tier, donations, …).
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) {
    final data = snap.data();
    if (data == null) return null;
    return AppUser.fromMap(uid, data);
  });
});

final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(appUserProvider).valueOrNull?.tier.isPaid ?? false,
);

class AuthService {
  AuthService(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);
    final user = AppUser(
      uid: cred.user!.uid,
      email: email,
      displayName: displayName,
      locale: locale,
    );
    await _db.collection('users').doc(user.uid).set(user.toMap());
    return cred;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  Future<void> updateProfile(String uid, Map<String, dynamic> patch) =>
      _db.collection('users').doc(uid).set(patch, SetOptions(merge: true));
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);
