//MATCH:
try { run(); } catch ({ value }) { use(value); }
//MATCH:
try { run(); } catch ({ value = make() }) { use(value); }
try { run(); } catch ({ other = make() }) { use(other); }
try { run(); } catch ({ other: value }) { use(value); }
