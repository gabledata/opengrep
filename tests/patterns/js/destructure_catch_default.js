//MATCH:
try { run(); } catch ({ value = make() }) { use(value); }
//MATCH:
try { run(); } catch ({ value = fallback }) { use(value); }
try { run(); } catch ({ value }) { use(value); }
try { run(); } catch ({ other = make() }) { use(other); }
