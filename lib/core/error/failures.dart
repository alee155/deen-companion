/// Base failure type returned by the domain layer. Repositories catch
/// data-layer exceptions and translate them into one of these — the
/// presentation layer only ever deals with Failure, never raw exceptions.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong on our end. Try again.',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = "You're offline. Check your connection.",
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = "Couldn't load saved data."]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = "We couldn't find that."]);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}

class LocationFailure extends Failure {
  const LocationFailure([
    super.message = "Enable location access to get accurate prayer times.",
  ]);
}
