// Gable modification notice. This file was changed by Gable.ai:
//   2026-11-19  Preserve JavaScript destructuring defaults in the generic AST
// See GABLE-MODIFICATIONS.md. End of Gable modification notice.
// A destructured parameter with a default value previously parsed
// to an opaque `OtherPat (ExprToPattern, [E (Assign (...))])` wrap
// around the destructure, hiding the field shape from the matcher.
// Now the destructure parses as a real `PatRecord` and the default
// rides on `parameter_classic.pdefault` -- the same slot
// `ParamClassic` already uses. A rule pattern that does not mention
// a default therefore matches both with- and without-default
// targets, just as `function $F($X) { ... }` already matched
// `function f(x = 5)` for simple parameters.

//MATCH:
function with_default({a, b} = {a: 1, b: 2}) { return a; }

//MATCH:
function without_default({a, b}) { return a; }

function with_callback_default({a, b}: Options = {a: () => {
  const local = source();
  sink(local);
}, b: 2}) { return a; }

function with_field_defaults({a: renamed = source(), b = seed}: Options) {
  return renamed;
}

//MATCH:
function with_nested_defaults({outer: {value = helper(), marker}}) {
  return value;
}

function array_parameter([first, second]) { return first; }

function array_default([first = helper(), second]) { return first; }
