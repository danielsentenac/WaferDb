const defaultApiBase = String.fromEnvironment(
  'WAFERDB_API_BASE',
  defaultValue: 'http://127.0.0.1:8081/WaferDb/api',
);

const defaultDarkfieldRoot = String.fromEnvironment(
  'WAFERDB_DARKFIELD_ROOT',
  defaultValue: 'data/darkfield',
);

const defaultDarkfieldImportHost = String.fromEnvironment(
  'WAFERDB_DARKFIELD_IMPORT_HOST',
  defaultValue: 'olserver135',
);

const defaultStatusPhotoCameraDevice = String.fromEnvironment(
  'WAFERDB_STATUS_PHOTO_CAMERA_DEVICE',
  defaultValue: '/dev/video0',
);
