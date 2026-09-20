package com.dcenhance.xtream_player.dexcoreupdate;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import java.io.File;
import java.io.FileNotFoundException;

/** Exposes only a single verified private APK to Android's package installer. */
public final class DceArchiveUpdateProvider extends ContentProvider {
  @Override public boolean onCreate() { return true; }
  @Override public String getType(Uri uri) { return "application/vnd.android.package-archive"; }
  @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
    if (!"r".equals(mode) || getContext() == null || uri.getPathSegments().size() != 1) throw new FileNotFoundException("Read-only verified update required");
    try {
      File root = new File(getContext().getFilesDir(), "dexcore-archive-updates").getCanonicalFile();
      File file = new File(root, uri.getLastPathSegment()).getCanonicalFile();
      if (!file.getPath().startsWith(root.getPath() + File.separator) || !file.isFile()) throw new FileNotFoundException("Unknown update");
      return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    } catch (java.io.IOException invalid) { throw new FileNotFoundException("Unknown update"); }
  }
  @Override public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) { return new MatrixCursor(new String[]{"_display_name", "_size"}); }
  @Override public int delete(Uri uri, String selection, String[] selectionArgs) { return 0; }
  @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { return 0; }
  @Override public Uri insert(Uri uri, ContentValues values) { return null; }
}
