const handler = () => 0;
const outer = 1;
try {
  throw {};
} catch ({ handler = () => handler, other = () => outer, early = () => late, late }) {
  handler();
}
try {
  throw [];
} catch ([element = () => element]) {
  element();
}
let assigned = 0;
for ({ assigned = () => assigned } of []) {
}
