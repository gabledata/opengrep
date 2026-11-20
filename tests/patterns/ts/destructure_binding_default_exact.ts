//MATCH:
function defaulted({ value = make(), marker }) { return value; }
function differentDefault({ value = other(), marker }) { return value; }
function noDefault({ value, marker }) { return value; }
