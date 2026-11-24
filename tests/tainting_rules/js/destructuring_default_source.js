// A tainted default reaches its binding, because the binding takes the
// default when the destructured value is undefined.

function objectDeclaration(input) {
  const { a = source() } = input;
  // ruleid: destructuring-default-source
  sink(a);
}

function arrayDeclaration(input) {
  const [a = source()] = input;
  // ruleid: destructuring-default-source
  sink(a);
}

function assignment(input) {
  let a;
  ({ a = source() } = input);
  // ruleid: destructuring-default-source
  sink(a);
}

function memberTarget(input, target) {
  ({ a: target.field = source() } = input);
  // ruleid: destructuring-default-source
  sink(target.field);
}

function laterDefaultReadsEarlierBinding(input) {
  const [a = source(), b = a] = input;
  // ruleid: destructuring-default-source
  sink(b);
}

// The lowering of a parameter pattern does not evaluate its defaults.
function parameter({ a = source() }) {
  // todoruleid: destructuring-default-source
  sink(a);
}

// A catch pattern is not lowered.
function catchBinding() {
  try {
    run();
  } catch ({ a = source() }) {
    // todoruleid: destructuring-default-source
    sink(a);
  }
}

// A default reaches only its own binding, and only after it is evaluated.

function cleanDefault(input) {
  const { a = clean() } = input;
  // ok: destructuring-default-source
  sink(a);
}

function siblingBinding(input) {
  const { a = source(), b } = input;
  // ok: destructuring-default-source
  sink(b);
}

function destructuredValue(input) {
  const { a = source() } = input;
  // ok: destructuring-default-source
  sink(input);
}

function earlierDefaultReadsLaterBinding(input) {
  const [b = a, a = source()] = input;
  // ok: destructuring-default-source
  sink(b);
}
