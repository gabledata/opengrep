function outer(
  { callback = ({ nested }) => { const captured = nested; return captured; } }:
    { callback?: any }
) {
  return callback;
}
