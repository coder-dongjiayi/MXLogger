/// Display name for a native path or a browser file handle.
String mxFileName(String path) => path.replaceAll('\\', '/').split('/').last;
