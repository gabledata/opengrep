function parameterDefault({ a } = fallback) {}
function parameterPlain({ a }) {}
function shorthandDefault({ a = fallback }) {}
function shorthandPlain({ a }) {}
function renamedDefault({ a: b = fallback }) {}
function renamedPlain({ a: b }) {}
function nestedDefault({ a: { b } = fallback }) {}
function nestedPlain({ a: { b } }) {}
function elementDefault([a = fallback, b]) {}
function elementPlain([a, b]) {}
function nestedElementDefault([[a] = fallback]) {}
function nestedElementPlain([[a]]) {}
try {} catch ({ a = fallback }) {}
try {} catch ({ a }) {}
try {} catch ([a = fallback]) {}
try {} catch ([a]) {}
for ({ a = fallback } of xs) {}
for ({ a } of xs) {}
for ([a = fallback] of xs) {}
for ([a] of xs) {}
