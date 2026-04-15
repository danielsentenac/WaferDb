const defaultApiBase = String.fromEnvironment(
  'WAFERDB_API_BASE',
  defaultValue: 'http://127.0.0.1:8081/WaferDb/api',
);

const defaultDarkfieldRoot = String.fromEnvironment(
  'WAFERDB_DARKFIELD_ROOT',
  defaultValue: 'data/darkfield',
);
