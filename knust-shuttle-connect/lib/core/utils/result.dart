/// Minimal success/failure wrapper used by use cases so the presentation
/// layer never needs to catch data-layer exceptions directly.
class Result<T> {
  final T? value;
  final String? error;

  const Result._({this.value, this.error});

  const Result.success(T value) : this._(value: value);
  const Result.failure(String message) : this._(error: message);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}
