/// No-op fuera de web: en mobile la limpieza de sesión usa el signOut local de
/// gotrue (`AuthCubit.clearLocalSession`), que es el comportamiento previo.
Future<void> clearPersistedSessionKeepingPkceVerifier() async {}