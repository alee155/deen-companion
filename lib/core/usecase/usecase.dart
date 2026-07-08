import 'package:equatable/equatable.dart';
import '../error/failures.dart';

/// Every use case in every feature implements this contract.
/// [Type] is the success return type, [Params] is the input.
/// Returning `Result<Type>` (see below) instead of throwing keeps
/// error handling explicit all the way up to the UI.
abstract class UseCase<Type, Params> {
  Future<Result<Type>> call(Params params);
}

/// Lightweight Either-style result type — avoids pulling in dartz/fpdart
/// for a single concept, but gives the same "no exceptions across layers" guarantee.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.data);
    if (self is Error<T>) return failure(self.failure);
    throw StateError('Unreachable');
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Error<T> extends Result<T> {
  final Failure failure;
  const Error(this.failure);
}

/// For use cases with no parameters.
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
