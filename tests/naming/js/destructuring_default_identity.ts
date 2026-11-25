const later = "outer";
const outside = () => later;
function stable(
  { self = () => self, earlier = () => later, later = () => later }:
    { self?: any; earlier?: any; later?: any; marker?: typeof outside }
) {
  return [self, earlier, later];
}
