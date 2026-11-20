//MATCH:
function plain({ value, marker }) { return value; }
//MATCH:
function defaulted({ value = make(), marker }) { return value; }
//MATCH:
function identifierDefault({ value = fallbackValue, marker }) { return value; }
function otherField({ other = make(), marker }) { return other; }
