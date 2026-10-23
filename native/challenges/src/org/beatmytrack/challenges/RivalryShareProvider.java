package org.beatmytrack.challenges;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

/** A private, read-only provider; recipients receive a temporary URI read grant. */
public final class RivalryShareProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }

    private File image(Uri uri) throws FileNotFoundException {
        if (getContext() == null || uri == null || !"content".equals(uri.getScheme())
                || !(getContext().getPackageName()+".rivalry-share").equals(uri.getAuthority())
                || uri.getPathSegments().size() != 1) throw new FileNotFoundException("Unknown result image");
        try { return RivalryShareFiles.resolve(getContext().getCacheDir(),uri.getLastPathSegment()); }
        catch (IOException error) { throw new FileNotFoundException("Unknown result image"); }
    }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) throw new FileNotFoundException("Result images are read-only");
        return ParcelFileDescriptor.open(image(uri),ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public String getType(Uri uri) { return "image/png"; }

    @Override public Cursor query(Uri uri, String[] projection, String selection, String[] arguments, String order) {
        File file;
        try { file = image(uri); } catch (FileNotFoundException error) { return null; }
        String[] columns = projection == null ? new String[]{OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE} : projection;
        Object[] values = new Object[columns.length];
        for (int index = 0; index < columns.length; index++) {
            if (OpenableColumns.DISPLAY_NAME.equals(columns[index])) values[index] = "Beat my track - Weekly Rivalry.png";
            else if (OpenableColumns.SIZE.equals(columns[index])) values[index] = file.length();
        }
        MatrixCursor cursor = new MatrixCursor(columns,1);
        cursor.addRow(values);
        return cursor;
    }

    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException("Read-only"); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] arguments) { throw new UnsupportedOperationException("Read-only"); }
    @Override public int delete(Uri uri, String selection, String[] arguments) { throw new UnsupportedOperationException("Read-only"); }
}
